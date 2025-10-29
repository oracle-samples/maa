#!/bin/bash
# Copyright (c) 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# This is an example of a script to run the idmConfigTool command.
#
export DOMAIN_HOME=<OAM_DOMAIN_HOME>
export ORACLE_HOME=<OAM_ORACLE_HOME>/idm
export JAVA_HOME=<JAVA_HOME>
export CLASSPATH=$CLASSPATH:$ORACLE_HOME/wlserver/server/lib/weblogic.jar


LOGDIR=<WORKDIR>

action=$1
configFile=$2

if [ "configFile" = "" ] || [ "$action" = "" ]
then
   echo Usage runIdmConfig.sh configFile action
   exit 1
fi

cd $ORACLE_HOME/idmtools/bin

if [ -f <WORKDIR>/automation_integ.log ]
then
     rm  <WORKDIR>/automation_integ.log
fi

./idmConfigTool.sh -$action input_file=<WORKDIR>/$configFile log_file=<WORKDIR>/$action.log
cat <WORKDIR>/automation_integ.log


exit

