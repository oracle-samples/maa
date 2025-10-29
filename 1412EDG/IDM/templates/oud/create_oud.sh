#!/bin/bash
# Copyright (c) 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# This is an example of creating an OUD instance silently
#
#
# Dependencies:
#
#
# Usage: create_oud_instance.sh
#
# Common Environment Variables
#

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

while getopts 'r:p:' OPTION
do
  case "$OPTION" in
    r)
      RSPFILE=$SCRIPTDIR/responsefile/$OPTARG
     ;;
    p)
      PWDFILE=$SCRIPTDIR/responsefile/$OPTARG
     ;;
    ?)
     echo "script usage: $(basename $0) [-r responsefile -p passwordfile] " >&2
     exit 1
     ;;
   esac
done


RSPFILE=${RSPFILE=$SCRIPTDIR/responsefile/idm.rsp}
PWDFILE=${PWDFILE=$SCRIPTDIR/responsefile/.idmpwds}

. $RSPFILE
if [ $? -gt 0 ]
then
    echo "Responsefile : $RSPFILE does not exist."
    exit 1
fi

. $PWDFILE
if [ $? -gt 0 ]
then
    echo "Passwordfile : $PWDFILE does not exist."
    exit 1
fi


echo "$LDAP_KEYSTORE_PWD" > $OUD_CERT_PWF
echo "$LDAP_TRUSTSTORE_PWD" > $OUD_TRUST_PWF
echo "$LDAP_ADMIN_PWD" > <WORKDIR>/.oudpwd
OUD_CERT_STORE=<OUD_CERT_STORE>
export JAVA_HOME=<JAVA_HOME>

$OUD_ORACLE_HOME/oud/oud-setup \
        --cli \
        --no-prompt \
        --noPropertiesFile \
        -I <INSTANCE_DIR> \
        -h <HOSTNAME> \
        -D $LDAP_ADMIN_USER \
        -j <WORKDIR>/.oudpwd \
	--usePkcs12keyStore $OUD_KEYSTORE_LOC/$(basename $OUD_CERT_STORE) \
	--keyStorePasswordFile $OUD_KEYSTORE_LOC/$(basename $OUD_CERT_PWF) \
        --certNickname <OUD_CERT_NICKNAME> \
        --ldapPort <OUD_LDAP_PORT> \
        --adminConnectorPort <OUD_ADMIN_PORT> \
        --ldapsPort <OUD_LDAPS_PORT> \
        --baseDN $LDAP_SEARCHBASE \
	--addBaseEntry \
        --serverTuning systemMemory:$OUDSERVER_PCT \
        --offlineToolsTuning jvm-default \
	--doNotStart

#cp <WORKDIR>/99-user.ldif <INSTANCE_DIR>/config/schema
#<INSTANCE_DIR>/bin/import-ldif -l <WORKDIR>/base.ldif -O -b  $LDAP_SEARCHBASE --rejectFile <WORKDIR>/rejects.ldif --skipFile <WORKDIR>/skip.ldif

<INSTANCE_DIR>/bin/start-ds

<INSTANCE_DIR>/bin/dsconfig -D "$LDAP_ADMIN_USER" -j $REMOTE_WORKDIR/.oudpwd -X -n set-trust-manager-provider-prop --provider-name=pkcs12 --set trust-store-file:$OUD_KEYSTORE_LOC/$(basename $OUD_TRUST_STORE) --set trust-store-pin:$LDAP_TRUSTSTORE_PWD --set enabled:true
