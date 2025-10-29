# Copyright (c) 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# This is an example of deleting an OIG domains files
#
# Usage: Not invoked directly
ORACLE_HOME=<OIG_ORACLE_HOME>
DOMAIN_HOME=<OIG_DOMAIN_HOME>
rm -rf <OIG_ORACLE_HOME>/idm/Autodiscovery.txt

SCRIPT_DIR=<WORKDIR>

kill -9  $(ps -fu <OIG_OWNER> | grep u01 | awk '{ print $2 }')
rm -rf <OIG_DOMAIN_HOME> <OIG_NM_HOME> <WORKDIR>/logs/* <WORKDIR>/*.sh <MSERVER_HOME>

