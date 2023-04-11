FROM ubuntu:18.04
MAINTAINER Sergey Isaev <serj.hoop@gmail.com>

RUN apt-get update && apt-get install --yes --no-install-recommends \
    make jq gcc libpq-dev wget curl locales vim-tiny git cmake \
    build-essential gcc-multilib perl python3 python3-pip locales-all \
    libbz2-dev zlib1g-dev libncurses5-dev libncursesw5-dev \
    liblzma-dev gzip zip unzip fastqc samtools python3-setuptools \
    python-dev python3-dev python3-venv python3-wheel bowtie2
    
RUN python3 -m pip install -U --force-reinstall pip
RUN python3 -m pip install wheel ffq multiqc

RUN sed -i -e "s/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/" /etc/locale.gen && \
    dpkg-reconfigure --frontend=noninteractive locales && \
    update-locale LANG=en_US.UTF-8
ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8
