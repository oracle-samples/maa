#!/bin/bash
# Copyright (c) 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# This is an example of Enrolling OAM with Node Manager
#
# Usage: Not invoked directly
export WLST_PROPERTIES="-Dweblogic.security.TrustKeyStore=CustomTrust -Dweblogic.security.CustomTrustKeyStoreFileName=<TRUST_STORE> -Dweblogic.security.CustomTrustKeyStorePassPhrase=<TRUST_STORE_PWD> -Dweblogic.security.SSL.ignoreHostnameVerification=true"

export DOMAIN_HOME=<OAM_DOMAIN_HOME>
export ORACLE_HOME=<OAM_ORACLE_HOME>

echo "Starting Domain"
$ORACLE_HOME/oracle_common/common/bin/wlst.sh << EOF
connect('<OAM_WLS_ADMIN_USER>','<OAM_WLS_PWD>','<OAM_T3>://<OAM_ADMIN_HOST>:<OAM_ADMIN_PORT>')
nmEnroll('<OAM_DOMAIN_HOME>')
nmGenBootStartupProps('AdminServer')
exit()

EOF
exit $?
