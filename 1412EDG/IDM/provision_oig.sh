#!/bin/bash
# Copyright (c) 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# This is an example of provisioning Oracle Identity Governance and wiring it to Oracle Unified Directory
# and Oracle Access Manager
#
# Dependencies: ./common/functions.sh
#               ./common/oig_functions.sh
#               ./templates/oig
#               ./responsefile/idm.rsp
#
# Usage: provision_oig.sh [-r responsefile -p passwordfile]
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
. $SCRIPTDIR/common/oig_functions.sh
. $SCRIPTDIR/common/ohs_functions.sh

START_TIME=`date +%s`

TEMPLATE_DIR=$SCRIPTDIR/templates/oig
WORKDIR=$LOCAL_WORKDIR/OIG
LOGDIR=$WORKDIR/logs


if [ "$INSTALL_OIG" != "true" ] && [ "$INSTALL_OIG" != "TRUE" ]
then
     echo "You have not requested OIG installation"
     exit 1
fi

echo
echo -n "Provisioning OIG on "
date +"%a %d %b %Y %T"
echo "---------------------------------------------"
echo

create_local_workdir
create_logdir
printf "Using Installer : "
printf "$OIG_QUICK_INSTALLER\n\n"

echo -n "Provisioning OIG on " >> $LOGDIR/timings.log
date +"%a %d %b %Y %T" >> $LOGDIR/timings.log
echo "-----------------------------------------------" >> $LOGDIR/timings.log
echo >> $LOGDIR/timings.log
printf "Using Image:">> $LOGDIR/timings.log
printf "\n\t$OIG_QUICK_INSTALLER">> $LOGDIR/timings.log
STEPNO=0
PROGRESS=$(get_progress)

OIG_HOSTS=$(echo $OIG_HOSTS | sed "s/,/  /g")
oighost1=$(echo $OIG_HOSTS | awk '{ print $1}')

INSTANCE_NO=0
for oighost in $OIG_HOSTS
do
  INSTANCE_NO=$((INSTANCE_NO+1))
  HOSTLOG=$LOGDIR/$oighost

  if [ ! -d $HOSTLOG ]
  then
     mkdir $HOSTLOG
  fi

  new_step
  if [ $STEPNO -gt $PROGRESS ]
  then
    create_remote_workdir $oighost $OIG_OWNER
    update_progress
  fi

  new_step
  if [ $STEPNO -gt $PROGRESS ]
  then
     create_oig_install_scripts 
     update_progress
  fi

  new_step
  if [ $STEPNO -gt $PROGRESS ]
  then
     install_jdk $oighost $OIG_OWNER $OIG_ORACLE_HOME
     update_progress
  fi

  new_step
  if [ $STEPNO -gt $PROGRESS ]
  then
     copy_install_script $oighost $OIG_OWNER oig
     update_progress
  fi

  new_step
  if [ $STEPNO -gt $PROGRESS ]
  then
     run_install $oighost $OIG_OWNER oig
     update_progress
  fi

  if [ ! "$GEN_PATCH" = "" ]
  then
     new_step
     if [ $STEPNO -gt $PROGRESS ]
     then
        apply_patch $oighost $OIG_OWNER oig
        update_progress
     fi
  fi

  if  [ "$INSTALL_OAM" = "true" ] && [ "$OAM_OIG_INTEG" = "true" ]
  then
    # Copy Connector to Container
    #
      new_step
      if [ $STEPNO -gt $PROGRESS ]
      then
         copy_connector $oighost $OIG_OWNER
         update_progress
      fi
  fi


  new_step
  if [ $STEPNO -gt $PROGRESS ]
  then
     copy_rsp $oighost $OIG_OWNER $RSPFILE $PWDFILE
     update_progress
  fi

  new_step
  if [ $STEPNO -gt $PROGRESS ]
  then
     copy_certs $oighost $OIG_OWNER $OIG_KEYSTORE_LOC $OIG_CERT_STORE $OIG_TRUST_STORE
     update_progress
  fi



  if [ $INSTANCE_NO -eq 1 ]
  then  

     new_step
     if [ $STEPNO -gt $PROGRESS ]
     then
       create_sedfile $oighost
       update_progress
     fi

     new_step
     if [ $STEPNO -gt $PROGRESS ]
     then
       make_create_scripts $oighost
       update_progress
     fi

     new_step
     if [ $STEPNO -gt $PROGRESS ]
     then
       copy_create_scripts $oighost $OIG_OWNER 
       update_progress
     fi

     new_step
     if [ $STEPNO -gt $PROGRESS ]
     then
       if [ "$OIG_CERT_TYPE" = "host" ]
       then
          certAlias=$(echo $oighost | cut -f1 -d.)
       else
          certAlias=$OIG_CERT_NAME
       fi
       create_per_hostnm $oighost $OIG_OWNER $INSTANCE_NO $OIG_DOMAIN_NAME $OIG_DOMAIN_HOME $OIG_MSERVER_HOME $certAlias
       update_progress
     fi

     new_step
     if [ $STEPNO -gt $PROGRESS ]
     then
       start_nm $oighost $OIG_OWNER $OIG_NM_HOME
       update_progress
     fi

     new_step
     if [ $STEPNO -gt $PROGRESS ]
     then
        check_ldap_user $LDAP_OIGLDAP_USER
        update_progress
     fi

     new_step
     if [ $STEPNO -gt $PROGRESS ]
     then
        create_schemas $oighost $OIG_OWNER OIG
        update_progress
     fi

     new_step
     if [ $STEPNO -gt $PROGRESS ]
     then
        create_domain $oighost $OIG_OWNER OIG
        update_progress
     fi

     new_step
     if [ $STEPNO -gt $PROGRESS ]
     then
        run_offline_config $oighost 
        update_progress
     fi

     new_step
     if [ $STEPNO -gt $PROGRESS ]
     then
        update_ssl $oighost $OIG_OWNER 
        update_progress
     fi

     new_step
     if [ $STEPNO -gt $PROGRESS ]
     then
        update_domainenv $oighost1 
        update_progress
     fi

     new_step
     if [ $STEPNO -gt $PROGRESS ]
     then
        start_admin $oighost 
        update_progress
     fi

     new_step
     if [ $STEPNO -gt $PROGRESS ]
     then
        enroll_domain $oighost 
        update_progress
     fi


     new_step
     if [ $STEPNO -gt $PROGRESS ]
     then
        start_ms $oighost1 $INSTANCE_NO
        update_progress
     fi
     new_step
     if [ $STEPNO -gt $PROGRESS ]
     then
       check_oim_bootstrap $oighost $OIG_OWNER
       update_progress
     fi

     ######################
     ## TO BE REMOVED #####

     #new_step
     #if [ $STEPNO -gt $PROGRESS ]
     #then
        #create_wls_user $oighost1 
        #update_progress
     #fi

     #new_step
     #if [ $STEPNO -gt $PROGRESS ]
     #then
     #   update_soa_urls $oighost $OIG_OWNER
     #   update_progress
     #fi

     if [ "$OAM_OIG_INTEG" = "true" ]
     then
        new_step
        if [ $STEPNO -gt $PROGRESS ]
        then
           run_integration $oighost $OIG_OWNER configureSSOIntegration
           update_progress
        fi
     fi

     new_step
     if [ $STEPNO -gt $PROGRESS ]
     then
        run_integration $oighost $OIG_OWNER configureLDAPConnector
        update_progress
     fi

     #
     # Create an Email Driver
     #
     if [ "$OIG_EMAIL_CREATE" = "true" ] || [ "$OIG_EMAIL_CREATE" = "TRUE" ] 
     then
         new_step
         if [ $STEPNO -gt $PROGRESS ]
         then
           create_email_driver $oighost $OIG_OWNER
           update_progress
         fi
     
         new_step
         if [ $STEPNO -gt $PROGRESS ]
         then
     #      set_email_notifications $oighost $OIG_OWNER
           update_progress
         fi

     fi

     if [ "$OAM_OIG_INTEG" = "true" ]
     then
        new_step
        if [ $STEPNO -gt $PROGRESS ]
        then
           run_integration $oighost $OIG_OWNER configureWLSAuthnProviders
           update_progress
        fi

        new_step
        if [ $STEPNO -gt $PROGRESS ]
        then
           run_integration $oighost $OIG_OWNER configureSSOIntegration
           update_progress
        fi

        new_step
        if [ $STEPNO -gt $PROGRESS ]
        then
           run_integration $oighost $OIG_OWNER configureSOAIntegration
           update_progress
        fi
        new_step
        if [ $STEPNO -gt $PROGRESS ]
        then
           run_integration $oighost $OIG_OWNER enableOAMSessionDeletion
           update_progress
        fi

     new_step
     if [ $STEPNO -gt $PROGRESS ]
     then
        stop_ms $oighost 
        update_progress
     fi

     new_step
     if [ $STEPNO -gt $PROGRESS ]
     then
        start_admin $oighost 
        update_progress
     fi


     # Assign WSM Roles
     #
     if [ "$OAM_OIG_INTEG" = "true" ]
     then
        new_step
        if [ $STEPNO -gt $PROGRESS ]
        then
           assign_wsmroles $oighost
           update_progress
        fi
     fi

     new_step
     if [ $STEPNO -gt $PROGRESS ]
     then
        start_ms $oighost1 $INSTANCE_NO
        update_progress
     fi


     fi
     # Integrate OIG and BI
     #
     if [ "$OIG_BI_INTEG" = "true" ] || [ "$OIG_BI_INTEG" = "TRUE" ]
     then
         new_step
         if [ $STEPNO -gt $PROGRESS ]
         then
           update_biconfig $oighost $OIG_OWNER
           update_progress
         fi
     fi

     new_step
     if [ $STEPNO -gt $PROGRESS ]
     then
        stop_ms $oighost 
        update_progress
     fi

     new_step
     if [ $STEPNO -gt $PROGRESS ]
     then
        stop_nm $oighost $OIG_OWNER $OIG_NM_HOME
        update_progress
     fi

     # Get Loadbalancer Certificates
     #
     certs=false
     if  [ "$INSTALL_OAM" = "true" ] && [ "$OAM_OIG_INTEG" = "true" ] && [ "$OIG_DOMAIN_SSL_ENABLED" = "false" ]
     then
          new_step
          if [ $STEPNO -gt $PROGRESS ]
          then
             get_lbr_certificate $OAM_LOGIN_LBR_HOST $OAM_LOGIN_LBR_PORT
             update_progress
          fi
          certs=true
     fi
     new_step
     if [ $STEPNO -gt $PROGRESS ]
     then
        pack_domain oig
        update_progress
     fi

     new_step
     if [ $STEPNO -gt $PROGRESS ]
     then
        reconfig_nm $oighost $OIG_OWNER $OIG_NM_HOME $OIG_DOMAIN_NAME "$OIG_MSERVER_HOME;$OIG_DOMAIN_HOME"
        update_progress
     fi
  else
     new_step
     if [ $STEPNO -gt $PROGRESS ]
     then
       if [ "$OIG_CERT_TYPE" = "host" ]
       then
          certAlias=$(echo $oighost | cut -f1 -d.)
       else
          certAlias=$OAM_CERT_NAME
       fi
       create_per_hostnm $oighost $OIG_OWNER $INSTANCE_NO $OIG_DOMAIN_NAME $OIG_DOMAIN_HOME $OIG_MSERVER_HOME $certAlias
       update_progress
     fi
  fi

  new_step
  if [ $STEPNO -gt $PROGRESS ]
  then
    start_nm $oighost $OIG_OWNER $OIG_NM_HOME 
    update_progress
  fi

  new_step
  if [ $STEPNO -gt $PROGRESS ]
  then
    unpack_domain oig $oighost
    update_progress
  fi
  
  if [ $INSTANCE_NO -eq 1 ]
  then
     new_step
     if [ $STEPNO -gt $PROGRESS ]
     then
        start_admin $oighost1
        update_progress
     fi
  fi

  new_step
  if [ $STEPNO -gt $PROGRESS ]
  then
    start_ms $oighost1 $INSTANCE_NO
    update_progress
  fi

done

new_step
if [ $STEPNO -gt $PROGRESS ]
then
   create_oig_ohs_config
   update_progress
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

# Add certificates to Oracle Keystore Service
#
if [ "$certs" = "true" ]
then
   new_step
   if [ $STEPNO -gt $PROGRESS ]
   then
      add_certs_to_kss
      update_progress
   fi
fi



if  [ "$INSTALL_OAM" = "true" ] && [ "$OAM_OIG_INTEG" = "true" ]
then
   # Restart OAM Domain
   #
   new_step
   if [ $STEPNO -gt $PROGRESS ]
   then
      stop_oam_domain 
      update_progress
   fi

   new_step
   if [ $STEPNO -gt $PROGRESS ]
   then
      start_oam_domain 
      update_progress
   fi
fi

FINISH_TIME=`date +%s`
print_time TOTAL "Create OIG" $START_TIME $FINISH_TIME 
print_time TOTAL "Create OIG" $START_TIME $FINISH_TIME >> $LOGDIR/timings.log

touch $LOCAL_WORKDIR/oig_installed
exit

