# Hbase image

This repository handles the `hbase` image used in IKATS application.

## Build the image

```bash
docker build . -t hbase
```

## RUN the image

```bash
docker run -it \
  -e CLUSTER_MODE=${CLUSTER_MODE} \
  -e ZK_QUORUM_URI=${uri_to_zookeeper} \
  -e ZK_QUORUM_URI=${uri_to_zookeeper} \
  -e HDFS_URI=${uri_to_hdfs} \
  -v ${hbase_volume}:/data/hbase \
  hbase
```

where

* `CLUSTER_MODE` set to `false` when running docker-compose, `true` when running on kubernetes cluster
* `uri_to_zookeeper` is the URI to zookeper service (only when `CLUSTER_MODE` is set to `true`)
* `uri_to_hdfs`