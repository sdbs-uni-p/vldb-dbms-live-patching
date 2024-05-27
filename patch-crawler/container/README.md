# Patch Crawler - Docker Container

Docker container to crawl the development history of MariaDB and Redis for live patchable commits.

You can either execute `docker-build` first and than `run-container` or you may execute the following commands manually:

```
cd container

# 1. Build Docker image:
docker build -t patch-crawler .

# 2. Prepare host system and enable tracing of events:
sudo su -c "echo -1 > /proc/sys/kernel/perf_event_paranoid"

# 3. Run Docker container:
# "--cap-add=SYS_PTRACE --privileged": Required for event tracing using perf.
# "--tmpfs /tmp": We build MariaDB about 4500 times, which can be done in tmpfs (to protect the hard disk and speed up the crawling process).
docker run --cap-add=SYS_PTRACE --privileged --tmpfs /tmp -it -d --name wfpatch-patch-crawler patch-crawler

# 4. Accessing the container
docker exec -it wfpatch-patch-crawler /bin/bash
```

### Perf

You may need to install perf manually, depending on the host system. If the version of the Docker container and the host OS match and the host OS has not installed a different Linux kernel, you can use perf within the Docker container. Otherwise, you may have to compile perf for your respective kernel manually. See the commands in `patch-crawler/container/resources/system-setup/system-setup.d/01-perf` on how to manually install perf. Please note, the required packages may be different for different kernel versions, so these commands are not a guarantee for immediate success.
