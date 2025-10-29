#!/bin/bash
# Copyright (c) 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# This is an example script to create an OIG domain
#
ORACLE_HOME=<OIG_ORACLE_HOME>
DOMAIN_HOME=<OIG_DOMAIN_HOME>
JAVA_HOME=<JAVA_HOME>
rm -rf <OIG_ORACLE_HOME>/idm/Autodiscovery.txt

SCRIPT_DIR=<WORKDIR>
$ORACLE_HOME/oracle_common/common/bin/wlst.sh $SCRIPT_DIR/create_oig_domain.py -r <WORKDIR>/responsefile/idm.rsp -p <WORKDIR>/responsefile/.idmpwds -j $JAVA_HOME
if [ $? -gt 0 ]
then
  echo "OIG DOMAIN FAILED"
  exit 1
else
  echo "OIG DOMAIN SUCCESS"
  cp <WORKDIR>/setUserOverrides* $DOMAIN_HOME/bin
fi
mkdir -p $DOMAIN_HOME/servers/AdminServer/security/
echo "username=<OIG_WLS_ADMIN_USER>" > $DOMAIN_HOME/servers/AdminServer/security/boot.properties
echo "password=<OIG_WLS_PWD>" >> $DOMAIN_HOME/servers/AdminServer/security/boot.properties

