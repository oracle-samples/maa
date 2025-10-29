# Copyright (c) 2021, 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# This is an example of procedures used to configure OAM
#
# Usage: Not invoked directly

create_oam_install_scripts()
{

   ST=$(date +%s)
   print_msg "Creating OAM Installation Scripts "
   cp $TEMPLATE_DIR/install_oam.sh $WORKDIR
   file=$WORKDIR/install_oam.sh

   ORACLE_BASE=$(dirname $OAM_ORACLE_HOME)
   ORA_INVENTORY=$(dirname $ORACLE_BASE)
   update_variable "<OAM_SHIPHOME_DIR>" $OAM_SHIPHOME_DIR $file
   update_variable "<GEN_JDK_VER>" $GEN_JDK_VER $file
   update_variable "<ORACLE_BASE>" $ORACLE_BASE $file
   update_variable "<WORKDIR>" $REMOTE_WORKDIR $file
   update_variable "<OAM_ORACLE_HOME>" $OAM_ORACLE_HOME $file
   update_variable "<OAM_INFRA_INSTALLER>" $OAM_INFRA_INSTALLER $file
   update_variable "<OAM_IDM_INSTALLER>" $OAM_IDM_INSTALLER $file

   cp $TEMPLATE_DIR/install_oam.rsp $WORKDIR
   update_variable "<OAM_ORACLE_HOME>" $OAM_ORACLE_HOME $WORKDIR/install_oam.rsp
   cp $TEMPLATE_DIR/install_infra.rsp $WORKDIR
   update_variable "<OAM_ORACLE_HOME>" $OAM_ORACLE_HOME $WORKDIR/install_infra.rsp

   echo "inventory_loc=$ORACLE_BASE/oraInventory" > $WORKDIR/oraInst.loc
   echo "inst_group=$OAM_GROUP" >> $WORKDIR/oraInst.loc

   print_status $?

   ET=$(date +%s)
   print_time STEP "Create OAM Installation Scripts" $ST $ET >> $LOGDIR/timings.log

}

# Create a file to edit template files enmass
#
create_sedfile()
{
     host=$1
     ST=$(date +%s)
     print_msg "Creating Sed files to update creation files"

     echo "" > $WORKDIR/oam.sedfile
     file=$WORKDIR/oam.sedfile

     ORACLE_BASE=$(dirname $OAM_ORACLE_HOME)
     JAVA_HOME=$ORACLE_BASE/jdk
     hostname=$(echo $host | cut -f1 -d.)
     oamTrustStore=$OAM_KEYSTORE_LOC/$(basename $OAM_TRUST_STORE)
     tmp=$(echo $OAM_LOGIN_LBR_HOST=login.edg.com | cut -f1 -d.) 
     cookieDomain=$(echo $OAM_LOGIN_LBR_HOST | sed "s/$tmp//")

     create_sed_entry "<OAM_DOMAIN_NAME>" $OAM_DOMAIN_NAME $file
     create_sed_entry "<OAM_DOMAIN_HOME>" $OAM_DOMAIN_HOME $file
     create_sed_entry "<WORKDIR>" $REMOTE_WORKDIR $file
     create_sed_entry "<JAVA_HOME>" $JAVA_HOME $file
     create_sed_entry "<OAM_OWNER>" $OAM_OWNER $file
     create_sed_entry "<OAM_ORACLE_HOME>" $OAM_ORACLE_HOME $file
     create_sed_entry "<COOKIE_DOMAIN>" $cookieDomain $file
     create_sed_entry "<OAM_DB_SCAN>" $OAM_DB_SCAN $file
     create_sed_entry "<OAM_DB_LISTENER>" $OAM_DB_LISTENER $file
     create_sed_entry "<OAM_DB_SERVICE>" $OAM_DB_SERVICE $file
     create_sed_entry "<OAM_RCU_PREFIX>" $OAM_RCU_PREFIX $file
     create_sed_entry "<OAM_DB_SYS_PWD>" $OAM_DB_SYS_PWD $file
     create_sed_entry "<OAM_DB_SCHEMA_PWD>" $OAM_DB_SCHEMA_PWD $file
     create_sed_entry "<TRUST_STORE>" $oamTrustStore $file
     create_sed_entry "<OAM_TRUST_STORE>" $oamTrustStore $file
     create_sed_entry "<OAM_TRUST_PWD>" $OAM_TRUSTSTORE_PWD $file
     create_sed_entry "<TRUST_STORE_PWD>" $OIG_TRUSTSTORE_PWD $file
     create_sed_entry "<DOMAIN_HOME>" $OAM_DOMAIN_HOME $file
     create_sed_entry "<OAM_ORACLE_HOME>" $OAM_ORACLE_HOME $file
     create_sed_entry "<CERT_STORE>" $OAM_KEYSTORE_LOC/$(basename $OAM_CERT_STORE) $file
     create_sed_entry "<CERT_FILE>" $OAM_CERT_STORE $file
     if [ "$OAM_CERT_TYPE" = "host" ]
     then
        create_sed_entry "<CERT_ALIAS>" "host" $file
     else
        create_sed_entry "<CERT_ALIAS>" $OAM_CERT_NAME $file
     fi
     create_sed_entry "<CERT_STORE_PWD>" $OAM_KEYSTORE_PWD $file
     create_sed_entry "<NM_PWD>" $OAM_NM_PWD $file
     create_sed_entry "<NM_HOME>" $OAM_NM_HOME $file
     create_sed_entry "<OAM_NM_PWD>" $OAM_NM_PWD $file
     create_sed_entry "<OAM_NM_HOME>" $OAM_NM_HOME $file
     create_sed_entry "<OAM_TRUST_STORE>" $OAM_KEYSTORE_LOC/$(basename $OIG_TRUST_STORE) $file
     create_sed_entry "<OAM_TRUST_PWD>" $OAM_TRUSTSTORE_PWD $file
     if [ "$OIG_MODE" = "secure" ]
     then
        create_sed_entry "<OIG_ADMIN_PORT>" $OIG_ADMIN_ADMIN_PORT $file
     elif [ "$OIG_DOMAIN_SSL_ENABLED" = "true" ]
     then
        create_sed_entry "<OIG_ADMIN_PORT>" $OIG_ADMIN_SSL_PORT $file
     else
        create_sed_entry "<OIG_ADMIN_PORT>" $OIG_ADMIN_PORT $file
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
        create_sed_entry "<OAM_T3>" "t3s" $file
     else
	create_sed_entry "<OAM_T3>" "t3" $file
        create_sed_entry "<OAM_ADMIN_WLS_PORT>" $OAM_ADMIN_PORT $file
     fi
          if [ "$OIG_DOMAIN_SSL_ENABLED" = "true" ]
     then
        create_sed_entry "<OIG_ADMIN_WLS_PORT>" $OIG_ADMIN_SSL_PORT $file
        create_sed_entry "<OIG_T3>" "t3s" $file
        create_sed_entry "<OIG_OIM_PORT>" $OIG_OIM_SSL_PORT $file
        create_sed_entry "<JOB_ARGS>" "$OIG_KEYSTORE_LOC/$(basename $OIG_TRUST_STORE) $OIG_TRUSTSTORE_PWD" $file
        create_sed_entry "<OIG_SOA_PORT>" $OIG_SOA_SSL_PORT $file
     else
        create_sed_entry "<OIG_ADMIN_WLS_PORT>" $OIG_ADMIN_PORT $file
        create_sed_entry "<OIG_T3>" "t3" $file
        create_sed_entry "<OIG_OIM_PORT>" $OIG_OIM_PORT $file
        create_sed_entry "<JOB_ARGS>" "" $file
        echo "/WLST_PROPERTIES/d" >> $file
        create_sed_entry "<OIG_SOA_PORT>" $SOA_OIM_PORT $file
     fi
     create_sed_entry "<OAM_ADMIN_HOST>" $OAM_ADMIN_HOST $file
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
     create_sed_entry "<LDAP_OAMLDAP_USER>" $LDAP_OAMLDAP_USER $file
     create_sed_entry "<LDAP_OIGLDAP_USER>" $LDAP_OIGLDAP_USER $file
     create_sed_entry "<LDAP_WLSADMIN_USER>" $LDAP_WLSADMIN_USER $file
     create_sed_entry "<LDAP_OAMADMIN_GRP>" $LDAP_OAMADMIN_GRP $file
     create_sed_entry "<LDAP_OIGADMIN_GRP>" $LDAP_OIGADMIN_GRP $file
     create_sed_entry "<LDAP_WLSADMIN_GRP>" $LDAP_WLSADMIN_GRP $file
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
     create_sed_entry "<OAM_LOGIN_LBR_PROTOCOL>" $OAM_LOGIN_LBR_PROTOCOL $file
     create_sed_entry "<OIG_LBR_PROTOCOL>" $OIG_LBR_PROTOCOL $file
     create_sed_entry "<OIG_LBR_HOST>" $OIG_LBR_HOST $file
     create_sed_entry "<OIG_LBR_PORT>" $OIG_LBR_PORT $file
     create_sed_entry "<OIG_LBR_INT_PROTOCOL>" $OIG_LBR_INT_PROTOCOL $file
     create_sed_entry "<OIG_LBR_INT_HOST>" $OIG_LBR_INT_HOST $file
     create_sed_entry "<OIG_LBR_INT_PORT>" $OIG_LBR_INT_PORT $file
     create_sed_entry "<OAM_OIG_INTEG>" $OAM_OIG_INTEG $file
     create_sed_entry "<OAM_WLS_PWD>" $OAM_WLS_PWD $file
     create_sed_entry "<OAM_DOMAIN_SSL_ENABLED>" $OAM_DOMAIN_SSL_ENABLED $file
     create_sed_entry "<LDAP_OAMADMIN_USER>" $LDAP_OAMADMIN_USER $file
     create_sed_entry "<MSERVER_HOME>" $OAM_MSERVER_HOME $file
     create_sed_entry "<DOMAIN_NAME>" $OAM_DOMAIN_NAME $file

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
   print_msg "Creating OAM Domain Scripts "
   printf "\n\t\t\tCreating directory $WORKDIR/create_scripts - "
   mkdir $WORKDIR/create_scripts >/dev/null 2>&1
   echo "Success"
   OAM_TEMPLATES="create_oam_domain.py create_domain.sh create_schemas.sh drop_schemas.sh"
   OAM_TEMPLATES="$OAM_TEMPLATES  setUser*.sh enroll_domain.sh start_oam.sh stop_oam.sh "
   OAM_TEMPLATES="$OAM_TEMPLATES delete_oam_files.sh start_admin.sh start_ms.sh "
   OAM_TEMPLATES="$OAM_TEMPLATES configoam.props runIdmConfig.sh  config_adf_security.py update_oamds.py"
   OAM_TEMPLATES="$OAM_TEMPLATES  start_admin.sh "
   GEN_TEMPLATES="setup_ssl.py update_ssl.sh nodemanager.properties create_nm.sh start_nm.sh run_wlst.sh pack_domain.sh unpack_domain.sh"

   printf "\t\t\tCreating scripts - "
   for template in $OAM_TEMPLATES
   do
       cp $TEMPLATE_DIR/$template $WORKDIR/create_scripts
   done

   for template in $GEN_TEMPLATES
   do
       cp $TEMPLATE_DIR/../general/$template $WORKDIR/create_scripts
   done

   for file in $OAM_TEMPLATES $GEN_TEMPLATES
   do
      sed -i $WORKDIR/create_scripts/$file -f $WORKDIR/oam.sedfile
   done

   numHosts=$(echo $OAM_HOSTS | wc -w)
   index=1
   while [ $index -le $numHosts ]
   do
      echo "shutdown('oam_server$index','Server', ignoreSessions='true', force='true')" >> $WORKDIR/create_scripts/stop_oam.sh
      echo "shutdown('oam_policy_mgr$index','Server', ignoreSessions='true', force='true')" >> $WORKDIR/create_scripts/stop_oam.sh
      index=$((index+1))
   done
   echo "shutdown('AdminServer','Server', ignoreSessions='true', force='true')" >> $WORKDIR/create_scripts/stop_oam.sh
   echo "exit()" >> $WORKDIR/create_scripts/stop_oam.sh
   echo >> $WORKDIR/create_scripts/stop_oam.sh
   echo "EOF" >> $WORKDIR/create_scripts/stop_oam.sh

   print_status $?
   ET=$(date +%s)
   print_time STEP "Create OAM Domain Creation Scripts" $ST $ET >> $LOGDIR/timings.log

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

     $SSH $OAM_OWNER@$host $REMOTE_WORKDIR/enroll_domain.sh > $LOGDIR/enroll_domain.log 2>&1
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

     $SSH $OAM_OWNER@$host $REMOTE_WORKDIR/start_ms.sh $server_no > $LOGDIR/start_ms.log 2>&1
     printf "\n\t\t\toam_server$server_no - "
     grep -q "oam_server$server_no started successfully" $LOGDIR/start_ms.log
     print_status $? $LOGDIR/start_ms.log
     printf "\t\t\tpolicy_mgr_server$server_no - "
     print_status $? $LOGDIR/start_ms.log
     ET=$(date +%s)
     print_time STEP "Starting Managed Servers" $ST $ET >> $LOGDIR/timings.log
}

start_oam_domain()
{
     host=$1
     # Start the Domain
     #
     print_msg "Starting the OAM Domain"
     ST=$(date +%s)

     host=$(echo $OAM_HOSTS | awk '{ print $1}')
     $SSH $OIG_OWNER@$host $REMOTE_WORKDIR/start_oam.sh > $LOGDIR/start_oam.log 2>&1
     printf "\n\t\t\tAdmin Server - "
     grep -q "Successfully started server AdminServer" $LOGDIR/start_oam.log
     print_status $? $LOGDIR/start_oam.log
     printf "\t\t\toam_cluster - "
     grep -q "oam_cluster are started successfully" $LOGDIR/start_oam.log
     print_status $? $LOGDIR/start_oam.log
     printf "\t\t\tpolicy_cluster - "
     grep -q "policy_cluster are started successfully" $LOGDIR/start_oam.log
     ET=$(date +%s)
     print_time STEP "Start OAM Domain" $ST $ET >> $LOGDIR/timings.log
}

stop_oam_domain()
{  
     host=$1
     # Stop the Domain
     #
     print_msg "Stop the OAM Domain"
     ST=$(date +%s)

     host=$(echo $OAM_HOSTS | awk ' {print $1}' )
     $SSH $OAM_OWNER@$host $REMOTE_WORKDIR/stop_oam.sh > $LOGDIR/stop_oam.log 2>&1
     print_status $? $LOGDIR/stop_oam.log
     ET=$(date +%s)
     print_time STEP "Stop the OAM domain" $ST $ET >> $LOGDIR/timings.log
}
# Create the OAM domain
#
create_oam_domain()
{

     print_msg "Initialising the Domain"
     ST=$(date +%s)
     cd $WORKDIR/samples/create-access-domain/domain-home-on-pv

     ./create-domain.sh -i $WORKDIR/create-domain-inputs.yaml -t 1200 -o output > $LOGDIR/create_domain.log 2>$LOGDIR/create_domain.log
     grep -qs ERROR $LOGDIR/create_domain.log
     if [ $? = 0 ]
     then
         echo "Fail - Check logfile $LOGDIR/create_domain.log for details"
         exit 1
     fi

     pod=`kubectl get pod -n $OAMNS | grep $OAM_DOMAIN_NAME | awk '{ print $1 }'`
     kubectl logs -n $OAMNS $pod | grep -q Failed
     if [ $? = 0 ]
     then
        echo "Fail - See kubectl logs -n $OAMNS $pod for details"
        exit 1
     fi

     kubectl logs -n $OAMNS $pod | grep -q "Successfully Completed"
     if [ $? = 1 ]
     then
        echo "Fail - See kubectl logs -n $OAMNS $pod for details"
        exit 1
     fi

     status=`kubectl get pod -n $OAMNS | grep create | awk  '{ print $3}'`
     create_job_name=`kubectl get pod -n $OAMNS | grep create | awk  '{ print $1}'`
     if [ "$status" = "Pending" ] || [ "$status" = "Error" ]
     then
         kubectl describe job -n $OAMNS $create_job_name >> $LOGDIR/create_domain.log 2>&1
         kubectl -n $OAMNS describe domain $OAM_DOMAIN_ID >> $LOGDIR/create_domain.log 2>&1
         kubectl logs -n $OAMNS $create_job_name >> $LOGDIR/create_domain.log 2>&1
         echo " Failed - see logfile $LOGDIR/create_domain.log"
         exit 1
     else
         echo "Success"
     fi
     ET=$(date +%s)

     print_time STEP "Initialise the Domain" $ST $ET >> $LOGDIR/timings.log

}

create_oam_domain_wdt()
{

     print_msg "Initialising the Domain"
     ST=$(date +%s)
     
     printf "\n\t\t\tCreating the domain - "
     oper_pod=$(kubectl get pods -n $OPERNS --no-headers=true | grep -v webhook | head -1 | awk '{ print $1 }')
     if [ "$oper_pod" = "" ]
     then
        echo "Failed to get the name of the WebLogic Operator Pod."
        exit 1
     fi

     kubectl create -f $WORKDIR/weblogic-domains/$OAM_DOMAIN_NAME/domain.yaml > $LOGDIR/create_domain.log 2>$LOGDIR/create_domain.log
     print_status $? $LOGDIR/create_domain.log

     
     printf "\t\t\tChecking no errors in WebLogic Operator log - "
     sleep 30
     kubectl logs -n $OPERNS $oper_pod --since=60s| grep $OAM_DOMAIN_NAME | grep SEVERE >> $LOGDIR/create_domain.log
     grep -q SEVERE $LOGDIR/create_domain.log
     if [ $? -eq 0 ]
     then 
        echo "Failed - Check Logfile: $LOGDIR/create_domain.log"
        exit 1
     fi

     sleep 30
     kubectl logs -n $OPERNS $oper_pod --since=120s| grep $OAM_DOMAIN_NAME | grep SEVERE >> $LOGDIR/create_domain.log
     grep -q SEVERE $LOGDIR/create_domain.log
     if [ $? -eq 0 ]
     then 
        echo "Failed - Check Logfile: $LOGDIR/create_domain.log"
        exit 1
     else
        echo "Success"
     fi

     ET=$(date +%s)

     print_time STEP "Initialise the Domain" $ST $ET >> $LOGDIR/timings.log

}

#
# Start the domain for the first time.
#
perform_first_start()
{
     # Start the Domain
     #
     ST=$(date +%s)
     print_msg "Starting the Domain"

     cd $WORKDIR/samples/create-access-domain/domain-home-on-pv
     cp output/weblogic-domains/$OAM_DOMAIN_NAME/domain.yaml output/weblogic-domains/$OAM_DOMAIN_NAME/domain_original.yaml
     echo
     update_java_parameters

     printf "\t\t\tPatching the Domain - "
     kubectl apply -f output/weblogic-domains/$OAM_DOMAIN_NAME/domain.yaml > $LOGDIR/first_start.log
     print_status $? $LOGDIR/first_start.log

     ET=$(date +%s)

     print_time STEP "Start the Domain" $ST $ET >> $LOGDIR/timings.log
}

# Create NodePort Services for OAM
#
create_oam_nodeport()
{
     ST=$(date +%s)
     print_msg  "Creating OAM NodePort Services "
     echo
     cp $TEMPLATE_DIR/*nodeport*.yaml $WORKDIR
     cp $TEMPLATE_DIR/*clusterip*.yaml $WORKDIR

     update_variable "<DOMAIN_NAME>" $OAM_DOMAIN_NAME $WORKDIR/oam_nodeport.yaml
     update_variable "<NAMESPACE>" $OAMNS $WORKDIR/oam_nodeport.yaml
     update_variable "<OAM_OAM_K8>" $OAM_OAM_K8 $WORKDIR/oam_nodeport.yaml
     update_variable "<DOMAIN_NAME>" $OAM_DOMAIN_NAME $WORKDIR/policy_nodeport.yaml
     update_variable "<NAMESPACE>" $OAMNS $WORKDIR/policy_nodeport.yaml
     update_variable "<OAM_POLICY_K8>" $OAM_POLICY_K8 $WORKDIR/policy_nodeport.yaml
     update_variable "<DOMAIN_NAME>" $OAM_DOMAIN_NAME $WORKDIR/oap_nodeport.yaml
     update_variable "<NAMESPACE>" $OAMNS $WORKDIR/oap_nodeport.yaml
     update_variable "<OAP_PORT>" $OAM_OAP_PORT $WORKDIR/oap_nodeport.yaml
     update_variable "<OAP_SERVICEPORT>" $OAM_OAP_SERVICE_PORT $WORKDIR/oap_nodeport.yaml
     update_variable "<OAP_PORT>" $OAM_OAP_PORT $WORKDIR/oap_clusterip.yaml
     update_variable "<NAMESPACE>" $OAMNS $WORKDIR/oap_clusterip.yaml
     update_variable "<DOMAIN_NAME>" $OAM_DOMAIN_NAME $WORKDIR/oap_clusterip.yaml

     printf "\t\t\t\tOAM Service - "
     kubectl create -f $WORKDIR/oam_nodeport.yaml > $LOGDIR/nodeport.log 2>>$LOGDIR/nodeport.log
     if [ $? -eq 0 ] 
     then
         echo  "Success"
     else
         echo  "Failed"
  
     fi
     printf "\t\t\t\tPolicy Mangaer Service - "
     kubectl create -f $WORKDIR/policy_nodeport.yaml >> $LOGDIR/nodeport.log 2>>$LOGDIR/nodeport.log
     if [ $? -eq 0 ] 
     then
         echo  "Success"
     else
         echo  "Failed"
  
     fi

     printf "\t\t\t\tOAP Service ClusterIP - "
     kubectl create -f $WORKDIR/oap_clusterip.yaml >> $LOGDIR/nodeport.log 2>>$LOGDIR/nodeport.log
     if [ $? -eq 0 ] 
     then
         echo  "Success"
     else
         echo  "Failed"
  
     fi
     ET=$(date +%s) 
     print_time STEP "Create Kubernetes OAM NodePort Services " $ST $ET >> $LOGDIR/timings.log
}

# Create Ingress Services for OAM
#
create_oam_ingress_manual()
{
     ST=$(date +%s)
     print_msg  "Creating OAM Ingress Services "
     cp $TEMPLATE_DIR/oam_ingress.yaml $WORKDIR
     filename=$WORKDIR/oam_ingress.yaml

     update_variable "<OAM_DOMAIN_NAME>" $OAM_DOMAIN_NAME $filename
     update_variable "<OAMNS>" $OAMNS $filename
     update_variable "<OAM_LOGIN_LBR_HOST>" $OAM_LOGIN_LBR_HOST $filename
     update_variable "<OAM_ADMIN_LBR_HOST>" $OAM_ADMIN_LBR_HOST $filename
     update_variable "<OAM_ADMIN_PORT>" $OAM_ADMIN_PORT $filename

     kubectl create -f $filename > $LOGDIR/ingress.log 2>>$LOGDIR/ingress.log
     print_status $? $LOGDIR/ingress.log
     ET=$(date +%s) 
     print_time STEP "Create Kubernetes OAM Ingress Services " $ST $ET >> $LOGDIR/timings.log
}

# Create Ingress Services for OAM
#
create_oam_ingress()
{
     ST=$(date +%s)
     print_msg  "Creating OAM Ingress Services "
     cp $WORKDIR/samples/charts/ingress-per-domain/values.yaml $WORKDIR/override_ingress.yaml
     filename=$WORKDIR/override_ingress.yaml

     replace_value2 domainUID $OAM_DOMAIN_NAME $filename
     replace_value2  adminServerPort $OAM_ADMIN_PORT $filename
     replace_value2  enabled true $filename
     replace_value2 runtime $OAM_LOGIN_LBR_HOST $filename
     replace_value2 admin  $OAM_ADMIN_LBR_HOST $filename
     replace_value2 sslType  NONSSL $filename

     cd $WORKDIR/samples
     helm install oam-nginx charts/ingress-per-domain --namespace $OAMNS --values $filename  > $LOGDIR/ingress.log 2>>$LOGDIR/ingress.log
     print_status $? $LOGDIR/ingress.log
     ET=$(date +%s) 
     print_time STEP "Create Kubernetes OAM Ingress Services " $ST $ET >> $LOGDIR/timings.log
}
# Update the newly created OAM domain using OAM API's
#
update_default_oam_domain()
{
     ADMINURL=$1
     USER=$2

     ST=$(date +%s)
     print_msg "Updating default OAM Domain Settings"

     cp $TEMPLATE_DIR/oamconfig_modify_template.xml  $WORKDIR/oamconfig_modify.xml

     for i in $( seq 1 $OAM_SERVER_COUNT)
     do
         sed -i "2i<Setting Name=\"Value\" Type=\"xsd:string\" Path=\"/DeployedComponent/Server/NGAMServer/Instance/oam_server$i/CoherenceConfiguration/LocalHost/Value\">$OAM_DOMAIN_NAME-oam-server$i</Setting>" $WORKDIR/oamconfig_modify.xml
         sed -i "2i<Setting Name=\"Port\" Type=\"xsd:integer\" Path=\"/DeployedComponent/Server/NGAMServer/Instance/oam_server$i/oamproxy/Port\">$OAM_OAP_PORT</Setting>" $WORKDIR/oamconfig_modify.xml
         sed -i "2i<Setting Name=\"host\" Type=\"xsd:string\" Path=\"/DeployedComponent/Server/NGAMServer/Instance/oam_server$i/host\">$OAM_DOMAIN_NAME-oam-server$i</Setting>"  $WORKDIR/oamconfig_modify.xml
     done

     update_variable "<OAM_SERVER>" $OAM_DOMAIN_NAME $WORKDIR/oamconfig_modify.xml
     update_variable "<OAP_PORT>" $OAM_OAP_PORT $WORKDIR/oamconfig_modify.xml
     update_variable "<LBR_HOST>" $OAM_LOGIN_LBR_HOST $WORKDIR/oamconfig_modify.xml
     update_variable "<LBR_PORT>" $OAM_LOGIN_LBR_PORT $WORKDIR/oamconfig_modify.xml
     update_variable "<LBR_PROTOCOL>" $OAM_LOGIN_LBR_PROTOCOL $WORKDIR/oamconfig_modify.xml
     update_variable "<OAP_HOST>" $OAM_OAP_HOST $WORKDIR/oamconfig_modify.xml
     update_variable "<OAP_SERVICE_PORT>" $OAM_OAP_SERVICE_PORT $WORKDIR/oamconfig_modify.xml

     ENCUSER=`encode_pwd ${USER}`
     USER_HEADER="-H 'Authorization: Basic $ENCUSER'"
     
     PUTCURL="curl -s -x '' -X PUT $ADMINURL/iam/admin/config/api/v1/config -ikL -H 'Content-Type: application/xml'  $USER_HEADER -H 'cache-control: no-cache' -d @$WORKDIR/oamconfig_modify.xml" 
     GET_OAMCONFIG="curl -s -x '' -X GET $ADMINURL/iam/admin/config/api/v1/config -ikL -H 'Content-Type: application/xml'  $USER_HEADER -H 'cache-control: no-cache' "

     echo "Executing Command :  $PUTCURL "> $LOGDIR/update_oam.log 
     eval $PUTCURL>> $LOGDIR/update_oam.log 2>&1
     eval $GET_OAMCONFIG > $WORKDIR/oam-config.xml

     grep -q OAMRestEndPointHostName $WORKDIR/oam-config.xml | grep $OAM_LOGIN_LBR_HOST
     if [ $? -eq 1 ] 
     then
         echo  "Success"
     else
         echo  "Failed"
         exit 1
     fi

     ET=$(date +%s)
     print_time STEP "Update Default OAM Domain " $ST $ET >> $LOGDIR/timings.log
}

# Update Application Domain HostIDs
#
update_oam_hostids()
{
     ADMINURL=$1
     USER=$2
     
     print_msg "Update Host Identifiers"
     ST=$(date +%s)

     ENCUSER=$(encode_pwd ${USER})
     USER_HEADER="-H 'Authorization: Basic $ENCUSER'"

     CMD="curl -k -s -X GET $USER_HEADER $ADMINURL/oam/services/rest/11.1.2.0.0/ssa/policyadmin/hostidentifier?name=IAMSuiteAgent"' | grep "<id>" | sed "s/^ *//g;s/<id>//;s/<\/id>//"'
     echo "Executing Command : $CMD" > $LOGDIR/host_identifiers.log 2>&1
     ID=$(eval $CMD)
     
     if [ "$ID" = "" ]
     then
        curl -X GET $USER_HEADER $ADMINURL/oam/services/rest/11.1.2.0.0/ssa/policyadmin/hostidentifier?name=IAMSuiteAgent >> $LOGDIR/host_identifiers.log 2>&1
	print_status $? $LOGDIR/host_identifiers.log
     fi

     CURL_COMMAND="curl -k -X PUT $USER_HEADER"
     OAM_RESTAPI="$ADMINURL/oam/services/rest/11.1.2.0.0/ssa/policyadmin/hostidentifier"
     CONTENT_JSON="-H 'Content-Type: application/json' -H 'cache-control: no-cache'"
     START_JSON="-d '{\"Hosts\":{\"host\":[{\"port\":\"80\",\"hostName\":\"IAMSuiteAgent\"},{\"hostName\":\"IAMSuiteAgent\"}"
     END_JSON="]},\"description\":\"Host identifier for IAM Suite resources\",\"name\":\"IAMSuiteAgent\",\"id\":\"${ID}\"}'"
     JSON_HOSTS=",{\"port\":\"$OAM_LOGIN_LBR_PORT\",\"hostName\":\"$OAM_LOGIN_LBR_HOST\"}"
     JSON_HOSTS="$JSON_HOSTS",{\"port\":\"$OIG_LBR_PORT\",\"hostName\":\"$OIG_LBR_HOST\"}""
     JSON_HOSTS="$JSON_HOSTS",{\"port\":\"$OIG_LBR_INT_PORT\",\"hostName\":\"$OIG_LBR_INT_HOST\"}""
     JSON_HOSTS="$JSON_HOSTS",{\"port\":\"$OAM_ADMIN_LBR_PORT\",\"hostName\":\"$OAM_ADMIN_LBR_HOST\"}""
     JSON_HOSTS="$JSON_HOSTS",{\"port\":\"$OIG_ADMIN_LBR_PORT\",\"hostName\":\"$OIG_ADMIN_LBR_HOST\"}""
     for ohshost in $(echo $OHS_HOSTS | sed 's/,/  /g')
     do

	if [ "$OAM_DOMAIN_SSL_ENABLED" = "true" ]
        then
           JSON_HOSTS="$JSON_HOSTS",{\"port\":\"$OAM_OHS_ADMIN_PORT\",\"hostName\":\"$ohshost\"}""
           JSON_HOSTS="$JSON_HOSTS",{\"port\":\"$OAM_OHS_LOGIN_PORT\",\"hostName\":\"$ohshost\"}""
	fi

	if [ "$OIG_DOMAIN_SSL_ENABLED" = "true" ]
        then
           JSON_HOSTS="$JSON_HOSTS",{\"port\":\"$OIG_OHS_ADMIN_PORT\",\"hostName\":\"$ohshost\"}""
           JSON_HOSTS="$JSON_HOSTS",{\"port\":\"$OIG_OHS_OIM_PORT\",\"hostName\":\"$ohshost\"}""
           JSON_HOSTS="$JSON_HOSTS",{\"port\":\"$OIG_OHS_INT_PORT\",\"hostName\":\"$ohshost\"}""
	fi
        JSON_HOSTS="$JSON_HOSTS",{\"port\":\"$OHS_PORT\",\"hostName\":\"$ohshost\"}""
     done 
     JSON=${START_JSON}${JSON_HOSTS}${END_JSON}

     echo "Executing Command : " "$CURL_COMMAND \"$OAM_RESTAPI\" $CONTENT_JSON $JSON" >> $LOGDIR/host_identifiers.log
     eval "$CURL_COMMAND \"$OAM_RESTAPI\" $CONTENT_JSON $JSON" >> $LOGDIR/host_identifiers.log 2>&1

     print_status $? $LOGDIR/host_identifiers.log
     ET=$(date +%s)
     print_time STEP "Update Host Identifiers" $ST $ET >> $LOGDIR/timings.log
}


# Add Resources to IAMSuite Application domain
#
add_oam_resources()
{
     ADMINURL=$1
     USER=$2
     INPUT_FILE="$TEMPLATE_DIR/resource_list.txt"

     ST=$(date +%s)
     print_msg "Add Missing Resources"
     echo "Add Missing Resources"  > $LOGDIR/add_resources.log

     OAM_RESTAPI="'$ADMINURL/oam/services/rest/11.1.2.0.0/ssa/policyadmin/resource'"

     ENCUSER=`encode_pwd ${USER}`
     USER_HEADER="-H 'Authorization: Basic $ENCUSER'"

     CURL_COMMAND="curl -s -X POST $USER_HEADER"
     CONTENT_TYPE="-H 'Content-Type: application/json' -H 'cache-control: no-cache'"

     while IFS= read -r RESOURCE
     do

       RES_URL=`echo $RESOURCE | cut -f1 -d:`
       RES_TYPE=`echo $RESOURCE | cut -f2 -d:`
       RES_AUTHN=`echo $RESOURCE | cut -f3 -d:`
       RES_AUTHZ=`echo $RESOURCE | cut -f4 -d:`
    
       START_JSON="-d '{\"queryString\":null,\"applicationDomainName\":\"IAM Suite\",\"hostIdentifierName\":\"IAMSuiteAgent\",\"resourceURL\":\"${RES_URL}\",\"protectionLevel\":\"$RES_TYPE\""
       START_JSON="${START_JSON},\"QueryParameters\":null,\"resourceTypeName\":\"HTTP\",\"Operations\":null,\"description\":\"${RES_URL}\",\"name\":\"${RES_URL}\",\"id\":\"1\"}'"

       RES_JSON=$START_JSON

       XX=`eval "$CURL_COMMAND $OAM_RESTAPI $CONTENT_TYPE $RES_JSON"`  >> $LOGDIR/add_resources.log

       ID=`echo $XX | cut -f2 -d=`

       echo "  Created Resource ${RES_URL} ID: $ID" >> $LOGDIR/add_resources.log
       if [ "$RES_TYPE" = "PROTECTED" ]
       then
          PROTECTED_RESOURCES="$PROTECTED_RESOURCES $ID"
       fi

     done < $INPUT_FILE

     echo "Protected Resources" $PROTECTED_RESOURCES  >> $LOGDIR/add_resources.log

     # Assign Protected Resources to Authentication Policy

     REST_API="'$ADMINURL/oam/services/rest/11.1.2.0.0/ssa/policyadmin/authnpolicy?appdomain=IAM%20Suite&name=Protected%20HigherLevel%20Policy'"

     GET_CURL_COMMAND="curl -s -X GET $USER_HEADER"
     PUT_CURL_COMMAND="curl -s -o /dev/null  -X PUT $USER_HEADER"
     CONTENT_TYPE="-H 'Content-Type: application/xml' -H 'cache-control: no-cache'"

     eval "$GET_CURL_COMMAND $REST_API " > /tmp/authn.xml
     if [ $? = 1 ] 
     then
         echo  "Failed"
         exit 1
     fi

     for RESOURCE in $PROTECTED_RESOURCES
     do
      sed -i '/<Resources>*/a \ \ \ \ \ \ <Resource>'${RESOURCE}'</Resource>' /tmp/authn.xml
     done

     sed -i 's/<\/AuthenticationPolicies>//;s/<AuthenticationPolicies>/\n/' /tmp/authn.xml
     sed -i '/<\?xml/d' /tmp/authn.xml
     eval "$PUT_CURL_COMMAND $REST_API $CONTENT_TYPE -d @/tmp/authn.xml"
     if [ $? = 1 ] 
     then
         echo  "Failed"
         exit 1
     fi

     # Assign Protected Resources to Authorisation Policy

     REST_API="'$ADMINURL/oam/services/rest/11.1.2.0.0/ssa/policyadmin/authzpolicy?appdomain=IAM%20Suite&name=Protected%20Resource%20Policy'"

     eval "$GET_CURL_COMMAND $REST_API " > /tmp/authz.xml
     if [ $? = 1 ] 
     then
         echo  "Failed"
         exit 1
     fi

     for RESOURCE in $PROTECTED_RESOURCES
     do
        sed -i '/<Resources>*/a \ \ \ \ \ \ <Resource>'${RESOURCE}'</Resource>' /tmp/authz.xml
     done

     sed -i 's/<\/AuthorizationPolicies>//;s/<AuthorizationPolicies>/\n/' /tmp/authz.xml
     sed -i '/<\?xml/d' /tmp/authz.xml
     eval "$PUT_CURL_COMMAND $REST_API $CONTENT_TYPE -d @/tmp/authz.xml" >$LOGDIR/authn.log

     if [ $? = 1 ] 
     then
         echo  "Failed"
         exit 1
     else
         echo "Success"
     fi

     ET=$(date +%s)
     print_time STEP "Add Resources" $ST $ET >> $LOGDIR/timings.log
     
}

# Wire OAM to OUD
#
run_idmConfigTool()
{

   host=$1
   ST=$(date +%s)
   print_msg "Wiring OAM to LDAP"

   $SSH $OAM_OWNER@$host $REMOTE_WORKDIR/runIdmConfig.sh configOAM configoam.props > $LOGDIR/configoam.log 2>&1
   print_status $? $LOGDIR/configoam.log
    
   printf "\t\t\tChecking Log File - "
   $SSH $OAM_OWNER@$host cat $REMOTE_WORKDIR/automation_integ.log  >> $LOGDIR/configoam.log 2>&1

   grep SEVERE $LOGDIR/configoam.log | grep -v simple | grep -v Suceeded> /dev/null
   if [ $? = 0 ]
   then
      echo "Failed - Check logifle $WORKDIR/logs/configoam.log"
      echo "SEVERE Error Message Detected." >>  $WORKDIR/logs/configoam.log
      exit 1
   else
      echo "Success"
   fi

   ET=$(date +%s)
   print_time STEP "Wire OAM to LDAP" $ST $ET >> $LOGDIR/timings.log

}

# Create a Webgate Agent for IAMSuite
#
create_wg_agent()
{
   ST=$(date +%s)
   print_msg "Create Webgate Agent"
   
   cp $TEMPLATE_DIR/Webgate_IDM.xml $WORKDIR
   cp $TEMPLATE_DIR/create_wg.sh $WORKDIR
   update_variable "<OAM_DOMAIN_NAME>" $OAM_DOMAIN_NAME $WORKDIR/Webgate_IDM.xml
   update_variable "<OAMNS>" $OAMNS $WORKDIR/Webgate_IDM.xml
   update_variable "<LDAP_OAMADMIN_USER>" $LDAP_OAMADMIN_USER $WORKDIR/create_wg.sh
   update_variable "<LDAP_USER_PWD>" $LDAP_USER_PWD $WORKDIR/create_wg.sh
   update_variable "<OAM_WEBLOGIC_USER>" $OAM_WEBLOGIC_USER $WORKDIR/create_wg.sh
   update_variable "<OAM_WEBLOGIC_PWD>" $OAM_WEBLOGIC_PWD $WORKDIR/create_wg.sh
   update_variable "<PV_MOUNT>" $PV_MOUNT $WORKDIR/create_wg.sh
   update_variable "<OAM_DOMAIN_NAME>" $OAM_DOMAIN_NAME $WORKDIR/create_wg.sh

   copy_to_k8 $WORKDIR/Webgate_IDM.xml workdir $OAMNS $OAM_DOMAIN_NAME
   copy_to_k8 $WORKDIR/create_wg.sh workdir $OAMNS $OAM_DOMAIN_NAME

   run_command_k8 $OAMNS $OAM_DOMAIN_NAME "chmod 750 $PV_MOUNT/workdir/create_wg.sh"
   run_command_k8 $OAMNS $OAM_DOMAIN_NAME "$PV_MOUNT/workdir/create_wg.sh" > $LOGDIR/create_wg.log 2>&1

   grep -q "completed successfully" $LOGDIR/create_wg.log
   print_status $? $LOGDIR/create_wg.log

   ET=$(date +%s)
   print_time STEP "Time taken to create Webgate" $ST $ET >> $LOGDIR/timings.log
}

# Configure ADF Logout
# 
config_adf_logout()
{
    
   ST=$(date +%s)
   print_msg "Setting ADF Logout"
   $SSH $OAM_OWNER@$host   $REMOTE_WORKDIR/run_wlst.sh $REMOTE_WORKDIR/config_adf_security.py > $LOGDIR/config_adf_security.log 2>&1

   print_status $? $LOGDIR/config_adf_security.log
   ET=$(date +%s)
   print_time STEP "Set ADF Logout" $ST $ET >> $LOGDIR/timings.log
}


# Update OAM Datasource
# 
update_oamds()
{
    
   host=$1
   ST=$(date +%s)
   print_msg "Updating OAMDS"

   $SSH $OAM_OWNER@$host   $REMOTE_WORKDIR/run_wlst.sh $REMOTE_WORKDIR/update_oamds.py > $LOGDIR/update_oamds.log 2>&1
   print_status $?  $LOGDIR/update_oamds.log
   ET=$(date +%s)
   print_time STEP "Update OAM Datasource" $ST $ET >> $LOGDIR/timings.log
}

# Create a configuration file which can be used by Oracle HTTP server for accessing OAM
#
create_oam_ohs_config()
{
   ST=$(date +%s)
   
   print_msg "Creating OHS Config Files" 
   echo
   OHS_PATH=$LOCAL_WORKDIR/OHS
   ohshosts=$(echo $OHS_HOSTS | sed 's/,/ /g')
   oamhosts=$(echo $OAM_HOSTS | sed 's/,/ /g')
   for ohshost in $ohshosts
   do
       hostsn=$(echo $ohshost | cut -f1 -d.)
       if  [ ! -d $OHS_PATH/$ohshost ]
       then
          mkdir -p $OHS_PATH/$ohshost
       fi

      printf "\t\t\tCreating Virtual Host Files for host $hostsn- "
      cp $TEMPLATE_DIR/iadadmin_vh.conf $OHS_PATH/$ohshost/iadadmin_vh.conf
      cp $TEMPLATE_DIR/login_vh.conf $OHS_PATH/$ohshost/login_vh.conf

      if [ "$OAM_DOMAIN_SSL_ENABLED" = "true" ]
      then
	 if [ ! "$OAM_MODE" = "secure" ]
         then
            OAM_ADMIN_ADMIN_PORT=$OAM_OAM_SSL_PORT
	 fi
         OAM_OAM_PORT=$OAM_OAM_SSL_PORT
         OAM_POLICY_PORT=$OAM_POLICY_SSL_PORT
         OAM_ADMIN_PORT=$OAM_ADMIN_SSL_PORT
         ohsadminport=$OAM_OHS_ADMIN_PORT
         ohsLoginport=$OAM_OHS_LOGIN_PORT
      else
         OAM_OAM_PORT=$OAM_OAM_PORT
         OAM_POLICY_PORT=$OAM_POLICY_PORT
         OAM_ADMIN_PORT=$OIG_ADMIN_PORT
         ohsadminport=$OAM_OHS_ADMIN_PORT
         ohsLoginport=$OAM_OHS_LOGIN_PORT

      fi
      if [ "$OHS_SSL_ENABLED" = "true" ]
      then
         sed -i "/<Virtual/i Listen $ohshost:$OAM_OHS_ADMIN_PORT" $OHS_PATH/$ohshost/iadadmin_vh.conf
         sed -i "/<Virtual/i Listen $ohshost:$OAM_OHS_LOGIN_PORT" $OHS_PATH/$ohshost/login_vh.conf
         sed -i "/ServerAdmin/a\    SSLEngine on\n    SSLWallet \"$OHS_WALLETS/wallet_$OAM_ADMIN_LBR_HOST\"" $OHS_PATH/$ohshost/iadadmin_vh.conf
         sed -i "/ServerAdmin/a\    SSLEngine on\n    SSLWallet \"$OHS_WALLETS/wallet_$OAM_LOGIN_LBR_HOST\"" $OHS_PATH/$ohshost/login_vh.conf
      fi
      update_variable "<OHS_HOST>" $ohshost $OHS_PATH/$ohshost/iadadmin_vh.conf
      update_variable "<OHS_PORT>" $ohsadminport $OHS_PATH/$ohshost/iadadmin_vh.conf
      update_variable "<OAM_ADMIN_LBR_PROTOCOL>" $OAM_ADMIN_LBR_PROTOCOL $OHS_PATH/$ohshost/iadadmin_vh.conf
      update_variable "<OAM_ADMIN_LBR_HOST>" $OAM_ADMIN_LBR_HOST $OHS_PATH/$ohshost/iadadmin_vh.conf
      update_variable "<OAM_ADMIN_LBR_PORT>" $OAM_ADMIN_LBR_PORT $OHS_PATH/$ohshost/iadadmin_vh.conf
      update_variable "<OHS_HOST>" $ohshost $OHS_PATH/$ohshost/login_vh.conf
      update_variable "<OHS_PORT>" $ohsLoginport $OHS_PATH/$ohshost/login_vh.conf
      update_variable "<OAM_LOGIN_LBR_PROTOCOL>" $OAM_LOGIN_LBR_PROTOCOL $OHS_PATH/$ohshost/login_vh.conf
      update_variable "<OAM_LOGIN_LBR_HOST>" $OAM_LOGIN_LBR_HOST $OHS_PATH/$ohshost/login_vh.conf
      update_variable "<OAM_LOGIN_LBR_PORT>" $OAM_LOGIN_LBR_PORT $OHS_PATH/$ohshost/login_vh.conf
      print_status $?

      create_location $TEMPLATE_DIR/locations.txt "$oamhosts" $OHS_PATH/$ohshost $OAM_DOMAIN_SSL_ENABLED

   done

   ET=$(date +%s)
   print_time STEP "Creating OHS config" $ST $ET >> $LOGDIR/timings.log
}

# Copy Webgate Files to DOMAIN_HOME/output
#
copy_wg_files()
{
   ST=$(date +%s)
   print_msg "Copying Webgate Artifacts to $LOCAL_WORKDIR/OHS/webgate"
   if  [ ! -d $LOCAL_WORKDIR/OHS/webgate ]
   then
       mkdir -p $LOCAL_WORKDIR/OHS/webgate
   fi
   oamhost1=$(echo $OAM_HOSTS | awk '{print $1}')
   echo $SCP -r $OAM_OWNER@$oamhost1:$OAM_DOMAIN_HOME/output/Webgate_IDM/* $LOCAL_WORKDIR/OHS/webgate > $LOGDIR/copy_wg_files 2>&1
   $SCP -r $OAM_OWNER@$oamhost1:$OAM_DOMAIN_HOME/output/Webgate_IDM/* $LOCAL_WORKDIR/OHS/webgate >> $LOGDIR/copy_wg_files 2>&1
   print_status $? $LOGDIR/copy_wg_files
   ET=$(date +%s)
   print_time STEP "Copy Webgate Artifacts to $LOCAL_WORKDIR/OHS/webgate" $ST $ET >> $LOGDIR/timings.log
}




delete_oam_files()
{
   hostname=$1
   logfile=$2
   ST=$(date +%s)
   print_msg "Delete OAM Domain Files"

   hostsn=$(echo $hostname | cut -f1 -d.)
   printf "\n\t\tCopying Script to host $hostsn - "
   $SCP  $WORKDIR/create_scripts/delete_oam_files.sh $OAM_OWNER@$hostname:$REMOTE_WORKDIR >>$logfile 2>&1
   if [ $? -gt 0 ]
   then 
     echo "Failed"
   else
     echo "Success"
   fi
   printf "\t\tDeleting file on host $hostsn - "
   $SSH $OAM_OWNER@$hostname $REMOTE_WORKDIR/delete_oam_files.sh  >>$logfile 2>&1
   if [ $? -gt 0 ]
   then 
     echo "Failed"
   else
     echo "Success"
   fi
   ET=$(date +%s)
}

