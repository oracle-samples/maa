#!/bin/bash
# Copyright (c) 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# This is an example of deleting an OAM domains files
#
# Usage: Not invoked directly
ORACLE_HOME=<OAM_ORACLE_HOME>
DOMAIN_HOME=<OAM_DOMAIN_HOME>
rm -rf <OAM_ORACLE_HOME>/idm/Autodiscovery.txt

SCRIPT_DIR=<WORKDIR>

kill -9  $(ps -fu <OAM_OWNER> | grep u01 | awk '{ print $2 }')
rm -rf <OAM_DOMAIN_HOME> <OAM_NM_HOME> <WORKDIR>/logs/* <WORKDIR>/*.sh <MSERVER_HOME>

