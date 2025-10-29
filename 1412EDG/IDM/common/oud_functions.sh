# Copyright (c) 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# This is an example of the checks that can be performed before Provisioning Identity Management
# to reduce the likelihood of provisioning failing.
#
#
# Usage: Not invoked directly
#

create_oracle_home()
{
   host=$1
   ST=$(date +%s)
   print_msg "Creating OUD Installation Directory on host $host"


   $SSH $OUD_OWNER@$host "mkdir -p $OUD_ORACLE_HOME" > $LOGDIR/$host/create_oh.log 2>&1
   XX=$?
   if [ $XX -gt 0 ]
   then
      grep -q "exists" $LOGDIR/$host/create_oh.log
      if [ $? -eq  0 ]
      then
         echo "Already Exists"
      else
         print_status $XX $LOGDIR/$host/create_oh.log
      fi
   else
      echo "Success"
   fi

   ET=$(date +%s)
   print_time STEP "Create OUD Installation Scripts" $ST $ET >> $LOGDIR/timings.log

}
create_oud_install_scripts()
{
   instance=oud${1}

   ST=$(date +%s)
   print_msg "Creating OUD Installation Scripts "
   cp $TEMPLATE_DIR/install_oud.sh $WORKDIR
   file=$WORKDIR/install_oud.sh

   ORACLE_BASE=$(dirname $OUD_ORACLE_HOME)
   ORA_INVENTORY=$(dirname $ORACLE_BASE)
   update_variable "<OUD_SHIPHOME_DIR>" $OUD_SHIPHOME_DIR $file
   update_variable "<GEN_JDK_VER>" $GEN_JDK_VER $file
   update_variable "<ORACLE_BASE>" $ORACLE_BASE $file
   update_variable "<WORKDIR>" $REMOTE_WORKDIR $file
   update_variable "<OUD_ORACLE_HOME>" $OUD_ORACLE_HOME $file
   update_variable "<OUD_INSTALLER>" $OUD_INSTALLER $file


   cp $TEMPLATE_DIR/install_oud.rsp $WORKDIR
   update_variable "<OUD_ORACLE_HOME>" $OUD_ORACLE_HOME $WORKDIR/install_oud.rsp

   echo "inventory_loc=$ORACLE_BASE/oraInventory" > $WORKDIR/oraInst.loc
   echo "inst_group=$OUD_GROUP" >> $WORKDIR/oraInst.loc

   print_status $? 

   ET=$(date +%s)
   print_time STEP "Create OUD Installation Scripts" $ST $ET >> $LOGDIR/timings.log

}

# Update the LDAP seed file with values from the responsefile
#
create_property_file()
{
   host=$1
   ST=$(date +%s)
   print_msg "Creating property file"
   #cp $TEMPLATE_DIR/base.ldif $WORKDIR
   cp $TEMPLATE_DIR/idstore.props $WORKDIR

   #file=$WORKDIR/base.ldif
   file=$WORKDIR/idstore.props

   # Perform variable substitution in template files
   #
   update_variable "<LDAP_HOST>" $host $file
   if [ "$OUD_MODE" = "secure" ]
   then
      update_variable "<LDAP_PORT>" $OUD_LDAPS_PORT $file
      update_variable "<OUD_TRUST_STORE>" $OUD_KEYSTORE_LOC/$(basename $OUD_TRUST_STORE) $file
      update_variable "<OUD_TRUST_PWD>" $LDAP_TRUSTSTORE_PWD $file
   else
      update_variable "<LDAP_PORT>" $OUD_LDAP_PORT $file
      update_variable "<OUD_TRUST_STORE>" "" $file
      update_variable "<OUD_TRUST_PWD>" "" $file
   fi
   update_variable "<LDAP_ADMIN_USER>" $LDAP_ADMIN_USER $file
   update_variable "<LDAP_ADMIN_PWD>" $LDAP_ADMIN_PWD $file
   update_variable "<OUD_ADMIN_TRUST_STORE>" $OUD_INST_LOC/oud1/config/admin-keystore $file
   update_variable "<OUD_ADMIN_PORT>" $OUD_ADMIN_PORT $file
   update_variable "<LDAP_ADMIN_PORT>" $OUD_ADMIN_PORT $file
   update_variable "<LDAP_SECURE>" $OUD_ENABLE_LDAPS $file
   update_variable "<LDAP_SEARCHBASE>" $LDAP_SEARCHBASE $file
   OUD_REGION=$(echo $LDAP_SEARCHBASE | cut -f1 -d, | cut -f2 -d=)
   update_variable "<OUD_REGION>" $OUD_REGION $file
   update_variable "<LDAP_GROUP_SEARCHBASE>" $LDAP_GROUP_SEARCHBASE $file
   update_variable "<LDAP_USER_SEARCHBASE>" $LDAP_USER_SEARCHBASE $file
   update_variable "<LDAP_RESERVE_SEARCHBASE>" $LDAP_RESERVE_SEARCHBASE $file
   update_variable "<LDAP_SYSTEMIDS>" $LDAP_SYSTEMIDS $file
   update_variable "<LDAP_OAMADMIN_USER>" $LDAP_OAMADMIN_USER $file
   update_variable "<LDAP_OAMADMIN_GRP>" $LDAP_OAMADMIN_GRP $file
   update_variable "<LDAP_OIGADMIN_GRP>" $LDAP_OIGADMIN_GRP $file
   update_variable "<LDAP_OAMLDAP_USER>" $LDAP_OAMLDAP_USER  $file
   update_variable "<LDAP_OIGLDAP_USER>" $LDAP_OIGLDAP_USER  $file
   update_variable "<LDAP_WLSADMIN_USER>" $LDAP_WLSADMIN_USER  $file
   update_variable "<LDAP_WLSADMIN_GRP>" $LDAP_WLSADMIN_GRP  $file
   update_variable "<LDAP_XELSYSADM_USER>" $LDAP_XELSYSADM_USER  $file
   update_variable "<LDAP_USER_PWD>" $LDAP_USER_PWD  $file
   update_variable "<LDAP_USER_PWD>" $LDAP_USER_PWD  $file
   update_variable "<PASSWORD>" $LDAP_USER_PWD  $file
   #update_variable "<OUD_PWD_EXPIRY>" $OUD_PWD_EXPIRY  $file

   echo "Success"
   ET=$(date +%s)
   print_time STEP "Create LDAP property file " $ST $ET >> $LOGDIR/timings.log
}
create_acl_property_file()
{
   host=$1
   instance=$2
   ST=$(date +%s)
   print_msg "Creating property file for ACLs for $host"
   printf "\n\t\t\tCreating property file - "
   cp $TEMPLATE_DIR/acl.props $WORKDIR/acl.$host.props

   file=$WORKDIR/acl.$host.props

   # Perform variable substitution in template files
   #
   update_variable "<LDAP_HOST>" $host $file
   if [ "$OUD_MODE" = "secure" ]
   then
      update_variable "<LDAP_PORT>" $OUD_LDAPS_PORT $file
   else
      update_variable "<LDAP_PORT>" $OUD_LDAP_PORT $file
   fi
   update_variable "<LDAP_ADMIN_USER>" $LDAP_ADMIN_USER $file
   update_variable "<LDAP_ADMIN_PWD>" $LDAP_ADMIN_PWD $file
   update_variable "<OUD_ADMIN_TRUST_STORE>" $OUD_INST_LOC/oud${instance}/config/admin-keystore $file
   update_variable "<OUD_ADMIN_PORT>" $OUD_ADMIN_PORT $file
   update_variable "<LDAP_ADMIN_PORT>" $OUD_ADMIN_PORT $file
   update_variable "<LDAP_SECURE>" $OUD_ENABLE_LDAPS $file
   update_variable "<LDAP_SEARCHBASE>" $LDAP_SEARCHBASE $file
   update_variable "<LDAP_OIGADMIN_GRP>" $LDAP_OIGADMIN_GRP $file

   echo "Success"
   printf "\t\t\tCopying property file - "
   $SCP $file  $OUD_OWNER@$host:$REMOTE_WORKDIR/acl.props >> $LOGDIR/acl_copy.$host.log 2>&1
   print_status $? $LOGDIR/acl_copy.$host.log

   ET=$(date +%s)
   print_time STEP "Create acl property file for host $host" $ST $ET >> $LOGDIR/timings.log
}

update_oud_pwd()
{
   host=$1
   ST=$(date +%s)
   print_msg "Update OUD Admin keystore Password"
   printf "\n\t\t\tCreating password file - "
   print_status $?
   echo $LDAP_ADMIN_PWD > $WORKDIR/.oudpwd
   printf "\t\t\tCopying password file - "
   $SCP $WORKDIR/.oudpwd $OUD_OWNER@$host:$REMOTE_WORKDIR > $LOGDIR/update_ks_pwd.log 2>&1
   print_status $? $LOGDIR/update_ks_pwd.log
   printf "\t\t\tObtaining Password from OUD - "
   CMD="$OUD_INST_LOC/oud1/bin/dsconfig -h $host -p $OUD_ADMIN_PORT -D $LDAP_ADMIN_USER -j $REMOTE_WORKDIR/.oudpwd -X -n get-key-manager-provider-prop --provider-name Administration --property key-store-pin --showKeystorePassword | grep "store-pin" | cut -f2 -d":
   echo $CMD >> $LOGDIR/update_ks_pwd.log 2>&1
   PWD=$($SSH $OUD_OWNER@$host $CMD 2>/dev/null)
   print_status $?
   printf "\t\t\tUpdating property file - "
   update_variable "<OUD_ADMIN_TRUST_PWD>" $PWD  $WORKDIR/idstore.props
   print_status $?

   ET=$(date +%s)
   print_time STEP "Update OUD Admin keystore Password " $ST $ET >> $LOGDIR/timings.log
}

create_idmconfig_script()
{
   ST=$(date +%s)
   print_msg "Create Integration script "
   cp $TEMPLATE_DIR/runLDAPConfig.sh $WORKDIR
   file=$WORKDIR/runLDAPConfig.sh
   
   ORACLE_BASE=$(dirname $OUD_ORACLE_HOME)
   update_variable "<OUD_ORACLE_HOME>" $OUD_ORACLE_HOME  $file
   update_variable "<JAVA_HOME>" $ORACLE_BASE/jdk  $file
   update_variable "<WORKDIR>" $REMOTE_WORKDIR  $file
   echo "Success"
   ET=$(date +%s)
   print_time STEP "Create runIDMConfig script" $ST $ET >> $LOGDIR/timings.log
}

copy_seedfile()
{
    host=$1
    ST=$(date +%s)
    print_msg "Copying OUD Seed files to $host"
    $SCP $WORKDIR/base.ldif  $OUD_OWNER@$host:$REMOTE_WORKDIR >> $LOGDIR/copy_seed.log 2>&1
    $SCP $TEMPLATE_DIR/99-user.ldif  $OUD_OWNER@$host:$REMOTE_WORKDIR >> $LOGDIR/copy_seed.log 2>&1
    $SCP $WORKDIR/idstore.props  $OUD_OWNER@$host:$REMOTE_WORKDIR >> $LOGDIR/copy_seed.log 2>&1
    $SCP $WORKDIR/runLDAPConfig.sh  $OUD_OWNER@$host:$REMOTE_WORKDIR >> $LOGDIR/copy_seed.log 2>&1
    print_status $? $LOGDIR/copy_seed.log

    ET=$(date +%s)
    print_time STEP "Copy seed file to $host" $ST $ET >> $LOGDIR/timings.log
}

create_oud_create_script()
{
   instance=oud${1}
   host=$2

   ST=$(date +%s)
   print_msg "Creating OUD Creation Scripts "

   mkdir -p $WORKDIR/$host > /dev/null 2>&1
   cp $TEMPLATE_DIR/create_oud.sh $WORKDIR/$host
   file=$WORKDIR/$host/create_oud.sh
   ORACLE_BASE=$(dirname $OUD_ORACLE_HOME)
   JAVA_HOME=$ORACLE_BASE/jdk
   update_variable "<INSTANCE_DIR>" ${OUD_INST_LOC}/$instance $file
   update_variable "<HOSTNAME>" $host $file
   update_variable "<WORKDIR>" $REMOTE_WORKDIR $file
   update_variable "<OUD_KEYSTORE_LOC>" $OUD_KEYSTORE_LOC $file
   update_variable "<OUD_CERT_NAME>" $OUD_CERT_NAME $file
   update_variable "<JAVA_HOME>" $JAVA_HOME $file
   if [ "$OUD_MODE" = "secure" ]
   then
      update_variable "<OUD_LDAP_PORT>" "disabled" $file
      update_variable "<OUD_LDAPS_PORT>" $OUD_LDAPS_PORT $file
      if [ "$OUD_CERT_TYPE" = "host" ]
      then
          certStore=$host.p12
	  certNickname=$(echo $certStore |  cut -f1 -d.)
      else
          certStore=$OUD_CERT_STORE
          certNickname=$OUD_CERT_NAME
      fi

      update_variable "<OUD_CERT_STORE>" $certStore $file
      update_variable "<OUD_CERT_NICKNAME>" $certNickname $file
      update_variable "<OUD_CERT_PWF>" $(basename $OUD_CERT_PWF) $file
      update_variable "<OUD_PWF>" .oudpwd $file
   else
      update_variable "<OUD_LDAP_PORT>" $OUD_LDAP_PORT $file
      update_variable "<OUD_LDAPS_PORT>" "disabled" $file
   fi
   update_variable "<OUD_ADMIN_PORT>" $OUD_ADMIN_PORT $file


   print_status $? 

    ET=$(date +%s)
    print_time STEP "Creating OUD Creation Scripts" $ST $ET >> $LOGDIR/timings.log

}


create_repl_script()
{
   host1=$1
   host2=$2

   host2sn=$(echo $host2| cut -f1 -d.)
   ST=$(date +%s/)
   print_msg "Creating OUD Replication Scripts for $host2sn"

   cp $TEMPLATE_DIR/enable_replication.sh $WORKDIR/enable_replication_$host2sn.sh
   file=$WORKDIR/enable_replication_$host2sn.sh

   update_variable "<INSTANCE_DIR>" ${OUD_INST_LOC}/oud1 $file
   update_variable "<LDAPHOST1>" $host1 $file
   update_variable "<LDAPHOST2>" $host2 $file
   update_variable "<WORKDIR>" $REMOTE_WORKDIR $file
   update_variable "<OUD_REPLICATION_PORT>" $OUD_REPLICATION_PORT $file
   update_variable "<OUD_ADMIN_PORT>" $OUD_ADMIN_PORT $file

   print_status $? 

   ET=$(date +%s)

}

copy_create_script()
{
    host=$1
    user=$2
    ST=$(date +%s)
    print_msg "Copying Create script to $host"
    $SCP $WORKDIR/$host/create_oud.sh $user@$host:$REMOTE_WORKDIR > $LOGDIR/install_copy.log 2>&1
    print_status $? $LOGDIR/install_copy.log
    printf "\t\t\tSetting Execute Permission "
    $SSH $user@$host "chmod 702 $REMOTE_WORKDIR/create_oud.sh" >> $LOGDIR/install_copy.log 2>&1
    print_status $? $LOGDIR/install_copy.log

    ET=$(date +%s)
    print_time STEP "Copying create instance script" $ST $ET >> $LOGDIR/timings.log
}

copy_repl_script()
{
    host=$1
    host2=$2
    ST=$(date +%s)
    host2sn=$(echo $host2| cut -f1 -d.)
    print_msg "Copying Replication script to $host"
    $SCP $WORKDIR/enable_replication_$host2sn.sh $OUD_OWNER@$host:$REMOTE_WORKDIR > $LOGDIR/repl_copy.log 2>&1
    print_status $? $LOGDIR/repl_copy.log
    printf "\t\t\tSetting Execute Permission "
    $SSH $OUD_OWNER@$host "chmod 700 $REMOTE_WORKDIR/enable_replication_$host2sn.sh" >>$LOGDIR/repl_copy.log 2>&1
    print_status $? $LOGDIR/repl§_copy.log

    ET=$(date +%s)
    print_time STEP "Copying Replication script" $ST $ET >> $LOGDIR/timings.log
}
create_instance()
{
    host=$1
    ST=$(date +%s)
    print_msg "Creating OUD Instance on $host"
    $SSH  $user@$host $REMOTE_WORKDIR/create_oud.sh > $LOGDIR/create_oud_instance_$host.log 2>&1
    print_status $? $LOGDIR/create_oud_instance_$host.log

    ET=$(date +%s)
    print_time STEP "Create OUD Instance" $ST $ET >> $LOGDIR/timings.log
}

enable_replicaton()
{
    host1=$1
    host2=$2
    host1sn=$(echo $host1| cut -f1 -d.)
    host2sn=$(echo $host2| cut -f1 -d.)
    ST=$(date +%s)
    print_msg "Enabling Replication from $host1sn to $host2sn"
    $SSH  $OUD_OWNER@$host1 $REMOTE_WORKDIR/enable_replication_$host2sn.sh > $LOGDIR/enable_replication_$host2sn.log 2>&1
    print_status $? $LOGDIR/enable_replication_$host2sn.log

    ET=$(date +%s)
    print_time STEP "Enabling Replication from $host1sn to $host2sn" $ST $ET >> $LOGDIR/timings.log
}

run_preconfig()
{

   host=$1
   ST=$(date +%s)
   print_msg "Extending OUD Directory Schema"

   $SSH $OUD_OWNER@$host $REMOTE_WORKDIR/runLDAPConfig.sh preConfigIDStore idstore.props > $LOGDIR/preconfig.log 2>&1
   print_status $? $LOGDIR/preconfig.log

   printf "\t\t\tChecking Log File - "
   $SSH $OAM_OWNER@$host cat $REMOTE_WORKDIR/preConfigIDStore.log  >> $LOGDIR/preconfig.log 2>&1

   grep SEVERE $LOGDIR/preconfig.log | grep -v simple > /dev/null
   if [ $? = 0 ]
   then
      echo "Failed - Check logifle $LOGDIR/preconfig.log"
      exit 1
   else
      echo "Success"
   fi

   ET=$(date +%s)
   print_time STEP "Extending OUD Directory Schema" $ST $ET >> $LOGDIR/timings.log

}

run_prepare()
{

   host=$1
   ST=$(date +%s)
   print_msg "Seeding OUD Directory Schema"

   $SSH $OUD_OWNER@$host $REMOTE_WORKDIR/runLDAPConfig.sh prepareIDStore idstore.props > $LOGDIR/prepare.log 2>&1
   print_status $? $LOGDIR/prepare.log

   printf "\t\t\tChecking Log File - "
   $SSH $OAM_OWNER@$host cat $REMOTE_WORKDIR/prepareIDStore.log  >> $LOGDIR/prepare.log 2>&1

   grep SEVERE $LOGDIR/preconfig.log | grep -v simple > /dev/null
   if [ $? = 0 ]
   then
      echo "Failed - Check logifle $LOGDIR/prepare.log"
      exit 1
   else
      echo "Success"
   fi

   ET=$(date +%s)
   print_time STEP "Seeding OUD Directory Schema" $ST $ET >> $LOGDIR/timings.log

}

run_addobjectclass()
{

   host=$1
   ST=$(date +%s)
   print_msg "Adding Object Classes to existing users"

   $SSH $OUD_OWNER@$host $REMOTE_WORKDIR/runLDAPConfig.sh  addMissingObjectClasses  idstore.props > $LOGDIR/object_class.log 2>&1
   print_status $? $LOGDIR/object_class.log

   printf "\t\t\tChecking Log File - "
   $SSH $OAM_OWNER@$host: cat $REMOTE_WORKDIR/addMissingObjectClasses.log  >> $LOGDIR/object_class.log 2>&1

   grep SEVERE $LOGDIR/object_class.log | grep -v simple > /dev/null
   if [ $? = 0 ]
   then
      echo "Failed - Check logifle $LOGDIR/object_class.log"
      exit 1
   else
      echo "Success"
   fi

   ET=$(date +%s)
   print_time STEP "Add Object Classes to existing users" $ST $ET >> $LOGDIR/timings.log

}
run_acl()
{

   host=$1
   ST=$(date +%s)
    hostsn=$(echo $host| cut -f1 -d.)
   print_msg "Creating Access Control Lists on $hostsn"
   echo "$SSH $OUD_OWNER@$host $REMOTE_WORKDIR/runLDAPConfig.sh setupOUDacl acl.props" > $LOGDIR/create_acl_$hostsn.log 
   $SSH $OUD_OWNER@$host $REMOTE_WORKDIR/runLDAPConfig.sh setupOUDacl acl.props >> $LOGDIR/create_acl_$hostsn.log 2>&1
   print_status $? $LOGDIR/create_acl_$hostsn.log

   printf "\t\t\tChecking Log File - "
   $SSH $OAM_OWNER@$host cat $REMOTE_WORKDIR/setupOUDacl.log  >> $LOGDIR/create_acl_$hostsn.log 2>&1

   grep SEVERE $LOGDIR/create_acl_$hostsn.log | grep -v simple > /dev/null
   if [ $? = 0 ]
   then
      echo "Failed - Check logifle $LOGDIR/create_acl_$hostsn.log"
      exit 1
   else
      echo "Success"
   fi

   ET=$(date +%s)
   print_time STEP "Creating Access Control Lists on $hostsn" $ST $ET >> $LOGDIR/timings.log

}
# Create the OUD instances using helm
#
create_oud()
{

   ST=$(date +%s)
   print_msg "Use Helm to create OUD"

   rm -f $OUD_LOCAL_CONFIG_SHARE/rejects.ldif $OUD_LOCAL_CONFIG_SHARE/skip.ldif 2> /dev/null > /dev/null
   cd $WORKDIR/samples/kubernetes/helm/
   helm install --namespace $OUDNS --values $WORKDIR/override_oud.yaml $OUD_POD_PREFIX oud-ds-rs > $LOGDIR/create_oud.log 2>&1
   print_status $? $LOGDIR/create_oud.log
   ET=$(date +%s)
   print_time STEP "Create OUD Instances" $ST $ET >> $LOGDIR/timings.log

}



# Check Validate OUD Dataload was successful
#
validate_oud()
{
    ST=$(date +%s)
    print_msg "Validating OUD"
    echo "Validating OUD" > $LOGDIR/validate_oud.log
    echo "--------------" >> $LOGDIR/validate_oud.log
    echo "" >> $LOGDIR/validate_oud.log
    FAIL=0

    printf "\n\t\t\tChecking for Creation Errors - "
    grep -q SEVERE_ERROR $LOGDIR/${OUD_POD_PREFIX}-oud-ds-rs-0.log
    if [ $? = 0 ]
    then
         echo "SEVERE Errors Found check logfile $LOGDIR/${OUD_POD_PREFIX}-oud-ds-rs-0.log"
         echo "SEVERE Errors Found check logfile $LOGDIR/${OUD_POD_PREFIX}-oud-ds-rs-0.log" >> $LOGDIR/validate_oud.log
         FAIL=1
    else
         echo "No Errors"
         echo "No Creation Errors discovered" >> $LOGDIR/validate_oud.log
    fi

    if [ ! "$ENABLE_DR" = "true" ] || [ "$DR_TYPE" = "PRIMARY" ]
    then
       printf "\t\t\tChecking for Import Errors - "
       grep -q ERROR $OUD_LOCAL_SHARE/${OUD_POD_PREFIX}-oud-ds-rs-0/logs/importLdifCmd.log
       if [ $? = 0 ]
       then
            echo "Import Errors Found check logfile $OUD_LOCAL_SHARE/${OUD_POD_PREFIX}-oud-ds-rs-0/logs/importLdifCmd.log"
            echo "Import Errors Found check logfile $OUD_LOCAL_SHARE/${OUD_POD_PREFIX}-oud-ds-rs-0/logs/importLdifCmd.log" >> $LOGDIR/validate_oud.log
            FAIL=1
       else
            echo "No Errors"
            echo "No Import Errors discovered" >> $LOGDIR/validate_oud.log
       fi
       printf "\t\t\tChecking for Rejects - "
       if [ -s $OUD_LOCAL_CONFIG_SHARE/rejects.ldif ]
       then 
            echo "Rejects found check File: $OUD_LOCAL_CONFIG_SHARE/rejects.ldif"
            echo "Rejects found check File: $OUD_LOCAL_CONFIG_SHARE/rejects.ldif" >> $LOGDIR/validate_oud.log
            FAIL=1
       else
            echo "No Rejects found"
            echo "No Reject Errors discovered" >> $LOGDIR/validate_oud.log
       fi
       printf "\t\t\tChecking for Skipped Records - "
       if [ -s $OUD_LOCAL_CONFIG_SHARE/skip.ldif ]
       then 
            echo "Skipped Records found check File: $OUD_LOCAL_CONFIG_SHARE/skip.ldif"
            echo "Skipped Records found check File: $OUD_LOCAL_CONFIG_SHARE/skip.ldif" >> $LOGDIR/validate_oud.log
            FAIL=1
       else
            echo "No Skipped Records found"
            echo "No Skipped Records discovered" >> $LOGDIR/validate_oud.log
       fi
    fi


    if [ "$FAIL" = "1" ]
    then
        printf "\t\t\tOUD Validation Failed\n"
        exit 1
    else
        printf "\t\t\tOUD Validation Succeeded\n"
    fi


   ET=$(date +%s)
   print_time STEP "Validating OUD" $ST $ET >> $LOGDIR/timings.log
}

# Create scripts to create OUDSM
#
create_oudsm_install_scripts()
{

   ST=$(date +%s)
   print_msg "Creating OUDSM Installation Scripts "
   cp $TEMPLATE_DIR/install_oudsm.sh $WORKDIR
   file=$WORKDIR/install_oudsm.sh

   ORACLE_BASE=$(dirname $OUDSM_ORACLE_HOME)
   ORA_INVENTORY=$(dirname $ORACLE_BASE)
   update_variable "<OUDSM_SHIPHOME_DIR>" $OUD_SHIPHOME_DIR $file
   update_variable "<GEN_JDK_VER>" $GEN_JDK_VER $file
   update_variable "<ORACLE_BASE>" $ORACLE_BASE $file
   update_variable "<WORKDIR>" $REMOTE_WORKDIR $file
   update_variable "<OUDSM_ORACLE_HOME>" $OUDSM_ORACLE_HOME $file
   update_variable "<OUDSM_INFRA_INSTALLER>" $OUDSM_INFRA_INSTALLER $file
   update_variable "<OUDSM_INSTALLER>" $OUDSM_INSTALLER $file

   cp $TEMPLATE_DIR/install_oudsm.rsp $WORKDIR
   update_variable "<OUDSM_ORACLE_HOME>" $OUDSM_ORACLE_HOME $WORKDIR/install_oudsm.rsp
   cp $TEMPLATE_DIR/install_infra.rsp $WORKDIR
   update_variable "<OUDSM_ORACLE_HOME>" $OUDSM_ORACLE_HOME $WORKDIR/install_infra.rsp

   echo "inventory_loc=$ORACLE_BASE" > $WORKDIR/oraInst.loc
   echo "inst_group=$OAM_GROUP" >> $WORKDIR/oraInst.loc

   print_status $?

   ET=$(date +%s)
   print_time STEP "Create OUDSM Installation Scripts" $ST $ET >> $LOGDIR/timings.log

}
create_oudsm_wlst()
{
   ST=$(date +%s)
   print_msg "Create OUDSM Creation Script"

   CMD="createOUDSMDomain(domainLocation=\"$OUDSM_DOMAIN_HOME\","
   CMD="${CMD}weblogicPort=$OUDSM_PORT,"
   CMD="${CMD}weblogicSSLPort=$OUDSM_SSL_PORT,"
   CMD="${CMD}weblogicUserName=\"$OUDSM_WLSUSER\",weblogicUserPassword=\"$OUDSM_PWD\")"

   echo "$CMD" > $WORKDIR/create_oudsm.py
   print_status $?
   ET=$(date +%s)
   print_time STEP "Create OUDSM Creation Script" $ST $ET >> $LOGDIR/timings.log
}

# Create OUSDM instance using helm
#
create_oudsm()
{

   ST=$(date +%s)
   print_msg "Creating OUDSM Domain"

   printf "\n\t\t\tCopying creation script to $OUDSM_HOST - "
   $SCP $WORKDIR/create_oudsm.py $OUDSM_OWNER@$OUDSM_HOST:$REMOTE_WORKDIR  > $LOGDIR/create_oudsm.log 2>&1
   print_status $? $LOGDIR/create_oudsm.log
   printf "\t\t\tCreating OUDSM Domain - "
   $SSH $OUDSM_OWNER@$OUDSM_HOST $OUDSM_ORACLE_HOME/oracle_common/common/bin/wlst.sh $REMOTE_WORKDIR/create_oudsm.py >> $LOGDIR/create_oudsm.log 2>&1
   grep -q "Successfully created OUDSM domain" $LOGDIR/create_oudsm.log
   print_status $? $LOGDIR/create_oudsm.log

   ET=$(date +%s)
   print_time STEP "Create OUDSM Instances" $ST $ET >> $LOGDIR/timings.log

}

# Check that OUDSM has started
#
start_oudsm()
{
   ST=$(date +%s)
   print_msg "Starting OUDSM"
   $SSH $OUD_USER@$OUDHOST nohup $OUDSM_DOMAIN_HOME/bin/startWeblogic.sh & > $LOGDIR/start_oudsm.log 2>&1
   print_status $?  $LOGDIR/start_oudsm.log 
   
   ET=$(date +%s)
   print_time STEP "Start OUDSM" $ST $ET >> $LOGDIR/timings.log
}


create_oudsm_ohs_entries()
{
   print_msg "Create OUDSM OHS entries"
   ST=$(date +%s)

   CONFFILE=$LOCAL_WORKDIR/ohs_oudsm.conf

   cp $TEMPLATE_DIR/ohs_oudsm.conf $CONFFILE
   if [ "$OUDSM_SSL_ENABLED" = "true" ] 
   then
      update_variable "<OUDSM_SERVICE_PORT>" $OUDSM_SSL_PORT $CONFFILE
   else
      update_variable "<OUDSM_SERVICE_PORT>" $OUDSM_PORT $CONFFILE
   fi

   OHSHOST1FILES=$LOCAL_WORKDIR/OHS/$OHS_HOST1
   OHSHOST2FILES=$LOCAL_WORKDIR/OHS/$OHS_HOST2

   echo "$CONFFILE Created"

   if [ -d $OHSHOST1FILES ]
   then
       printf "\t\t\tCopying to $OHSHOST1FILES - "
       cp $CONFFILE $OHSHOST1FILES
       print_status $?
   fi
   if [ -d $OHSHOST2FILES ]
   then
       printf "\t\t\tCopying to $OHSHOST2FILES - "
       cp $CONFFILE $OHSHOST2FILES
       print_status $?
   fi
   ET=$(date +%s)
   print_time STEP "Create OHS Entries" $ST $ET >> $LOGDIR/timings.log
}



