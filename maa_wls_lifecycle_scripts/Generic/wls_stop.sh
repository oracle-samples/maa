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

echo -e

exit_code=0

function log() {
    while IFS= read -r line; do
        DATE=`date '+%Y-%m-%d %H:%M:%S.%N'`
        echo "$DATE ==> $line"
    done
}

usage()
{
cat <<EOF
Usage: $0 [aserver/mserver/servers/nm/cluster] [server_name/cluster_name]
aserver         stops the Admin server in this host
mserver         stops the managed server provided as "server_name" in this host
nm              stops the node manager in this host
cluster         it connects to Admin Server to remotely stop all the managed servers of the provided cluster name. Node manager must be already up in the hosts.

server_name     the name of the managed server that you want to stop when using 'mserver' option
cluster_name    the name of the WebLogic cluster that you want to stop when using 'cluster' option

EOF
}



# Kill the java process. arg1=name of the wls server
killserver()
{
  PID=$(ps -ef | grep java  | grep "weblogic.Name=$1" | awk '{print $2}' | head -1)
  if [ ! -z $PID ]; then
        echo "killing $PID weblogic.Name=$1" ; kill -9 $PID ; sleep 10
  fi
  rm -f ${WLS_DOMAIN_HOME}/servers/$1/data/nodemanager/*.lck
  rm -f ${WLS_DOMAIN_HOME}/servers/$1/data/nodemanager/*.state
  rm -f ${WLS_DOMAIN_HOME}/servers/$1/data/nodemanager/*.pid
}

killnm()
{
  PID=$(ps -ef | grep java  | grep "weblogic.NodeManager" | awk '{print $2}' | head -1)
  if [ ! -z $PID ]; then
        echo "killing $PID weblogic.NodeManager" ; kill -9 $PID ; sleep 10
  fi
  echo "Node Manager is not running" | log
}

stopms()
{
    if [ -z "$SERVER_NAME" ]; then
        echo "Provide the managed server name" | log
        usage
        exit 1
    fi

echo "Stopping managed server - "$SERVER_NAME | log
export WLS_DOMAIN_HOME=$MSERVER_HOME
$ORACLE_HOME/oracle_common/common/bin/wlst.sh  ${exec_path}/py_scripts/stop_servers.py ${SERVER_NAME}
exit_code=$?
if [ $exit_code -gt 0 ]; then
    echo "Failed to stop managed server- ${SERVER_NAME} with admin server" | log
    echo "Will try to kill through node manager" | log
    $ORACLE_HOME/oracle_common/common/bin/wlst.sh  ${exec_path}/py_scripts/nmkill_servers.py ${SERVER_NAME}
    exit_code=$?
    if [ $exit_code -gt 0 ]; then
        echo "Failed to stop managed server- ${SERVER_NAME} with node manager. Node manager or server not currently running" | log
        killserver $SERVER_NAME
    fi
fi
}

stopas()
{
#if [ $IS_ADMIN_INSTANCE == 'true' ]; then
    echo "Stopping Admin server" | log
    export WLS_DOMAIN_HOME=$ASERVER_HOME
    $ORACLE_HOME/oracle_common/common/bin/wlst.sh  ${exec_path}/py_scripts/stop_servers.py ${ADMIN_SERVER_NAME}
    exit_code=$?
    if [ $exit_code -gt 0 ]; then
        echo "Failed to stop Admin Server ${ADMIN_SERVER_NAME} with admin server" | log
        echo "Will try to kill through node manager" | log
        $ORACLE_HOME/oracle_common/common/bin/wlst.sh  ${exec_path}/py_scripts/nmkill_servers.py ${ADMIN_SERVER_NAME}
        exit_code=$?
        if [ $exit_code -gt 0 ]; then
                echo "Failed to stop admin server ${ADMIN_SERVER_NAME} with node manager. Node manager or server not currently running. " | log
                killserver ${ADMIN_SERVER_NAME}
        fi
    fi
#fi
}

stopnm()
{
  # REVIEW, this depends on how is NM (per domain or per host)
  echo "Stopping nodemanager." | log
  ${NM_SCRIPTS}/stopNodeManager.sh
  exit_code=$?
  if [ $exit_code -gt 0 ]; then
    echo "Unable to stop the Nodemanager." | log
    killnm
  else
    echo "Stopped nodemanager." | log
  fi
}

stopcluster()
{
    if [ -z "$CLUSTER_NAME" ]; then
        echo "Provide the WebLogic cluster  name" | log
        usage
        exit 1
    fi
    echo "Stopping WebLogic Cluster - "$CLUSTER_NAME | log
    $ORACLE_HOME/oracle_common/common/bin/wlst.sh  ${exec_path}/py_scripts/stop_cluster.py ${CLUSTER_NAME}
}



####################
# MAIN
####################
component=$OPTION
if [[ "$#" == 0 || $component != 'mserver' && $component != 'aserver' && $component != 'nm' && $component != 'cluster' ]]; then
  usage
  exit 1
fi

if [[ $component == 'mserver' ]]; then
        stopms
fi
if [[ $component == 'aserver' ]]; then
        stopas
fi
if [[ $component == 'nm' ]]; then
        stopnm
fi
if [[ $component == 'cluster' ]]; then
        stopcluster
fi


