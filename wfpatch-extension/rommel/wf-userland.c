#define _GNU_SOURCE 1
#include <stdbool.h>
#include <stdio.h>
#include <glob.h>
#include <stdarg.h>
#include <pthread.h>
#include <dlfcn.h>
#include <stddef.h>
#include <errno.h>
#include <stdlib.h>
#include <time.h>
#include <assert.h>
#include <unistd.h>
#include <pthread.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <sys/syscall.h>
#include <limits.h>
#include <fcntl.h>
#include <stdint.h>
#include <string.h>
#include <link.h>
#include <elf.h>

#include "wf-userland.h"

static void *wf_plt_trampoline(char *name, void *func_ptr);


static struct wf_configuration wf_config;

#define log(...) do { fprintf(stderr, "wf-userland: "__VA_ARGS__); } while(0)
#define die(...) do { log("[ERROR] " __VA_ARGS__); exit(EXIT_FAILURE); } while(0)
#define die_perror(m, ...) do { perror(m); die(__VA_ARGS__); } while(0)

static FILE *wf_log_file;
static void wf_log(char *fmt, ...) {
    if (wf_log_file) {
        va_list(args);
        va_start(args, fmt);
        vfprintf(wf_log_file, fmt, args);
        fflush(wf_log_file);
    }
}

// Returns the a timestamp in miliseconds. The first call zeroes the clock
static struct timespec wf_ts0;
static void wf_timestamp_reset(void) { // returns 0 seconds first time called
    clock_gettime(CLOCK_REALTIME, &wf_ts0);
}

static double wf_timestamp(void) { // returns 0 seconds first time called
    struct timespec ts;
    clock_gettime(CLOCK_REALTIME, &ts);
    return (ts.tv_sec - wf_ts0.tv_sec)*1000. + (ts.tv_nsec - wf_ts0.tv_nsec) / 1000000.;
}



////////////////////////////////////////////////////////////////
// Kernel Interface
static unsigned pagesize;
static void *addr_to_page(void *addr) {
    if (pagesize == 0) {
        pagesize = sysconf(_SC_PAGESIZE);
    }
    void *page = addr - ((uintptr_t) addr % pagesize);
    return page;
}

int wf_kernel_pin(void* start, void* end) {
    // Pin code as non shared for AS generations
    uintptr_t start_page = (uintptr_t)addr_to_page(start);
    uintptr_t end_page   = (uintptr_t)addr_to_page(end + pagesize - 1);

    int rc = syscall(1002, start_page, end_page - start_page);
    log("memory pin [%p:+0x%lx]: rc=%d\n", (void*)start_page,
        end_page - start_page, rc);
    if (rc == -1)
        die_perror("wf_kernel_pin", "Could not unshare the text segment");
    
    return rc;
}

int wf_kernel_as_new(void) {
    int rc = syscall(1000);
    // log("AS create: %d\n", rc);
    if (rc == -1)
        die_perror("wf_kernel_as_new", "Could not create a new address space");
    return rc;
}

int wf_kernel_as_switch(int as_id) {
    int rc = syscall(1001, as_id);
    // log("AS switch: %d %d\n", as_id, rc);
    if (rc == -1)
        die_perror("wf_kernel_as_switch", "Could not migrate to the new address space");
    return rc;
}

int wf_kernel_as_delete(int as_id) {
    int rc = syscall(1003, as_id);
    // log("address space delete(%d)=%d\n", as_id, rc);
    return rc;
}


////////////////////////////////////////////////////////////////
// Apply Patch
// Magic Names: ehdr, shstr
#define offset_to_ptr(offset) (((void*) (ehdr)) + ((int) (offset)))
#define shdr_from_idx(idx) offset_to_ptr(ehdr->e_shoff + ehdr->e_shentsize * idx);
#define section_name(shdr) (((char*) offset_to_ptr(shstr->sh_offset)) + shdr->sh_name)

extern void *_GLOBAL_OFFSET_TABLE_;

bool wf_relocate_calc(unsigned type,
                        /* input */  uintptr_t reloc_src, uintptr_t reloc_dst, uintptr_t reloc_addend,
                        /* output */ void **loc, uint64_t *val, char *size) {

    uintptr_t S = reloc_src, A = reloc_addend, P = reloc_dst;

#define is_pc32_rel(x) ((INT_MIN <= (intptr_t) (x)) && ((intptr_t) (x) <= INT_MAX))

    *loc = (void*) reloc_dst;
    switch (type) {
    case R_X86_64_NONE:
        return false;
    case R_X86_64_PC32:
    case R_X86_64_PLT32:
    case R_X86_64_GOTPCREL:
    case R_X86_64_REX_GOTPCRELX:
        *val = (uint64_t)(S + A - P);
        assert(is_pc32_rel(*val) && "Patch was loaded tooo far away");
        *size = 4;
        break;
    case R_X86_64_32S:
        *val = (uint64_t)((int32_t)S + A);
        *size = 4;
        break;
    case R_X86_64_32:
        *val = (uint64_t)((uint32_t)S + A);
        *size = 4;
        break;
    case R_X86_64_64:
        *val = (uint64_t) S + A;
        *size = 8;
        break;
    default:
        die("Unsupported relocation %d for source (0x%lx <- 0x%lx)\n",
            type, reloc_dst, reloc_src);
    }
    return true;
}

void *wf_find_symbol(char * name);

void wf_relocate(Elf64_Ehdr *ehdr, void *elf_end, Elf64_Shdr* shdr) {
    // Section Header String table
    Elf64_Shdr *shstr = shdr_from_idx(ehdr->e_shstrndx);
    
    Elf64_Shdr *shdr_symtab = shdr_from_idx(shdr->sh_link);
    Elf64_Sym *symbol_table = offset_to_ptr(shdr_symtab->sh_offset);
    
    Elf64_Shdr *shdr_strtab = shdr_from_idx(shdr_symtab->sh_link);
    char *strtab = offset_to_ptr(shdr_strtab->sh_offset);

    // Which section should be modified
    Elf64_Shdr * shdr_target = shdr_from_idx(shdr->sh_info);

    unsigned  rela_num = shdr->sh_size / shdr->sh_entsize;
    log("[%s] %d relocs for %s\n",
           section_name(shdr),
           rela_num,
           section_name(shdr_target));

    if (!strncmp(".rela.debug_", section_name(shdr), 12)) {
        log(".. debug relocations, skipping.\n");
        return;
    }

    Elf64_Rela * rela = offset_to_ptr(shdr->sh_offset);
    for (unsigned i = 0; i < rela_num; i++) {
        Elf64_Rela * rela = offset_to_ptr(shdr->sh_offset + i * shdr->sh_entsize);

        // Where to modify
        uintptr_t reloc_dst = (uintptr_t)  offset_to_ptr(shdr_target->sh_offset + rela->r_offset);

        // What should be written into that place
        Elf64_Sym * symbol = &symbol_table[ELF64_R_SYM(rela->r_info)];
        char *symbol_name = strtab + symbol->st_name;
        void *reloc_src;
        if (symbol->st_shndx != 0) {
            Elf64_Shdr * symbol_section = shdr_from_idx(symbol->st_shndx);
            if (ELF64_ST_TYPE(symbol->st_info) == STT_SECTION) {
                symbol_name = section_name(symbol_section);
                reloc_src = offset_to_ptr(symbol_section->sh_offset);
            } else {
                reloc_src = offset_to_ptr(symbol_section->sh_offset + symbol->st_value);
            }
        } else if (symbol_name && *symbol_name == 0) {
            log("Empty Symbol name... continue on this...\n");
            continue;
        } else { 
            // Find Name in original binary
            reloc_src = wf_find_symbol(symbol_name);
            if (!reloc_src) {
                reloc_src = dlsym(RTLD_DEFAULT, symbol_name);
                reloc_src = wf_plt_trampoline(symbol_name, reloc_src);
            }
            if (!reloc_src) {
                log("Probaly `%s' is a library function that was not called in original binary. We do not support this yet.\n", symbol_name);
                die("Could not find symbol %s.\n", symbol_name);
            }
        }

        // FIXME: log_debug
        // log("   %p+(%ld) -> %p (%s)\n", (void*)reloc_dst, rela->r_addend, reloc_src, symbol_name);

        void* loc;
        uint64_t val;
        char size;
        bool action = wf_relocate_calc(ELF64_R_TYPE(rela->r_info),
                                       (uintptr_t) reloc_src, reloc_dst, rela->r_addend,
                                       &loc, &val, &size);
        if (!action) continue;

        if (loc < (void*) ehdr || loc >= elf_end) {
			die("bad relocation 0x%p for symbol %s\n", loc, symbol_name);
		}

        // log("   *%p = 0x%lx [%d]\n", loc, val, size);

        if (size == 4) {
            *(uint32_t *) loc = val;
        } else if (size == 8) {
            *(uint64_t *) loc = val;
        } else
            die("Invalid relocation size");

    }
}

struct kpatch_patch_func {
	unsigned long new_addr;
	unsigned long new_size;
	unsigned long old_addr;
	unsigned long old_size;
	unsigned long sympos;
	char *name;
	char *objname;
};

struct kpatch_relocation {
	unsigned long dest;
	unsigned int type;
	int external;
	long addend;
	char *objname; /* object to which this rela applies to */
	struct kpatch_symbol *ksym;
};

struct kpatch_symbol {
	unsigned long src;
	unsigned long sympos;
	unsigned char bind, type;
	char *name;
	char *objname; /* object to which this sym belongs */
};

struct kpatch_patch_dynrela {
	unsigned long dest;
	unsigned long src;
	unsigned long type;
	unsigned long sympos;
	char *name;
	char *objname;
	int external;
	long addend;
};

struct kpatch_pre_patch_callback {
	int (*callback)(void *obj);
	char *objname;
};
struct kpatch_post_patch_callback {
	void (*callback)(void *obj);
	char *objname;
};
struct kpatch_pre_unpatch_callback {
	void (*callback)(void *obj);
	char *objname;
};
struct kpatch_post_unpatch_callback {
	void (*callback)(void *obj);
	char *objname;
};

static void *wf_vspace_end = NULL;
static void *wf_vspace_bump_ptr = NULL;

void * wf_vspace_reservere(uintptr_t bytes) {
    uintptr_t size = ((bytes + 0xfff) & (~((uintptr_t) 0xfff)));
    wf_vspace_bump_ptr -= size;
    log("vspace %p (%lx %lx)\n", wf_vspace_bump_ptr, bytes, size);
    return wf_vspace_bump_ptr;
}


static Elf64_Ehdr * wf_load_elf(char *filename, bool close_to_binary, void **elf_end) {
    int fd = open(filename, O_RDONLY);
    if (!fd) die_perror("open", "Could not open patch file: %s", filename);

    // Mapt the whole file
    struct stat size;
    if (fstat(fd, &size) == -1) die_perror("fstat", "Could not determine size: %s\n", filename);

    void *hint = 0;
    if (close_to_binary) {
        hint = wf_vspace_reservere(size.st_size);
    }
    void *elf_start = mmap(hint, size.st_size, PROT_WRITE, MAP_PRIVATE, fd, 0);
    if (elf_start == MAP_FAILED) die_perror("mmap", "Could not map patch: %s", filename);
    *elf_end = elf_start + size.st_size;

    // 1. Find Tables
    Elf64_Ehdr *ehdr = elf_start;

	if (strncmp((const char *)ehdr->e_ident, "\177ELF", 4) != 0) {
		die("Patch is not an ELF file");
	}
    if (ehdr->e_ident[EI_CLASS] != ELFCLASS64) {
        die("Patch is not an 64-Bit ELF");
    }
    return ehdr;
}

static void wf_unload_elf(Elf64_Ehdr *ehdr, void *elf_end) {
    munmap(ehdr, (uintptr_t) elf_end - (uintptr_t) ehdr);
}


struct wf_symbol {
    char * name;
    void * addr;
};

static struct wf_symbol *wf_symbols = NULL;
static unsigned wf_symbol_count;


static int dl_iterate_cb_stop;
static int
dl_iterate_cb(struct dl_phdr_info *info, size_t size, void *data) {
    Elf64_Ehdr *ehdr = (Elf64_Ehdr *) data;
    // We only process the main binary
    if (dl_iterate_cb_stop) return 0;
    dl_iterate_cb_stop = 1;

    // Section Header String table
    Elf64_Shdr *shstr = shdr_from_idx(ehdr->e_shstrndx);

    // Allocate enough space for all symbols
    unsigned symbols_max = 0;
    for (unsigned i = 0; i < ehdr->e_shnum; i++) {
        Elf64_Shdr * shdr = shdr_from_idx(i);
        if (shdr->sh_type == SHT_SYMTAB) {
            Elf64_Sym *symbol_table = offset_to_ptr(shdr->sh_offset);
            unsigned  symbol_count = shdr->sh_size / shdr->sh_entsize;
            symbols_max += symbol_count;
        }
    }
    wf_symbols = malloc(sizeof(struct wf_symbol) * symbols_max);
    if (!wf_symbols) die_perror("malloc", "could not allocate space for symbols");

    // Pin all the executable sections
    for (int j = 0; j < info->dlpi_phnum; j++) {
        const Elf64_Phdr *phdr = &info->dlpi_phdr[j];
        if (phdr->p_type != PT_LOAD) continue;
        void *seg_vstart = (void *) (info->dlpi_addr + phdr->p_vaddr);
        void *seg_vend = seg_vstart + phdr->p_memsz;

        if (phdr->p_flags & PF_X) { // Executable segment
            wf_kernel_pin(seg_vstart, seg_vend);
        }
    }

    // Initialize our patch bumping allocator before the actual
    // binary. We need this space to allocate PLT entries
    wf_vspace_end = (void*) ((uintptr_t) info->dlpi_addr & ~((uintptr_t) 0x1ff)) - 0x1000*1024;
    assert(((uintptr_t)wf_vspace_end & 0x1ff) == 0 && "Not page alinged");
    wf_vspace_bump_ptr = wf_vspace_end;

    // Find all Symbols in ELF
    for (unsigned i = 0; i < ehdr->e_shnum; i++) {
        Elf64_Shdr * shdr = shdr_from_idx(i);
        if (shdr->sh_type == SHT_SYMTAB) {
            Elf64_Sym *symbol_table = offset_to_ptr(shdr->sh_offset);
            unsigned  symbol_count = shdr->sh_size / shdr->sh_entsize;

            Elf64_Shdr *shdr_strtab = shdr_from_idx(shdr->sh_link);
            char *strtab = offset_to_ptr(shdr_strtab->sh_offset);

            for (unsigned s = 0; s < symbol_count; s++) {
                int sym_type = ELF32_ST_TYPE(symbol_table[s].st_info);
                if (sym_type != STT_FUNC && sym_type != STT_OBJECT)
                    continue;

                char *sym_name = strtab + symbol_table[s].st_name;
                ptrdiff_t sym_value = symbol_table[s].st_value;
                void *sym_addr = (void*)info->dlpi_addr + sym_value;

                wf_symbols[wf_symbol_count].name = strdup(sym_name);
                wf_symbols[wf_symbol_count].addr = sym_addr;
                wf_symbol_count += 1;
                // log("found %s @ %p (+0x%lx)\n", sym_name, sym_addr, sym_value);
            }
        }
    }
    return 0;
}


void wf_load_symbols(char *filename) {
    void * elf_end;
    Elf64_Ehdr * ehdr = wf_load_elf(filename, /* I don't care where */ 0, &elf_end);

    dl_iterate_cb_stop = false;
    dl_iterate_phdr(dl_iterate_cb, ehdr);

    wf_unload_elf(ehdr, elf_end);
}

void *wf_find_symbol(char * name) {
    for (unsigned i = 0; i < wf_symbol_count; i++) {
        if (strcmp(name, wf_symbols[i].name) == 0) {
            return wf_symbols[i].addr;
        }
    }
    
    return 0;
}

static int wf_malloc_space = 0;
static void *wf_malloc_ptr = 0;

void *wf_malloc_near(unsigned char size) {
    if (wf_malloc_space < size) {
        wf_malloc_ptr = wf_vspace_reservere(4096);
        {
            void *x = mmap(wf_malloc_ptr, 4096,
                           PROT_READ | PROT_WRITE | PROT_EXEC,
                           MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
            if (x != wf_malloc_ptr) die_perror("mmap", "wf_malloc_near\n");
        }
        wf_malloc_space = 4096;
    }

    void * ret = wf_malloc_ptr;
    wf_malloc_ptr   += size;
    wf_malloc_space -= size;
    return ret;
}

static void *wf_plt_trampoline(char *name, void *func_ptr) {
    struct plt_entry {
        void *target;
        char jmpq[6];
    };
    struct plt_entry *plt = wf_malloc_near(sizeof(struct plt_entry));

    // jmp *%rip(-6)
    plt->target = func_ptr;
    plt->jmpq[0] = 0xff;
    plt->jmpq[1] = 0x25;
    *((uint32_t *)&plt->jmpq[2]) = -6 - 8;
    log("    PLT %s == %p (%p)\n", name, func_ptr, &plt->jmpq);

    return &plt->jmpq;
}

void wf_load_patch_from_file(char *filename) {
    void * elf_end;
    Elf64_Ehdr * ehdr = wf_load_elf(filename, /* close */ 1, &elf_end);

    int rc = mprotect(ehdr, elf_end - (void*)ehdr, PROT_WRITE | PROT_EXEC | PROT_READ);
    if (rc == -1) die_perror("mprotect", "Could not mprotect patch");


    Elf64_Shdr *shstr = shdr_from_idx(ehdr->e_shstrndx);

    // Extract all related sections from patch file
    Elf64_Shdr *kpatch_strings = NULL, *kpatch_funcs = NULL, *kpatch_relocations = NULL, *kpatch_symbols=NULL;

    for (unsigned i = 0; i < ehdr->e_shnum; i++) {
        Elf64_Shdr * shdr = shdr_from_idx(i);

        // Name of section
        char *name = section_name(shdr);

        // Perform relocations
        if (shdr->sh_type == SHT_RELA) {
            wf_relocate(ehdr, elf_end, shdr);
        }

        if (strcmp(name, ".kpatch.strings") == 0)
            kpatch_strings = shdr;
        else if (strcmp(name, ".kpatch.funcs") == 0)
            kpatch_funcs = shdr;
        else if (strcmp(name, ".kpatch.relocations") == 0)
            kpatch_relocations = shdr;
        else if (strcmp(name, ".kpatch.symbols") == 0)
            kpatch_symbols = shdr;
    }

    // Iterate over all symbols
    // printf("%d sections\n", ehdr->e_shnum);

    // Extract arrays
    struct kpatch_patch_func *funcs = offset_to_ptr(kpatch_funcs->sh_offset);
    int funcs_count = kpatch_funcs->sh_size / sizeof(struct kpatch_patch_func);
    assert(funcs_count * sizeof(struct kpatch_patch_func) == kpatch_funcs->sh_size);

    struct kpatch_symbol *symbols = offset_to_ptr(kpatch_symbols->sh_offset);
    int symbols_count = kpatch_symbols->sh_size / sizeof(struct kpatch_symbol);
    assert(symbols_count * sizeof(struct kpatch_symbol) == kpatch_symbols->sh_size);

    struct kpatch_relocation *relocations = offset_to_ptr(kpatch_relocations->sh_offset);
    int relocations_count = kpatch_relocations->sh_size / sizeof(struct kpatch_relocation);
    assert(relocations_count * sizeof(struct kpatch_relocation) == kpatch_relocations->sh_size);

    for (unsigned f = 0; f < funcs_count; f++) {
        log ("kpatch_func: name:%s objname:%s new: %p\n",
             funcs[f].name, funcs[f].objname, (void*) funcs[f].new_addr);

        funcs[f].old_addr = (uintptr_t) wf_find_symbol(funcs[f].name);
        // printf("PATCH %p -> %p\n", funcs[f].old_addr, funcs[f].new_addr);
        // Insert a call to the new function
        char * jumpsite = (char *)funcs[f].old_addr;
        void* page = addr_to_page(jumpsite);
        int rc = mprotect(page, pagesize, PROT_WRITE | PROT_EXEC | PROT_READ);
        
        if (rc == -1)
            die_perror("mprotect", "Cannot patch callsite at %p\n", page);
        
        *jumpsite = 0xe9; // jmp == 0xe9 OF OF OF OF
        *(int32_t*)(jumpsite + 1) = funcs[f].new_addr - 5 -funcs[f].old_addr;
        mprotect(page, pagesize, PROT_EXEC |PROT_READ);
    }

    // We know that ksyms are duplicated.
    // for (unsigned k = 0; k < symbols_count; k++) {
    //     printf("ksym: %s\n", symbols[k].name);
    // }

    // Relocations
    for (unsigned r = 0; r < relocations_count; r++) {
        struct kpatch_relocation *rela = &relocations[r];
        struct kpatch_symbol *ksym = rela->ksym;

        log("  reloc: [%s/%s pos=%ld, type=%d], ext=%d, type=%d, add=%d *%p\n",
            ksym->objname, ksym->name, ksym->sympos, ksym->type,
            rela->external, rela->type, rela->addend, (void*)rela->dest);

        uintptr_t reloc_src;
        if (rela->external) {
            reloc_src = dlsym(RTLD_DEFAULT, ksym->name);
            if (!reloc_src)
                die("Library symbol %s not found", ksym->name);
        } else {
            reloc_src = wf_find_symbol(ksym->name);
            log("    local %s == %p\n", ksym->name, reloc_src);
            if (!reloc_src) {
                die("Could not find symbol %s in original binary\n",
                    ksym->name);
            }
        }

        if (rela->type == R_X86_64_PLT32) {
            if (ksym->sympos == 0) {
                // Allocate space for trampolines
                ksym->sympos = (uintptr_t)wf_plt_trampoline(ksym->name, reloc_src);
            }
            reloc_src = ksym->sympos;
        } else if (rela->type == R_X86_64_GOTPCREL || rela->type == R_X86_64_REX_GOTPCRELX) {
            if (ksym->sympos == 0) {
                struct got_entry {
                    void *target;
                };
                struct got_entry *got = wf_malloc_near(sizeof(struct got_entry));
                ksym->sympos = (uintptr_t)got;
                got->target = reloc_src;
                log("    GOT %s == %p (%p)\n", ksym->name, reloc_src, got);
            }
            reloc_src = ksym->sympos;
        } else if (rela->type == R_X86_64_PC32
                   || rela->type == R_X86_64_64) {
            log("    direct %s == %p\n", ksym->name, reloc_src);
        } else {
            die("Unsupported relocation type %d for library name %s\n",
                rela->type, ksym->name);
        }

        void* loc;
        uint64_t val;
        char size;

        bool action = wf_relocate_calc(
            rela->type,
            (uintptr_t) reloc_src, rela->dest, rela->addend,
            &loc, &val, &size
            );
        if (!action) continue;
        // printf("%p %p %d\n", ksym_addr, rela->dest, rela->addend);
        // printf("PATCH *%p[%d] = %d\n", loc, size, val);

        if (size == 4) {
            *(uint32_t *) loc = val;
        } else if (size == 8) {
            *(uint64_t *) loc = val;
        } else
            die("Invalid relocation size");

        // Fixme OLD section

        rela->dest = 0;
    }

    for (unsigned r = 0; r < relocations_count; r++) {
        if (relocations[r].dest == 0) continue; // already handled

        printf("kpatch_relocation: name:%s/%s objname:%s type=%d, external=%d, *%p = ... (SHOULD NOT HAPPEN)\n",
               relocations[r].ksym->objname, relocations[r].ksym->name,
               relocations[r].objname, relocations[r].type, relocations[r].external,
               (void *)relocations[r].dest);
        // Fixme OLD section
        assert(false && "All relocations should have been handleded above");
    }

}

char *wf_patch_queue = NULL;

bool wf_load_patch(void) {
    char *patch = NULL;
    
    if (wf_patch_queue && *wf_patch_queue) {
        char *patch_stack = wf_patch_queue;
        char *p = strchr(wf_patch_queue, ';');
        if (p) { *p = 0; wf_patch_queue = p + 1;}
        else   { wf_patch_queue = 0; };

        char *patch_stack_cpy = strdup(patch_stack);
        log("applying patch: %s\n", patch_stack);
        char *saveptr = NULL;
        char *patch;
        p = patch_stack;
        while (patch = strtok_r(p, ",", &saveptr)){
            p = NULL;
            if (strchr(patch, '*')){
                log("loading patch glob: %s\n", patch);
                glob_t globbuf;
                if (glob(patch, 0, NULL, &globbuf) != 0) {
                    die("glob failed: %s\n", patch);
                }
                for (unsigned i = 0; i < globbuf.gl_pathc; i++) {
                    log("loading patch: %s\n", globbuf.gl_pathv[i]);
                    wf_load_patch_from_file(globbuf.gl_pathv[i]);
                }
                globfree(&globbuf);
            } else {
                log("loading patch: %s\n", patch);
                wf_load_patch_from_file(patch);
            }
        }

        wf_log("- [patched, %.4f, \"%s\"]\n",
               wf_timestamp(),patch_stack_cpy);
        free(patch_stack_cpy);

        if (wf_config.patch_applied)
            wf_config.patch_applied();

        return true;
    }
    return false;
}



////////////////////////////////////////////////////////////////
// Patching Thread and API

static pthread_t wf_patch_thread;
static pthread_cond_t wf_cond_initiate;
static int wf_global;


static pthread_mutex_t wf_mutex_thread_count;
static volatile int wf_existing_threads;
static volatile int wf_migrated_threads; // migrated or barriered.
static pthread_cond_t wf_cond_from_threads;
static pthread_cond_t wf_cond_to_threads;


static volatile int wf_target_generation;
static __thread int wf_current_generation;
static volatile int generation_id;
static volatile int previous_generation_id;




static void wf_initiate_patching(void);

static void wf_sigpatch_handler(int sig) {
    pthread_cond_signal(&wf_cond_initiate);
}

static int wf_config_get(char * name, int default_value) {
    char *env = getenv(name);
    if (!env) return default_value;
    char *ptr;
    long ret;
    ret = strtol(env, &ptr, 10);
    if (!ptr || *ptr != '\0') die("invalid env config %s: %s", name, env);
    return (int) ret;
}

static double wf_config_get_double(char * name, double default_value) {
    char *env = getenv(name);
    if (!env) return default_value;
    char *ptr;
    double ret;
    ret = strtod(env, &ptr);
    if (!ptr || *ptr != '\0') die("invalid env config %s: %s", name, env);
    return ret;
}

double time_diff(struct timespec now, struct timespec future) {
    return ( future.tv_sec - now.tv_sec )
        +  ( future.tv_nsec - now.tv_nsec ) / 1E9;
}



static void* wf_patch_thread_entry(void *arg) {
    (void)arg;
    { // Initialize Signals
        struct sigaction act;
        sigemptyset (&act.sa_mask);
        act.sa_flags = 0;
        act.sa_handler = wf_sigpatch_handler;
        if (sigaction(SIGPATCH, &act, NULL) != 0) {
            perror("sigaction");
        }
    }

    int wait = wf_config_get("WF_CYCLIC_BOOT", -1);
    if (wait > 0) {
        sleep(wait);
        log("WF_CYCLIC_BOOT is done\n");
    }

    {
        int mode;
        if ((mode = wf_config_get("WF_CYCLIC_MICRO", 0)) != 0) {
            int cycles = wf_config_get("WF_CYCLIC_BOUND", 1000000);

            if (mode == 1) {
                log("Perform microbenchmark: AS Create+Destroy\n");
                wf_log("microbench%d\n", mode);

                for (unsigned i = 0; i < cycles; i++) {
                    wf_timestamp_reset();

                    int new_as = wf_kernel_as_new();
                    if (new_as < 0) die("as new");

                    int rc = wf_kernel_as_delete(new_as);
                    if (rc < 0) die("as delete");

                    double duration = wf_timestamp();
                    wf_log("%f\n", duration);
                }
            }

            if (mode == 2) {
                log("Perform microbenchmark: AS Switch\n");
                wf_log("microbench%d\n", mode);

                int new_as = wf_kernel_as_new();
                if (new_as < 0) die("as new");

                for (unsigned i = 0; i < cycles; i++) {
                    wf_timestamp_reset();

                    int rc = wf_kernel_as_switch(new_as);
                    if (rc < 0) die("as switch");

                    rc = wf_kernel_as_switch(0);
                    if (rc < 0) die("as switch");

                    double duration = wf_timestamp();
                    wf_log("%f\n", duration);
                }
            }

            exit(0);
        }
    }


    pthread_mutex_t __dummy;
    pthread_mutex_init(&__dummy, NULL);

    struct timespec absolute_wait;
    clock_gettime(CLOCK_REALTIME, &absolute_wait);

    pthread_mutex_lock(&__dummy);
    while (true) {
        // Wait for signal, or do periodic tests
        double wait = wf_config_get_double("WF_CYCLIC", -1);
        int random_ms = wf_config_get("WF_CYCLIC_RANDOM", -1);
        if (wf_config_get("WF_CYCLIC_RANDOM", -1) != -1) {
            random_ms = (random() % (2 * random_ms)) - random_ms;
            // log("wf-cyclic random: %f\n", random_ms/1000.0);
            wait += (random_ms / 1000.0);
        }
        int bound = wf_config_get("WF_CYCLIC_BOUND", -1);
        if (wait == -1) {
            pthread_cond_wait(&wf_cond_initiate, &__dummy);
        } else {
            // FIXME: We use this for benchmarking
            if (bound > 0 && wf_target_generation >= bound) {
                log("Cyclic test was OK\n");
                _exit(0);
            }
            struct timespec now;
            clock_gettime(CLOCK_REALTIME, &now);
            double wait_remaining;
            do {
                absolute_wait.tv_sec  += (int)wait;
                absolute_wait.tv_nsec += (int)((wait - (int) wait) * 1e9);
                while (absolute_wait.tv_nsec > 1e9) {
                    absolute_wait.tv_sec  += 1;
                    absolute_wait.tv_nsec  -= 1000000000;
                }
                // printf("%ld\n", absolute_wait.tv_nsec);

                wait_remaining = time_diff(now, absolute_wait);
            } while(wait_remaining < 0);

            // log("sleeping for %f seconds\n", wait_remaining);
            errno = pthread_cond_timedwait(&wf_cond_initiate, &__dummy, &absolute_wait);
            // perror("cond timedwait");

            struct timespec now2;
            clock_gettime(CLOCK_REALTIME, &now2);

            double waited = time_diff(now, now2);
            log("waited for %f seconds\n", waited);
        }

        wf_initiate_patching();
    }
    return NULL;
}


typedef struct {
    double timestamp;
    char *name;
    unsigned int threads;
} time_thread_point_t;

static time_thread_point_t *wf_timepoints;
volatile unsigned int wf_timepoints_idx;

int wf_timepoint(char *name, unsigned int threads) {
    assert (wf_timepoints != NULL);

    int idx = __atomic_fetch_add(&wf_timepoints_idx, 1, __ATOMIC_SEQ_CST);
    time_thread_point_t x = {
        .timestamp = wf_timestamp(),
        .name = name,
        .threads = threads,
    };
    wf_timepoints[idx] = x;

    return idx;
}



static
void wf_timepoint_dump() {
    for (unsigned int i = 0; i < wf_timepoints_idx; i++){
        wf_log("- [migrated, \"%s\", %.4f, %d]\n",
               wf_timepoints[i].name,
               wf_timepoints[i].timestamp,
               wf_timepoints[i].threads
           );
    }
}

typedef enum {
    IDLE,
    GLOBAL_QUIESCENCE,
    LOCAL_QUIESCENCE,
} wf_state_t;

static volatile wf_state_t wf_state;

bool wf_transition_ongoing(bool global) {
    if ((global > 0)  && wf_global)
        return wf_migrated_threads != wf_existing_threads;
    if ((global == 0) && !wf_global)
        return wf_migrated_threads != wf_existing_threads;
    return false;
}

static void wf_initiate_patching(void) {
    static int first = 0;
    if (!first) first = 1;
    else wf_log("---\n");
    // Reset the time
    wf_timestamp_reset();

    pthread_mutex_lock(&wf_mutex_thread_count);
    wf_migrated_threads = 0;
    // Retrieve the current number of threads from the application,
    // otherwise, we rely on the thread_birth() and thread_death()
    // library calls.
    if (!wf_config.track_threads) {
        int threads = wf_config.thread_count(wf_global);
        wf_existing_threads = threads;
    }

    wf_log("- [apply, %ld.%09ld, %s, %d]\n",
           wf_ts0.tv_sec,
           wf_ts0.tv_nsec,
           wf_global > 0 ? "global" : ( wf_global == 0 ? "local" : "base"),
           wf_existing_threads
        );


    // FIXME reserve more threads, workaround for thread birth
    wf_timepoints = malloc(sizeof(time_thread_point_t) *  (wf_existing_threads + 10));
    wf_timepoints_idx = 0;

    wf_state = IDLE;

    if (wf_global > 0) {
        wf_target_generation ++;

        ////////////////////////////////////////////////////////////////
        // Now we reach global quiescence with our application
        wf_state = GLOBAL_QUIESCENCE;

        // Some Applications need a trigger to reach global quiescence
        if (wf_config.trigger_global_quiescence)
            wf_config.trigger_global_quiescence();

        while (wf_migrated_threads < wf_existing_threads)
            pthread_cond_wait(&wf_cond_from_threads, &wf_mutex_thread_count);
        ////////////////////////////////////////////////////////////////
        double wf_time_global_quiescence = wf_timestamp();

        wf_timepoint_dump(wf_existing_threads);
        wf_log("- [quiescence, %.4f]\n",
               wf_time_global_quiescence);


        // Load and Apply the patch
        wf_load_patch();

        wf_state = IDLE;

        ////////////////////////////////////////////////////////////////
        // Let's leave the global quiescence point
        pthread_cond_broadcast(&wf_cond_to_threads); // Wakeup all sleeping threads
        pthread_mutex_unlock(&wf_mutex_thread_count);
        ////////////////////////////////////////////////////////////////
    } else if (wf_global == 0) {
        previous_generation_id = generation_id;

        generation_id = wf_kernel_as_new();

        wf_kernel_as_switch(generation_id);

        // Load and Apply the patch
        wf_load_patch();


        ////////////////////////////////////////////////////////////////
        wf_target_generation ++;
        wf_state = LOCAL_QUIESCENCE;

        // Some applications require a trigger to reach local quiescence
        if (wf_config.trigger_local_quiescence)
            wf_config.trigger_local_quiescence();

        while (wf_migrated_threads < wf_existing_threads)
            pthread_cond_wait(&wf_cond_from_threads, &wf_mutex_thread_count);

        // After successful migration of all threads, we try to delete
        // the previous address-space generation
        wf_kernel_as_delete(previous_generation_id);

        wf_timepoint_dump();

        wf_state = IDLE;

        pthread_mutex_unlock(&wf_mutex_thread_count);
    } else {
        pthread_mutex_unlock(&wf_mutex_thread_count);
        /* WF_GLOBAL < 0 */
        wf_target_generation ++;
    }

    double wf_time_end = wf_timestamp();
    wf_log("- [finished, %.4f]\n", wf_time_end);

    log("%s Migration %d in %.4f\n",
        wf_global > 0 ? "Global" : (
            wf_global == 0 ? "Local" : (
                "No")),
        wf_target_generation,
        wf_time_end
    );


    // Must be called in all circumstances as thread count could take
    // a lock.
    if (wf_config.patch_done) {
        wf_config.patch_done();
    }


    free(wf_timepoints);
    wf_timepoints = NULL;
}

void wf_global_quiescence(char *name, unsigned int threads) {
    // every global quiescence point is also an local quiescence point
    if (wf_state == LOCAL_QUIESCENCE) {
        wf_local_quiescence(name);
        return;
    }
    if (wf_state == GLOBAL_QUIESCENCE) {
        wf_timepoint(name, threads);

        pthread_mutex_lock(&wf_mutex_thread_count);
        __sync_fetch_and_add(&wf_migrated_threads, 1);

        // Signal that one thread has reached the barrier
        if (wf_config.thread_migrated) {
            int remaining = wf_existing_threads - wf_migrated_threads;
            wf_config.thread_migrated(remaining);
        }
        
        if (wf_migrated_threads == wf_existing_threads) {
            pthread_cond_signal(&wf_cond_from_threads);
        }
        // BLOCK: Wait for patcher thread to respond
        pthread_cond_wait(&wf_cond_to_threads, &wf_mutex_thread_count);
        pthread_mutex_unlock(&wf_mutex_thread_count);
    }
}

void wf_local_quiescence(char *name) {
    if (wf_state == LOCAL_QUIESCENCE) {
        if (wf_target_generation != wf_current_generation) {
            wf_current_generation = wf_target_generation;
            wf_timepoint(name, 1);

            wf_kernel_as_switch(generation_id);

            // Wakeup Patcher Threads
            pthread_mutex_lock(&wf_mutex_thread_count);
            __sync_fetch_and_add(&wf_migrated_threads, 1);

            if (wf_config.thread_migrated) {
                int remaining = wf_existing_threads - wf_migrated_threads;
                // printf("remaining: %s %d\n", name, remaining);
                wf_config.thread_migrated(remaining);
            }

            if (wf_migrated_threads == wf_existing_threads) {
                pthread_cond_signal(&wf_cond_from_threads);
            }
            // BLOCK: We do not block here
            pthread_mutex_unlock(&wf_mutex_thread_count);
        }
    }
}

void wf_thread_birth(char *name) {
    assert(wf_config.track_threads
           && "You are not allowed to call wf_thread_birth() with track_threads=0");
    pthread_mutex_lock(&wf_mutex_thread_count);
    wf_existing_threads += 1;
    pthread_mutex_unlock(&wf_mutex_thread_count);

    if (wf_state != IDLE)
        wf_log("- [birth, %.2f, \"%s\"]\n", wf_timestamp(), name);

    // Birth is a point of Quiesence
    wf_global_quiescence(name, 1);
}

void wf_thread_death(char *name) {
    assert(wf_config.track_threads
           && "You are not allowed to call wf_thread_death() with track_threads=0");

    pthread_mutex_lock(&wf_mutex_thread_count);
    wf_existing_threads -= 1;
    // Wakeup patcher thread in case we were the last thread.
    if (wf_state == LOCAL_QUIESCENCE || wf_state == GLOBAL_QUIESCENCE){
        if (wf_target_generation == wf_current_generation) {
            wf_migrated_threads -= 1;
        }
        wf_log("- [death, %.2f, \"%s\"]\n", wf_timestamp(), name);
        if (wf_migrated_threads == wf_existing_threads) {
            pthread_cond_signal(&wf_cond_from_threads);
        }
    }
    pthread_mutex_unlock(&wf_mutex_thread_count);
}

void wf_init(struct wf_configuration config) {
    wf_global = wf_config_get("WF_GLOBAL", 1);
    wf_load_symbols("/proc/self/exe");

    pthread_condattr_t attr;
    pthread_condattr_init(&attr);
    pthread_condattr_setclock(&attr, CLOCK_REALTIME);
    pthread_cond_init(&wf_cond_initiate, &attr);

    assert((config.track_threads
            || config.thread_count != NULL)
           && "Either .track_threads or .thread_count must be given");

    // Copy(!) away the configuration that we got from the
    // configuration
    wf_config = config;

    char *logfile = getenv("WF_LOGFILE");
    if (logfile) {
        log("opening wf logfile: %s\n", logfile);
        wf_log_file = fopen(logfile, "w+");
    } else {
        wf_log_file = stderr;
    }

    // Load the patch queue, if possible
    char *queue = getenv("WF_PATCH_QUEUE");
    if (queue) wf_patch_queue = strdup(queue);

    // We start a thread that does all the heavy lifting of address
    // space management
    if ((errno = pthread_create(&wf_patch_thread, NULL,
                                &wf_patch_thread_entry, NULL)) != 0) {
        perror("pthread_create");
    }

    pthread_setname_np(wf_patch_thread, "patcher");
}
