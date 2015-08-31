#!/bin/bash

mm_pd_cfg_file="/etc/kafka-mirrormaker/mirrormaker-producer.config"
mm_cs_cfg_file="/etc/kafka-mirrormaker/mirrormaker-consumer.config"

: ${MM_PD_PRODUCER_TYPE:="async"}
: ${MM_PD_CLIENT_ID:="mirrormaker"}
: ${MM_PD_COMPRESSION_CODEC:="snappy"}
: ${MM_PD_REQUEST_REQUIRED_ACKS:=1}
: ${MM_PD_PRODUCER_TYPE:="async"}
: ${MM_PD_METADATA_BROKER_LIST:=""}

: ${MM_CS_GROUP_ID:="mirrormaker"}
: ${MM_CS_ZOOKEEPER_CONNECT:=""}

: ${MM_STREAMS:=2}
: ${MM_TOPICS:=".*"}

export MM_PD_PRODUCER_TYPE
export MM_PD_CLIENT_ID
export MM_PD_COMPRESSION_CODEC
export MM_PD_REQUEST_REQUIRED_ACKS
export MM_PD_PRODUCER_TYPE
export MM_PD_METADATA_BROKER_LIST

export MM_CS_GROUP_ID
export MM_CS_ZOOKEEPER_CONNECT

export MM_STREAMS
export MM_TOPICS

# Download the config file, if given a URL
if [ ! -z "$MM_PD_CFG_URL" ]; then
  echo "[MM] Downloading MM producer config file from ${MM_PD_CFG_URL}"
  curl --location --silent --insecure --output ${mm_pd_cfg_file} ${MM_PD_CFG_URL}
  if [ $? -ne 0 ]; then
    echo "[MM] Failed to download ${MM_PD_CFG_URL} exiting."
    exit 1
  fi
fi
if [ ! -z "$MM_CS_CFG_URL" ]; then
  echo "[MM] Downloading MM conusumer 1 config file from ${MM_CS_CFG_URL}"
  curl --location --silent --insecure --output ${mm_cs_cfg_file} ${MM_CS_CFG_URL}
  if [ $? -ne 0 ]; then
    echo "[MM] Failed to download ${MM_CS_CFG_URL} exiting."
    exit 1
  fi
fi

if [ ! -f ${mm_pd_cfg_file} ]; then
  echo '# Generated by mirrormaker-docker.sh' > ${mm_pd_cfg_file}
fi
for var in $(env | grep -v '^MM_PD_CFG_' | grep '^MM_PD_' | sort); do
  key=$(echo $var | sed -r 's/MM_PD_(.*)=.*/\1/g' | tr A-Z a-z | tr _ .)
  value=$(echo $var | sed -r 's/.*=(.*)/\1/g')
  echo "${key}=${value}" >> ${mm_pd_cfg_file}
done
if [ ! -f ${mm_cs_cfg_file} ]; then
  echo '# Generated by mirrormaker-docker.sh' > ${mm_cs_cfg_file}
fi
for var in $(env | grep -v '^MM_CS_CFG_' | grep '^MM_CS_' | sort); do
  key=$(echo $var | sed -r 's/MM_CS_(.*)=.*/\1/g' | tr A-Z a-z | tr _ .)
  value=$(echo $var | sed -r 's/.*=(.*)/\1/g')
  echo "${key}=${value}" >> ${mm_cs_cfg_file}
done

# Check for needed consumer/producer properties
grep zookeeper.connect ${mm_cs_cfg_file} &>/dev/null
if [ $? -ne 0 ]; then
  echo "[MM] Missing mandatory consumer setting: zookeeper.connect"
  exit 1
fi
grep metadata.broker.list ${mm_pd_cfg_file} &>/dev/null
if [ $? -ne 0 ]; then
  echo "[MM] Missing mandatory producer setting: metadata.broker.list"
  exit 1
fi

# Add needed minimum options if none are given
if [[ "$@" ==  *"--"* ]]; then
  if [[ "$@" !=  *"--num.streams"* ]]; then
    params="--num.streams $MM_STREAMS "
  fi
  if [[ "$@" !=  *"--whitelist"* && "$@" !=  *"--blacklist"* ]]; then
    params=${params}"--whitelist=\"${MM_TOPICS}\""
  fi

  exec /usr/bin/kafka-run-class kafka.tools.MirrorMaker --producer.config ${mm_pd_cfg_file} --consumer.config ${mm_cs_cfg_file} "$@" $params
else
  exec "$@"
fi
