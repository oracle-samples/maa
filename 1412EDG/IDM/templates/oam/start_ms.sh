#!/bin/bash
# Copyright (c) 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# This is an example of a WLST script to start managed servers.
#
export WLST_PROPERTIES="-Dweblogic.security.TrustKeyStore=CustomTrust -Dweblogic.security.CustomTrustKeyStoreFileName=<TRUST_STORE> -Dweblogic.security.CustomTrustKeyStorePassPhrase=<TRUST_STORE_PWD> -Dweblogic.security.SSL.ignoreHostnameVerification=true"

export DOMAIN_HOME=<OAM_DOMAIN_HOME>
export ORACLE_HOME=<OAM_ORACLE_HOME>

SRVR=$1
$ORACLE_HOME/oracle_common/common/bin/wlst.sh << EOF
connect('<OAM_WLS_ADMIN_USER>','<OAM_WLS_PWD>','<OAM_T3>://<OAM_ADMIN_HOST>:<OAM_ADMIN_PORT>')
start('oam_server${SRVR}','Server')
start('oam_policy_mgr${SRVR}','Server')
exit()

EOF
