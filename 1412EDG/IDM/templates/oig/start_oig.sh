#!/bin/bash
# Copyright (c) 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# This is an example of a script which can be used to start the OIG domain

export WLST_PROPERTIES="-Dweblogic.security.TrustKeyStore=CustomTrust -Dweblogic.security.CustomTrustKeyStoreFileName=<TRUST_STORE> -Dweblogic.security.CustomTrustKeyStorePassPhrase=<TRUST_STORE_PWD> -Dweblogic.security.SSL.ignoreHostnameVerification=true"

export DOMAIN_HOME=<OIG_DOMAIN_HOME>
export ORACLE_HOME=<OIG_ORACLE_HOME>

echo "Starting Domain"
$ORACLE_HOME/oracle_common/common/bin/wlst.sh << EOF
nmConnect('admin','<OIG_NM_PWD>','<HOSTNAME>','5556','<OIG_DOMAIN_NAME>','<OIG_DOMAIN_HOME>','SSL')
nmStart('AdminServer')
nmDisconnect()
connect('<OIG_WLS_ADMIN_USER>','<OIG_WLS_PWD>','<OIG_T3>://<OIG_ADMIN_HOST>:<OIG_ADMIN_PORT>')
start('soa_cluster', 'Cluster')
start('oim_cluster', 'Cluster')
exit()

EOF
exit $?
