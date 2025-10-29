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


<INSTANCE_DIR>/bin/dsreplication -n enable \
        --host1 <LDAPHOST1> \
        --port1 <OUD_ADMIN_PORT> \
        --bindDN1 $LDAP_ADMIN_USER \
        --bindPasswordFile1 <WORKDIR>/.oudpwd \
        --replicationPort1 <OUD_REPLICATION_PORT> \
        --secureReplication1 \
        --host2 <LDAPHOST2> \
        --port2 <OUD_ADMIN_PORT> \
        --bindDN2  $LDAP_ADMIN_USER \
        --bindPasswordFile2 <WORKDIR>/.oudpwd \
        --replicationPort2 <OUD_REPLICATION_PORT> \
        --secureReplication2 \
        --trustAll \
        --adminUID admin \
        --adminPasswordFile <WORKDIR>/.oudpwd \
        --baseDN $LDAP_SEARCHBASE

<INSTANCE_DIR>/bin/dsreplication initialize \
        --baseDN $LDAP_SEARCHBASE \
        --adminUID admin \
        --adminPasswordFile  <WORKDIR>/.oudpwd \
        --hostSource <LDAPHOST1> \
        --portSource <OUD_ADMIN_PORT> \
        --hostDestination <LDAPHOST2> \
        --portDestination <OUD_ADMIN_PORT> -X -n

<INSTANCE_DIR>/bin/dsreplication status --hostname <LDAPHOST1> --port <OUD_ADMIN_PORT> --adminUID admin --adminPasswordFile <WORKDIR>/.oudpwd -n -X
