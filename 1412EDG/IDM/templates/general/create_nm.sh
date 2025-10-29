#!/bin/bash
# Copyright (c) 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# This is an example script to invoke create a per host node manager
#
NM_HOME=<NM_HOME>
ORACLE_HOME=<ORACLE_HOME>

mkdir -p $NM_HOME > create_dir.log

cd $NM_HOME
cp <WORKDIR>/nodemanager.properties .
cp $ORACLE_HOME/wlserver/server/bin/startNodeManager.sh .
cp $ORACLE_HOME/wlserver/server/bin/stopNodeManager.sh .
sed -i "/unset JAVA_VM MEM_ARGS/a NODEMGR_HOME=\"<NM_HOME>\"" startNodeManager.sh
sed -i "/umask 027/a NODEMGR_HOME=\"<NM_HOME>\"" stopNodeManager.sh
cp <WORKDIR>/nodemanager.domains $NM_HOME
