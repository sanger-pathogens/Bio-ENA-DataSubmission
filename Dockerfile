FROM ubuntu:18.04
MAINTAINER = path-help@sanger.ac.uk

# dependency versions -- COULD specify these at build time
ARG VR_CODEBASE_VERSION=0.04
ARG CONFIG_GENERAL_VERSION=2.52

RUN apt-get update -qq -y
RUN apt-get upgrade -qq -y
RUN apt-get install -qq -y \
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
    locales \
    genometools
    
RUN   sed -i -e 's/# \(en_GB\.UTF-8 .*\)/\1/' /etc/locale.gen && \
      touch /usr/share/locale/locale.alias && \
      locale-gen
ENV   LANG     en_GB.UTF-8
ENV   LANGUAGE en_GB:en
ENV   LC_ALL   en_GB.UTF-8

# dzil
RUN cpanm --notest \
    Dist::Zilla \
    Config::General@${CONFIG_GENERAL_VERSION}

# vr-codebase
RUN cd /opt \
    && wget -q https://github.com/sanger-pathogens/vr-codebase/archive/v${VR_CODEBASE_VERSION}.tar.gz \
    && tar xf v${VR_CODEBASE_VERSION}.tar.gz \
    && rm v${VR_CODEBASE_VERSION}.tar.gz
ENV PERL5LIB /opt/vr-codebase-${VR_CODEBASE_VERSION}/modules:$PERL5LIB

# bio-ena-datasubmission
RUN mkdir -p /opt/Bio-ENA-DataSubmission
COPY . /opt/Bio-ENA-DataSubmission
ENV PATH /opt/Bio-ENA-DataSubmission/bin:$PATH
ENV PERL5LIB /opt/Bio-ENA-DataSubmission/lib:$PERL5LIB
ENV ENA_SUBMISSIONS_DATA /opt/Bio-ENA-DataSubmission/data
RUN cd /opt/Bio-ENA-DataSubmission && dzil authordeps --missing | cpanm --notest
RUN cd /opt/Bio-ENA-DataSubmission && dzil listdeps --missing | grep -v 'VRTrack::Lane' | cpanm --notest

RUN   cd /opt/Bio-ENA-DataSubmission && \
      dzil test
