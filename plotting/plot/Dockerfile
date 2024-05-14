# Copyright 2022, Michael Fruth <michael.fruth@uni-passau.de>

FROM r-base:4.1.2

MAINTAINER Michael Fruth <michael.fruth@uni-passau.de>

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG="C"
ENV LC_ALL="C"

################
# INSTALLATION #
################
RUN apt-get update
RUN apt-get install -y  --no-install-recommends\
    libcurl4-openssl-dev \
    libssl-dev \
    libfreetype6-dev \
    libfontconfig1-dev

WORKDIR /root/plot
COPY renv.lock .
RUN Rscript -e 'install.packages("remotes")' 
RUN Rscript -e 'remotes::install_version("renv", version = "0.17.3")'
#RUN Rscript -e 'install.packages("renv")'
RUN Rscript -e 'renv::init()'
RUN Rscript -e 'renv::restore()'

