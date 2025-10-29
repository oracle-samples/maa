#!/bin/bash
# Copyright (c) 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# This is an example of a script which will delete an OUDSM deployment
#
# Dependencies: ../common/functions.sh
#               ../responsefile/idm.rsp
#
# Usage: delete_oudsm.sh  [-r responsefile -p passwordfile]
#
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SCRIPTDIR=$SCRIPTDIR/..

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

. $SCRIPTDIR/common/functions.sh

mkdir $LOCAL_WORKDIR/deleteLogs > /dev/null 2>&1

LOG=$LOCAL_WORKDIR/deleteLogs/delete_oudsm_`date +%F_%T`.log

START_TIME=$(date +%s)

ST=$(date +%s)

echo "Deleting Oracle Unified Directory Service Manager"
echo "-------------------------------------------------"
echo
echo Log of Delete Session can be found at: $LOG
echo


echo "Stopping OUDSM - "

$SSH $OUDSM_OWNER@$OUDSM_HOST $OUDSM_DOMAIN_HOME/bin/stopWebLogic.sh >$LOG 2>&1

echo "Deleting OUDSM Domain on $OUDSM_HOST" 
$SSH $OUDSM_OWNER@$OUDSM_HOST rm -r $OUDSM_DOMAIN_HOME >> $LOG 2>&1

echo "Delete Local Working Directory"
rm -rf  $LOCAL_WORKDIR/OUDSM/* $LOCAL_WORKDIR/oudsm_installed>> $LOG 2>&1

FINISH_TIME=$(date +%s)
print_time TOTAL "Delete OUDSM " $START_TIME $FINISH_TIME
