# Patch Crawler - Docker Container

Docker container to crawl the development history of MariaDB and Redis for live patchable commits.

You have two options to get a Docker image: either build it yourself using docker-build or download a pre-built image using download-pre-built-image. Once the image is ready, you can start a Docker container using run-container. Alternatively, you can manually execute the corresponding commands as follows:

```
cd ~/dbms-live-patching/patch-crawler/container

# 1. Build Docker image
docker build -t patch-crawler .
# or download pre-built image from Zenodo
docker image import https://zenodo.org/records/12166690/files/docker-image-patch-crawler.tar.xz
docker tag d1a5d958027d patch-crawler:latest

# 2. Prepare host system and enable tracing of events:
sudo su -c "echo -1 > /proc/sys/kernel/perf_event_paranoid"

# 3. Run Docker container:
# "--cap-add=SYS_PTRACE --privileged": Required for event tracing using perf.
# "--tmpfs /tmp": We build MariaDB about 4500 times, which can be done in tmpfs (to protect the hard disk and speed up the crawling process).
docker run --cap-add=SYS_PTRACE --privileged --tmpfs /tmp -it -d --name wfpatch-patch-crawler patch-crawler

# 4. Accessing the container
docker exec -it wfpatch-patch-crawler /bin/bash
```

### `perf`

You may need to install `perf` manually, depending on the host system (we assume the host system runs Debian 11 with Linux kernel 5.15; which is the setup of the QEMU VM). If the version of the Docker container and the host OS match and the host OS has not installed a different Linux kernel, you can use `perf` within the Docker container. Otherwise, you may have to compile `perf` for your respective kernel manually. See the commands in `~/dbms-live-patching/patch-crawler/container/resources/system-setup/system-setup.d/01-perf` on how to manually install `perf`. Please note, the required packages may be different for different kernel versions, so these commands are not a guarantee for immediate success.
