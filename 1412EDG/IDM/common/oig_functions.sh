# Copyright (c) 2021, 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# This is an example of functions and procedures to provision and Configure Oracle Identity Governance
#
#
# Usage: not invoked Directly
#

# Create scripts which will be used to install Oracle Identity and Access Management
#
create_oig_install_scripts()
{

   ST=$(date +%s)
   print_msg "Creating OIG Installation Scripts "
   cp $TEMPLATE_DIR/install_oig.sh $WORKDIR
   file=$WORKDIR/install_oig.sh

   ORACLE_BASE=$(dirname $OIG_ORACLE_HOME)
   ORA_INVENTORY=$(dirname $ORACLE_BASE)
   #TAR_FILE=$(ls $OIG_SHIPHOME_DIR/jdk-${GEN_JDK_VER}+*_linux-x64_bin.tar.gz | head -1)
   update_variable "<OIG_SHIPHOME_DIR>" $OIG_SHIPHOME_DIR $file
   update_variable "<GEN_JDK_VER>" $GEN_JDK_VER $file
   update_variable "<ORACLE_BASE>" $ORACLE_BASE $file
   update_variable "<WORKDIR>" $REMOTE_WORKDIR $file
   update_variable "<OIG_ORACLE_HOME>" $OIG_ORACLE_HOME $file
   update_variable "<OIG_INSTALLER>" $OIG_QUICK_INSTALLER $file

   cp $TEMPLATE_DIR/install_oig.rsp $WORKDIR
   update_variable "<OIG_ORACLE_HOME>" $OIG_ORACLE_HOME $WORKDIR/install_oig.rsp

   echo "inventory_loc=$ORACLE_BASE/oraInventory" > $WORKDIR/oraInst.loc
   echo "inst_group=$OIG_GROUP" >> $WORKDIR/oraInst.loc

   print_status $? 

    ET=$(date +%s)
    print_time STEP "Create OIG Installation Scripts" $ST $ET >> $LOGDIR/timings.log

}

# Copy the connector bundle to the ORACLE_HOME
#
copy_connector()
{

    host=$1
    user=$2

    ST=$(date +%s)
    print_msg "Installing Connector into Oracle Home"

    printf "\n\t\t\tCheck Connector Bundle Exists - "
    $SSH $user@$host ls $CONNECTOR_DIR/${CONNECTOR_VER}.zip > /dev/null 2>&1
    if [ $? -eq 0 ]
    then
          echo "Success"
    else
          echo " Connector Bundle not found in $CONNECTOR_DIR.  Please download and stage before continuing"
          exit 1
    fi

    printf "\t\t\tInstall Connector on host $host - "
    $SSH $user@$host ls -d $OIG_ORACLE_HOME/idm/server/ConnectorDefaultDirectory/${CONNECTOR_VER} > /dev/null 2>&1
    if [ $? -eq 0 ]
    then
          echo "Already Installed"
    else
       $SSH $user@$host unzip $CONNECTOR_DIR/${CONNECTOR_VER}.zip -d $OIG_ORACLE_HOME/idm/server/ConnectorDefaultDirectory >$LOGDIR/copy_connector_$host.log 2>&1
       print_status $? $LOGDIR/copy_connector_$host.log
    fi

    ET=$(date +%s)
    print_time STEP "Installing Connector" $ST $ET >> $LOGDIR/timings.log
}

# Create a file to edit template files enmass
#
create_sedfile()
{
     host=$1
     ST=$(date +%s)
     print_msg "Creating Sed files to update creation files"
 
     echo "" > $WORKDIR/oig.sedfile 
     file=$WORKDIR/oig.sedfile

     ORACLE_BASE=$(dirname $OIG_ORACLE_HOME)
     JAVA_HOME=$ORACLE_BASE/jdk
     hostname=$(echo $host | cut -f1 -d.)
     oigTrustStore=$OIG_KEYSTORE_LOC/$(basename $OIG_TRUST_STORE)
     
     create_sed_entry "<OIG_DOMAIN_NAME>" $OIG_DOMAIN_NAME $file
     create_sed_entry "<OIG_DOMAIN_HOME>" $OIG_DOMAIN_HOME $file
     create_sed_entry "<WORKDIR>" $REMOTE_WORKDIR $file
     create_sed_entry "<JAVA_HOME>" $JAVA_HOME $file
     create_sed_entry "<OIG_OWNER>" $OIG_OWNER $file
     create_sed_entry "<OIG_ORACLE_HOME>" $OIG_ORACLE_HOME $file
     create_sed_entry "<OIG_DB_SCAN>" $OIG_DB_SCAN $file
     create_sed_entry "<OIG_DB_LISTENER>" $OIG_DB_LISTENER $file
     create_sed_entry "<OIG_DB_SERVICE>" $OIG_DB_SERVICE $file
     create_sed_entry "<OIG_RCU_PREFIX>" $OIG_RCU_PREFIX $file
     create_sed_entry "<OIG_DB_SYS_PWD>" $OIG_DB_SYS_PWD $file
     create_sed_entry "<OIG_DB_SCHEMA_PWD>" $OIG_DB_SCHEMA_PWD $file
     create_sed_entry "<TRUST_STORE>" $oigTrustStore $file
     create_sed_entry "<OIG_TRUST_STORE>" $oigTrustStore $file
     create_sed_entry "<OIG_TRUST_PWD>" $OIG_TRUSTSTORE_PWD $file
     create_sed_entry "<TRUST_STORE_PWD>" $OIG_TRUSTSTORE_PWD $file
     create_sed_entry "<DOMAIN_HOME>" $OIG_DOMAIN_HOME $file
     create_sed_entry "<OIG_ORACLE_HOME>" $OIG_ORACLE_HOME $file
     create_sed_entry "<CERT_STORE>" $OIG_KEYSTORE_LOC/$(basename $OIG_CERT_STORE) $file
     if [ "$OIG_CERT_TYPE" = "host" ]
     then
        create_sed_entry "<CERT_ALIAS>" "host" $file
     else
        create_sed_entry "<CERT_ALIAS>" $OIG_CERT_NAME $file
     fi
     create_sed_entry "<CERT_FILE>" $OIG_CERT_STORE $file
     create_sed_entry "<CERT_STORE_PWD>" $OIG_KEYSTORE_PWD $file
     create_sed_entry "<NM_PWD>" $OIG_NM_PWD $file
     create_sed_entry "<NM_HOME>" $OIG_NM_HOME $file
     create_sed_entry "<OIG_NM_PWD>" $OIG_NM_PWD $file
     create_sed_entry "<OIG_NM_HOME>" $OIG_NM_HOME $file
     create_sed_entry "<OAM_TRUST_STORE>" $OAM_KEYSTORE_LOC/$(basename $OIG_TRUST_STORE) $file
     create_sed_entry "<OAM_TRUST_PWD>" $OAM_TRUSTSTORE_PWD $file
     if [ "$OIG_MODE" = "secure" ]
     then
        create_sed_entry "<OIG_ADMIN_PORT>" $OIG_ADMIN_ADMIN_PORT $file
        create_sed_entry "<OIG_OIM_ADMIN_PORT>" $OIG_OIM_ADMIN_PORT $file
        create_sed_entry "<OIG_OIM_PORT>" $OIG_OIM_ADMIN_PORT $file
     elif [ "$OIG_DOMAIN_SSL_ENABLED" = "true" ]
     then
        create_sed_entry "<OIG_ADMIN_PORT>" $OIG_ADMIN_SSL_PORT $file
        create_sed_entry "<OIG_OIM_ADMIN_PORT>" $OIG_OIM_SSL_PORT $file
        create_sed_entry "<OIG_OIM_PORT>" $OIG_OIM_SSL_PORT $file
        create_sed_entry "<OIG_ADMIN_WLS_PORT>" $OIG_ADMIN_SSL_PORT $file
     else
        create_sed_entry "<OIG_ADMIN_PORT>" $OIG_ADMIN_PORT $file
        create_sed_entry "<OIG_OIM_ADMIN_PORT>" $OIG_OIM_PORT $file
        create_sed_entry "<OIG_OIM_PORT>" $OIG_OIM_PORT $file
        create_sed_entry "<OIG_ADMIN_WLS_PORT>" $OIG_ADMIN_PORT $file
     fi
     if [ "$OIG_DOMAIN_SSL_ENABLED" = "true" ]
     then
        create_sed_entry "<OIG_T3>" "t3s" $file
        create_sed_entry "<JOB_ARGS>" "$OIG_KEYSTORE_LOC/$(basename $OIG_TRUST_STORE) $OIG_TRUSTSTORE_PWD" $file
        create_sed_entry "<OIG_SOA_PORT>" $OIG_SOA_SSL_PORT $file
        create_sed_entry "<OIG_OIM_NOT_ADMIN_PORT>" $OIG_OIM_SSL_PORT $file
     else
        create_sed_entry "<OIG_T3>" "t3" $file
        create_sed_entry "<OIG_OIM_NOT_ADMIN_PORT>" $OIG_OIM_PORT $file
        create_sed_entry "<JOB_ARGS>" "" $file
	echo "/WLST_PROPERTIES/d" >> $file
        create_sed_entry "<OIG_SOA_PORT>" $SOA_OIM_PORT $file
     fi
     if [ "$OAM_MODE" = "secure" ]
     then
        create_sed_entry "<OAM_ADMIN_PORT>" $OAM_ADMIN_ADMIN_PORT $file
     elif [ "$OAM_DOMAIN_SSL_ENABLED" = "true" ]
     then
        create_sed_entry "<OAM_ADMIN_PORT>" $OAM_ADMIN_SSL_PORT $file
     else
        create_sed_entry "<OAM_ADMIN_PORT>" $OAM_ADMIN_PORT $file
     fi
     if [ "$OAM_DOMAIN_SSL_ENABLED" = "true" ]
     then
        create_sed_entry "<OAM_ADMIN_WLS_PORT>" $OAM_ADMIN_SSL_PORT $file
     else
        create_sed_entry "<OAM_ADMIN_WLS_PORT>" $OAM_ADMIN_PORT $file
     fi
     create_sed_entry "<HOSTNAME>" $host $file
     create_sed_entry "<OIG_WLS_ADMIN_USER>" $OIG_WLS_ADMIN_USER $file
     create_sed_entry "<OIG_WLS_PWD>" $OIG_WLS_PWD $file
     create_sed_entry "<OIG_DOMAIN_SSL_ENABLED>" $OIG_DOMAIN_SSL_ENABLED $file
     create_sed_entry "<OIG_ADMIN_HOST>" $OIG_ADMIN_HOST $file
     create_sed_entry "<LDAP_WLSADMIN_GRP>" $LDAP_WLSADMIN_GRP $file
     create_sed_entry "<LDAP_HOST>" $LDAP_HOST $file
     if [ "$OUD_ENABLE_LDAPS" = "true" ]
     then
        create_sed_entry "<LDAP_PORT>" $OUD_LDAPS_PORT $file
        create_sed_entry "<LDAP_SECURE>" true $file
	create_sed_entry "<LDAP_TRUST_STORE>" $OIG_KEYSTORE_LOC/$(basename $OIG_TRUST_STORE) $file
        create_sed_entry "<LDAP_TRUST_PWD>" $OIG_TRUSTSTORE_PWD $file
     else
        create_sed_entry "<LDAP_PORT>" $OUD_LDAP_PORT $file
        create_sed_entry "<LDAP_SECURE>" false $file
	echo "/IDSTORE_KEYSTORE/d" >> $file
     fi
     create_sed_entry "<LDAP_OIGLDAP_USER>" $LDAP_OIGLDAP_USER $file
     create_sed_entry "<LDAP_SYSTEMIDS>" $LDAP_SYSTEMIDS $file
     create_sed_entry "<LDAP_USER_PWD>" $LDAP_USER_PWD $file
     create_sed_entry "<LDAP_USER_SEARCHBASE>" $LDAP_USER_SEARCHBASE $file
     create_sed_entry "<LDAP_GROUP_SEARCHBASE>" $LDAP_GROUP_SEARCHBASE $file
     create_sed_entry "<ORACLE_HOME>" $OIG_ORACLE_HOME $file
     create_sed_entry "<DIR_TYPE>" "OUD" $file
     create_sed_entry "<EMAIL_DOMAIN>" $(echo $LDAP_SEARCHBASE|sed 's/dc=//g;s/,/./g') $file
     create_sed_entry "<LDAP_ADMIN_USER>" $LDAP_ADMIN_USER $file
     create_sed_entry "<LDAP_ADMIN_PWD>" $LDAP_ADMIN_PWD $file
     create_sed_entry "<LDAP_SEARCHBASE>" $LDAP_SEARCHBASE $file
     create_sed_entry "<LDAP_SYSTEMIDS>" $LDAP_SYSTEMIDS $file
     create_sed_entry "<LDAP_XELSYSADM_USER>" $LDAP_XELSYSADM_USER $file
     create_sed_entry "<OAM_HOST>" $(echo $OAM_HOSTS | cut -f1 -d,) $file
     create_sed_entry "<OAM_WLS_ADMIN_USER>" $OAM_WLS_ADMIN_USER $file
     create_sed_entry "<OUD_XELSYSADM_PWD>" $LDAP_USER_PWD $file
     create_sed_entry "<OAM_DOMAIN_NAME>" $OAM_DOMAIN_NAME $file
     create_sed_entry "<OAM_ADMIN_HOST>" $OAM_ADMIN_HOST $file
     create_sed_entry "<OAM_LOGIN_LBR_HOST>" $OAM_LOGIN_LBR_HOST $file
     create_sed_entry "<OAM_LOGIN_LBR_PORT>" $OAM_LOGIN_LBR_PORT $file
     create_sed_entry "<OIG_LBR_PROTOCOL>" $OIG_LBR_PROTOCOL $file
     create_sed_entry "<OIG_LBR_HOST>" $OIG_LBR_HOST $file
     create_sed_entry "<OIG_LBR_PORT>" $OIG_LBR_PORT $file
     create_sed_entry "<OIG_LBR_INT_PROTOCOL>" $OIG_LBR_INT_PROTOCOL $file
     create_sed_entry "<OIG_LBR_INT_HOST>" $OIG_LBR_INT_HOST $file
     create_sed_entry "<OIG_LBR_INT_PORT>" $OIG_LBR_INT_PORT $file
     create_sed_entry "<OAM_WLS_PWD>" $OAM_WLS_PWD $file
     create_sed_entry "<OAM_DOMAIN_SSL_ENABLED>" $OAM_DOMAIN_SSL_ENABLED $file
     create_sed_entry "<LDAP_OAMADMIN_USER>" $LDAP_OAMADMIN_USER $file
     create_sed_entry "<MSERVER_HOME>" $OIG_MSERVER_HOME $file
     create_sed_entry "<DOMAIN_NAME>" $OIG_DOMAIN_NAME $file

     print_status $?

     ET=$(date +%s)

     print_time STEP "Create Sed file" $ST $ET >> $LOGDIR/timings.log
}

# Using the sedfile above convert the template files to environment specific files
#
make_create_scripts()
{

   host=$1
   ST=$(date +%s)
   print_msg "Creating OIG Domain Scripts "
   printf "\n\t\t\tCreating directory $WORKDIR/create_scripts - "
   mkdir $WORKDIR/create_scripts >/dev/null 2>&1
   echo "Success"
   OIG_TEMPLATES="create_oig_domain.py create_domain.sh create_schemas.sh drop_schemas.sh"
   OIG_TEMPLATES="$OIG_TEMPLATES /offline.sh setUser*.sh enroll_domain.sh start_oig.sh stop_oig.sh "
   OIG_TEMPLATES="$OIG_TEMPLATES delete_oig_files.sh configureWLSAuthnProviders.config start_admin.sh start_ms.sh stop_ms.sh"
   OIG_TEMPLATES="$OIG_TEMPLATES configureLDAPConnector.config configureSSOIntegration.config enableOAMSessionDeletion.config configureSOAIntegration.config"
   OIG_TEMPLATES="$OIG_TEMPLATES run_integration.sh start_admin.sh runJob.sh assign_wsm_roles.py update_soa.py create_email.py"
   OIG_TEMPLATES="$OIG_TEMPLATES update_notifications.py update_bi.py update_domainenv.sh"
   GEN_TEMPLATES="setup_ssl.py update_ssl.sh nodemanager.properties create_nm.sh start_nm.sh run_wlst.sh pack_domain.sh unpack_domain.sh"

   printf "\t\t\tCreating scripts - "
   for template in $OIG_TEMPLATES
   do
       cp $TEMPLATE_DIR/$template $WORKDIR/create_scripts
   done

   for template in $GEN_TEMPLATES
   do
       cp $TEMPLATE_DIR/../general/$template $WORKDIR/create_scripts
   done

   for file in $OIG_TEMPLATES $GEN_TEMPLATES
   do
      sed -i $WORKDIR/create_scripts/$file -f $WORKDIR/oig.sedfile
   done

    cp -r $TEMPLATE_DIR/lib $WORKDIR/create_scripts
    cp -r $TEMPLATE_DIR/runJob.java $WORKDIR/create_scripts
    print_status $?
    ET=$(date +%s)
    print_time STEP "Create OIG Domain Creation Scripts" $ST $ET >> $LOGDIR/timings.log

}

# Run the OIG offlineconfig script
#
run_offline_config()
{
      hostname=$1

      ST=$(date +%s)
      print_msg "Running offline config manager"
      $SSH $OIG_OWNER@$hostname $REMOTE_WORKDIR/offline.sh > $LOGDIR/offline.log 2>&1
      grep -q "ailed" $LOGDIR/offline.log
      if [ $? -eq 0 ]
      then
         print_status 1 $LOGDIR/offline.log
      else
         print_status 0 $LOGDIR/offline.log
      fi

      ET=$(date +%s)
      print_time STEP "Running offline config manager" $ST $ET >> $LOGDIR/timings.log
}

# Run an integration script
#
run_integration()
{
      hostname=$1
      user=$2
      action=$3
      configFile=${action}.config

      ST=$(date +%s)
      print_msg "Running Integration command $action"
      $SSH $user@$hostname $REMOTE_WORKDIR/run_integration.sh $configFile $action > $LOGDIR/integration_$action.log 2>&1
      if [ "$action" = "configureLDAPConnector" ]
      then
	   grep -q "CONNECTOR_CONFIGURATION_FAILED" $LOGDIR/integration_$action.log
	   if [ $? -eq 0 ]
	   then 
             print_status 1 $LOGDIR/integration_$action.log
	   fi
      fi
      grep -q "Exception occurred" $LOGDIR/integration_$action.log
      if [ $? -eq 0 ]
      then
	 print_status 1 $LOGDIR/integration_$action.log
      else
         grep -q "ailed" $LOGDIR/integration_$action.log
         if [ $? -eq 0 ]
         then
            print_status 1 $LOGDIR/integration_$action.log
         else
            print_status 0 $LOGDIR/integration_$action.log
         fi      
      fi

      ET=$(date +%s)
      print_time STEP "Running Integration command $action" $ST $ET >> $LOGDIR/timings.log
}




# Start the OIG domain 
# start Admin server and SOA then OIM
#
enroll_domain()
{
     host=$1
     # Start the Domain
     #
     print_msg "Enrolling the domain with Node Manager"
     ST=$(date +%s)

     $SSH $OIG_OWNER@$host $REMOTE_WORKDIR/enroll_domain.sh > $LOGDIR/enroll_domain.log 2>&1
     print_status $? $LOGDIR/enroll_domain.log
     
     ET=$(date +%s)
     print_time STEP "Enroll Domain" $ST $ET >> $LOGDIR/timings.log
}

start_admin()
{
     host=$1
     # Start the Domain
     #
     print_msg "Starting the Admin Server"
     ST=$(date +%s)

     $SSH $OIG_OWNER@$host $REMOTE_WORKDIR/start_admin.sh > $LOGDIR/start_admin.log 2>&1
     printf "\n\t\t\tAdmin Server - "
     grep -q "Successfully started server AdminServer" $LOGDIR/start_admin.log
     if [ $? = 0 ]
     then
	 echo "Success"
     else 
	 grep -q "already running" $LOGDIR/start_admin.log
	 if [ $? = 0 ]
	 then 
	    echo "Already Running"
	 else
            print_status 1 $LOGDIR/start_admin.log
         fi
     fi
     ET=$(date +%s)
     print_time STEP "Starting Admin Server" $ST $ET >> $LOGDIR/timings.log
}

start_ms()
{
     host=$1
     server_no=$2
     # Start the Domain
     #
     print_msg "Starting the Managed Servers"
     ST=$(date +%s)

     $SSH $OIG_OWNER@$host $REMOTE_WORKDIR/start_ms.sh $server_no > $LOGDIR/start_ms.log 2>&1
     printf "\n\t\t\tsoa_server${server_no} - "
     grep -q "soa_server${server_no} started successfully" $LOGDIR/start_ms.log
     print_status $? $LOGDIR/start_ms.log
     printf "\t\t\toim_server${server_no} - "
     grep -q "oim_server${server_no} started successfully" $LOGDIR/start_ms.log
     print_status $? $LOGDIR/start_ms.log
     ET=$(date +%s)
     print_time STEP "Starting Managed Servers" $ST $ET >> $LOGDIR/timings.log
}
stop_ms()
{
     host=$1
     # Stop the Domain
     #
     print_msg "Stopping the Managed Servers"
     ST=$(date +%s)

     $SSH $OIG_OWNER@$host $REMOTE_WORKDIR/stop_ms.sh > $LOGDIR/stop_ms.log 2>&1
     print_status $? $LOGDIR/stop_ms.log
     ET=$(date +%s)
     print_time STEP "Stopping Managed Servers" $ST $ET >> $LOGDIR/timings.log
}

stop_oig_domain()
{
     # Stop the Domain
     #
     print_msg "Stop the OIG Domain"
     ST=$(date +%s)

     host=$(echo $OIG_HOSTS | awk ' {print $1}' )
     $SSH $OIG_OWNER@$host $REMOTE_WORKDIR/stop_oig.sh > $LOGDIR/stop_oig.log 2>&1
     print_status $? $LOGDIR/stop_oig.log
     ET=$(date +%s)
     print_time STEP "Stop the OIG domain" $ST $ET >> $LOGDIR/timings.log
}

start_oam_domain()
{
     # Start the Domain
     #
     print_msg "Starting the OAM Domain"
     ST=$(date +%s)

     oamhost1=$(echo $OAM_HOSTS | cut -f1 -d,)
     $SSH $OAM_OWNER@$oamhost1 $REMOTE_WORKDIR/start_admin.sh > $LOGDIR/start_oam.log 2>&1
     printf "\n\t\t\tAdmin Server - "
     grep -q "Successfully started server AdminServer" $LOGDIR/start_oam.log
     print_status $? $LOGDIR/start_oam.log
     instanceNo=1
     for oamhost in $OAM_HOSTS
     do
        printf "\t\t\toam_server$instanceNo - "
        $SSH $OAM_OWNER@$oamhost1 $REMOTE_WORKDIR/start_ms.sh $instanceNo > $LOGDIR/start_oam.log 2>&1
        grep -q "oam_server$instanceNo started successfully" $LOGDIR/start_oam.log
        print_status $? $LOGDIR/start_oam.log
        grep -q "oam_policy_mgr$instanceNo started successfully" $LOGDIR/start_oam.log
        print_status $? $LOGDIR/start_oam.log
        instanceNo=$((instanceNo+1))
     done
     ET=$(date +%s)
     print_time STEP "Start OAM Domain" $ST $ET >> $LOGDIR/timings.log
}

stop_oam_domain()
{
     # Stop the Domain
     #
     print_msg "Stop the OAM Domain"
     ST=$(date +%s)

     host=$(echo $OAM_HOSTS | cut -f1 -d,)
     $SSH $OAM_OWNER@$host $REMOTE_WORKDIR/stop_oam.sh > $LOGDIR/stop_oam.log 2>&1
     print_status $? $LOGDIR/stop_oam.log
     ET=$(date +%s)
     print_time STEP "Stop the OAM domain" $ST $ET >> $LOGDIR/timings.log
}

# Check the OIM Bootstrap completed successfully
#
check_oim_bootstrap()
{

     host=$1
     print_msg "Checking OIM Bootstrap"
     ST=$(date +%s)
     $SSH $OIG_OWNER@$host "grep -q 'BootStrap configuration Failed' $OIG_DOMAIN_HOME/servers/oim_server1/logs/oim_server1.out"
     if [ $? = 0 ]
     then
        echo "BootStrap configuration Failed - check kubectl logs -n $OIGNS ${OIG_DOMAIN_NAME}-oim-server1"
        exit 1
     else
        echo "Bootstrap Successful."
     fi

     ET=$(date +%s)
     print_time STEP "Check OIM Bootstrap Start " $ST $ET >> $LOGDIR/timings.log
}


#
# Update SOA URLS
#
update_soa_urls()
{
     host=$1
     user=$2
     ST=$(date +%s)
     print_msg "Update SOA URLs"
     $SSH $user@$host   $REMOTE_WORKDIR/run_wlst.sh $REMOTE_WORKDIR/update_soa.py > $LOGDIR/update_soa.log 2>&1
     print_status $? $LOGDIR/update_soa.log
     ET=$(date +%s)
     print_time STEP "Update SOA URLS" $ST $ET >> $LOGDIR/timings.log
}

#
# Assign WSM Roles
#
assign_wsmroles()
{
     host=$1
     ST=$(date +%s)
     print_msg "Assign WSM Roles"
     filename=$WORKDIR/create_scripts/assign_wsm_roles.py
     $SSH $OIG_OWNER@$host $REMOTE_WORKDIR/run_wlst.sh $REMOTE_WORKDIR/assign_wsm_roles.py >> $LOGDIR/assign_wsm_roles.log 2>&1
     print_status $? $LOGDIR/assign_wsm_roles.log
     ET=$(date +%s)
     print_time STEP "Assign WSM Roles" $ST $ET >> $LOGDIR/timings.log
}
     
# Add missing Object Classes to existing LDAP entries
#
add_object_classes()
{
     ST=$(date +%s)

     print_msg  "Add Missing Object Classes to LDAP"

     copy_to_k8 $TEMPLATE_DIR/add_object_classes.sh workdir $OIGNS $OIG_DOMAIN_NAME
     run_command_k8 $OIGNS $OIG_DOMAIN_NAME "$PV_MOUNT/workdir/add_object_classes.sh "> $LOGDIR/add_object_classes.log
     print_status $? $LOGDIR/add_object_classes.log

     ET=$(date +%s)
     print_time STEP "Add missing object classes to LDAP" $ST $ET >> $LOGDIR/timings.log
}

#
# Run Recon Jobs
#
run_recon_jobs()
{

     host=$1
     ST=$(date +%s)
     print_msg "Run Recon Jobs"

     echo $SSH $OIG_OWNER@$host $REMOTE_WORKDIR/runJob.sh > $LOGDIR/recon_jobs.log 2>&1
     $SSH $OIG_OWNER@$host $REMOTE_WORKDIR/runJob.sh >> $LOGDIR/recon_jobs.log 2>&1
     if [ $? -gt 0 ]
     then
        echo "Failed see logfile: $LOGDIR/recon_jobs.log"
        exit 1
     fi

     grep -q "Caused by:" $LOGDIR/recon_jobs.log

     if [ $? -eq 0 ]
     then
        echo "Failed see logfile: $LOGDIR/recon_jobs.log"
        exit 1
     fi
     grep -q "Status: Failed" $LOGDIR/recon_jobs.log

     if [ $? -eq 0 ]
     then
        echo "Failed see logfile: $LOGDIR/recon_jobs.log"
        exit 1
     else
        echo "Success"
     fi
     ET=$(date +%s)
     print_time STEP "Run Recon Jobs" $ST $ET >> $LOGDIR/timings.log
}

#
# Update BI Config
#
update_biconfig()
{
     host=$1
     user=$2

     ST=$(date +%s)
     print_msg "Update BI Integration"

     file=$WORKDIR/create_scripts/update_bi.py 
     update_variable "<OIG_BI_PROTOCOL>" $OIG_BI_PROTOCOL $file
     update_variable "<OIG_BI_HOST>" $OIG_BI_HOST $file
     update_variable "<OIG_BI_PORT>" $OIG_BI_PORT $file
     update_variable "<OIG_BI_USER>" $OIG_BI_USER $file
     update_variable "<OIG_BI_USER_PWD>" $OIG_BI_USER_PWD $file

     $SCP $file $user@$host:$REMOTE_WORKDIR/update_bi.py >$LOGDIR/update_bi.log 2>&1
     $SSH $user@$host $REMOTE_WORKDIR/run_wlst.sh $REMOTE_WORKDIR/update_bi.py >> $LOGDIR/update_bi.log 2>&1
     print_status $? $LOGDIR/update_bi.log
     ET=$(date +%s)
     print_time STEP "Update BI Integration" $ST $ET >> $LOGDIR/timings.log
}

#
# Create Email Driver
#
create_email_driver()
{

     host=$1
     user=$2
     ST=$(date +%s)
     print_msg "Create Email Driver"

     filename=$WORKDIR/create_scripts/create_email.py

     update_variable "<OIG_EMAIL_SERVER>" $OIG_EMAIL_SERVER $filename
     update_variable "<OIG_EMAIL_PORT>" $OIG_EMAIL_PORT $filename
     if [ "$OIG_EMAIL_SECURITY" = "" ]
     then
         sed -i '/OutgoingMailServerSecurity/d' $filename
     else
         update_variable "<OIG_EMAIL_SECURITY>" $OIG_EMAIL_SECURITY $filename
     fi
     if [ "$OIG_EMAIL_PWD" = "" ]
     then
         sed -i '/OutgoingPassword/d' $filename
     else
         update_variable "<OIG_EMAIL_PWD>" $OIG_EMAIL_PWD $filename
     fi

     update_variable "<OIG_EMAIL_ADDRESS>" $OIG_EMAIL_ADDRESS $filename
     $SCP $filename  $user@$host:$REMOTE_WORKDIR >$LOGDIR/create_email.log 2>&1
     $SSH $user@$host $REMOTE_WORKDIR/run_wlst.sh $REMOTE_WORKDIR/create_email.py >> $LOGDIR/create_email.log 2>&1

     print_status $? $LOGDIR/create_email.log
     ET=$(date +%s)
     print_time STEP "Create Email Driver" $ST $ET >> $LOGDIR/timings.log
}

#
# Set Notifications to Email
#
set_email_notifications()
{

     host=$1
     user=$2
     ST=$(date +%s)
     print_msg "Set Notifications to Email"


     filename=$WORKDIR/create_scripts/update_notifications.py

     update_variable "<OIG_EMAIL_FROM_ADDRESS>" $OIG_EMAIL_FROM_ADDRESS $filename
     update_variable "<OIG_EMAIL_REPLY_ADDRESS>" $OIG_EMAIL_REPLY_ADDRESS $filename

     $SCP $filename  $user@$host:$REMOTE_WORKDIR > $LOGDIR/update_notifications.log 2>&1
     $SSH $user@$host $REMOTE_WORKDIR/run_wlst.sh  $REMOTE_WORKDIR/update_notifications.py >> $LOGDIR/update_notifications.log 2>&1

     print_status $? $LOGDIR/update_notifications.log
     ET=$(date +%s)
     print_time STEP "Set Notifications to Email" $ST $ET >> $LOGDIR/timings.log
}

# Add Loadbalancer Certs to Oracle Keystore Service
#
add_certs_to_kss()
{
     ST=$(date +%s)
     print_msg "Add Certificates to Oracle Keystore Service"
     echo "connect('$OIG_WEBLOGIC_USER','$OIG_WEBLOGIC_PWD','t3://$OIG_ADMIN_HOST:$OIG_ADMIN_PORT') " > $WORKDIR/add_cert_to_kss.py
     echo "svc = getOpssService(name='KeyStoreService')" >> $WORKDIR/add_cert_to_kss.py

     for cert in `ls -1 $WORKDIR/*.pem`
     do
           aliasname=$(basename $cert | sed 's/.pem//')
           echo "svc.importKeyStoreCertificate(appStripe='system',name='trust',password='', keypassword='',alias='$aliasname',type='TrustedCertificate', filepath='$PV_MOUNT/keystores/$aliasname.pem')" >> $WORKDIR/add_cert_to_kss.py
           $SCP $cert $OIG_OWNER:$OIG_ADMIN_HOST:$REMOTE_WORKDIR  
     done
     echo "syncKeyStores(appStripe='system', keystoreFormat='KSS')" >> $WORKDIR/add_cert_to_kss.py
     echo "exit()" >> $WORKDIR/add_cert_to_kss.py
     
     $SCP  $WORKDIR/add_cert_to_kss.py  $OIG_OWNER:$OIG_ADMIN_HOST:$REMOTE_WORKDIR >$LOGDIR/add_cert_to_kss.log 2>&1
     $SSH $OIG_OWNER:$OIG_ADMIN_HOST $REMOTE_WORKDIR/run_wlst.sh $REMOTE_WORKDIR/add_cert_to_kss.py >> $LOGDIR/add_cert_to_kss.log 2>&1
     print_status $? $LOGDIR/add_cert_to_kss.log
     ET=$(date +%s)
     print_time STEP "Add Certificates to Keystore" $ST $ET >> $LOGDIR/timings.log
}

# 
# Create OIG OHS Config Files
#
create_oig_ohs_config()
{
   ST=$(date +%s)


   print_msg "Creating OHS Config files"
   OHS_PATH=$LOCAL_WORKDIR/OHS

   ohshosts=$(echo $OHS_HOSTS | sed 's/,/ /g')
   oighosts=$(echo $OIG_HOSTS | sed 's/,/ /g')
   for ohshost in $ohshosts
   do 
      hostsn=$(echo $ohshost | cut -f1 -d.)
      if ! [ -d $OHS_PATH/$ohshost ]
      then
          mkdir -p $OHS_PATH/$ohshost
      fi

      printf "\n\t\t\tCreating Virtual Host Files for $hostsn - "
      cp $TEMPLATE_DIR/igdadmin_vh.conf $OHS_PATH/$ohshost/igdadmin_vh.conf
      cp $TEMPLATE_DIR/igdinternal_vh.conf $OHS_PATH/$ohshost/igdinternal_vh.conf
      cp $TEMPLATE_DIR/oim_vh.conf $OHS_PATH/$ohshost/oim_vh.conf

      if [ "$OIG_DOMAIN_SSL_ENABLED" = "true" ]
      then
         OIG_OIM_PORT=$OIG_OIM_SSL_PORT 
         OIG_SOA_PORT=$OIG_SOA_SSL_PORT
         OIG_ADMIN_PORT=$OIG_ADMIN_SSL_PORT
	 ohsadminport=$OIG_OHS_ADMIN_PORT
	 ohsintport=$OIG_OHS_INT_PORT
	 ohsoimport=$OIG_OHS_OIM_PORT
      else
         OIG_OIM_PORT=$OIG_OIM_PORT 
         OIG_SOA_PORT=$OIG_SOA_PORT
         OIG_ADMIN_PORT=$OIG_ADMIN_PORT
	 ohsadminport=$OHS_PORT
	 ohsintport=$OHS_PORT
	 ohsoimport=$OHS_PORT

      fi
            if [ "$OHS_SSL_ENABLED" = "true" ]
      then
	 sed -i "/<Virtual/i Listen $ohshost:$OIG_OHS_ADMIN_PORT" $OHS_PATH/$ohshost/igdadmin_vh.conf
	 sed -i "/<Virtual/i Listen $ohshost:$OIG_OHS_OIM_PORT" $OHS_PATH/$ohshost/oim_vh.conf
	 sed -i "/<Virtual/i Listen $ohshost:$OIG_OHS_INT_PORT" $OHS_PATH/$ohshost/igdinternal_vh.conf
	 sed -i "/ServerAdmin/a\    SSLEngine on\n    SSLWallet \"$OHS_WALLETS/wallet_$OIG_ADMIN_LBR_HOST\"" $OHS_PATH/$ohshost/igdadmin_vh.conf
	 sed -i "/ServerAdmin/a\    SSLEngine on\n    SSLWallet \"$OHS_WALLETS/wallet_$OIG_LBR_HOST\"" $OHS_PATH/$ohshost/oim_vh.conf
	 sed -i "/ServerAdmin/a\    SSLEngine on\n    SSLWallet \"$OHS_WALLETS/wallet_$OIG_LBR_INT_HOST\"" $OHS_PATH/$ohshost/igdinternal_vh.conf

      fi

      update_variable "<OHS_HOST>" $ohshost $OHS_PATH/$ohshost/igdadmin_vh.conf
      update_variable "<OHS_PORT>" $ohsadminport $OHS_PATH/$ohshost/igdadmin_vh.conf
      update_variable "<OIG_ADMIN_LBR_PROTOCOL>" $OIG_ADMIN_LBR_PROTOCOL $OHS_PATH/$ohshost/igdadmin_vh.conf
      update_variable "<OIG_ADMIN_LBR_HOST>" $OIG_ADMIN_LBR_HOST $OHS_PATH/$ohshost/igdadmin_vh.conf
      update_variable "<OIG_ADMIN_LBR_PORT>" $OIG_ADMIN_LBR_PORT $OHS_PATH/$ohshost/igdadmin_vh.conf

      update_variable "<OHS_HOST>" $ohshost $OHS_PATH/$ohshost/oim_vh.conf
      update_variable "<OHS_PORT>" $ohsoimport $OHS_PATH/$ohshost/oim_vh.conf
      update_variable "<OIG_LBR_PROTOCOL>" $OIG_LBR_PROTOCOL $OHS_PATH/$ohshost/oim_vh.conf
      update_variable "<OIG_LBR_HOST>" $OIG_LBR_HOST $OHS_PATH/$ohshost/oim_vh.conf
      update_variable "<OIG_LBR_PORT>" $OIG_LBR_PORT $OHS_PATH/$ohshost/oim_vh.conf

      update_variable "<OHS_HOST>" $ohshost $OHS_PATH/$ohshost/igdinternal_vh.conf
      update_variable "<OHS_PORT>" $ohsintport $OHS_PATH/$ohshost/igdinternal_vh.conf
      update_variable "<OIG_LBR_INT_PROTOCOL>" $OIG_LBR_INT_PROTOCOL $OHS_PATH/$ohshost/igdinternal_vh.conf
      update_variable "<OIG_LBR_INT_HOST>" $OIG_LBR_INT_HOST $OHS_PATH/$ohshost/igdinternal_vh.conf
      update_variable "<OIG_LBR_INT_PORT>" $OIG_LBR_INT_PORT $OHS_PATH/$ohshost/igdinternal_vh.conf
      echo


      create_location $TEMPLATE_DIR/locations.txt "$oighosts" $OHS_PATH/$ohshost $OIG_DOMAIN_SSL_ENABLED
      
   done

   ET=$(date +%s)
   print_time STEP "Creating OHS config" $ST $ET >> $LOGDIR/timings.log
}


# Delete the OIG files created by a fresh installation.
#
delete_oig_files()
{
   hostname=$1
   logfile=$2
   ST=$(date +%s)
   print_msg "Delete OIG Domain Files"

   hostsn=$(echo $hostname | cut -f1 -d.)
   printf "\n\t\tCopying Script to host $hostsn - "
   $SCP  $WORKDIR/create_scripts/delete_oig_files.sh $OIG_OWNER@$hostname: >>$logfile 2>&1
   if [ $? -gt 0 ]
   then
     echo "Failed"
   else
     echo "Success"
   fi
   printf "\t\tDeleting files on host $hostsn - "
   $SSH $OIG_OWNER@$hostname ./delete_oig_files.sh >>$logfile 2>&1
   if [ $? -gt 0 ]
   then
     echo "Failed"
   else
     echo "Success"
   fi

   ET=$(date +%s)
}

update_domainenv()
{
   hostname=$1
   ST=$(date +%s)
   print_msg "Update Classpath"
  
   $SSH $OIG_OWNER@$hostname $REMOTE_WORKDIR/update_domainenv.sh >$LOGDIR/update_domainenv.log 2>&1

   print_status $?  $LOGDIR/update_domainenv.log

   ET=$(date +%s)
   print_time STEP "Delete OIG Domain Files" $ST $ET >> $LOGDIR/timings.log
}

# TO BE REMOVED
#
create_wls_user()
{
   ST=$(date +%s)
   print_msg "****** TEMPORARY Create WLS User "
   $SSH $OIG_OWNER@$OIG_ADMIN_HOST /home/oracle/createSOAUser.sh > $LOGDIR/create_wls_user.log 2>&1

   print_status $?  $LOGDIR/create_wls_user.log

   ET=$(date +%s)
   print_time STEP "Delete OIG Domain Files" $ST $ET >> $LOGDIR/timings.log
}


