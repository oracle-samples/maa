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
Usage: $0 [nm/aserver/mserver/all]
nm		starts Node Manager only
aserver		if this is adminhost, it starts the Admin Server (and Node Manager in case it is down)
mserver		starts the managed server in this host (and Node Manager in case it is down)
all		starts Node Manager (if not already up), Admin server, managed server in this host
EOF
}

startnm()
{
NM_CHECK_CMD=$(ps -ef | grep [N]odeManager | awk '{print $2}')
if [ "$NM_CHECK_CMD" != '' ]; then
    echo "NodeManager is already running."
else
   echo "Starting nodemanager" | log
   $WLS_DOMAIN_HOME/bin/startNodeManager.sh & 
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
if [ $IS_ADMIN_INSTANCE == 'true' ]; then
    echo "Starting Admin server" | log
    cd $WLS_DOMAIN_HOME
    echo "AdminServer" | /u01/app/oracle/middleware/oracle_common/common/bin/wlst.sh  /opt/scripts/restart/start_servers.py
fi
}

startms()
{
    echo "Starting managed server - "$SERVER_NAME | log
    cd $WLS_DOMAIN_HOME
    echo "ManagedServer" | /u01/app/oracle/middleware/oracle_common/common/bin/wlst.sh  /opt/scripts/restart/start_servers.py
}


###########################
# MAIN
##########################
component=$1
if [[ "$#" == 0 || $component != 'nm' && $component != 'aserver' && $component != 'mserver' && $component != 'all' ]]; then
  usage
  exit 1
fi

if [[ $component == 'nm' || $component == 'aserver' || $component == 'mserver' || $component == 'all' ]]; then
	startnm
fi
if [[ $component == 'aserver' || $component == 'all' ]]; then
	startas
fi
if [[ $component == 'mserver' || $component == 'all' ]]; then
	startms
fi

