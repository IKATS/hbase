FROM openjdk:8-jre-slim

LABEL license="Apache License, Version 2.0"
LABEL copyright="CS Systèmes d'Information"
LABEL maintainer="contact@ikats.org"
LABEL version="0.12.0"


RUN apt update && apt install -y \
  wget \
  openssh-client \
  openssh-server \
  gnupg

WORKDIR /root

# Set HBase environment
ENV HBASE_VERSION 2.0.2
ENV HBASE_HOME=/root/hbase-${HBASE_VERSION}

# Get the Hbase binary and checksum files
RUN wget -nv http://apache.mirrors.ovh.net/ftp.apache.org/dist/hbase/${HBASE_VERSION}/hbase-${HBASE_VERSION}-bin.tar.gz
RUN wget https://apache.org/dist/hbase/${HBASE_VERSION}/hbase-${HBASE_VERSION}-bin.tar.gz.sha512

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
  echo "export PATH=$PATH:${HBASE_HOME}" >> ~/.bashrc && \
  echo "export HBASE_MANAGES_ZK=false" >> ~/.bashrc

# Put IKATS dedicated script for starting
COPY assets/ssh_config ./.ssh/config
COPY assets/container_init.sh .
COPY assets/hbase-site-docker.xml ./hbase-site.xml
COPY assets/inject_configuration.sh .

EXPOSE 60000 60010
CMD bash container_init.sh
