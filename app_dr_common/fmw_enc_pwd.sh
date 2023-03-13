#!/bin/bash

## fmw_enc_pwd.sh script version 1.0.
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

### This script encrypts a password using WLS encryption.
### Usage:
###
###      ./fmw_enc_pwd.sh [UNENCRYPTED_PASSWORD]
### Where:
###	UNENCRYPTED_PASSWORD:
###					This is the uncrypted password that will be encrypted.

export DEC_PASSWORD=$1
echo "domain='${DOMAIN_HOME}'" > /tmp/pret.py
echo "service=weblogic.security.internal.SerializedSystemIni.getEncryptionService(domain)" >>/tmp/pret.py
echo "encryption=weblogic.security.internal.encryption.ClearOrEncryptedService(service)" >>/tmp/pret.py
echo "print encryption.encrypt('${DEC_PASSWORD}')"  >>/tmp/pret.py
export enc_pwd=$($MIDDLEWARE_HOME/oracle_common/common/bin/wlst.sh /tmp/pret.py | tail -1)
echo "$enc_pwd"
rm /tmp/pret.py

