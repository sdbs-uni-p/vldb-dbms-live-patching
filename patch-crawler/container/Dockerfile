# Copyright 2022, Michael Fruth <michael.fruth@uni-passau.de>

FROM debian:bullseye

MAINTAINER Michael Fruth <michael.fruth@uni-passau.de>

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG="C"
ENV LC_ALL="C"

################
# INSTALLATION #
################
RUN apt-get update && apt-get upgrade -y
RUN apt-get install -y --no-install-recommends\
    bison \
    build-essential \
    ca-certificates \
    ccache \
    cmake \
    curl \
    git \
    gnutls-dev \
    libboost-all-dev \
    libcurl4-openssl-dev \
    libelf-dev \
    libevent-dev \
    libncurses5-dev \
    libpcre2-dev \
    libssl-dev \
    libxml2-dev \
    ninja-build \
    openjdk-17-jdk \
    pkg-config \
    psmisc \
    python3-pip \
    rsync \
    sudo \
    tmux \
    unzip \
    vim \
    wget \
    zlib1g-dev \
    zsh

# We need passwordless root/sudo user.
COPY resources/sudoers /etc/sudoers

##################
# INFRASTRUCTURE #
##################

# Setup user
RUN useradd -m -G sudo -s /bin/bash repro && echo "repro:repro" | chpasswd
USER repro

WORKDIR /home/repro

# Install pyenv
RUN curl -L https://github.com/pyenv/pyenv-installer/raw/master/bin/pyenv-installer | bash

COPY --chown=repro:repro resources/system-setup/ /tmp/system-setup/
RUN /tmp/system-setup/system-setup
RUN rm -rf /tmp/system-setup

COPY --chown=repro:repro resources/dotfiles/* /home/repro/
RUN git clone https://github.com/sdbs-uni-p/vldb-dbms-live-patching.git dbms-live-patching
WORKDIR /home/repro/dbms-live-patching
RUN ./utils/setup

ENV REPLICATION_CLONE_FROM_GIT=false

