#!/bin/bash
# Copyright (c) 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# This is an example of a script which can be used to deploy Oracle Access Manager and wire it to 
# Oracle Unified Directory
#
# Dependencies: ./common/functions.sh
#               ./common/oam_functions.sh
#               ./templates/oam
#               ./responsefile/idm.rsp
#
# Usage: provision_oam.sh  [-r responsefile -p passwordfile]
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
. $SCRIPTDIR/common/oam_functions.sh
. $SCRIPTDIR/common/ohs_functions.sh

START_TIME=$(date +%s)

TEMPLATE_DIR=$SCRIPTDIR/templates/oam
WORKDIR=$LOCAL_WORKDIR/OAM
LOGDIR=$WORKDIR/logs


if [ "$INSTALL_OAM" != "true" ] 
then
     echo "You have not requested OAM installation"
     exit 1
fi

echo
echo -n "Provisioning OAM on "
date +"%a %d %b %Y %T"
echo "--------------------------------------------"

create_local_workdir
create_logdir
printf "Using Installers:"
printf "\n\t$OAM_INFRA_INSTALLER"
printf "\n\t$OAM_IDM_INSTALLER\n\n"

echo -n "Provisioning OAM on " >> $LOGDIR/timings.log
date +"%a %d %b %Y %T" >> $LOGDIR/timings.log
echo "-------------------------------------------" >> $LOGDIR/timings.log

STEPNO=0
PROGRESS=$(get_progress)

OAM_HOSTS=$(echo $OAM_HOSTS | sed "s/,/  /g")
oamhost1=$(echo $OAM_HOSTS | awk '{ print $1}')


INSTANCE_NO=0
for oamhost in $OAM_HOSTS
do
  INSTANCE_NO=$((INSTANCE_NO+1))

  HOSTLOG=$LOGDIR/$oamhost
  if [ ! -d $HOSTLOG ]
  then
     mkdir $HOSTLOG
  fi
  new_step
  if [ $STEPNO -gt $PROGRESS ]
  then
    create_remote_workdir $oamhost $OAM_OWNER
    update_progress
  fi
  
  new_step
  if [ $STEPNO -gt $PROGRESS ]
  then
     create_oam_install_scripts
     update_progress
  fi

  new_step
  if [ $STEPNO -gt $PROGRESS ]
  then
     install_jdk $oamhost $OAM_OWNER $OAM_ORACLE_HOME
     update_progress
  fi

  new_step
  if [ $STEPNO -gt $PROGRESS ]
  then
     copy_install_script $oamhost $OAM_OWNER oam
     update_progress
  fi

  new_step
  if [ $STEPNO -gt $PROGRESS ]
  then
     run_install $oamhost $OAM_OWNER oam
     update_progress
  fi

  if [ ! "$GEN_PATCH" = "" ]
  then
     new_step
     if [ $STEPNO -gt $PROGRESS ]
     then
        apply_patch $oamhost $OAM_OWNER oam
        update_progress
     fi
  fi

  new_step
  if [ $STEPNO -gt $PROGRESS ]
  then
     copy_rsp $oamhost $OAM_OWNER $RSPFILE $PWDFILE
     update_progress
  fi

  new_step
  if [ $STEPNO -gt $PROGRESS ]
  then
     copy_certs $oamhost $OAM_OWNER $OAM_KEYSTORE_LOC $OAM_CERT_STORE $OAM_TRUST_STORE
     update_progress
  fi

  if [ $INSTANCE_NO -eq 1 ]
  then
     new_step
     if [ $STEPNO -gt $PROGRESS ]
     then
       create_sedfile $oamhost
       update_progress
     fi

     new_step
     if [ $STEPNO -gt $PROGRESS ]
     then
       make_create_scripts $oamhost
       update_progress
     fi

     new_step
     if [ $STEPNO -gt $PROGRESS ]
     then
       copy_create_scripts $oamhost $OAM_OWNER
       update_progress
     fi

     new_step
     if [ $STEPNO -gt $PROGRESS ]
     then
       if [ "$OAM_CERT_TYPE" = "host" ]
       then
          certAlias=$(echo $oamhost | cut -f1 -d.)
       else
          certAlias=$OAM_CERT_NAME
       fi

       create_per_hostnm $oamhost $OAM_OWNER $INSTANCE_NO $OAM_DOMAIN_NAME $OAM_DOMAIN_HOME $OAM_MSERVER_HOME $certAlias
       update_progress
     fi
     
     new_step
     if [ $STEPNO -gt $PROGRESS ]
     then
       start_nm $oamhost $OAM_OWNER $OAM_NM_HOME
       update_progress
     fi

     new_step
     if [ $STEPNO -gt $PROGRESS ]
     then
        check_ldap_user $LDAP_OAMLDAP_USER
        update_progress
     fi

     new_step
     if [ $STEPNO -gt $PROGRESS ]
     then
        create_schemas $oamhost $OAM_OWNER OAM
        update_progress
     fi

     new_step
     if [ $STEPNO -gt $PROGRESS ]
     then
        create_domain $oamhost $OAM_OWNER OAM
        update_progress
     fi

     new_step
     if [ $STEPNO -gt $PROGRESS ]
     then
        update_ssl $oamhost $OAM_OWNER
        update_progress
     fi


     # Enroll Domain with Node Manager
     #
     new_step
     if [ $STEPNO -gt $PROGRESS ]
     then
         enroll_domain $oamhost
         update_progress
     fi

     # Start Domain
     #
     new_step
     if [ $STEPNO -gt $PROGRESS ]
     then
         start_admin $oamhost
         update_progress
     fi

    # Update OAM HostIds
    #
    new_step
    if [ $STEPNO -gt $PROGRESS ]
    then
       if [ "$OAM_DOMAIN_SSL_ENABLED" = "true" ]
       then
          oamAdminUrl="https://$OAM_ADMIN_HOST:$OAM_ADMIN_SSL_PORT"
       else
          oamAdminUrl="http://$OAM_ADMIN_HOST:$OAM_ADMIN_PORT"
       fi
       update_oam_hostids $oamAdminUrl $OAM_WLS_ADMIN_USER:$OAM_WLS_PWD
       update_progress
    fi

    # run idmConfigTool to wire to OUD
    #
    new_step
    if [ $STEPNO -gt $PROGRESS ]
    then
       run_idmConfigTool $oamhost
       update_progress
    fi

    # Update OAM Datasouce
    #
    new_step
    if [ $STEPNO -gt $PROGRESS ]
    then
       update_oamds $oamhost
       update_progress
    fi

    # Add ADF logout
    #
    new_step
    if [ $STEPNO -gt $PROGRESS ]
    then
       config_adf_logout $oamhost
       update_progress
    fi

    # Stop Domain
    #
    new_step
    if [ $STEPNO -gt $PROGRESS ]
    then
       stop_oam_domain $oamhost
       update_progress
    fi


    new_step
    if [ $STEPNO -gt $PROGRESS ]
    then
       stop_nm $oamhost $OAM_OWNER $OAM_NM_HOME
       update_progress
    fi

    new_step
    if [ $STEPNO -gt $PROGRESS ]
    then
      pack_domain oam
      update_progress
    fi

    new_step
    if [ $STEPNO -gt $PROGRESS ]
    then
        reconfig_nm $oamhost $OAM_OWNER $OAM_NM_HOME $OAM_DOMAIN_NAME "$OAM_MSERVER_HOME;$OAM_DOMAIN_HOME"
         update_progress
    fi
  else
     new_step
     if [ $STEPNO -gt $PROGRESS ]
     then
       if [ "$OAM_CERT_TYPE" = "host" ]
       then
          certAlias=$(echo $oamhost | cut -f1 -d.)
       else
          certAlias=$OAM_CERT_NAME
       fi

       create_per_hostnm $oamhost $OAM_OWNER $INSTANCE_NO $OAM_DOMAIN_NAME $OAM_DOMAIN_HOME $OAM_MSERVER_HOME $certAlias
       update_progress
     fi
  fi

  new_step
  if [ $STEPNO -gt $PROGRESS ]
  then
    start_nm $oamhost $OAM_OWNER $OAM_NM_HOME 5
    update_progress
  fi

  new_step
  if [ $STEPNO -gt $PROGRESS ]
  then
    unpack_domain oam $oamhost
    update_progress
  fi

  if [ $INSTANCE_NO -eq 1 ]
  then
     new_step
     if [ $STEPNO -gt $PROGRESS ]
     then
        start_admin $oamhost1
        update_progress
     fi
  fi

  new_step
  if [ $STEPNO -gt $PROGRESS ]
  then
    start_ms $oamhost1 $INSTANCE_NO
    update_progress
  fi

done

new_step
if [ $STEPNO -gt $PROGRESS ]
then
    create_oam_ohs_config
    update_progress
fi

if [ "$COPY_WG_FILES" = "true" ]
then
   new_step
   if [ $STEPNO -gt $PROGRESS ]
   then
       copy_wg_files
       update_progress
   fi
fi

new_step
if [ $STEPNO -gt $PROGRESS ]
then
    if [ "$UPDATE_OHS" = "true" ]
    then
       copy_ohs_config
       update_progress
    fi
fi


new_step
if [ $STEPNO -gt $PROGRESS ]
then
   check_healthcheck_ok
   update_progress
fi

FINISH_TIME=$(date +%s)
print_time TOTAL "Create OAM" $START_TIME $FINISH_TIME 
print_time TOTAL "Create OAM" $START_TIME $FINISH_TIME >> $LOGDIR/timings.log

touch $LOCAL_WORKDIR/oam_installed
