#! /bin/sh -

sed -i 's:</configuration>::' "${HBASE_HOME}/conf/hbase-site.xml"

[[ -z "${HDFS_URI}" ]] && echo "Missing required HDFS_URI variable" && exit 1
[[ -z "${ZK_QUORUM_URI}" ]] && echo "Missing required ZK_QUORUM_URI variable" && exit 1
[[ ! -f /root/.ssh_keys/id_rsa ]] && echo "SSH key missing, please mount one at /root/.ssh_keys/id_rsa" && exit 1
[[ ! -f /root/.ssh_keys/id_rsa.pub ]] && echo "SSH public key missing, please mount one at /root/.ssh_keys/id_rsa.pub" && exit 1

mkdir -p /root/.ssh
cp /root/.ssh_keys/id_rsa* /root/.ssh/
chmod 600 /root/.ssh/id_rsa
chmod 644 /root/.ssh/id_rsa.pub
cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys

rm -r "${HBASE_HOME}/conf/regionservers"
ln -fs /etc/hbase/regionservers "${HBASE_HOME}/conf/regionservers"

service ssh start

sed -i 's/# export HBASE_MANAGES_ZK=.*/export HBASE_MANAGES_ZK=false/' "${HBASE_HOME}/conf/hbase-env.sh"

MASTER=$([[ ! -z "${IS_MASTER}" ]] && hostname || cat /etc/hbase/master)

REGION_HOSTNAME=$([[ -z "${IS_MASTER}" ]] && cat << EOF
<property>
  <name>hbase.regionserver.hostname</name>
  <value>$(hostname)</value>
</property>
EOF
)

cat >> "${HBASE_HOME}/conf/hbase-site.xml" << EOF

<property>
  <name>hbase.rootdir</name>
  <value>hdfs://$HDFS_URI/hbase</value>
</property>

<property>
<name>hbase.master</name>
<value>$MASTER</value>
</property>

<property>
  <name>hbase.master.port</name>
  <value>16000</value>
</property>

<property>
  <name>hbase.master.info.port</name>
  <value>16010</value>
</property>

<property>
  <name>hbase.regionserver.port</name>
  <value>16020</value>
</property>

<property>
  <name>hbase.regionserver.info.port</name>
  <value>16030</value>
</property>

<property>
  <name>hbase.regionserver.hostname.disable.master.reversedns</name>
  <value>true</value>
</property>

$REGION_HOSTNAME

<property>
  <name>hbase.cluster.distributed</name>
  <value>true</value>
</property>

<property>
  <name>hbase.zookeeper.quorum</name>
  <value>$ZK_QUORUM_URI</value>
</property>

<property>
  <name>zookeeper.znode.parent</name>
  <value>/hbase</value>
</property>

<property>
  <name>dfs.replication</name>
  <value>1</value>
</property>

<property>
  <name>hbase.zookeeper.property.clientPort</name>
  <value>2181</value>
</property>

</configuration>
EOF

echo "$MASTER" > /tmp/current_hbase_master
