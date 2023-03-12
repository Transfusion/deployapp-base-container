FROM ghcr.io/graalvm/graalvm-ce:ol9-java11-22.3.1
RUN gu install ruby && /opt/graalvm-ce-java11-22.3.1/languages/ruby/lib/truffle/post_install_hook.sh
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