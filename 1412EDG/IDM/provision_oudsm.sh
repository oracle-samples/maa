#!/bin/bash
# Copyright (c) 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# This is an example of provisioning Oracle Unified Directory Services Manager
#
# Dependencies: ./common/functions.sh
#               ./common/oud_functions.sh
#               ./templates/oudsm
#               ./responsefile/idm.rsp
#
# Usage: provision_oudsm.sh [-r responsefile -p passwordfile]
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

. $SCRIPTDIR/common/functions.sh
. $SCRIPTDIR/common/oud_functions.sh

START_TIME=$(date +%s)
TEMPLATE_DIR=$SCRIPTDIR/templates/oudsm
WORKDIR=$LOCAL_WORKDIR/OUDSM

LOGDIR=$WORKDIR/logs
HOSTLOG=$LOGDIR

if [ "$INSTALL_OUDSM" != "true" ] && [ "$INSTALL_OUDSM" != "TRUE" ]
then
     echo "You have not requested OUDSM installation"
     exit 1
fi


echo
echo -n "Provisioning OUDSM on "
date +"%a %d %b %Y %T"
echo "--------------------------------------------------"
echo

create_local_workdir
create_logdir
printf "Using Installer : "
printf "$OUD_INSTALLER\n\n"

echo -n "Provisioning OUDSM on " >> $LOGDIR/timings.log
date +"%a %d %b %Y %T" >> $LOGDIR/timings.log
echo "-------------------------------------------------" >> $LOGDIR/timings.log
echo >> $LOGDIR/timings.log

STEPNO=1
PROGRESS=$(get_progress)

# Create OUDSM
#
if [ $STEPNO -gt $PROGRESS ]
then
    create_oudsm_install_scripts
    update_progress
fi

new_step
if [ $STEPNO -gt $PROGRESS ]
then
   install_jdk $OUDSM_HOST $OUDSM_OWNER $OUDSM_ORACLE_HOME
   update_progress
fi

new_step
if [ $STEPNO -gt $PROGRESS ]
then
   copy_install_script $OUDSM_HOST $OUDSM_OWNER oudsm
   update_progress
fi

new_step
if [ $STEPNO -gt $PROGRESS ]
then
   run_install $OUDSM_HOST $OUDSM_OWNER oudsm
   update_progress
fi

new_step
if [ $STEPNO -gt $PROGRESS ]
then
    create_oudsm_wlst
    update_progress
fi
new_step
if [ $STEPNO -gt $PROGRESS ]
then
    create_oudsm
    update_progress
fi

# Start OUDSM Domain
#
new_step
if [ $STEPNO -gt $PROGRESS ] 
then
   start_oudsm
   update_progress
fi

# Create OUDSM OHS Entries
#
new_step
if [ $STEPNO -gt $PROGRESS ]
then
    create_oudsm_ohs_entries
    update_progress
fi

FINISH_TIME=$(date +%s)
print_time TOTAL "Create OUDSM" $START_TIME $FINISH_TIME 
print_time TOTAL "Create OUDSM" $START_TIME $FINISH_TIME >> $LOGDIR/timings.log
touch $LOCAL_WORKDIR/oudsm_installed
