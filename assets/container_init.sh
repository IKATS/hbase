#! /bin/bash

set -xe

if "${CLUSTER_MODE:-false}"
then

  bash inject_configuration.sh
  echo "Waiting for service discovery to kick in before starting HBase"
  while [ "$(wc -l /etc/hbase/hosts | head -n 1 | cut -d ' ' -f1)" -eq "0" ]
  do
    echo "Could not discover services, waiting."
    sleep 5
  done

  cat /etc/hbase/hosts > /etc/hosts;
  [[ ! -z $IS_MASTER ]] && \
    (bash "${HBASE_HOME}/bin/start-hbase.sh" && \
    bash "${HBASE_HOME}/bin/hbase-daemon.sh" start rest \
    || exit 1)
  [[ -z "${IS_MASTER}" ]] && (bash "${HBASE_HOME}/bin/hbase-daemon.sh" start regionserver || exit 1)
  tail -f ${HBASE_HOME}/logs/* &
  while true
  do
    if [ ! -z "${IS_MASTER}" ]
    then
      ps ax | grep "foreground_start master" | grep -v "grep" > /dev/null
      if [ $? -ne 0 ]
      then
        echo "Master is down, exiting"
        echo 'HBase master crashed.' > /dev/termination-log
        exit 2
      fi
    else
      diff /tmp/current_hbase_master /etc/hbase/master || true
      if [ $? -ne 0 ]
      then
        echo "Master IP changed"
        echo "Previous IP: $(cat /etc/hbase/master)"
        echo "Current IP: $(cat /tmp/current_hbase_master)"
        echo "Exiting application"
        echo 'Master changed.' > /dev/termination-log
        exit 0
      fi
      ps ax | grep "foreground_start regionserver" | grep -v "grep" > /dev/null
      if [ $? -ne 0 ]
      then
        echo "Region server is down, exiting"
        echo 'HBase RegionServer crashed.' > /dev/termination-log
        exit 3
      fi
    fi
    cat /etc/hbase/hosts > /etc/hosts;
    sleep 10
  done

else
  echo "docker-compose mode"
  envsubst < /root/hbase-site-template.xml > "${HBASE_HOME}/conf/hbase-site.xml"
  envsubst < /root/zoo-template.cfg > "${HBASE_HOME}/conf/zoo.cfg"
  "${HBASE_HOME}/bin/hbase" thrift start &
  "${HBASE_HOME}/bin/hbase" rest start &
  "${HBASE_HOME}/bin/hbase" master start &
  sleep infinity
fi