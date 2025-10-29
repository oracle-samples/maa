#!/bin/bash
# Copyright (c) 2021, 2024, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# This is an example of the checks that can be performed before Provisioning Identity Management
# to reduce the likelihood of provisioning failing.
#
# Dependencies: ./common/functions.sh
# 
# Usage: prereqchecks.sh [-r responsefile -p passwordfile]
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

OAM_HOSTS=$(echo $OAM_HOSTS | sed 's/,/ /g')
OHS_HOSTS=$(echo $OHS_HOSTS | sed 's/,/ /g')
OUD_HOSTS=$(echo $OUD_HOSTS | sed 's/,/ /g')
OIG_HOSTS=$(echo $OIG_HOSTS | sed 's/,/ /g')

echo "***********************************"
echo "*                                 *"
echo "* Performing Pre-requisite checks *"
echo "*                                 *"
echo "***********************************"
echo
FAIL=0
WARN=0
echo "Performing General Checks"
echo "-------------------------"

if [ "$INSTALL_OUD" = "true" ] && [ "$INSTALL_OID" = "true" ]
then
    echo "Install OUD or OID but not both."
    FAIL=$((FAIL+1))
fi

echo -n "Checking Local Working Directory : "
if [ -d $LOCAL_WORKDIR ]
then
      echo "Success"
else
      echo -n "Directory Does not exist - Creating"
      mkdir -p $LOCAL_WORKDIR
      if [ $? = 0 ]
      then
         echo ".. Success"
      else
         echo ".. Failed"
         FAIL=$((FAIL+1))
      fi
fi

if [ "$INSTALL_OHS" = "true" ]
then
   hosts="$OHS_HOSTS"
fi
if [ "$INSTALL_OUD" = "true" ]
then
   hosts="$hosts $OUD_HOSTS"
fi
if [ "$INSTALL_OAM" = "true" ]
then
   hosts="$hosts $OAM_ADMIN_HOST $OAM_HOSTS"
fi
if [ "$INSTALL_OIG" = "true" ]
then
   hosts="$hosts $OIG_ADMIN_HOST $OIG_HOSTS"
fi
hosts=$(echo $hosts | sed 's/,/ /g')

echo "Checking SSH Connectivity"
for host in $hosts
do
    check_connectivity $host 22
    FAIL=$((FAIL+$?))
done


if [ "$INSTALL_OHS" = "true" ] || [ "$UPDATE_OHS" = "true" ] || [ "$COPY_WG_FILES" = "true" ]
then
    echo "Checking SSH Equivalence for OHS User $OHS_OWNER"
    check_ssh "$OHS_HOSTS" $OHS_OWNER
    FAIL=$((FAIL+$?))
fi

if [ "$INSTALL_OUD" = "true" ]
then
    echo "Checking SSH Equivalence for OUD User $OUD_OWNER"
    check_ssh "$OUD_HOSTS" $OUD_OWNER
    FAIL=$((FAIL+$?))
fi

if [ "$INSTALL_OAM" = "true" ]
then
    echo "Checking SSH Equivalence for OAM User $OAM_OWNER"
    check_ssh "$OAM_HOSTS" $OAM_OWNER
    FAIL=$((FAIL+$?))
fi

if [ "$INSTALL_OIG" = "true" ]
then
    echo "Checking SSH Equivalence for OIG $OIG_OWNER"
    check_ssh "$OIG_HOSTS" $OIG_OWNER
    FAIL=$((FAIL+$?))
fi


# Check Load Balancers are set up
#


echo ""
echo "Checking Loadbalancers are setup"
echo "--------------------------------"
if [ "$INSTALL_OAM" = "true" ]
then
    if ! check_lbr $OAM_LOGIN_LBR_HOST $OAM_LOGIN_LBR_PORT
    then
        echo "Setup $OAM_LOGIN_LBR_HOST:$OAM_LOGIN_LBR_HOST Before continuing."
        FAIL=$((FAIL+1))
    fi
    if ! check_lbr $OAM_ADMIN_LBR_HOST $OAM_ADMIN_LBR_PORT
    then
        echo "Setup $OAM_ADMIN_LBR_HOST:$OAM_ADMIN_LBR_HOST Before continuing."
        FAIL=$((FAIL+1))
    fi
fi

if [ "$INSTALL_OIG" = "true" ]
then
    if ! check_lbr $OIG_LBR_HOST $OIG_LBR_PORT
    then
        echo "Setup $OIG_LBR_HOST:$OIG_LBR_HOST Before continuing."
        FAIL=$((FAIL+1))
    fi
    if ! check_lbr $OIG_ADMIN_LBR_HOST $OIG_ADMIN_LBR_PORT
    then
        echo "Setup $OIG_ADMIN_LBR_HOST:$OIG_ADMIN_LBR_HOST Before continuing."
        FAIL=$((FAIL+1))
    fi

    if ! check_lbr $OIG_LBR_INT_HOST $OIG_LBR_INT_PORT
    then
        echo "Setup $OIG_LBR_INT_HOST:$OIG_LBR_INT_PORT Before continuing. It is OK to ignore this one if running on a deployment host"
        WARN=$((WARN+1))
    fi
fi

if ! check_lbr $LDAP_HOST $LDAP_PORT
then
  echo "Setup $LDAP_HOST:$LDAP_PORT Before continuing."
  FAIL=$((FAIL+1))
fi

check_connectivity $LDAP_HOST $LDAP_PORT 
FAIL=$((FAIL+$?))

# Check DB
#
echo ""
echo "Checking Database Connectivity"
echo "------------------------------"

if [ "$INSTALL_OAM" = "true" ]
then
    echo -n "Checking OAM Database : "
    nc -z $OAM_DB_SCAN $OAM_DB_LISTENER
    if [ $? = 0 ] 
    then
       echo "Success"
    else
       echo "Failed"
       FAIL=$((FAIL+1))
    fi
fi
    
if [ "$INSTALL_OIG" = "true" ]
then
    echo -n "Checking OIG Database : "
    nc -z $OIG_DB_SCAN $OIG_DB_LISTENER
    if [ $? = 0 ] 
    then
       echo "Success"
    else
       echo "Failed"
       FAIL=$((FAIL+1))
    fi
fi


# OHS CHECKS
#


if [ "$INSTALL_OHS" = "true" ] || [ "$USE_OHS" = "true" ]
then
    echo ""
    echo "Checking Oracle Http Server Pre-requisties"
    echo "------------------------------------------"


    if [  "$INSTALL_OHS" = "true" ] 
    then
       for ohsHost in $OHS_HOSTS
       do
           echo -n "Checking OHS Installer exists on host $ohsHost : "
           ohsInstaller=$OHS_SHIPHOME_DIR/$OHS_INSTALLER
	   $SSH $OHS_OWNER@$ohsHost ls $ohsInstaller >/dev/null 2>&1
           if [ $? -eq 0 ]
           then
              echo "Success"
           else
              echo "Failed"
              FAIL=$((FAIL+1))
           fi 

           check_oracle_base $ohsHost $OHS_OWNER $OHS_ORACLE_HOME
           FAIL=$((FAIL+$?))
           check_oracle_base $ohsHost $OHS_OWNER $(dirname $OHS_DOMAIN)
           FAIL=$((FAIL+$?))

           if [ "$INSTALL_OAM" = "true" ]
           then
              if [ "$OAM_MODE" = "secure" ]
              then
                check_remote_connectivity $ohsHost $OHS_OWNER $OAM_ADMIN_HOST $OAM_ADMIN_ADMIN_PORT
                FAIL=$((FAIL+$?))
              fi
              if [ "$OAM_DOMAIN_SSL_ENABLED" = "true" ]
              then
                check_remote_connectivity $ohsHost $OHS_OWNER $OAM_ADMIN_HOST $OAM_ADMIN_SSL_PORT
                FAIL=$((FAIL+$?))
              else
                check_remote_connectivity $ohsHost $OHS_OWNER $OAM_ADMIN_HOST $OAM_ADMIN_PORT
                FAIL=$((FAIL+$?))
              fi
              for oamHost in $OAM_HOSTS
              do
                 if [ "$OAM_DOMAIN_SSL_ENABLED" = "true" ]
                 then
                   check_remote_connectivity $ohsHost $OHS_OWNER $oamHost $OAM_OAM_SSL_PORT
                   FAIL=$((FAIL+$?))
                   check_remote_connectivity $ohsHost $OHS_OWNER $oamHost $OAM_POLICY_SSL_PORT
                   FAIL=$((FAIL+$?))
                 else
                   check_remote_connectivity $ohsHost $OHS_OWNER $oamHost $OAM_OAM_PORT
                   FAIL=$((FAIL+$?))
                   check_remote_connectivity $ohsHost $OHS_OWNER $oamHost $OAM_POLICY_PORT
                   FAIL=$((FAIL+$?))
                 fi
              done
           fi
           if [ "$INSTALL_OIG" = "true" ]
           then
              if [ "$OIG_MODE" = "secure" ]
              then
                check_remote_connectivity $ohsHost $OHS_OWNER $OIG_ADMIN_HOST $OIG_ADMIN_ADMIN_PORT
                FAIL=$((FAIL+$?))
              fi
              if [ "$OAM_DOMAIN_SSL_ENABLED" = "true" ]
              then
                check_remote_connectivity $ohsHost $OHS_OWNER $OIG_ADMIN_HOST $OIG_ADMIN_SSL_PORT
                FAIL=$((FAIL+$?))
              else
                check_remote_connectivity $ohsHost $OHS_OWNER $OIG_ADMIN_HOST $OIG_ADMIN_PORT
                FAIL=$((FAIL+$?))
              fi
              for oigHost in $OIG_HOSTS
              do
                 if [ "$OIG_DOMAIN_SSL_ENABLED" = "true" ]
                 then
                   check_remote_connectivity $ohsHost $OHS_OWNER $oigHost $OIG_OIM_SSL_PORT
                   FAIL=$((FAIL+$?))
                   check_remote_connectivity $ohsHost $OHS_OWNER $oigHost $OIG_SOA_SSL_PORT
                   FAIL=$((FAIL+$?))
                 else
                   check_remote_connectivity $ohsHost $OHS_OWNER $oigHost $OIG_OIM_PORT
                   FAIL=$((FAIL+$?))
                   check_remote_connectivity $ohsHost $OHS_OWNER $oigHost $OIG_SOA_PORT
                   FAIL=$((FAIL+$?))
                 fi
              done
           fi
       done
       echo
   fi
fi



# OUD CHECKS
#
echo ""
echo "Checking Oracle Unified Directory Pre-requisties"
echo "------------------------------------------------"
if [ "$INSTALL_OUD" = "true" ]
then
   for oudHost in $OUD_HOSTS
   do
      echo -n "Checking OUD Installer exists on host $oudHost : "
      oudInstaller=$OUD_SHIPHOME_DIR/$OUD_INSTALLER
      $SSH $OUD_OWNER@$oudHost ls $oudInstaller >/dev/null 2>&1
      if [ $? -eq 0 ]
      then
        echo "Success"
      else
        echo "Failed"
        FAIL=$((FAIL+1))
      fi 
      check_remote_connectivity $oudHost $OUD_OWNER $LDAP_HOST $LDAP_PORT
      FAIL=$((FAIL+$?))

      check_oracle_base $oudHost $OUD_OWNER $OUD_ORACLE_HOME
      FAIL=$((FAIL+$?))
      check_oracle_base $oudHost $OUD_OWNER $OUD_INST_LOC
      FAIL=$((FAIL+$?))
    done


    echo -n "Checking LDAP User Password Format : "
    if check_password "UN" $LDAP_USER_PWD
    then
      echo "Success"
    else
      FAIL=$((FAIL+1))
    fi

    check_ldapsearch
    if [ $? = 0 ]
    then
      echo "Success"
    else
      echo "Failed"
      FAIL=$((FAIL+1))
    fi
fi

#  OUDSM CHECKS
echo ""
echo "Checking Oracle Unified Directory "
echo "----------------------------------"
echo
if [ "$INSTALL_OUDSM" = "true" ]
then
    echo -n "Checking OUDSM Admin Password Format : "
    if check_password "UN" $OUDSM_PWD
    then
      echo "Success"
    else
       FAIL=$((FAIL+1))
    fi
fi

#  OAM CHECKS
echo ""
echo "Checking Oracle Access Manager"
echo "------------------------------"
echo
if [ "$INSTALL_OAM" = "true" ]
then
   for oamHost in $OAM_HOSTS
   do
      echo -n "Checking IDM Infrastructure Installer exists on host $oamHost : "
      oamInstaller=$OAM_SHIPHOME_DIR/$OAM_INFRA_INSTALLER
      $SSH $OAM_OWNER@$oamHost ls $oamInstaller >/dev/null 2>&1
      if [ $? -eq 0 ]
      then
        echo "Success"
      else
        echo "Failed"
        FAIL=$((FAIL+1))
      fi 
      echo -n "Checking IDM Installer exists on host $oamHost : "
      oamInstaller=$OAM_SHIPHOME_DIR/$OAM_IDM_INSTALLER
      $SSH $OAM_OWNER@$oamHost ls $oamInstaller >/dev/null 2>&1
      if [ $? -eq 0 ]
      then
        echo "Success"
      else
        echo "Failed"
        FAIL=$((FAIL+1))
      fi 
      check_fs_mounted $oamHost $OAM_OWNER $OAM_ORACLE_HOME 
      check_oracle_base $oamHost $OAM_OWNER $OAM_ORACLE_HOME
      FAIL=$((FAIL+$?))
      check_oracle_base $oamHost $OAM_OWNER $(dirname $OAM_MSERVER_HOME)
      FAIL=$((FAIL+$?))
      check_oracle_base $oamHost $OAM_OWNER $(dirname $OAM_DOMAIN_HOME)
      FAIL=$((FAIL+$?))
      check_remote_connectivity $oamHost $OAM_OWNER $LDAP_HOST $LDAP_PORT
      FAIL=$((FAIL+$?))
      check_remote_connectivity $oamHost $OAM_OWNER $OAM_LOGIN_LBR_HOST $OAM_LOGIN_LBR_PORT
      FAIL=$((FAIL+$?))
      check_remote_connectivity $oamHost $OAM_OWNER $OAM_ADMIN_LBR_HOST $OAM_ADMIN_LBR_PORT
      FAIL=$((FAIL+$?))
      if [ "$OAM_OIG_INTEG" = "true" ]
      then
         check_remote_connectivity $oamHost $OAM_OWNER $OIG_LBR_HOST $OIG_LBR_PORT
         FAIL=$((FAIL+$?))
      fi
    done
    OAMHOST1=$(echo $OAM_HOSTS | awk '{print $1}')
    check_fs_mounted $OAMHOST1 $OAM_OWNER $(dirname $OAM_DOMAIN_HOME)
    echo -n "Checking OAM Schema Password Format : "
    if check_password "UNS" $OAM_DB_SCHEMA_PWD
    then
      echo "Success"
    else
      FAIL=$((FAIL+1))
    fi
    echo -n "Checking OAM WebLogic Password Format :"
    if check_password "UN" $OAM_WLS_PWD
    then
      echo "Success"
    else
      FAIL=$((FAIL+1))
    fi
fi

#  OIG CHECKS
echo ""
echo "Checking Oracle Identity Governance "
echo "------------------------------------"
echo
if [ "$INSTALL_OIG" = "true" ]
then
   for oigHost in $OIG_HOSTS
   do
      echo -n "Checking OIG Installer exists on host $oigHost :"
      oigInstaller=$OIG_SHIPHOME_DIR/$OIG_QUICK_INSTALLER
      $SSH $OIG_OWNER@$oigHost ls $oigInstaller >/dev/null 2>&1
      if [ $? -eq 0 ]
      then
        echo "Success"
      else
        echo "Failed"
        FAIL=$((FAIL+1))
      fi 
      if [ "$INSTALL_OAM" = "true" ]
      then 
         echo -n "Checking Connector Bundle $CONNECTOR_VER has been downloaded to $CONNECTOR_DIR : "
         $SSH $OIG_OWNER@$oigHost ls $CONNECTOR_DIR/${CONNECTOR_VER}.zip > /dev/null 2>&1
         if [ $? -eq 0 ]
         then 
            echo "Success"
         else
            echo " Connector Bundle not found at $CONNECTOR_DIR/${CONNECTOR_VER}.zip  "
            FAIL=$((FAIL+1))
         fi
      fi
      check_fs_mounted $oigHost $OIG_OWNER $OIG_ORACLE_HOME 
      check_oracle_base $oigHost $OIG_OWNER $OIG_ORACLE_HOME
      FAIL=$((FAIL+$?))
      check_oracle_base $oigHost $OIG_OWNER $(dirname $OIG_MSERVER_HOME)
      FAIL=$((FAIL+$?))
      check_oracle_base $oigHost $OIG_OWNER $(dirname $OIG_DOMAIN_HOME)
      FAIL=$((FAIL+$?))
      check_remote_connectivity $oigHost $OIG_OWNER $LDAP_HOST $LDAP_PORT
      FAIL=$((FAIL+$?))
      check_remote_connectivity $oigHost $OIG_OWNER $OIG_LBR_HOST $OIG_LBR_PORT
      FAIL=$((FAIL+$?))
      check_remote_connectivity $oigHost $OIG_OWNER $OIG_ADMIN_LBR_HOST $OIG_ADMIN_LBR_PORT
      FAIL=$((FAIL+$?))
      check_remote_connectivity $oigHost $OIG_OWNER $OIG_LBR_INT_HOST $OIG_LBR_INT_PORT
      FAIL=$((FAIL+$?))
      if [ "$OAM_OIG_INTEG" = "true" ]
      then
         check_remote_connectivity $oigHost $OIG_OWNER $OAM_LOGIN_LBR_HOST $OAM_LOGIN_LBR_PORT
         FAIL=$((FAIL+$?))
      fi
     
    done
    OIGHOST1=$(echo $OIG_HOSTS | awk '{print $1}')
    check_fs_mounted $OIGHOST1 $OIG_OWNER $(dirname $OIG_DOMAIN_HOME)
    

    echo -n "Checking OIG Schema Password Format : "
    if check_password "UNS" $OIG_DB_SCHEMA_PWD
    then
      echo "Success"
    else
      FAIL=$((FAIL+1))
    fi
    echo -n "Checking OIG WebLogic Password Format : "
    if check_password "UN" $OIG_WLS_PWD
    then
      echo "Success"
    else
      FAIL=$((FAIL+1))
    fi
fi





echo
echo "Summary"
echo "--------------------"
echo
if [ $FAIL = 0 ]
then
      echo "All checks Passed"
else
      echo "$FAIL checks Failed"
      exit 1
fi

if [ $WARN -gt 0 ]
then
      echo "$WARN Warnings found."
      exit 2
fi
