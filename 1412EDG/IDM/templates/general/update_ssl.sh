#!/bin/bash
# Copyright (c) 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# This is an example script to update a domains keystores
#
export WLST_PROPERTIES="-Dweblogic.security.TrustKeyStore=CustomTrust -Dweblogic.security.CustomTrustKeyStoreFileName=<TRUST_STORE> -Dweblogic.security.CustomTrustKeyStorePassPhrase=<TRUST_STORE_PWD> -Dweblogic.security.SSL.ignoreHostnameVerification=true"

export DOMAIN_HOME=<DOMAIN_HOME>

<ORACLE_HOME>/oracle_common/common/bin/wlst.sh <WORKDIR>/setup_ssl.py -d $DOMAIN_HOME -k <CERT_STORE> -t <TRUST_STORE> -a <CERT_ALIAS> -p <TRUST_STORE_PWD> -n <NM_PWD>
