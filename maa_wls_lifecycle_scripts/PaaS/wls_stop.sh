#!/usr/bin/env bash
#
# Copyright (c) 2023 Oracle and/or its affiliates. 
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/

#Set env
source /opt/scripts/restart/setEnv.sh

WLS_DOMAIN_NAME=$(echo $wls_domainName)
WLS_ADMIN_HOST=$(echo $wls_adminHost)
WLS_DOMAIN_HOME=$(echo $wls_domainHome)
WLS_PORT=$(echo $wls_adminPort)
SERVER_NAME=$(echo $wls_msserverName)

#IS_ADMIN_INSTANCE=$(python /opt/scripts/databag.py is_admin_instance)
# This if is to make script valid both for soamp and wls for oci
if [ "$wls_hostIndex" == "0" ]; then
        IS_ADMIN_INSTANCE="true"
else
        IS_ADMIN_INSTANCE="false"
fi

# This if is to make script valid both for soa and wls for oci
if [ -z "$ADMIN_SERVER_NAME" ]; then
	# Then it is soamp so getting it with python
	ADMIN_SERVER_NAME=$(python /opt/scripts/databag.py wls_admin_server_name)
fi

WLS_USER_ADMIN_CONFIGFILE="/opt/scripts/restart/oracle-WebLogicConfig.properties"
WLS_USER_ADMIN_KEYFILE="/opt/scripts/restart/oracle-WebLogicKey.properties"

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
Usage: $0 [aserver/mserver/servers/nm/all]
aserver		stops the Admin server in this host
mserver		stops the managed server in this host
servers		stops the Admin and managed servers in this host
nm		stops the node manager in this host
all		stop all (admin, managed and node manager) in this host
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
echo "Stopping managed server - "$SERVER_NAME | log
cd $WLS_DOMAIN_HOME
/u01/app/oracle/middleware/oracle_common/common/bin/wlst.sh  /opt/scripts/restart/stop_servers.py "ManagedServer" ${WLS_USER_ADMIN_CONFIGFILE} ${WLS_USER_ADMIN_KEYFILE}
exit_code=$?
if [ $exit_code -gt 0 ]; then
    echo "Failed to stop managed server- $SERVER_NAME with admin server" | log
    echo "Will try to kill through node manager" | log
    cd $WLS_DOMAIN_HOME
    /u01/app/oracle/middleware/oracle_common/common/bin/wlst.sh  /opt/scripts/restart/nmkill_servers.py "ManagedServer"
    exit_code=$?
    if [ $exit_code -gt 0 ]; then
	echo "Failed to stop managed server- $SERVER_NAME with node manager. Node manager or server not currently running" | log
    	killserver $SERVER_NAME
    fi
fi
}

stopas()
{
if [ $IS_ADMIN_INSTANCE == 'true' ]; then
    echo "Stopping Admin server" | log
    cd $WLS_DOMAIN_HOME
    /u01/app/oracle/middleware/oracle_common/common/bin/wlst.sh  /opt/scripts/restart/stop_servers.py "AdminServer" ${WLS_USER_ADMIN_CONFIGFILE} ${WLS_USER_ADMIN_KEYFILE}
    exit_code=$?
    if [ $exit_code -gt 0 ]; then
        echo "Failed to stop Admin Server $ADMIN_SERVER_NAME with admin server" | log
	echo "Will try to kill through node manager" | log
	cd $WLS_DOMAIN_HOME
	/u01/app/oracle/middleware/oracle_common/common/bin/wlst.sh  /opt/scripts/restart/nmkill_servers.py "AdminServer"
	exit_code=$?
	if [ $exit_code -gt 0 ]; then
		echo "Failed to stop admin server $ADMIN_SERVER_NAME  with node manager. Node manager or server not currently running. " | log
		killserver $ADMIN_SERVER_NAME
	fi
    fi
fi
}

stopnm()
{
  echo "Stopping nodemanager." | log
  $WLS_DOMAIN_HOME/bin/stopNodeManager.sh
  exit_code=$?
  if [ $exit_code -gt 0 ]; then
    echo "Unable to stop the Nodemanager." | log
    killnm
  else
    echo "Stopped nodemanager." | log
  fi
}



####################
# MAIN
####################
component=$1
if [[ "$#" == 0 || $component != 'mserver' && $component != 'aserver' && $component != 'servers' && $component != 'nm' && $component != 'all' ]]; then
  usage
  exit 1
fi

if [[ $component == 'mserver' || $component == 'servers' || $component == 'all' ]]; then
        stopms
fi
if [[ $component == 'aserver' || $component == 'servers' || $component == 'all' ]]; then
        stopas
fi
if [[ $component == 'nm' || $component == 'all' ]]; then
	stopnm
fi
