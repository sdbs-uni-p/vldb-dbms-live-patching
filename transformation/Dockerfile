# Copyright 2022, Michael Fruth <michael.fruth@uni-passau.de>

FROM python:3.10

MAINTAINER Michael Fruth <michael.fruth@uni-passau.de>

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG="C"
ENV LC_ALL="C"

################
# INSTALLATION #
################
RUN apt-get update
RUN apt-get install -y --no-install-recommends\
    unzip \
    wget \
    zsh

RUN pip install pipenv

WORKDIR /root/analysis
COPY . .
RUN pipenv install

ENTRYPOINT ["./transform-experiment"]

