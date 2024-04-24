#!/usr/bin/env bash
#
# Copyright (c) 2024 Oracle and/or its affiliates
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/

export exec_path=$(dirname "$0")

#Set env
source ${exec_path}/domain_properties.env

OPTION=$1
SERVER_NAME=$2
CLUSTER_NAME=$2

function log() {
    while IFS= read -r line; do
        DATE=`date '+%Y-%m-%d %H:%M:%S.%N'`
        echo "$DATE ==> $line"
    done
}

echo -e

exit_code=0

usage()
{
cat <<EOF
Script to start WebLogic processes in this host
Usage: $0 [nm/aserver/mserver/cluster] [server_name/cluster_name]
nm              it starts the Node Manager in this host
aserver         it starts the Admin Server (and Node Manager in case it is down). It must run in the admin host.
mserver         it starts the managed server in this host (and Node Manager in case it is down)
cluster         it connects to Admin Server to remotely start all the managed servers of the provided cluster name. Node manager must be already up in the hosts.

server_name     the name of the managed server that you want to start when using 'mserver' option
cluster_name    the name of the WebLogic Cluster that you want to start when using 'cluster' option

EOF
}

startnm()
{
NM_CHECK_CMD=$(ps -ef | grep [N]odeManager | awk '{print $2}')
if [ "$NM_CHECK_CMD" != '' ]; then
    echo "NodeManager is already running."
else
   echo "Starting nodemanager" | log
   $NM_SCRIPTS/startNodeManager.sh &
   exit_code=$?
   if [ $exit_code -gt 0 ]; then
     echo "Failed to start nodemanager" | log
     exit 1
   fi
   echo "Started Nodemanager." | log
fi
}

startas()
{
#if [ $IS_ADMIN_INSTANCE == 'true' ]; then
    export WLS_DOMAIN_HOME=$ASERVER_HOME
    echo "Starting Admin server" | log
    $ORACLE_HOME/oracle_common/common/bin/wlst.sh  ${exec_path}/py_scripts/start_servers.py ${ADMIN_SERVER_NAME}
#fi
}

startms()
{
    if [ -z "$SERVER_NAME" ]; then
        echo "Provide the managed server name" | log
        usage
        exit 1
    fi
    export WLS_DOMAIN_HOME=$MSERVER_HOME
    echo "Starting managed server - "$SERVER_NAME | log
    $ORACLE_HOME/oracle_common/common/bin/wlst.sh  ${exec_path}/py_scripts/start_servers.py ${SERVER_NAME}
}

startcluster()
{
    if [ -z "$CLUSTER_NAME" ]; then
        echo "Provide the WebLogic cluster  name" | log
        usage
        exit 1
    fi
    echo "Starting WebLogic Cluster - "$CLUSTER_NAME | log
    $ORACLE_HOME/oracle_common/common/bin/wlst.sh  ${exec_path}/py_scripts/start_cluster.py ${CLUSTER_NAME}
}


###########################
# MAIN
##########################
component=$1
if [[ "$#" == 0 || $component != 'nm' && $component != 'aserver' && $component != 'mserver' && $component != 'all'  && $component != 'cluster' ]]; then
  usage
  exit 1
fi

if [[ $component == 'cluster' ]]; then
        startcluster
fi
if [[ $component == 'nm' || $component == 'aserver' || $component == 'mserver' ]]; then
        startnm
fi

if [[ $component == 'aserver' ]]; then
        startas
fi
if [[ $component == 'mserver' ]]; then
        startms
fi
