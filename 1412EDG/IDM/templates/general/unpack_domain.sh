#!/bin/bash
# Copyright (c) 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# This is an example script to unpack a domain
#
export ORACLE_HOME=<ORACLE_HOME>
export ORACLE_COMMON_HOME=$ORACLE_HOME/oracle_common
cd $ORACLE_COMMON_HOME/common/bin
 
./unpack.sh -domain=<MSERVER_HOME> -overwrite_domain=true -template=<WORKDIR>/<DOMAIN_NAME>-domain.jar -log_priority=DEBUG -log=<WORKDIR>/unpack.log -app_dir=<MSERVER_HOME>/applications
