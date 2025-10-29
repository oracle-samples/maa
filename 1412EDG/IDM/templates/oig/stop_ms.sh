#!/bin/bash
# Copyright (c) 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# This is an example of a script which can be used to stop managed servers

export WLST_PROPERTIES="-Dweblogic.security.TrustKeyStore=CustomTrust -Dweblogic.security.CustomTrustKeyStoreFileName=<TRUST_STORE> -Dweblogic.security.CustomTrustKeyStorePassPhrase=<TRUST_STORE_PWD> -Dweblogic.security.SSL.ignoreHostnameVerification=true"

export DOMAIN_HOME=<OIG_DOMAIN_HOME>
export ORACLE_HOME=<OIG_ORACLE_HOME>

echo "Stopping Domain"
$ORACLE_HOME/oracle_common/common/bin/wlst.sh << EOF
connect('<OIG_WLS_ADMIN_USER>','<OIG_WLS_PWD>','<OIG_T3>://<OIG_ADMIN_HOST>:<OIG_ADMIN_PORT>')
shutdown('oim_server1','Server', ignoreSessions='true', force='true')
shutdown('soa_server1','Server', ignoreSessions='true', force='true')
shutdown('AdminServer','Server', ignoreSessions='true', force='true')
exit()

EOF

