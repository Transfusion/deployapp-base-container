# Copyright (c) 2020, 2022 Oracle and/or its affiliates.
# Modified by Bryan Kok <bryan.wyern1@gmail.com>
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/

# https://github.com/graalvm/container/blob/8ad2728080b26b56a24da68303dc3107231d4ce3/community/Dockerfile.ol9-java17

ARG BASE_IMAGE=container-registry.oracle.com/os/oraclelinux:9-slim

FROM ${BASE_IMAGE}

# Note: If you are behind a web proxy, set the build variables for the build:
#       E.g.:  docker build --build-arg "https_proxy=..." --build-arg "http_proxy=..." --build-arg "no_proxy=..." ...
LABEL \
    org.opencontainers.image.url='https://github.com/graalvm/container' \
    org.opencontainers.image.source='https://github.com/graalvm/container/tree/master/community' \
    org.opencontainers.image.title='GraalVM Community Edition' \
    org.opencontainers.image.authors='GraalVM Sustaining Team <graalvm-sustaining_ww_grp@oracle.com>' \
    org.opencontainers.image.description='GraalVM is a universal virtual machine for running applications written in JavaScript, Python, Ruby, R, JVM-based languages like Java, Scala, Clojure, Kotlin, and LLVM-based languages such as C and C++.'
    
RUN microdnf update -y oraclelinux-release-el9 \
    # modifications
    && microdnf --enablerepo ol9_codeready_builder install -y libyaml-devel bzip2-devel ed gcc gcc-c++ gcc-gfortran gzip file fontconfig less libcurl-devel make openssl openssl-devel readline-devel tar glibc-langpack-en \
    vi which xz-devel zlib-devel findutils glibc-static libstdc++ libstdc++-devel libstdc++-static zlib-static libxcrypt-compat \
    && microdnf clean all

RUN fc-cache -f -v

# modifications
ARG GRAALVM_VERSION=23.0.0-dev
ARG JAVA_VERSION=java17

ARG GRAALVM_PKG=https://github.com/graalvm/graalvm-ce-dev-builds/releases/download/23.0.0-dev-20230321_0741/graalvm-ce-$JAVA_VERSION-GRAALVM_ARCH-dev.tar.gz
ARG TARGETPLATFORM

ENV LANG=en_US.UTF-8 \
    JAVA_HOME=/opt/graalvm-ce-$JAVA_VERSION-$GRAALVM_VERSION

COPY gu-wrapper.sh /usr/local/bin/gu
RUN set -eux \
    # modifications
    && if [[ $(uname -i) == x86_64* ]]; then GRAALVM_PKG=${GRAALVM_PKG/GRAALVM_ARCH/linux-amd64}; fi \
    && if [[ $(uname -i) == aarch64* ]]; then GRAALVM_PKG=${GRAALVM_PKG/GRAALVM_ARCH/linux-aarch64}; fi \
    && curl --fail --silent --location --retry 3 ${GRAALVM_PKG} \
    | gunzip | tar x -C /opt/ \
    # Set alternative links
    && mkdir -p "/usr/java" \
    && ln -sfT "$JAVA_HOME" /usr/java/default \
    && ln -sfT "$JAVA_HOME" /usr/java/latest \
    && for bin in "$JAVA_HOME/bin/"*; do \
    base="$(basename "$bin")"; \
    [ ! -e "/usr/bin/$base" ]; \
    alternatives --install "/usr/bin/$base" "$base" "$bin" 20000; \
    done \
    && chmod +x /usr/local/bin/gu

CMD java -version

# modifications begin here
RUN gu install ruby && /opt/graalvm-ce-java17-23.0.0-dev/languages/ruby/lib/truffle/post_install_hook.sh
RUN microdnf install git unzip zip -y
WORKDIR /tmp/
# now install protoc because the version from the repos is too old
# https://github.com/protocolbuffers/protobuf/issues/11935
RUN [[ $(uname -i) == aarch64* ]] && curl -OL https://github.com/protocolbuffers/protobuf/releases/download/v22.0/protoc-22.0-linux-aarch_64.zip; exit 0
RUN [[ $(uname -i) == x86_64* ]] && curl -OL https://github.com/protocolbuffers/protobuf/releases/download/v22.0/protoc-22.0-linux-x86_64.zip; exit 0
RUN unzip protoc*.zip
RUN mv ./bin/protoc /usr/bin/
RUN protoc --version
RUN git clone https://github.com/Transfusion/protobuf.git
WORKDIR /tmp/protobuf
RUN git checkout v3.21.12-no-lto
RUN cd ruby/ && bundle && rake && rake clobber_package gem && gem install `ls pkg/google-protobuf-*.gem`
RUN gem install app-info -v 2.8.3