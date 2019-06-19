FROM ubuntu:18.04
MAINTAINER = path-help@sanger.ac.uk


ARG ENA_SUBMISSIONS_VERSION
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
ENV WEBIN_CLI_VERSION=1.8.4
RUN mkdir -p /opt/webin-cli \
    && cd /opt/webin-cli \
    && wget -q https://github.com/enasequence/webin-cli/releases/download/v$WEBIN_CLI_VERSION/webin-cli-$WEBIN_CLI_VERSION.jar \
    && chmod 755 /opt/webin-cli/webin-cli-$WEBIN_CLI_VERSION.jar
ENV ENA_SUBMISSIONS_WEBIN_CLI /opt/webin-cli/webin-cli-$WEBIN_CLI_VERSION.jar

#vr-codebase
ENV VR_CODEBASE_VERSION=0.04
RUN cd /opt \
    && wget -q https://github.com/sanger-pathogens/vr-codebase/archive/v${VR_CODEBASE_VERSION}.tar.gz \
    && tar xf v${VR_CODEBASE_VERSION}.tar.gz \
    && rm v${VR_CODEBASE_VERSION}.tar.gz
ENV PERL5LIB /opt/vr-codebase-${VR_CODEBASE_VERSION}/modules:$PERL5LIB

#bio-ena-datasubmission
RUN cd /opt \
    && wget -q https://github.com/sanger-pathogens/Bio-ENA-DataSubmission/archive/v${ENA_SUBMISSIONS_VERSION}.tar.gz \
    && tar xf v${ENA_SUBMISSIONS_VERSION}.tar.gz \
    && rm v${ENA_SUBMISSIONS_VERSION}.tar.gz 
ENV PATH /opt/Bio-ENA-DataSubmission-${ENA_SUBMISSIONS_VERSION}/bin:$PATH
ENV PERL5LIB /opt/Bio-ENA-DataSubmission-${ENA_SUBMISSIONS_VERSION}/lib:$PERL5LIB
ENV ENA_SUBMISSIONS_DATA /opt/Bio-ENA-DataSubmission-${ENA_SUBMISSIONS_VERSION}/data
RUN cd /opt/Bio-ENA-DataSubmission-${ENA_SUBMISSIONS_VERSION} && dzil authordeps --missing | cpanm --notest
RUN cd /opt/Bio-ENA-DataSubmission-${ENA_SUBMISSIONS_VERSION} && dzil listdeps --missing | grep -v 'VRTrack::Lane' | cpanm --notest
ENV ENA_SUBMISSIONS_VERSION=${ENA_SUBMISSIONS_VERSION}

LABEL SHORT_NAME bio-ena-datasubmission
LABEL org.label-schema.name "bio-ena-datasubmission-${ENA_SUBMISSIONS_VERSION}"
LABEL org.label-schema.description "Sanger pathogen image of bio-ena-datasubmission version ${ENA_SUBMISSIONS_VERSION}" 
LABEL org.label-schema.schema-version "1.0"

