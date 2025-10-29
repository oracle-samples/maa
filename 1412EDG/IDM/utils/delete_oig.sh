#!/bin/bash
# Copyright (c) 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# This is an example of a script which will delete an OIG deployment
#
# Dependencies: ../common/functions.sh
#               ../responsefile/idm.rsp
#
# Usage: delete_oig.sh [-r responsefile -p passwordfile]
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
. $SCRIPTDIR/common/oig_functions.sh

export WORKDIR=$LOCAL_WORKDIR/OIG
LOGDIR=$LOCAL_WORKDIR/delete_logs/OIG
if [ ! -e $LOGDIR ]
then
  mkdir -p $LOGDIR
fi

START_TIME=$(date +%s)

mkdir $LOCAL_WORKDIR/deleteLogs > /dev/null 2>&1

LOG=$LOCAL_WORKDIR/deleteLogs/delete_oig_`date +%F_%T`.log

START_TIME=$(date +%s)

ST=$(date +%s)

echo "Deleting Oracle Identity Governance"
echo "-----------------------------------"
echo
echo Log of Delete Session can be found at: $LOG
echo

ST=$(date +%s)


OIG_HOSTS=$(echo $OIG_HOSTS | sed "s/,/  /g")
INSTANCE_NO=0
for oighost in $OIG_HOSTS
do
  INSTANCE_NO=$((INSTANCE_NO+1))

  ET=$(date +%s)
  echo "Delete OIG Domain" 


  echo  "Stopping OIG"

  $SSH $OIG_OWNER@$oighost $REMOTE_WORKDIR/stop_oig.sh  >>$LOG 2>&1

  # Drop the OIG schemas
  #

  if [ $INSTANCE_NO -eq 1 ]
  then
    printf "Drop Schemas - "
    drop_schemas  $oighost $OIG_OWNER >>$LOG 2>&1
    ET=$(date +%s)

    grep -q "Prefix validation failed." $LOG
    if [ $? -eq 0 ]
    then
      echo "Schema Does not exist"
    else
      grep -q "ORA-01940" $LOG
      if [ $? -eq 0 ]
      then
        echo "Failed User Connected logfile $LOG"
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
  echo "Delete OIG Domain Files on $oighost"
  delete_oig_files $oighost $LOG 
done


echo "Deleting $WORKDIR"
if [ ! "$WORKDIR" = "" ] 
then
  rm  -rf $WORKDIR/*
else
  echo "Unable to working files."

fi

echo "Deleting OHS config Files"
if [ ! "$LOCAL_WORKDIR" = "" ]
then
  rm  -rf $LOCAL_WORKDIR/OHS/*/oim_vh.conf $LOCAL_WORKDIR/OHS/*/igdadmin_vh.conf $LOCAL_WORKDIR/OHS/*/igdinternal_vh.conf $LOCAL_WORKDIR/oig_installed>> $LOG 2>&1
fi 


FINISH_TIME=$(date +%s)
print_time TOTAL "Delete OIG Domain" $START_TIME $FINISH_TIME 
