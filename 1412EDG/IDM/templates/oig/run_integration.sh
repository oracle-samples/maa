#!/bin/bash
# Copyright (c) 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# This is an example of a script which can be used to run the OIGOAMIntegration.sh command

export DOMAIN_HOME=<OIG_DOMAIN_HOME>
export ORACLE_HOME=<OIG_ORACLE_HOME>
export JAVA_HOME=<JAVA_HOME>


LOGDIR=<WORKDIR>

configFile=$1
action=$2

if [ "configFile" = "" ] || [ "$action" = "" ]
then
   echo Usage runIntegration.sh configFile action
   exit 1
fi
cp <WORKDIR>/$configFile $ORACLE_HOME/idm//server/ssointg/config
chmod 750 $ORACLE_HOME/idm/server/ssointg/bin/OIGOAMIntegration.sh
chmod 750 $ORACLE_HOME/idm/server/ssointg/bin/_OIGOAMIntegration.sh
cd $ORACLE_HOME/idm/server/ssointg/bin
./OIGOAMIntegration.sh -$action

