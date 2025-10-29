#!/bin/bash
# Copyright (c) 2021, 2024, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# This is an example of a script which will delete an OUD deployment
#
# Dependencies: ../common/functions.sh
#               ../responsefile/idm.rsp
#
# Usage: delete_oud.sh [-r responsefile -p passwordfile]
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

WORKDIR=$LOCAL_WORKDIR/OUD
LOGDIR=$LOCAL_WORKDIR/delete_logs/OUD

if [ ! -e $LOGDIR ]
then
  mkdir -p $LOGDIR
fi

mkdir $LOCAL_WORKDIR/deleteLogs > /dev/null 2>&1

LOG=$LOCAL_WORKDIR/deleteLogs/delete_oud_$(date +%F_%T).log

START_TIME=$(date +%s)

ST=$(date +%s)

echo "Deleting Oracle Unified Directory"
echo "---------------------------------"
echo
echo Log of Delete Session can be found at: $LOG
echo

OUD_HOSTS=$(echo $OUD_HOSTS | sed "s/,/  /g")
INSTANCE_NO=1
for oudhost in $OUD_HOSTS
do
   printf "Stop Instance oud${INSTANCE_NO} on $oudhost - "
   $SSH $OUD_OWNER@$oudhost $OUD_INST_LOC/oud${INSTANCE_NO}/bin/stop-ds >>$LOG 2>&1
   if [ $? -gt 0 ]
   then 
     grep -q "Server already stopped" $LOG
     if [ $? -eq 0 ]
     then
	echo "Not Running."
     else
	echo "Failed - See logfile $LOG"
     fi
   else
     echo "Success"
   fi
   printf "Removing Files $OUD_INST_LOC/oud${INSTANCE_NO} - "
   $SSH $OUD_OWNER@$oudhost rm -r $OUD_INST_LOC/oud${INSTANCE_NO}  >>$LOG 2>&1
      if [ $? -gt 0 ]
   then
     grep -q "No such file or directory" $LOG
     if [ $? -eq 0 ]
     then
        echo "Does not exist."
     else
        echo "Failed - See logfile $LOG"
     fi
   else
     echo "Success"
   fi

   INSTANCE_NO=$((INSTANCE_NO+1))
done


echo "Delete Working Directory"
if [ ! "$LOCAL_WORKDIR" = "" ]
then
  rm -rf $LOCAL_WORKDIR/OUD $LOCAL_WORKDIR/oud_installed
else
  echo "Unable to Delete Directory  $LOCAL_WORKDIR/OUD."
fi


FINISH_TIME=$(date +%s)
print_time TOTAL "Delete OUD " $START_TIME $FINISH_TIME
