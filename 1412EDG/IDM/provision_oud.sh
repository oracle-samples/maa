#!/bin/bash
# Copyright (c) 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# This is an example of deploying Oracle Unified Directory, configuring it for use with Oracle Access Manager
# and Oracle Identity Governance.   It will also seed users and groups required by those products
#
# Dependencies: ./common/functions.sh
#               ./common/oud_functions.sh
#               ./responsefile/idm.rsp
#               ./templates/oud
#
# Usage: provision_oud.sh [-r responsefile -p passwordfile]
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

TEMPLATE_DIR=$SCRIPTDIR/templates/oud

START_TIME=$(date +%s)
WORKDIR=$LOCAL_WORKDIR/OUD
LOGDIR=$WORKDIR/logs

if [ "$INSTALL_OUD" != "true" ] && [ "$INSTALL_OUD" != "TRUE" ]
then
     echo "You have not requested OUD installation"
     exit 1
fi

echo 
echo -n "Provisioning OUD on " 
date +"%a %d %b %Y %T" 
echo "--------------------------------------------" 
echo 

create_local_workdir
create_logdir
printf "Using Installer : "
printf "$OUD_INSTALLER\n\n"
echo -n "Provisioning OUD on " >> $LOGDIR/timings.log
date +"%a %d %b %Y %T" >> $LOGDIR/timings.log
echo "------------------------------------------------" >> $LOGDIR/timings.log
echo >> $LOGDIR/timings.log

STEPNO=0
PROGRESS=$(get_progress)
OUD_HOSTS=$(echo $OUD_HOSTS | sed "s/,/  /g")

INSTANCE_NO=0
for ldaphost in $OUD_HOSTS 
do
  INSTANCE_NO=$((INSTANCE_NO+1))
  HOSTLOG=$LOGDIR/$ldaphost
  if [ ! -d $HOSTLOG ]
  then
     mkdir $HOSTLOG
  fi

  new_step
  if [ $STEPNO -gt $PROGRESS ]
  then
     create_remote_workdir $ldaphost $OUD_OWNER
     update_progress
  fi

  new_step
  if [ $STEPNO -gt $PROGRESS ]
  then
     create_oud_install_scripts 
     update_progress
  fi


  new_step
  if [ $STEPNO -gt $PROGRESS ]
  then
     create_oracle_home $ldaphost
     update_progress
  fi

  new_step
  if [ $STEPNO -gt $PROGRESS ]
  then
     install_jdk $ldaphost $OUD_OWNER $OUD_ORACLE_HOME
     update_progress
  fi

  new_step
  if [ $STEPNO -gt $PROGRESS ]
  then
     copy_install_script $ldaphost $OUD_OWNER oud
     update_progress
  fi

  new_step
  if [ $STEPNO -gt $PROGRESS ]
  then
     run_install $ldaphost $OUD_OWNER oud
     update_progress
  fi

  if [ ! "$OUD_PATCHES" = "" ]
  then
     new_step
     if [ $STEPNO -gt $PROGRESS ]
     then
	create_opatch $ldaphost $OUD_OWNER oud
	update_progress
     fi

     new_step
     if [ $STEPNO -gt $PROGRESS ]
     then
        oudPatches=$(echo $OUD_PATCHES | sed 's/,/ /g')
        for patch in $oudPatches
        do 
	   apply_oneoff_patch  $ldaphost $OUD_OWNER oud $patch
        done
        update_progress
     fi

     #apply_patch $ldaphost $OUD_OWNER oud
  fi

  new_step
  if [ $STEPNO -gt $PROGRESS ]
  then
     copy_rsp $ldaphost $OUD_OWNER $RSPFILE $PWDFILE
     update_progress
  fi


  new_step
  if [ $STEPNO -gt $PROGRESS ]
  then
     if [ "$OUD_CERT_TYPE" = "host" ]
     then
        cert_name=$OUD_CERT_STORE/$ldaphost.p12
     else
        cert_name=$OUD_CERT_STORE
     fi
     
     copy_certs $ldaphost $OUD_OWNER $OUD_KEYSTORE_LOC $cert_name $OUD_TRUST_STORE
     update_progress
  fi

  new_step
  if [ $STEPNO -gt $PROGRESS ]
  then
     create_oud_create_script $INSTANCE_NO $ldaphost 
     update_progress
  fi

  new_step
  if [ $STEPNO -gt $PROGRESS ]
  then
     copy_create_script $ldaphost $OUD_OWNER
     update_progress
  fi
  
  new_step
  if [ $STEPNO -gt $PROGRESS ]
  then
     create_instance $ldaphost 
     update_progress
  fi

  if [ $INSTANCE_NO -eq 1 ]
  then

    new_step
    if [ $STEPNO -gt $PROGRESS ]
    then
      create_property_file $ldaphost
      update_progress
    fi

    new_step
    if [ $STEPNO -gt $PROGRESS ]
    then
      update_oud_pwd $ldaphost
      update_progress
    fi

    new_step
    if [ $STEPNO -gt $PROGRESS ]
    then
      create_idmconfig_script
      update_progress
    fi

    new_step
    if [ $STEPNO -gt $PROGRESS ]
    then
       copy_seedfile $ldaphost 
       update_progress
    fi

    new_step
    if [ $STEPNO -gt $PROGRESS ]
    then
       run_preconfig $ldaphost 
       update_progress
    fi

    new_step
    if [ $STEPNO -gt $PROGRESS ]
    then
       run_prepare $ldaphost 
       update_progress
    fi

    new_step
    if [ $STEPNO -gt $PROGRESS ]
    then
       run_addobjectclass $ldaphost 
       update_progress
    fi
  else
    new_step
    if [ $STEPNO -gt $PROGRESS ]
    then
       copy_seedfile $ldaphost 
       update_progress
    fi
  fi
  
done

oudHost1=$(echo $OUD_HOSTS | awk '{print $1}')


if [ $INSTANCE_NO -gt 1 ]
then
   INSTANCE_NO=0
   for ldaphost in $OUD_HOSTS 
   do
     INSTANCE_NO=$((INSTANCE_NO+1))
     if [ $INSTANCE_NO -eq 1 ]
     then
        ldaphost1=$ldaphost
     else
        ldaphost2=$ldaphost

        new_step
        if [ $STEPNO -gt $PROGRESS ]
        then
          create_repl_script $ldaphost1 $ldaphost2
          update_progress
        fi

        new_step
        if [ $STEPNO -gt $PROGRESS ]
        then
          copy_repl_script $ldaphost1 $ldaphost2
            update_progress
        fi

        new_step
        if [ $STEPNO -gt $PROGRESS ]
        then
          enable_replicaton $ldaphost1 $ldaphost2
          update_progress
        fi

     fi
   done
else
    echo "*** Only one Instance so Not enabling replication ***"
fi


for ldaphost in $OUD_HOSTS
do
  new_step
  if [ $STEPNO -gt $PROGRESS ]
  then
     create_acl_property_file $ldaphost $INSTANCE_NO
     update_progress
  fi

  new_step
  if [ $STEPNO -gt $PROGRESS ]
  then
     run_acl $ldaphost 
     update_progress
  fi
  
done



FINISH_TIME=$(date +%s)
print_time TOTAL "Create OUD" $START_TIME $FINISH_TIME 
print_time TOTAL "Create OUD" $START_TIME $FINISH_TIME >> $LOGDIR/timings.log

touch $LOCAL_WORKDIR/oud_installed
