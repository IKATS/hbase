FROM openjdk:8-jre-slim

LABEL license="Apache License, Version 2.0"
LABEL copyright="CS Systèmes d'Information"
LABEL maintainer="contact@ikats.org"
LABEL version="0.1.0"

VOLUME /var/zookeeper

RUN apt-get update \
  && apt-get upgrade -y \
  && apt-get install -y \
    wget \
    openssh-client \
    openssh-server \
    gnupg \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /root

# Set HBase environment
ENV HBASE_VERSION 2.0.2
ENV HBASE_HOME=/root/hbase-${HBASE_VERSION}

# Get the Hbase binary and checksum files
RUN wget -nv http://archive.apache.org/dist/hbase/${HBASE_VERSION}/hbase-${HBASE_VERSION}-bin.tar.gz
RUN wget http://archive.apache.org/dist/hbase/${HBASE_VERSION}/hbase-${HBASE_VERSION}-bin.tar.gz.sha512

# Validate the binary
RUN \
  gpg --print-md SHA512 hbase-${HBASE_VERSION}-bin.tar.gz > hbase-${HBASE_VERSION}-bin.tar.gz.sha512.local && \
  diff -q hbase-${HBASE_VERSION}-bin.tar.gz.sha512 hbase-${HBASE_VERSION}-bin.tar.gz.sha512.local

# Extract Hbase and set the runtime configuration
RUN \
  tar xzf hbase-${HBASE_VERSION}-bin.tar.gz && \
  rm -f hbase-${HBASE_VERSION}-bin.tar.gz

RUN \
  sed "s:# export JAVA_HOME=.*:export JAVA_HOME=$JAVA_HOME:" hbase-${HBASE_VERSION}/conf/hbase-env.sh -i && \
  echo "export HBASE_HOME=${HBASE_HOME}" >> ~/.bashrc && \
  echo "export PATH=$PATH:${HBASE_HOME}" >> ~/.bashrc

# Put IKATS dedicated script for starting
COPY assets/ssh_config ./.ssh/config
COPY assets/container_init.sh .
COPY assets/hbase-site-template.xml .
COPY assets/zoo-template.cfg .
COPY assets/inject_configuration.sh .

RUN mkdir -p /data/hbase

# REST API
EXPOSE 8080
# REST Web UI at :8085/rest.jsp
EXPOSE 8085
# Thrift API
EXPOSE 9090
# Thrift Web UI at :9095/thrift.jsp
EXPOSE 9095
# HBase's Embedded zookeeper cluster
EXPOSE 2181
# HBase Master web UI at :16010/master-status;  ZK at :16010/zk.jsp
EXPOSE 16010

CMD bash container_init.sh
