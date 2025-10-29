# Copyright (c) 2022, 2024, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# This is an example of procedures used to configure OHS
#
# Usage: Not invoked directly


create_ohs_install_scripts()
{

   ST=$(date +%s)
   print_msg "Creating OHS Installation Scripts "
   cp $TEMPLATE_DIR/install_ohs.sh $WORKDIR
   file=$WORKDIR/install_ohs.sh

   ORACLE_BASE=$(dirname $OHS_ORACLE_HOME)
   ORA_INVENTORY=$(dirname $ORACLE_BASE)
   update_variable "<OHS_SHIPHOME_DIR>" $OHS_SHIPHOME_DIR $file
   update_variable "<GEN_JDK_VER>" $GEN_JDK_VER $file
   update_variable "<ORACLE_BASE>" $ORACLE_BASE $file
   update_variable "<WORKDIR>" $REMOTE_WORKDIR $file
   update_variable "<OHS_ORACLE_HOME>" $OHS_ORACLE_HOME $file
   update_variable "<OHS_INSTALLER>" $OHS_INSTALLER $file

   cp $TEMPLATE_DIR/install_ohs.rsp $WORKDIR
   update_variable "<OHS_ORACLE_HOME>" $OHS_ORACLE_HOME $WORKDIR/install_ohs.rsp

   echo "inventory_loc=$ORACLE_BASE" > $WORKDIR/oraInst.loc
   echo "inst_group=$OHS_GROUP" >> $WORKDIR/oraInst.loc

   print_status $?

   ET=$(date +%s)
   print_time STEP "Create OHS Installation Scripts" $ST $ET >> $LOGDIR/timings.log

}


#
# Create the Oracle Home Directory 
#
create_config_dir()
{
   HOSTNAME=$1
   hostsn=$(echo $HOSTNAME | cut -f1 -d.)
   print_msg "Create Directores on $HOSTNAME"

   ST=$(date +%s)

   ORACLE_BASE=$(dirname $OHS_ORACLE_HOME)
   echo $SSH ${OHS_OWNER}@$HOSTNAME "mkdir -p  $ORACLE_BASE $OHS_DOMAIN"  >> $HOSTLOG/create_oh.log 2>&1 
   $SSH ${OHS_OWNER}@$HOSTNAME "mkdir -p  $ORACLE_BASE $OHS_DOMAIN"  >> $HOSTLOG/create_oh.log 2>&1 
   print_status $? $HOSTLOG/create_oh.log


   ET=$(date +%s)
   print_time STEP "Create Directories on $HOSTNAME" $ST $ET >> $LOGDIR/timings.log
}


#
# Install the Oracle HTTP Server
#
install_ohs()
{
   HOSTNAME=$1
   print_msg "Installing Oracle HTTP Server on $HOSTNAME"

   ST=$(date +%s)

   INSTALLER=`echo "$OHS_INSTALLER" | sed 's/_Disk1_1of1.zip/.bin/'`

   $SSH ${OHS_OWNER}@$HOSTNAME "./$INSTALLER -silent -responseFile ~/install_ohs.rsp" > $LOGDIR/$HOSTNAME/install_ohs.log 2>&1
 
   if [ $? -gt 0 ]
   then
      ERR=`grep Failed $LOGDIR/$HOSTNAME/install_ohs.log | grep -v compat-libcap | grep -v compat-libstdc | grep -v overall | wc -l`
      if [ $ERR = 0 ]
      then
        ssh $HOSTNAME "./$INSTALLER -silent -ignoreSysPreReqs -responseFile ~/install_ohs.rsp" > $LOGDIR/$HOSTNAME/install_ohs.log 2>&1
        print_status $? $LOGDIR/$HOSTNAME/install_ohs.log
      else
        echo "Failed - See logfile $LOGDIR/$HOSTNAME/install_ohs.log"
        exit 1
      fi
   else
      echo "Success"
   fi

   ET=$(date +%s)
   print_time STEP "Install Oracle HTTP Server on $HOSTNAME" $ST $ET >> $LOGDIR/timings.log
}

#
# Create a response file to create OHS Instance
#
create_instance_file()
{
   HOSTNAME=$1
   OHS_NAME=$2
   hostsn=$(echo $HOSTNAME | cut -f1 -d.)
   print_msg "Create Instance Creation File for $HOSTNAME"

   ST=$(date +%s)

   cp $TEMPLATE_DIR/create_instance.py $WORKDIR/create_instance_$hostsn.py

   filename=$WORKDIR/create_instance_$hostsn.py

   ORACLE_BASE=$(dirname $OHS_ORACLE_HOME)
   MW_HOME=$(dirname "$OHS_ORACLE_HOME")
   update_variable "<MW_HOME>" $OHS_ORACLE_HOME $filename
   update_variable "<JAVA_HOME>" $ORACLE_BASE/jdk $filename
   update_variable "<OHS_DOMAIN>" $OHS_DOMAIN $filename
   update_variable "<OHS_NAME>" $OHS_NAME $filename
   update_variable "<OHS_HTTP_PORT>" $OHS_PORT $filename
   update_variable "<OHS_HTTPS_PORT>" $OHS_HTTPS_PORT $filename
   update_variable "<NM_USER>" $NM_ADMIN_USER $filename
   update_variable "<NM_PWD>" $NM_ADMIN_PWD $filename

   NM_HOME=$OHS_DOMAIN/nodemanager
   update_variable "<NM_HOME>" $NM_HOME $filename
   update_variable "<NM_PORT>" $NM_PORT $filename


   $SCP $filename ${OHS_OWNER}@$HOSTNAME:$REMOTE_WORKDIR > $HOSTLOG/copy_instance_file.log 2>&1

   print_status $? $HOSTLOG/copy_instance_file.log

   ET=$(date +%s)
   print_time STEP "Copy Response File to $HOSTNAME" $ST $ET >> $LOGDIR/timings.log
}

#
# Create a response file to create OHS Instance
#
delete_instance()
{
   HOSTNAME=$1
   OHS_NAME=$2

   cp $TEMPLATE_DIR/delete_instance.py $WORKDIR/delete_instance_${OHS_NAME}.py
   if [ $? -gt 0 ]
   then
     echo "Failed to copy template file $TEMPLATE_DIR/delete_instance.py to $WORKDIR/delete_instance_${OHS_NAME}.py"
     exit 1
   fi

   filename=$WORKDIR/delete_instance_${OHS_NAME}.py

   MW_HOME=$(dirname "$OHS_ORACLE_HOME")
   update_variable "<MW_HOME>" $OHS_ORACLE_HOME $filename
   update_variable "<OHS_NAME>" $OHS_NAME $filename
   update_variable "<OHS_DOMAIN>" $OHS_DOMAIN $filename

   $SCP $filename ${OHS_OWNER}@$HOSTNAME:. 
   $SSH ${OHS_OWNER}@$HOSTNAME "$OHS_ORACLE_HOME/oracle_common/common/bin/wlst.sh delete_instance_${OHS_NAME}.py" 

}

# 
# Create the Oracle HTTTP Server Instance in Standalone mode.
#
create_instance()
{
   HOSTNAME=$1
   OHS_NAME=$2
   hostsn=$(echo $HOSTNAME | cut -f1 -d.)
   print_msg "Create Instance $OHS_NAME on $HOSTNAME"

   ST=$(date +%s)

   $SSH ${OHS_OWNER}@$HOSTNAME "$OHS_ORACLE_HOME/oracle_common/common/bin/wlst.sh $REMOTE_WORKDIR/create_instance_$hostsn.py" > $HOSTLOG/create_instance.log 2>&1
   print_status $? $HOSTLOG/create_instance.log

   ET=$(date +%s)
   print_time STEP "Create Instance $OHS_NAME on $HOSTNAME" $ST $ET >> $LOGDIR/timings.log

}

#
# Set OHS Tuning parameters
#
tune_instance()
{
   HOSTNAME=$1
   OHS_NAME=$2
   print_msg "Tune Oracle Http Server Instance on $HOSTNAME"
  
   ST=$(date +%s)

   $SCP $TEMPLATE_DIR/ohs.sedfile ${OHS_OWNER}@$HOSTNAME:. > $HOSTLOG/tune_instance.log 2>&1
   echo $SCP ${OHS_OWNER}@$HOSTNAME "sed -i -f ohs.sedfile $OHS_DOMAIN/config/fmwconfig/components/OHS/$OHS_NAME/httpd.conf" > $HOSTLOG/tune_instance.log 2>&1
   $SSH ${OHS_OWNER}@$HOSTNAME "sed -i -f ohs.sedfile $OHS_DOMAIN/config/fmwconfig/components/OHS/$OHS_NAME/httpd.conf" >> $HOSTLOG/tune_instance.log 2>&1

   print_status $? $HOSTLOG/tune_instance.log

   ET=$(date +%s)
   print_time STEP "Tune Instance $OHS_NAME on $HOSTNAME" $ST $ET >> $LOGDIR/timings.log

}  

#
# Set WebLogic SSL parameters
#
create_modwl()
{
   HOSTNAME=$1
   OHS_NAME=$2
   print_msg "Updating OHS Files for SSL"
  
   ST=$(date +%s)

   printf "\n\t\t\tCreating mod_wl_ohs.conf on $HOSTNAME - "
   cp $TEMPLATE_DIR/mod_wl_ohs.conf $WORKDIR
   update_variable "<WALLET>" $OHS_WALLETS $WORKDIR/mod_wl_ohs.conf
   $SCP $WORKDIR/mod_wl_ohs.conf ${OHS_OWNER}@$HOSTNAME:$OHS_DOMAIN/config/fmwconfig/components/OHS/$OHS_NAME/mod_wl_ohs.conf > $HOSTLOG/update_sslconf.log 2>&1
   print_status $? $HOSTLOG//create_modwl.log

   printf "\t\t\tUpdating ssl.conf on $HOSTNAME - "
   $SSH ${OHS_OWNER}@$HOSTNAME mv $OHS_DOMAIN/config/fmwconfig/components/OHS/$OHS_NAME/ssl.conf $OHS_DOMAIN/config/fmwconfig/components/OHS/$OHS_NAME/ssl.save  >> $HOSTLOG/update_sslconf.log 2>&1
   $SCP $TEMPLATE_DIR/ssl.conf ${OHS_OWNER}@$HOSTNAME:$OHS_DOMAIN/config/fmwconfig/components/OHS/$OHS_NAME/ssl.conf >> $HOSTLOG/update_sslconf.log 2>&1
   print_status $? $HOSTLOG//update_sslconf.log
   ET=$(date +%s)
   print_time STEP "Updated OHS Files for SSL on $HOSTNAME"  $ST $ET >> $LOGDIR/timings.log

}  

create_default_wallet()
{
   HOSTNAME=$1
   print_msg "Creating Default Wallet on $HOSTNAME"
  
   ST=$(date +%s)
   printf "\n\t\t\tCreating orapki runtime - "
   cp $TEMPLATE_DIR/run_orapki.sh $WORKDIR
   filename=$WORKDIR/run_orapki.sh
   ORACLE_BASE=$(dirname $OHS_ORACLE_HOME)
   update_variable "<OHS_ORACLE_HOME>" $OHS_ORACLE_HOME $filename
   update_variable "<JAVA_HOME>" $ORACLE_BASE/jdk $filename
   $SCP $filename $OHS_OWNER@$HOSTNAME:$REMOTE_WORKDIR >> $LOGDIR/create_default_wallet.log 2>&1
   print_status $? $LOGDIR/create_default_wallet.log
   printf "\t\t\tSetting execute permission - "
   $SSH $OHS_OWNER@$HOSTNAME chmod 700 $REMOTE_WORKDIR/run_orapki.sh >> $LOGDIR/create_default_wallet.log 2>&1
   print_status $? $LOGDIR/create_default_wallet.log

   printf "\t\t\tCreating Wallet - "
   $SSH $OHS_OWNER@$HOSTNAME mkdir -p $OHS_WALLETS >> $LOGDIR/create_default_wallet.log 2>&1
   $SSH $OHS_OWNER@$HOSTNAME $REMOTE_WORKDIR/run_orapki.sh wallet create -wallet $OHS_WALLETS -auto_login_only > $LOGDIR/create_default_wallet.log 2>&1
   XX=$?
   grep -q "already exists" $LOGDIR/create_default_wallet.log
   if [ $? = 0 ]
   then 
      echo "Already Exists"
   else
      print_status $XX $LOGDIR/create_default_wallet.log 2>&1
   fi

   ohsCAs=$(echo $OHS_CAS | sed "s/,/ /g")

   for cA in $ohsCAs
   do
       printf "\t\t\tCopying Certificate $cA to $HOSTNAME - "
       $SCP $cA $OHS_OWNER@$HOSTNAME:$REMOTE_WORKDIR  >> $LOGDIR/create_default_wallet.log 2>&1
       print_status $? $LOGDIR/create_default_wallet.log 2>&1

       printf "\t\t\tAdding $cA to Wallet - "
       $SSH $OHS_OWNER@$HOSTNAME  $REMOTE_WORKDIR/run_orapki.sh wallet  add -wallet $OHS_WALLETS -auto_login_only -trusted_cert -cert $REMOTE_WORKDIR/$(basename $cA) >> $LOGDIR/create_default_wallet.log 2>&1
       XX=$?

       tail -1 $LOGDIR/create_default_wallet.log | grep -q "The trusted certificate is already present" 
       if [ $? = 0 ]
       then 
          echo "Already Exists"
       else
          print_status $XX $LOGDIR/create_default_wallet.log 2>&1
       fi
   done

   ET=$(date +%s)
   print_time STEP "Created Default Wallet on $HOSTNAME" $ST $ET >> $LOGDIR/timings.log

}  

create_host_wallet()
{
   HOSTNAME=$1
   WHOST=$2
   WHOST_FILE=$3
   WHOST_PWD=$4
   TRUST=$5
   TRUST_PWS=$6

   print_msg "Creating OHS Wallet wallet_$WHOST on $HOSTNAME"
  
   ST=$(date +%s)
   printf "\n\t\t\tCopying Certificate $TRUST to $HOSTNAME - "
   echo $SCP $TRUST $OHS_OWNER@$HOSTNAME:$REMOTE_WORKDIR  > $LOGDIR/create_wallet_$WHOST.log 
   $SCP $TRUST $OHS_OWNER@$HOSTNAME:$REMOTE_WORKDIR  >> $LOGDIR/create_wallet_$WHOST.log 2>&1
   print_status $? $LOGDIR/create_wallet_$WHOST.log 2>&1
   printf "\t\t\tCopying Certificate $WHOST_FILE to $HOSTNAME - "
   echo $SCP $WHOST_FILE $OHS_OWNER@$HOSTNAME:$REMOTE_WORKDIR  >> $LOGDIR/create_wallet_$WHOST.log 
   $SCP $WHOST_FILE $OHS_OWNER@$HOSTNAME:$REMOTE_WORKDIR  >> $LOGDIR/create_wallet_$WHOST.log 2>&1
   print_status $? $LOGDIR/create_wallet_$WHOST.log 2>&1

   printf "\t\t\tCreating Wallet - "
   $SSH $OHS_OWNER@$HOSTNAME  $REMOTE_WORKDIR/run_orapki.sh wallet create -wallet $OHS_WALLETS/wallet_$WHOST  -auto_login_only >> $LOGDIR/create_wallet_$WHOST.log 2>&1
   XX=$?
   grep -q "already exists" $LOGDIR/create_wallet_$WHOST.log
   if [ $? = 0 ]
   then 
      echo "Already Exists"
   else
      print_status $XX $LOGDIR/create_wallet_$WHOST.log 2>&1
   fi

    printf "\t\t\tAdding $(basename $WHOST_FILE) to Wallet - "
    $SSH $OHS_OWNER@$HOSTNAME  $REMOTE_WORKDIR/run_orapki.sh wallet import_pkcs12 -wallet $OHS_WALLETS/wallet_$WHOST -auto_login_only -pkcs12file $REMOTE_WORKDIR/$(basename $WHOST_FILE)  -pkcs12pwd $WHOST_PWD >> $LOGDIR/create_wallet_$WHOST.log 2>&1
   print_status $? $LOGDIR/create_wallet_$WHOST.log 2>&1

   ET=$(date +%s)
   print_time STEP "Created OHS Wallet wallet_$WHOST on $HOSTNAME" $ST $ET >> $LOGDIR/timings.log

}  
#
# Create OHS Health-check
#
create_hc()
{
   HOSTNAME=$1
   OHS_NAME=$2

   print_msg "Create Health Check on $HOSTNAME"
  
   ST=$(date +%s)

   echo $SCP $TEMPLATE_DIR/health-check.html ${OHS_OWNER}@$HOSTNAME:$OHS_DOMAIN/config/fmwconfig/components/OHS/$OHS_NAME/htdocs > $HOSTLOG/create_hc.log 2>&1
   $SCP $TEMPLATE_DIR/health-check.html ${OHS_OWNER}@$HOSTNAME:$OHS_DOMAIN/config/fmwconfig/components/OHS/$OHS_NAME/htdocs >> $HOSTLOG/create_hc.log 2>&1

   print_status $? $HOSTLOG/create_hc.log

   ET=$(date +%s)
   print_time STEP "Create Health check on $HOSTNAME" $ST $ET >> $LOGDIR/timings.log

}  
#
# Start Node Manager
#
start_nm_ohs()
{
   HOSTNAME=$1
   print_msg "Start Node Manager on $HOSTNAME"
  
   ST=$(date +%s)

   $SSH ${OHS_OWNER}@$HOSTNAME "nohup $OHS_DOMAIN/bin/startNodeManager.sh >$OHS_DOMAIN/nodemanager/nohup.out 2>&1 &" >> $HOSTLOG/start_nm.log 2>&1

   print_status $? $HOSTLOG/start_nm.log

   ET=$(date +%s)
   print_time STEP "Start Node Manager on $HOSTNAME" $ST $ET >> $LOGDIR/timings.log

}  


#
# Stop Node Manager
#
stop_nm_ohs()
{
   HOSTNAME=$1
   print_msg "Stop Node Manager on $HOSTNAME"
  
   ST=$(date +%s)

   $SSH ${OHS_OWNER}@$HOSTNAME "$OHS_DOMAIN/bin/stopNodeManager.sh " 

   ET=$(date +%s)
}  

#
# Start the Oracle HTTP Server Instance
#
start_ohs()
{
   HOSTNAME=$1
   OHS_NAME=$2
   print_msg "Start Oracle HTTP Server on $HOSTNAME"
  
   ST=$(date +%s)

   echo $NM_ADMIN_PWD >$WORKDIR/nm.pwd
   $SCP $WORKDIR/nm.pwd ${OHS_OWNER}@$HOSTNAME:.nm.pwd > $HOSTLOG/start_ohs.log 2>&1

   $SSH ${OHS_OWNER}@$HOSTNAME "$OHS_DOMAIN/bin/startComponent.sh $OHS_NAME storeUserConfig < \$HOME/.nm.pwd" >> $HOSTLOG/start_ohs.log 2>&1
   $SSH ${OHS_OWNER}@$HOSTNAME "rm \$HOME/.nm.pwd" >> $HOSTLOG/start_ohs.log 2>&1

   print_status $? $HOSTLOG/start_ohs.log

   ET=$(date +%s)
   print_time STEP "Start Oracle Http Server on $HOSTNAME" $ST $ET >> $LOGDIR/timings.log

}  

#
# Stop the Oracle HTTP Server Instance
#
stop_ohs()
{
   HOSTNAME=$1
   OHS_NAME=$2
   print_msg "Stop Oracle HTTP Server on $HOSTNAME"
  
   $SSH ${OHS_OWNER}@$HOSTNAME "$OHS_DOMAIN/bin/stopComponent.sh $OHS_NAME " 

}  
#
# Deploy WebGate in OHS Instance
#
deploy_webgate()
{
   HOSTNAME=$1
   OHS_NAME=$2
   print_msg "Deploy WebGate on $HOSTNAME"

   ST=$(date +%s)

   echo $SSH ${OHS_OWNER}@$HOSTNAME "$OHS_ORACLE_HOME/webgate/ohs/tools/deployWebGate/deployWebGateInstance.sh -w $OHS_DOMAIN/config/fmwconfig/components/OHS/$OHS_NAME -oh $OHS_ORACLE_HOME"  > $HOSTLOG/deploy_webgate.log 2>&1
   $SSH ${OHS_OWNER}@$HOSTNAME "$OHS_ORACLE_HOME/webgate/ohs/tools/deployWebGate/deployWebGateInstance.sh -w $OHS_DOMAIN/config/fmwconfig/components/OHS/$OHS_NAME -oh $OHS_ORACLE_HOME"  >> $HOSTLOG/deploy_webgate.log 2>&1

   print_status $? $HOSTLOG/deploy_webgate.log

   ET=$(date +%s)
   print_time STEP "Deploy WebGate on $HOSTNAME" $ST $ET >> $LOGDIR/timings.log
}

#
# Enable WebGate
#
install_webgate()
{
   HOSTNAME=$1
   OHS_NAME=$2
   print_msg "Install WebGate on $HOSTNAME"

   ST=$(date +%s)

   echo $SSH ${OHS_OWNER}@$HOSTNAME "export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$OHS_ORACLE_HOME/lib;$OHS_ORACLE_HOME/webgate/ohs/tools/setup/InstallTools/EditHttpConf -w $OHS_DOMAIN/config/fmwconfig/components/OHS/$OHS_NAME -oh $OHS_ORACLE_HOME"  > $HOSTLOG/install_webgate.log 2>&1
   $SSH ${OHS_OWNER}@$HOSTNAME "export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$OHS_ORACLE_HOME/lib;$OHS_ORACLE_HOME/webgate/ohs/tools/setup/InstallTools/EditHttpConf -w $OHS_DOMAIN/config/fmwconfig/components/OHS/$OHS_NAME -oh $OHS_ORACLE_HOME"  > $HOSTLOG/install_webgate.log 2>&1

   print_status $? $HOSTLOG/install_webgate.log

   ET=$(date +%s)
   print_time STEP "Install WebGate on $HOSTNAME" $ST $ET >> $LOGDIR/timings.log
}

#
# Update WebGate to allow OAP Rest calls
#
update_webgate()
{
   HOSTNAME=$1
   OHS_NAME=$2
   print_msg "Enable OAM Rest OAP Calls on $HOSTNAME"

   ST=$(date +%s)


   cp $TEMPLATE_DIR/webgate_rest.conf $WORKDIR/webgate_rest.conf> $HOSTLOG/update_wg.log 2>&1
   if [ ! "$OHS_LBR_NETWORK" = "" ]
   then
      echo "" >> $WORKDIR/webgate_rest.conf
      echo "<LocationMatch \"/health-check.html\">" >> $WORKDIR/webgate_rest.conf
      echo "    require all granted" >> $WORKDIR/webgate_rest.conf
      echo  "</LocationMatch>"  >> $WORKDIR/webgate_rest.conf
   fi

   $SCP $WORKDIR/webgate_rest.conf ${OHS_OWNER}@$HOSTNAME:. > $HOSTLOG/update_wg.log 2>&1
   $SSH ${OHS_OWNER}@$HOSTNAME "cat \$HOME/webgate_rest.conf >>  $OHS_DOMAIN/config/fmwconfig/components/OHS/$OHS_NAME/webgate.conf"  > $HOSTLOG/enable_rest.log 2>&1

   print_status $? $HOSTLOG/enable_rest.log

   ET=$(date +%s)
   print_time STEP "Enable OAM Rest OAP calls on $HOSTNAME" $ST $ET >> $LOGDIR/timings.log
}

#
# Copy the Load Balancer certificate to the WebGate deployement
#
copy_lbr_cert()
{
   HOSTNAME=$1
   OHS_NAME=$2
   print_msg "Copy $OAM_LOGIN_LBR_HOST Certificate to WebGate on $HOSTNAME"

   ST=$(date +%s)

   printf "\n\t\t\tObtain Certificate - "
   get_lbr_certificate $OAM_LOGIN_LBR_HOST $OAM_LOGIN_LBR_PORT >$HOSTLOG/copy_cert.log 2>&1
   print_status $? $HOSTLOG/copy_cert.log

   printf "\t\t\tCopy Certificate - "
   $SCP $WORKDIR/${LBRHOST}.pem ${OHS_OWNER}@$HOSTNAME:$OHS_DOMAIN/config/fmwconfig/components/OHS/$OHS_NAME/webgate/config/cacert.pem >>$HOSTLOG/copy_cert.log 2>&1
   print_status $? $HOSTLOG/copy_cert.log

   ET=$(date +%s)
   print_time STEP "Copy $OAM_LOGIN_LBR_HOST Certificate to WebGate on $HOSTNAME" $ST $ET >> $LOGDIR/timings.log
}
copy_ca_cert()
{
   HOSTNAME=$1
   OHS_NAME=$2
   print_msg "Copy Certificate Authorities to WebGate on $HOSTNAME" 

   ST=$(date +%s)

   certs=$(echo $OHS_CAS | sed 's/,/ /g')

   printf "\n\t\t\tCreating cacert.pem  - "
   cat $certs > $WORKDIR/cacert.pem
   print_status $?

   printf "\t\t\tCopy Trust Store - "
   $SCP $WORKDIR/cacert.pem ${OHS_OWNER}@$HOSTNAME:$OHS_DOMAIN/config/fmwconfig/components/OHS/$OHS_NAME/webgate/config/cacert.pem >>$HOSTLOG/copy_ca.log 2>&1
   print_status $? $HOSTLOG/copy_ca.log
   printf "\t\t\tSetting Permissions - "
   $SSH  ${OHS_OWNER}@$HOSTNAME chmod 600 $OHS_DOMAIN/config/fmwconfig/components/OHS/$OHS_NAME/webgate/config/cacert.pem >>$HOSTLOG/copy_ca.log 2>&1
   print_status $? $HOSTLOG/copy_ca.log

   ET=$(date +%s)
   print_time STEP "Copy Certificate Authorites to WebGate on $HOSTNAME" $ST $ET >> $LOGDIR/timings.log
}

update_ohs_route()
{
   print_msg "Change OHS Routing"
   echo

   ST=$(date +%s)

   FILES=$(ls -1 $WORKDIR/*vh.conf)
   K8NODES=$(get_k8nodes)


   for file in $FILES
   do
    printf "\t\t\tProcessing File:$file - "
    PORTS=$(grep WebLogicCluster $file | sed "s/WebLogicCluster//" | awk 'BEGIN { RS = "," } { print $0 }' | cut -f2 -d: | sort | uniq)
    for PORT in $PORTS
    do
      ROUTE="WebLogicCluster "
      for NODE in $K8NODES
      do
        ROUTE="$ROUTE,$NODE:$PORT"
      done
      DIRECTIVE=$(echo $ROUTE | sed 's/,//')
      sed -i "/:$PORT/c\        $DIRECTIVE" $file >> $LOGDIR/update_ohs_route.log 2>&1
    done
    print_status $? $LOGDIR/update_ohs_route.log
   done

   ET=$(date +%s)
   print_time STEP "Change OHS Routing" $ST $ET >> $LOGDIR/timings.log
}


update_ohs_hostname()
{
   print_msg "Change OHS Virtual Host Name "
   ST=$(date +%s)
   OLD_HOSTNAME=$( grep "<VirtualHost" $WORKDIR/*.conf | cut -f2 -d: | awk '{ print $2 }' | head -1 )
   mkdir $WORKDIR/$OHS_HOST1  2>/dev/null
   cp $WORKDIR/*.conf $WORKDIR/$OHS_HOST1
   if [ ! "$OLD_HOSTNAME" = "$OHS_HOST1" ]
   then
      printf "\n\t\t\tChanging $OLD_HOSTNAME to $OHS_HOST1 - "
      sed -i "s/$OLD_HOSTNAME/$OHS_HOST1/" $WORKDIR/$OHS_HOST1/*.conf > $LOGDIR/update_vh.log 2>&1
      print_status $? $LOGDIR/update_vh.log
   fi

   if [ ! "$OHS_HOST2" = "" ]
   then
      mkdir $WORKDIR/$OHS_HOST2  2>/dev/null
      cp $WORKDIR/*.conf $WORKDIR/$OHS_HOST2
      printf "\n\t\t\tChanging $OLD_HOSTNAME to $OHS_HOST2 - "
      sed -i "s/$OLD_HOSTNAME/$OHS_HOST2/" $WORKDIR/$OHS_HOST2/*.conf >> $LOGDIR/update_vh.log 2>&1
      print_status $? $LOGDIR/update_vh.log
   fi
   ET=$(date +%s)
   print_time STEP "Change OHS Virtual HostName" $ST $ET >> $LOGDIR/timings.log
}

  
copy_ohs_dr_config()
{
   print_msg "Copy OHS Config"
   ST=$(date +%s)
   
   printf "\n\t\t\tCopy OHS Config to $OHS_HOST1 - "
   $SCP $WORKDIR/$OHS_HOST1/*vh.conf $OHS_HOST1:$OHS_DOMAIN/config/fmwconfig/components/OHS/$OHS1_NAME/moduleconf/ > $LOGDIR/copy_ohs_config.log 2>&1
   print_status $? $LOGDIR/copy_ohs_config.log

   if [ ! "$OHS_HOST2" = "" ]
   then
      printf "\t\t\tCopy OHS Config to $OHS_HOST2 - "
      $SCP $WORKDIR/$OHS_HOST2/*vh.conf $OHS_HOST2:$OHS_DOMAIN/config/fmwconfig/components/OHS/$OHS2_NAME/moduleconf/ > $LOGDIR/copy_ohs_config.log 2>&1
      print_status $? $LOGDIR/copy_ohs_config.log
   fi
   ET=$(date +%s)
   print_time STEP "Change OHS Routing" $ST $ET >> $LOGDIR/timings.log
}

# Add location directives to OHS Config Files
#
create_location()
{
  locfile=$1
  nodes=$2
  ohs_path=$3
  ssl_enabled=$4

  last_file=""
  while IFS= read -r LOCATIONS
  do
     file=$(echo $LOCATIONS | cut -f1 -d:)
     location=$(echo $LOCATIONS | cut -f2 -d:)
     port=$(echo $LOCATIONS | cut -f3 -d:)
     ssl=$(echo $LOCATIONS | cut -f4 -d:)

     conf_file=${file}_vh.conf

     case $file in
       iadadmin)
        protocol=$OAM_ADMIN_LBR_PROTOCOL
        ;;
       login)
        protocol=$OAM_LOGIN_LBR_PROTOCOL
        ;;
       oim)
        protocol=$OIG_LBR_PROTOCOL
        ;;
       igdinternal)
        protocol=$OIG_LBR_INT_PROTOCOL
        ;;
       igdadmin)
        protocol=$OIG_ADMIN_LBR_PROTOCOL
        ;;
       *)
         echo "FILE:$file"
        ;;
     esac

     sed -i "/<\/VirtualHost>/d" $ohs_path/$conf_file

     if [ ! "$last_file" = "$file" ]
     then
        if [ ! "$last_file" = "" ]
        then 
	   echo "Success"
        fi
        printf "\t\t\tAdding Location Directives to $conf_file - " 
        last_file=$file
     fi
     printf "\n\t\t\tAdding Location $location to $conf_file - " >> $LOGDIR/$file.log
     grep -q "$location>" $ohs_path/$conf_file
     if [ $? -eq 1 ]
     then
       printf "\n    <Location $location>" >> $ohs_path/$conf_file
       printf "\n        WLSRequest ON" >> $ohs_path/$conf_file

       if [ "$file" = "login" ]
       then
          printf "\n        WLCookieName OAMJSESSIONID" >> $ohs_path/$conf_file
          echo $location | grep -q well-known
          if [ $? -eq 0 ]
          then
              printf "\n        PathTrim /.well-known" >> $ohs_path/$conf_file
              printf "\n        PathPrepend /oauth2/rest" >> $ohs_path/$conf_file
          fi

       elif [ "$file" = "oim" ]
       then
          printf "\n        WLCookieName oimjsessionid" >> $ohs_path/$conf_file
       elif [ "$file" = "igdinternal" ]
       then
          if [ "$location" = "/spmlws" ] 
          then
            printf "\n        PathTrim /weblogic" >> $ohs_path/$conf_file
          fi
       fi

       if [ "$protocol" = "https" ] && [ "$ssl_enabled" = "false" ]
       then
          printf "\n        WLProxySSL ON" >> $ohs_path/$conf_file
          printf "\n        WLProxySSLPassThrough ON" >> $ohs_path/$conf_file
       fi

       if [ "$port" = "OIG_ADMIN_PORT" ]
       then
	  printf "\n        WebLogicHost $OIG_ADMIN_HOST">> $ohs_path/$conf_file
	  printf "\n        WebLogicPort $(($port))">> $ohs_path/$conf_file

       elif [ "$port" = "OIG_ADMIN_ADMIN_PORT" ]
       then
	  printf "\n        WebLogicHost $OAM_ADMIN_HOST">> $ohs_path/$conf_file
	  printf "\n        WebLogicPort $(($port))">> $ohs_path/$conf_file
     
       elif [ "$port" = "OAM_ADMIN_ADMIN_PORT" ]
       then
	  printf "\n        WebLogicHost $OAM_ADMIN_HOST">> $ohs_path/$conf_file
	  printf "\n        WebLogicPort $(($port))">> $ohs_path/$conf_file

       elif [ "$port" = "OAM_ADMIN_PORT" ]
       then
	  printf "\n        WebLogicHost $OAM_ADMIN_HOST">> $ohs_path/$conf_file
	  printf "\n        WebLogicPort $(($port))">> $ohs_path/$conf_file
       else
          cluster_cmd="        WebLogicCluster " >> $ohs_path/$conf_file
          node_count=0
          for node in $nodes
          do
             if [ $node_count -eq 0 ]
             then
                cluster_cmd=$cluster_cmd"$node:$(($port))"
             else
                cluster_cmd=$cluster_cmd",$node:$(($port))"
             fi
             ((node_count++))
          done
          printf "\n$cluster_cmd" >> $ohs_path/$conf_file
       fi

       printf "\n    </Location>\n" >> $ohs_path/$conf_file
       echo "Success" >>$LOGDIR/$file.log
    else
       echo "Already Exists" >>$LOGDIR/$file.log
    fi

    printf "\n</VirtualHost>\n" >> $ohs_path/$conf_file
  
  done < $locfile
  echo "Success"
}
