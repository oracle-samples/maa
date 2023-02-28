#!/bin/bash

## fmw_enc_pwd.sh script version 1.0.
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

export ENC_PASSWORD=$1
echo "domain='${DOMAIN_HOME}'" > /tmp/pret.py
echo "service=weblogic.security.internal.SerializedSystemIni.getEncryptionService(domain)" >>/tmp/pret.py
echo "encryption=weblogic.security.internal.encryption.ClearOrEncryptedService(service)" >>/tmp/pret.py
echo "print encryption.decrypt('${ENC_PASSWORD}')"  >>/tmp/pret.py
export dec_pwd=$($MIDDLEWARE_HOME/oracle_common/common/bin/wlst.sh /tmp/pret.py | tail -1)
echo "$dec_pwd"
rm /tmp/pret.py


