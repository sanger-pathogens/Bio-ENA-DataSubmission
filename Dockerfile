FROM ubuntu:18.04
MAINTAINER = path-help@sanger.ac.uk

ARG TAG=master
RUN apt-get update --quiet --assume-yes
RUN apt-get upgrade --quiet --assume-yes
RUN apt-get install --quiet --assume-yes \
    default-jdk \
    build-essential \
    git \
    file \
    wget \
    curl \
    libxml2-dev \
    libexpat1-dev \
    libgd-dev \
    libssl-dev \
    libdb-dev \
    libmysqlclient-dev \
    cpanminus \
    locales

RUN cp /usr/share/i18n/SUPPORTED /etc/locale.gen
RUN locale-gen

RUN cpanm --notest \
    Dist::Zilla \
    Moose \
    YAML::XS \
    DBD::mysql \
    Config::General@2.52

#webin-cli
ENV WEBIN_CLI_VERSION 1.8.4
RUN mkdir -p /opt/webin-cli \
    && cd /opt/webin-cli \
    && wget -q https://github.com/enasequence/webin-cli/releases/download/v$WEBIN_CLI_VERSION/webin-cli-$WEBIN_CLI_VERSION.jar \
    && chmod 755 /opt/webin-cli/webin-cli-$WEBIN_CLI_VERSION.jar
ENV ENA_SUBMISSIONS_WEBIN_CLI /opt/webin-cli/webin-cli-$WEBIN_CLI_VERSION.jar

#vr-codebase
RUN git clone https://github.com/sanger-pathogens/vr-codebase && rm -rf /vr-codebase/.git
ENV PERL5LIB /vr-codebase/modules:$PERL5LIB

#bio-ena-datasubmission
RUN git clone https://github.com/sanger-pathogens/Bio-ENA-DataSubmission \
    && cd /Bio-ENA-DataSubmission \
    && git checkout $TAG \
    && cd / \
    && rm -rf /Bio-ENA-DataSubmission/.git
ENV PATH /Bio-ENA-DataSubmission/bin:$PATH
ENV PERL5LIB /vr-codebase/modules:/Bio-ENA-DataSubmission/lib:$PERL5LIB
ENV ENA_SUBMISSIONS_DATA /Bio-ENA-DataSubmission/data
RUN cd /Bio-ENA-DataSubmission && dzil authordeps --missing | cpanm --notest
RUN cd /Bio-ENA-DataSubmission && dzil listdeps --missing | grep -v 'VRTrack::Lane' | cpanm --notest

LABEL SHORT_NAME bio-ena-datasubmission
LABEL org.label-schema.name "bio-ena-datasubmission-tbd"
LABEL org.label-schema.description "Sanger pathogen image of bio-ena-datasubmission version tbd" 
LABEL org.label-schema.schema-version "1.0"

