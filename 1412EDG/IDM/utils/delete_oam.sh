#!/bin/bash
# Copyright (c) 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# This is an example of a script which will delete an OAM deployment
#
# Dependencies: ../common/functions.sh
#               ../responsefile/idm.rsp
#
# Usage: delete_oam.sh [-r responsefile -p passwordfile]
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
. $SCRIPTDIR/common/oam_functions.sh

WORKDIR=$LOCAL_WORKDIR/OAM
LOGDIR=$LOCAL_WORKDIR/delete_logs/OAM
if [ ! -e $LOGDIR ]
then
  mkdir -p $LOGDIR
fi

mkdir $LOCAL_WORKDIR/deleteLogs > /dev/null 2>&1

LOG=$LOCAL_WORKDIR/deleteLogs/delete_oam_`date +%F_%T`.log

START_TIME=$(date +%s)

ST=$(date +%s)

echo "Deleting Oracle Access Manager"
echo "------------------------------"
echo
echo Log of Delete Session can be found at: $LOG
echo

OAM_HOSTS=$(echo $OAM_HOSTS | sed "s/,/  /g")
INSTANCE_NO=0
for oamhost in $OAM_HOSTS
do
  INSTANCE_NO=$((INSTANCE_NO+1))
  ET=$(date +%s)
  print_time STEP "Delete OAM Domain" $ST $ET

  echo  "Stopping OAM"

  $SSH $OAM_OWNER@$oamhost $REMOTE_WORKDIR/stop_oam.sh  >>$LOG 2>&1
  echo "Stopping Nodemanager"
  stop_nm $oamhost $OAM_OWNER $OAM_NM_HOME

# Drop OAM Schemas
#
ST=$(date +%s)

  if [ $INSTANCE_NO -eq 1 ]
  then
    printf "Drop Schemas - "

   drop_schemas  $oamhost $OAM_OWNER >>$LOG 2>&1
   ET=$(date +%s)

   grep -q "Prefix validation failed." $LOG
   if [ $? -eq 0 ]
   then
        echo "Schema Does not exist"
   else
        grep -q "is connected to the" $LOG
        if [ $? -eq 0 ]
        then
             echo "Failed User Connected - see logfile $LOG"
             exit 1
        fi

     grep -q "Drop : Operation Completed" $LOG 
     if [ $? -eq 0 ]
     then
          echo "Success"
     else
          echo "Failed see logfile $LOG"
     fi
   fi
   print_time STEP "Drop Schemas" $ST $ET
  fi
  echo "Delete OAM Domain Files on $oamhost"
  delete_oam_files $oamhost  $LOG 
done


printf "Deleting local working directory - "
if [ ! "$WORKDIR" = "" ] 
then
  rm  -rf $WORKDIR/* 
  print_status $?
else
  echo "Unable to directory $WORKDIR"
fi
printf "Deleting OHS config files - "
if [ ! "$LOCAL_WORKDIR" = "" ]
then
  rm  -rf $LOCAL_WORKDIR/OHS/*/login_vh.conf $LOCAL_WORKDIR/OHS/*/iadadmin_vh.conf $LOCAL_WORKDIR/oam_installed>> $LOG 2>&1
fi
echo "Success"


FINISH_TIME=$(date +%s)
print_time TOTAL "Delete OAM " $START_TIME $FINISH_TIME 
