#!/bin/bash
# Copyright (c) 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# This is an example script to pack a domain
#
export ORACLE_HOME=<ORACLE_HOME>
export ORACLE_COMMON_HOME=$ORACLE_HOME/oracle_common
cd $ORACLE_COMMON_HOME/common/bin
 
if [ -e <WORKDIR>/<DOMAIN_NAME>-domain.jar ]
then
    mv <WORKDIR>/<DOMAIN_NAME>-domain.jar <WORKDIR>/<DOMAIN_NAME>-domain.$(date +"%s")
fi
./pack.sh -managed=true -domain=<DOMAIN_HOME>  -template=<WORKDIR>/<DOMAIN_NAME>-domain.jar  -template_name=<DOMAIN_NAME>_domain_template -log_priority=DEBUG  -log=<WORKDIR>/pack.log
exit $?
