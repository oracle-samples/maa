#!/bin/bash
# Copyright (c) 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# This is an example of provisioning Oracle HTTP Server
#
# Dependencies: ./common/functions.sh
#               ./common/ohs_functions.sh
#               ./templates/ohs
#               ./responsefile/idm.rsp
#
# Usage: provision_ohs.sh [-r responsefile -p passwordfile]
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
. $SCRIPTDIR/common/ohs_functions.sh


START_TIME=`date +%s`

WORKDIR=$LOCAL_WORKDIR/OHS
LOGDIR=$WORKDIR/logs
HOSTLOG=$LOGDIR
TEMPLATE_DIR=$SCRIPTDIR/templates/ohs


if [ "$INSTALL_OHS" != "true" ] && [ "$INSTALL_OHS" != "TRUE" ]
then
     echo "You have not requested OHS installation"
     exit 1
fi

create_local_workdir
create_logdir
echo
echo -n "Provisioning Oracle HTTP Server on "
date +"%a %d %b %Y %T"
echo "-----------------------------------------------------------"
echo

echo -n "Provisioning Oracle HTTP Server on " >> $LOGDIR/timings.log
date +"%a %d %b %Y %T" >> $LOGDIR/timings.log
echo "----------------------------------------------------------" >> $LOGDIR/timings.log
echo 

STEPNO=0
PROGRESS=$(get_progress)


OHS_HOSTS=$(echo $OHS_HOSTS | sed "s/,/  /g")

INSTANCE_NO=0
for OHSHOST in $OHS_HOSTS
do
  INSTANCE_NO=$((INSTANCE_NO+1))

  HOSTLOG=$LOGDIR/$OHSHOST
  if [ ! -d $HOSTLOG ]
  then 
     mkdir $HOSTLOG
  fi
  new_step
  if [ $STEPNO -gt $PROGRESS ]
  then
    create_remote_workdir $OHSHOST $OHS_OWNER
    update_progress
  fi

  new_step
  if [ $STEPNO -gt $PROGRESS ]
  then
    create_config_dir $OHSHOST 
    update_progress
  fi

  new_step
  if [ $STEPNO -gt $PROGRESS ]
  then
     create_ohs_install_scripts
     update_progress
  fi

  new_step
  if [ $STEPNO -gt $PROGRESS ]
  then
     install_jdk $OHSHOST $OHS_OWNER $OHS_ORACLE_HOME
     update_progress
  fi

  new_step
  if [ $STEPNO -gt $PROGRESS ]
  then
     copy_install_script $OHSHOST $OHS_OWNER ohs
     update_progress
  fi

  new_step
  if [ $STEPNO -gt $PROGRESS ]
  then
     run_install $OHSHOST $OHS_OWNER ohs
     update_progress
  fi

  new_step
  if [ $STEPNO -gt $PROGRESS ]
  then
    create_instance_file $OHSHOST ohs${INSTANCE_NO}
    update_progress
  fi

  new_step
  if [ $STEPNO -gt $PROGRESS ]
  then
    create_instance $OHSHOST ohs${INSTANCE_NO}
    update_progress
  fi

  new_step
  if [ $STEPNO -gt $PROGRESS ]
  then
    tune_instance $OHSHOST ohs${INSTANCE_NO}
    update_progress
  fi

  new_step
  if [ $STEPNO -gt $PROGRESS ]
  then
    create_hc  $OHSHOST  ohs${INSTANCE_NO}
    update_progress
  fi

  new_step
  if [ $STEPNO -gt $PROGRESS ]
  then
    start_nm_ohs $OHSHOST 
    update_progress
  fi

  if [ "$OHS_SSL_ENABLED" = "true" ]
  then
    new_step
    if [ $STEPNO -gt $PROGRESS ]
    then
      create_default_wallet $OHSHOST 
      update_progress
    fi

    if [ "$INSTALL_OAM" = "true" ] && [ "$OAM_DOMAIN_SSL_ENABLED" = "true" ]
    then
       if [ "$OHS_CERT_TYPE" = "host" ]
       then
            oamAdminCert="${OHS_OAM_ADMIN_CERT%.*}.$OHSHOST.${OHS_OAM_ADMIN_CERT##*.}"
            oamLoginCert="${OHS_OAM_LOGIN_CERT%.*}.$OHSHOST.${OHS_OAM_LOGIN_CERT##*.}"
            oigAdminCert="${OHS_OIG_ADMIN_CERT%.*}.$OHSHOST.${OHS_OIG_ADMIN_CERT##*.}"
            oigOimCert="${OHS_OIG_OIM_CERT%.*}.$OHSHOST.${OHS_OIG_OIM_CERT##*.}"
            oigIntCert="${OHS_OIG_INT_CERT%.*}.$OHSHOST.${OHS_OIG_INT_CERT##*.}"
       else
            oamAdminCert=$OHS_OAM_ADMIN_CERT
            oamLoginCert=$OHS_OAM_LOGIN_CERT
            oigAdminCert=$OHS_OIG_ADMIN_CERT
            oigOimCert=$OHS_OIG_OIM_CERT
            oigIntCert=$OHS_OIG_INT_CERT
       fi
       new_step
       if [ $STEPNO -gt $PROGRESS ]
       then
         create_host_wallet $OHSHOST $OAM_ADMIN_LBR_HOST $oamAdminCert $OHS_OAM_ADMIN_KS_PWD $OAM_TRUST_STORE $OAM_KEYSTORE_PWD
         update_progress
       fi

       new_step
       if [ $STEPNO -gt $PROGRESS ]
       then
         create_host_wallet $OHSHOST $OAM_LOGIN_LBR_HOST $oamLoginCert $OHS_OAM_LOGIN_KS_PWD $OAM_TRUST_STORE $OAM_KEYSTORE_PWD
         update_progress
       fi
    fi

    if [ "$INSTALL_OIG" = "true" ] && [ "$OIG_DOMAIN_SSL_ENABLED" = "true" ]
    then
       new_step
       if [ $STEPNO -gt $PROGRESS ]
       then
         create_host_wallet $OHSHOST $OIG_ADMIN_LBR_HOST $oigAdminCert $OHS_OIG_ADMIN_KS_PWD $OIG_TRUST_STORE $OAM_KEYSTORE_PWD
         update_progress
       fi

       new_step
       if [ $STEPNO -gt $PROGRESS ]
       then
         create_host_wallet $OHSHOST $OIG_LBR_HOST $oigOimCert $OHS_OIG_OIM_KS_PWD $OIG_TRUST_STORE $OIG_KEYSTORE_PWD
         update_progress
       fi

       new_step
       if [ $STEPNO -gt $PROGRESS ]
       then
         create_host_wallet $OHSHOST $OIG_LBR_INT_HOST $oigIntCert $OHS_OIG_INT_KS_PWD $OIG_TRUST_STORE $OIG_KEYSTORE_PWD
         update_progress
       fi
     fi

    new_step
    if [ $STEPNO -gt $PROGRESS ]
    then
      create_modwl $OHSHOST ohs${INSTANCE_NO}
      update_progress
    fi
  fi 


  if [ "$DEPLOY_WG" = "true" ]
  then
      new_step
      if [ $STEPNO -gt $PROGRESS ]
      then
        deploy_webgate $OHSHOST ohs${INSTANCE_NO}
        update_progress
      fi

      new_step
      if [ $STEPNO -gt $PROGRESS ]
      then
        install_webgate $OHSHOST ohs${INSTANCE_NO}
        update_progress
      fi

      new_step
      if [ $STEPNO -gt $PROGRESS ]
      then
        update_webgate $OHSHOST ohs${INSTANCE_NO}
        update_progress
      fi

      new_step
      if [ $STEPNO -gt $PROGRESS ]
      then
        copy_lbr_cert $OHSHOST ohs${INSTANCE_NO}
        update_progress
      fi
  fi

  new_step
  if [ $STEPNO -gt $PROGRESS ]
  then
    start_ohs $OHSHOST ohs${INSTANCE_NO}
    update_progress
  fi
done


FINISH_TIME=$(date +%s)
print_time TOTAL "Create Oracle HTTP Server" $START_TIME $FINISH_TIME 
print_time TOTAL "Create Oracle HTTP Server" $START_TIME $FINISH_TIME >> $LOGDIR/timings.log

touch $LOCAL_WORKDIR/ohs_installed
