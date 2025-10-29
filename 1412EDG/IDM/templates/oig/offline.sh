#!/bin/bash
# Copyright (c) 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# This is an example of a script which can be used to run the OIG offline configuration script

export ORACLE_HOME=<OIG_ORACLE_HOME>
export DOMAIN_HOME=<OIG_DOMAIN_HOME>
export JAVA_HOME=<JAVA_HOME>

SCRIPT_DIR=<WORKDIR>
chmod +x $ORACLE_HOME/idm/server/bin/offlineConfigManager.sh
cd  $ORACLE_HOME/idm/server/bin/
./offlineConfigManager.sh
