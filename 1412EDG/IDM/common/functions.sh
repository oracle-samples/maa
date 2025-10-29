#!/bin/bash
# Copyright (c) 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# This is an example of common functions and procedures used by the provisioning and deletion scripts
# 
#
# Dependencies: 
#               
#
# Usage: invoked as needed not directly
#
# Common Environment Variables
#

export SAMPLES_DIR=`echo $SAMPLES_REP | awk -F  "/" '{print $NF}' | sed 's/.git.*//'`

SSH="ssh -o StrictHostKeyChecking=no"
SCP="scp -o StrictHostKeyChecking=no"


# Create local Directories
#
create_local_workdir()
{
    ST=$(date +%s)
    if  [ ! -d $WORKDIR ]
    then
        printf "\nCreating Working Directory : $WORKDIR - "
        mkdir -p $WORKDIR
        print_status $?
    else
        printf "Using Working Directory    : $WORKDIR\n"
    fi
    ET=$(date +%s)
}

create_logdir()
{
    ST=$(date +%s)
    if  [ ! -d $LOGDIR ]
    then
        printf "Creating Log Directory     : $LOGDIR  - "
        mkdir -p $LOGDIR
        print_status $?
    else
        printf "Using Log Directory        : $LOGDIR\n\n"
    fi


    ET=$(date +%s)
    print_time STEP "Create logs Directory" $ST $ET >> $LOGDIR/timings.log
}


check_connectivity()
{
   host=$1
   port=$2

   printf "\tChecking $host  Port $port : "
   nc -zvw 1 $host $port > /dev/null 2>&1
   if [ $? -gt 0 ]
   then 
     echo "Failed"
     return 1
   else
     echo "Success"
     return 0
   fi
}

check_remote_connectivity()
{
    sourceHost=$1
    sourceUser=$2
    destHost=$3
    port=$4

    printf "Checking $destHost Port $port is Open from $sourceHost - "
    RESULT=$($SSH $sourceUser@$sourceHost "nc -zv -w 1 $destHost $port |& tail -1 | cut -f2 -d: | sed 's/ //'")
    if [ "$RESULT" = "TIMEOUT." ]
    then
       echo "Failed."
       return 1
    else
       echo "Success"
       return 0
    fi
}

check_ssh()
{
   hostlist=$1
   user=$2

   fail=0
   for host in $hostlist
   do 
      printf "\tChecking $host : "
      $SSH $user@$host date> /dev/null 2>&1
      if [ $? -gt 0 ]
      then 
        echo "Failed"
	fail=$((fail+1)) 
      else
        echo "Success"
      fi
   done
   return $fail
}

check_fs_mounted()
{
    hostname=$1
    user=$2
    fs=$3

    ORACLE_BASE=$(dirname $fs)
    echo -n "Checking $ORACLE_BASE is mounted on $hostname : "
    $SSH $user@$hostname df $ORACLE_BASE >/dev/null 2>&1
    if [ $? -eq 0 ]
    then 
      echo "Success"
    else
      echo "Failed"
      FAIL=$((FAIL+1))
    fi
}

check_oracle_base()
{
    hostname=$1
    user=$2
    fs=$3

    ORACLE_BASE=$(dirname $fs)
    echo -n "Checking $ORACLE_BASE is writeable on $hostname : "
    
    $SSH $user@$hostname touch $ORACLE_BASE/xx >/dev/null 2>&1
    if [ $? -eq 0 ]
    then 
      echo "Success"
      $SSH $user@$hostname rm $ORACLE_BASE/xx >/dev/null 2>&1
    else
      echo "Failed"
      FAIL=$((FAIL+1))
    fi
}

create_remote_workdir()
{
    host=$1
    user=$2
    ST=$(date +%s)
    print_msg "Creating Remote Work Directory : $REMOTE_WORKDIR on $(echo $host | cut -f1 -d.)" 
    $SSH $user@$host "mkdir $REMOTE_WORKDIR"> $LOGDIR/create_workdir.log 2>&1
    echo "Success"

    ET=$(date +%s)
    print_time STEP "Create remote working Directory" $ST $ET >> $LOGDIR/timings.log
}

copy_rsp()
{
    host=$1
    user=$2
    rspfile=$3
    pwfile=$4
    ST=$(date +%s)
    print_msg "Copying response files to $host"
    $SSH $user@$host "mkdir $REMOTE_WORKDIR/responsefile"> $HOSTLOG/copy_rsp.log 2>&1
    $SCP $3  $user@$host:$REMOTE_WORKDIR/responsefile/idm.rsp >> $HOSTLOG/copy_rsp.log 2>&1
    $SCP $4  $user@$host:$REMOTE_WORKDIR/responsefile/.idmpwds >> $HOSTLOG/copy_rsp.log 2>&1
    print_status $? $HOSTLOG/copy_rsp.log

    ET=$(date +%s)
    print_time STEP "Copy Response file" $ST $ET >> $LOGDIR/timings.log
}

install_jdk()
{
    host=$1
    user=$2
    oraHome=$3
    ST=$(date +%s)
    print_msg "Installing JDK on $host"
    printf "\n\t\t\tCreating Install $host Script - "
    cp $TEMPLATE_DIR/../general/install_jdk.sh $WORKDIR
    file=$WORKDIR/install_jdk.sh
    ORACLE_BASE=$(dirname $oraHome)
    update_variable "<SHIPHOME_DIR>" $GEN_SHIPHOME_DIR $file
    update_variable "<GEN_JDK_VER>" $GEN_JDK_VER $file
    update_variable "<ORACLE_BASE>" $ORACLE_BASE $file
    print_status $?

    printf "\t\t\tCopying Install Script - "
    echo $SCP $file $user@$host:$REMOTE_WORKDIR > $HOSTLOG/install_jdk.log 2>&1
    $SCP $file $user@$host:$REMOTE_WORKDIR > $HOSTLOG/install_jdk.log 2>&1
    print_status $? $HOSTLOG/install_jdk.log

    printf "\t\t\tSetting Permissions - "
    $SSH  $user@$host chmod 700 $REMOTE_WORKDIR/*.sh >> $HOSTLOG/install_jdk.log 2>&1
    print_status $? $HOSTLOG/install_jdk.log

    printf "\t\t\tInstalling JDK Script - "
    $SSH $user@$host $REMOTE_WORKDIR/install_jdk.sh >> $HOSTLOG/install_jdk.log 2>&1
    XX=$?
    grep -q "JDK ALREADY INSTALLED" $HOSTLOG/install_jdk.log
    if [ $? -eq 0 ]
    then
      echo "Already Installed."
    else
      print_status $XX $HOSTLOG/install_jdk.log
    fi

    ET=$(date +%s)

    print_time STEP "Installing JDK on $host" $ST $ET >> $LOGDIR/timings.log

}

apply_patch()
{
    host=$1
    user=$2
    prod=$3
    ST=$(date +%s)
    print_msg "Applying Bundle Patch $GEN_PATCH to $host"
    
    case $prod in
      oud) 
           ORACLE_HOME=$OUD_ORACLE_HOME
           ;;
      oam) 
           ORACLE_HOME=$OAM_ORACLE_HOME
           ;;
      oig) 
           ORACLE_HOME=$OIG_ORACLE_HOME
           ;;
     esac

    
     $SSH $user@$host ls  $ORACLE_HOME/idm_spb_info.txt > /dev/null 2>&1
    if [ $? -gt 0 ]
    then
       printf "\n\t\t\tExtracting Patch to /tmp "
       $SSH $user@$host unzip -o $GEN_PATCH -d /tmp > $LOGDIR/$host/extract_patch.log
       print_status $? $LOGDIR/$host/extract_patch.log
       PATCH_DIR=$(head -2 $LOGDIR/$host/extract_patch.log | tail -1 | cut -f2 -d: | sed 's/ //g'i | cut -f 1-3 -d/)

       printf "\t\t\tApplying Patch prestop - "
       echo $SSH $user@$host $PATCH_DIR/tools/spbat/generic/SPBAT/spbat.sh -type $prod -phase downtime -mw_home $ORACLE_HOME -spb_download_dir $PATCH_DIR -log_dir $REMOTE_WORKDIR> $LOGDIR/$host/prestop_patch.log
       $SSH $user@$host $PATCH_DIR/tools/spbat/generic/SPBAT/spbat.sh -type $prod -phase prestop -mw_home $ORACLE_HOME >> $LOGDIR/$host/prestop_patch.log 2>&1
       print_status $? $LOGDIR/$host/prestop_patch.log
       printf "\t\t\tApplying Patch  $PATCH_DIR - "

       echo $SSH $user@$host $PATCH_DIR/tools/spbat/generic/SPBAT/spbat.sh -type $prod -phase downtime -mw_home $ORACLE_HOME -spb_download_dir $GEN_PATCHDIR -log_dir $REMOTE_WORKDIR> $LOGDIR/$host/apply_patch.log
       $SSH $user@$host $PATCH_DIR/tools/spbat/generic/SPBAT/spbat.sh -type $prod -phase downtime -mw_home $ORACLE_HOME >> $LOGDIR/$host/apply_patch.log 2>&1
       print_status $? $LOGDIR/$host/apply_patch.log
    else
       echo "Already Applied."
    fi

    ET=$(date +%s)
    print_time STEP "Applying Patch $PATCH to $host " $ST $ET >> $LOGDIR/timings.log
}

create_opatch()
{
    host=$1
    user=$2
    prod=$3
    ST=$(date +%s)
    print_msg "Creating Patch script on $host"

    case $prod in
      oud)
           ORACLE_HOME=$OUD_ORACLE_HOME
           ;;
      oam)
           ORACLE_HOME=$OAM_ORACLE_HOME
           ;;
      oig)
           ORACLE_HOME=$OIG_ORACLE_HOME
           ;;
     esac

   printf "\n\t\t\tCreating Script -"
   cp $TEMPLATE_DIR/../general/run_opatch.sh $WORKDIR > $LOGDIR/opatch_create.log 2>&1
   file=$WORKDIR/run_opatch.sh
   ORACLE_BASE=$(dirname $OUD_ORACLE_HOME)
   JAVA_HOME=$ORACLE_BASE/jdk

   update_variable "<JAVA_HOME>" $ORACLE_BASE/jdk $file
   update_variable "<ORACLE_HOME>" $ORACLE_HOME  $file
   print_status $? $LOGDIR/opatch_create.log

   printf "\t\t\tCopy script to $host - "
   $SCP $file $user@$host:$REMOTE_WORKDIR >> $LOGDIR/opatch_create.log 2>&1
   print_status $? $LOGDIR/opatch_create.log


   printf "\t\t\tSetting execute permisison - "
   $SSH $user@$host chmod 700 $REMOTE_WORKDIR/run_opatch.sh >> $LOGDIR/opatch_create.log 2>&1
   print_status $? $LOGDIR/opatch_create.log

   ET=$(date +%s)
   print_time STEP "Create patch script on host $host" $ST $ET >> $LOGDIR/timings.log
}

apply_oneoff_patch()
{
    host=$1
    user=$2
    prod=$3
    patch=$4
    ST=$(date +%s)
    print_msg "Applying Patch $patch to $host"
    
    case $prod in
      oud) 
           ORACLE_HOME=$OUD_ORACLE_HOME
           ;;
      oam) 
           ORACLE_HOME=$OAM_ORACLE_HOME
           ;;
      oig) 
           ORACLE_HOME=$OIG_ORACLE_HOME
           ;;
     esac

     printf "\n\t\t\tExtracting Patch to /tmp "


     $SSH $user@$host unzip -o $patch -d /tmp > $LOGDIR/$host/extract_patch.log
     print_status $? $LOGDIR/$host/extract_patch.log
     PATCH_DIR=$(basename $patch | cut -f1 -d_ | sed 's/p//')
     printf "\t\t\tApplying Patch $PATCH_DIR - "
     echo $SSH $user@$host $REMOTE_WORKDIR/run_opatch.sh $PATCH _DIR> $LOGDIR/$host/apply_patch_$PATCH_DIR.log
     $SSH $user@$host $REMOTE_WORKDIR/run_opatch.sh $PATCH_DIR >> $LOGDIR/$host/apply_patch_$PATCH_DIR.log 2>&1
     egrep -iq "OPatch Succeeded|have already installed same patch" $LOGDIR/$host/apply_patch_$PATCH_DIR.log
     print_status $? $LOGDIR/$host/apply_patch_$PATCH_DIR.log

    ET=$(date +%s)
    print_time STEP "Applying Patch $PATCH to $host " $ST $ET >> $LOGDIR/timings.log
}
copy_install_script()
{
    host=$1
    user=$2
    prod=$3
    ST=$(date +%s)
    print_msg "Copying Installation scripts to $host"
    $SCP $WORKDIR/install_$prod.sh $user@$host:$REMOTE_WORKDIR > $HOSTLOG/install_copy.log 2>&1
    $SCP $WORKDIR/install_*.rsp $user@$host:$REMOTE_WORKDIR >> $HOSTLOG/install_copy.log 2>&1
    if [ "$prod" = "oam" ]
    then
       $SCP $WORKDIR/install_infra.rsp $user@$host:$REMOTE_WORKDIR >> $HOSTLOG/install_copy.log 2>&1
    fi
    $SCP $WORKDIR/oraInst.loc $user@$host:$REMOTE_WORKDIR >> $HOSTLOG/install_copy.log 2>&1
    print_status $? $HOSTLOG/install_copy.log

    ET=$(date +%s)
    print_time STEP "Copy Install Script" $ST $ET >> $LOGDIR/timings.log
}

copy_create_scripts()
{
    host=$1
    user=$2
    ST=$(date +%s)
    print_msg "Copying Creation scripts to $host"
    $SCP -r $WORKDIR/create_scripts/* $user@$host:$REMOTE_WORKDIR > $LOGDIR/create_copy.log 2>&1
    print_status $? $LOGDIR/create_copy.log
    printf "\t\t\tSetting Permissions - "
    $SSH  $user@$host chmod 700 $REMOTE_WORKDIR/*.sh >> $LOGDIR/create_copy.log 2>&1
    print_status $? $LOGDIR/create_copy.log

    ET=$(date +%s)
    print_time STEP "Copy Creation Scripts" $ST $ET >> $LOGDIR/timings.log
}
copy_certs()
{
    host=$1
    user=$2
    storedir=$3
    certfile=$4
    trustfile=$5
    ST=$(date +%s)
    print_msg "Copying Certificates to $host"
    printf "\n\t\t\tCreating Keystores Directory - "
    $SSH  $user@$host "mkdir -p $storedir" > $LOGDIR/create_dir.log 2>&1
    grep -q "File exists" $LOGDIR/create_dir.log
    if [ $? -eq 0 ]
    then
	echo "Already Exists"
    else
	grep -q "Permission denied" $LOGDIR/create_dir.log
	if [ $? -eq 0 ]
        then
	   echo "Failed see logfile $LOGDIR/create_dir.log"
	   exit 1
	else
           echo "Success"
	fi
    fi
    printf "\t\t\tCopying $certfile - "
    $SCP $certfile $user@$host:$storedir > $LOGDIR/copy_certs.log 2>&1
    print_status $? $LOGDIR/copy_certs.log
    printf "\t\t\tCopying $trustfile - "
    $SCP $trustfile $user@$host:$storedir >> $LOGDIR/copy_certs.log 2>&1
    print_status $? $LOGDIR/copy_certs.log
    ET=$(date +%s)
    print_time STEP "Copy Install Script" $ST $ET >> $LOGDIR/timings.log
}

run_install()
{
    host=$1
    user=$2
    prod=$3
    hostsn=$(echo $host | cut -f1 -d.)
    ST=$(date +%s)
    print_msg "Installing $prod on $host"
    printf "\n\t\t\tSetting File Execute Permission - "
    $SSH $user@$host "chmod 700 $REMOTE_WORKDIR/install_$prod.sh"> $HOSTLOG/install_sw.log 2>&1
    print_status $? $HOSTLOG/install_sw.log

    printf "\t\t\tInstalling Software - "
    $SSH $user@$host $REMOTE_WORKDIR/install_$prod.sh> $HOSTLOG/install_sw.log 2>&1
   if [ "$prod" = "oig" ]
   then
      grep -q "OIG ALREADY INSTALLED" $HOSTLOG/install_sw.log
       if [ $? -eq 0 ]
       then
          echo "Already Installed"
       else
         grep -q "OIG SUCCESSFULLY INSTALLED" $HOSTLOG/install_sw.log
         if [ $? -eq 0 ]
         then
            echo "Success"
         else
            print_status 1 $HOSTLOG/install_sw.log
         fi
      fi

   elif [ "$prod" = "oam" ]
   then
      grep -q "OAM ALREADY INSTALLED" $HOSTLOG/install_sw.log
       if [ $? -eq 0 ]
       then
          echo "Already Installed"
       else
         grep -q "OAM SUCCESSFULLY INSTALLED" $HOSTLOG/install_sw.log
         if [ $? -eq 0 ]
         then
            echo "Success"
         else
            print_status 1 $HOSTLOG/install_sw.log
         fi
      fi

   elif [ "$prod" = "oudsm" ]
   then
      grep -q "OUDSM ALREADY INSTALLED" $HOSTLOG/install_sw.log
       if [ $? -eq 0 ]
       then
          echo "Already Installed"
       else
         grep -q "OUDSM SUCCESSFULLY INSTALLED" $HOSTLOG/install_sw.log
         if [ $? -eq 0 ]
         then
            echo "Success"
         else
            print_status 1 $HOSTLOG/install_sw.log
         fi
      fi
   elif [ "$prod" = "oud" ]
   then
      grep -q "OUD ALREADY INSTALLED" $HOSTLOG/install_sw.log
      if [ $? -eq 0 ]
      then
         echo "Already Installed"
      else
         grep -q "OUD SUCCESSFULLY INSTALLED" $HOSTLOG/install_sw.log
         if [ $? -eq 0 ]
         then
            echo "Success"
         else
            print_status 1 $HOSTLOG/install_sw.log
         fi
      fi
   elif [ "$prod" = "ohs" ]
   then
      grep -q "OHS ALREADY INSTALLED" $HOSTLOG/install_sw.log
       if [ $? -eq 0 ]
       then
          echo "Already Installed"
       else
         grep -q "OHS SUCCESSFULLY INSTALLED" $HOSTLOG/install_sw.log
         if [ $? -eq 0 ]
         then
            echo "Success"
         else
            print_status 1 $HOSTLOG/install_sw.log
         fi
      fi
    fi
    ET=$(date +%s)
    print_time STEP "Install OUD" $ST $ET >> $LOGDIR/timings.log
}


copy_template()
{
   file=$1
   dest=$2
   cp $file $dest
   if [ $? -gt 0 ]
   then
      echo "Failed to Copy template $file to $dest"
      exit 1
   fi
}
   
###########################

# Execute a command on remote host
#
run_command()
{
   hostname=$1
   user=$2
   command=$3
  
   $SSH $USER@$HOST $command
}



# Simple Validation functions
#
function check_yes()
{
     input=$1
     if [ "$input" == "y" ]
     then
         return 0
     elif [ "$input" = "Y" ]
     then
         return 0
     else
         return 1
     fi
}

# Encode/Decode Passwords
#
function encode_pwd()
{
    password=$1

    encoded_pwd=`echo -n $password | base64`

    echo $encoded_pwd
}
 
function decode_pwd()
{
    password=$1

    decoded_pwd=`echo -n $password | base64 --decode`

    echo $decoded_pwd
}

#Replace a value in a file
#
replace_value()
{
     name=$1
     val=$2
     filename=$3

     newval=$(echo $val | sed 's/\//\\\//g')
     sed -i 's/'$name'=.*/'$name'='"$newval"'/' $filename 2> /dev/null
     if [ $? -gt 0 ]
     then 
        echo "Error Modifying File: $filename, variable $name to $val"
        exit 1
     fi
}

replace_value2()
{
     name=$1
     val=$2
     filename=$3

     newval=$(echo $val | sed 's/\//\\\//g')
     sed -i 's/#'$name':.*/'$name':'" $newval"'/' $filename 2> /dev/null
     if [ $? -gt 0 ]
     then
        echo "Error Modifying File: $filename variable $name to $val"
     fi
     sed -i 's/'$name':.*/'$name':'" $newval"'/' $filename 2> /dev/null
     if [ $? -gt 0 ]
     then
        echo "Error Modifying File: $filename variable $name to $val"
        exit 1
     fi

}

#Replace a value in password file
#
replace_password()
{
     name=$1
     val=$2
     filename=$3

     newval=$(echo $val | sed 's/\//\\\//g')
     sed -i 's/'$name'=.*/'$name'='"\"$newval\""'/' $filename 2> /dev/null
     if [ $? -gt 0 ]
     then 
        echo "Error Modifying File: $filename variable $name to $val"
        exit 1
     fi
}
global_replace_value()
{
     val1=$1
     val2=$2
     filename=$3

     oldval=$(echo $val1 | sed 's/\//\\\//g')
     newval=$(echo $val2 | sed 's/\//\\\//g')
     sed -i "s/$oldval/$newval/" $filename 2> /dev/null
     if [ $? -gt 0 ]
     then 
        echo "Error Modifying File: $filename changing $val1 to $val2"
        exit 1
     fi
}

update_variable()
{
     VAR=$1
     VAL=$2
     FILE=$3
     if [ "$VAL" = "" ]
     then
        echo "Unable to update variable: $VAR with $VAL"
        exit 1
     fi
     NEWVAL=$(echo $VAL | sed 's/\//\\\//g')
     sed -i "s/$VAR/$NEWVAL/g" $FILE 2> /dev/null
     if [ $? -gt 0 ]
     then 
        echo "Error Modifying File: $FILE variable $VAR to $NEWVAL"
        exit 1
     fi
}

create_sed_entry()
{
     VAR=$1
     VAL=$2
     FILE=$3
     if [ "$VAL" = "" ]
     then
        echo "Unable to update variable: $VAR with $VAL"
        exit 1
     fi
     NEWVAL=$(echo $VAL | sed 's/\//\\\//g')
     echo "s/$VAR/$NEWVAL/g" >> $FILE 2> /dev/null
     if [ $? -gt 0 ]
     then 
        echo "Error Modifying File: $FILE variable $VAR to $NEWVAL"
        exit 1
     fi
}

#
# Check variable is numeric
#

check_number()
{
   VAL=$1

   if   ! [[ "$VAL" =~  ^[0-9]+$ ]]
   then
       return 1
   else
       return 0
   fi
}

# Check Password format
# TYP=UC - Must contain a Uppercase and a Number
# TYP=UCS - Must contain a Uppercase and a Number and Symbol
# TYP=NS - Must not contain a symbol
#
function check_password ()
{
  TYP=$1
  password=$2

  LEN=$(echo ${#password})

  RETCODE=0

   if [ $LEN -lt 8 ]; then

     echo "$password is smaller than 8 characters"
     RETCODE=1
   fi

   if [[ ! $password =~ [0-9] ]]
   then
      if [ "$TYP" = "UN" ]
      then
          echo "Password must contain a number"
          RETCODE=1
      fi
   fi

   if [[ ! $password =~ [A-Z] ]] && [ "$TYP" = "NS" ]
   then
      if [ "$TYP" = "UN" ]
      then
         echo "Password must contain an Uppercase Letter"
         RETCODE=1
      fi
   fi

   if  [[  $password =~ ^[[:alnum:]]+$ ]] && [ "$TYP" = "UNS" ]
   then
     echo "Password Must contain a Special Character"
     RETCODE=1
   fi

   if [[ ! $password =~ ^[[:alnum:]]+$ ]] && [ "$TYP" = "NS" ]
   then
     echo "Password Must Not contain a Special Character"
     RETCODE=1
   fi
   return $RETCODE
}

#Get the path and name of a image file
#
function get_image_file()
{
     path=$1
     file=$2
     image=`find $path -name ${file}-*.tar`
     if [ "$image" = "" ]
     then
          echo "There is no Image file for $file in $path"
          exit 1
     else
          echo $image
     fi
}

# Create WebLogic Domain
#
create_domain ()
{
      hostname=$1
      user=$2
      SCHEMA_TYPE=$3

      ST=$(date +%s)
      print_msg "Creating $SCHEMA_TYPE Domain"
      $SSH $user@$hostname $REMOTE_WORKDIR/create_domain.sh > $LOGDIR/create_domain.log 2>&1
      print_status $? $LOGDIR/create_domain.log

      ET=$(date +%s)
      print_time STEP "Create $SCHEMA_TYPE Domain" $ST $ET >> $LOGDIR/timings.log
}

update_ssl()
{
      hostname=$1
      user=$2
      SCHEMA_TYPE=$3

      ST=$(date +%s)
      print_msg "Updating Domain SSL"
      $SSH $user@$hostname $REMOTE_WORKDIR/update_ssl.sh > $LOGDIR/update_ssl.log 2>&1
      print_status $? $LOGDIR/update_ssl.log

      ET=$(date +%s)
      print_time STEP "Update Domain SSL " $ST $ET >> $LOGDIR/timings.log
}
# RCU Functions
#
create_schemas ()
{
      hostname=$1
      user=$2
      SCHEMA_TYPE=$3

      ST=$(date +%s)
      print_msg "Creating $SCHEMA_TYPE Schemas"
      $SSH $user@$hostname $REMOTE_WORKDIR/create_schemas.sh > $LOGDIR/create_schemas.log 2>&1
      print_status $? $LOGDIR/create_schemas.log

      #if [ "$SCHEMA_TYPE" = "OIG" ] 
      #then
	  #echo "*** TEMPORARY - Create OIM User - "
          #$SSH oracle@11.0.11.84 /home/oracle/create_user.sh >  $LOGDIR/create_user.log 2>&1
          #print_status $? $LOGDIR/create_user.log
      #fi
      ET=$(date +%s)
      print_time STEP "Create Schemas" $ST $ET >> $LOGDIR/timings.log
}

drop_schemas ()
{
      hostname=$1
      user=$2

      ST=$(date +%s)
      print_msg "Drop Schemas"
      $SSH $user@$hostname $REMOTE_WORKDIR/drop_schemas.sh > $LOGDIR/drop_schemas.log 2>&1
      cat $LOGDIR/drop_schemas.log

      ET=$(date +%s)
      print_time STEP "Drop Schemas" $ST $ET >> $LOGDIR/timings.log

}

create_per_hostnm ()
{
      hostname=$1
      user=$2
      instance=$3
      DOMAIN_NAME=$4
      DOMAIN_HOME=$5
      MSERVER_HOME=$6
      CERT_ALIAS=$7

      hostsn=$(echo $hostname | cut -f1 -d.)
      ST=$(date +%s)
      print_msg "Create per host node manager on $hostname"
      echo
      cp $WORKDIR/create_scripts/nodemanager.properties $WORKDIR/create_scripts/nodemanager.properties.$hostsn
      update_variable "<NM_CERT_ALIAS>" $CERT_ALIAS $WORKDIR/create_scripts/nodemanager.properties.$hostsn
      if [ $instance -eq 1 ]
      then
	 echo "$DOMAIN_NAME=$DOMAIN_HOME" > $WORKDIR/nodemanager.domains.$hostsn
      else
	 echo "$DOMAIN_NAME=$MSERVER_HOME" > $WORKDIR/nodemanager.domains.$hostsn
      fi
      printf "\t\t\tCopying Nodemanager scripts - "
      $SCP $WORKDIR/create_scripts/start_nm.sh $user@$hostname:$REMOTE_WORKDIR > $LOGDIR/create_nm_$hostsn.log 2>&1
      $SCP $WORKDIR/create_scripts/nodemanager.properties.$hostsn $user@$hostname:$REMOTE_WORKDIR/nodemanager.properties >> $LOGDIR/create_nm_$hostsn.log 2>&1
      $SCP $WORKDIR/create_scripts/create_nm.sh $user@$hostname:$REMOTE_WORKDIR >> $LOGDIR/create_nm_$hostsn.log 2>&1
      print_status $? $LOGDIR/create_nm_$hostsn.log
      printf "\t\t\tCreating Nodemanager.domains file - "
      $SCP $WORKDIR/nodemanager.domains.$hostsn $user@$hostname:$REMOTE_WORKDIR/nodemanager.domains >> $LOGDIR/create_nm_$hostsn.log 2>&1
      print_status $? $LOGDIR/create_nm_$hostsn.log
      printf "\t\t\tUpdating Permissions - "
      $SSH  $user@$hostname chmod 700 $REMOTE_WORKDIR/*.sh >> $LOGDIR/create_nm_$hostsn.log 2>&1
      print_status $? $LOGDIR/create_nm_$hostsn.log

      printf "\t\t\tCreating Node Manager - "
      $SSH $user@$hostname $REMOTE_WORKDIR/create_nm.sh >> $LOGDIR/create_nm_$hostsn.log 2>&1
      if [ $? -eq 0 ]
      then
         grep -q "Permission denied" $LOGDIR/create_nm_$hostsn.log
         if [ $? -eq 0 ]
         then
	     echo "Failed see logfile $LOGDIR/create_nm_$hostsn.log"
             exit 1
	 else
	     echo "Success"
	 fi
      else
         print_status $? $LOGDIR/create_nm_$hostsn.log
      fi

      ET=$(date +%s)
      print_time STEP "Create per host node manager on $hostname" $ST $ET >> $LOGDIR/timings.log

}
stop_nm()
{
      hostname=$1
      user=$2
      nm_home=$3

      hostsn=$(echo $hostname | cut -f1 -d.)
      ST=$(date +%s)
      print_msg "Stop Node Manager on $hostsn"
      $SSH $user@$hostname $nm_home/stopNodeManager.sh >> $LOGDIR/stop_nm_$hostsn.log 2>&1
      grep -q "Could not locate a NodeManager process" $LOGDIR/stop_nm_$hostsn.log
      if [ $? -eq 0 ]
      then
	 echo "Not Running"
      else 
	 echo "Success"
      fi
      sleep 10
      ET=$(date +%s)
      print_time STEP "Stop Node Manager on $hostsn" $ST $ET >> $LOGDIR/timings.log

}

start_nm()
{
      hostname=$1
      user=$2
      nm_home=$3
      delay=$4
      delay=${delay:=1}
      delay=$((delay*60))

      hostsn=$(echo $hostname | cut -f1 -d.)
      ST=$(date +%s)
      print_msg "Starting Node Manager on $hostsn"
      $SSH $user@$hostname $REMOTE_WORKDIR/start_nm.sh  > $LOGDIR/start_nm_$hostsn.log 2>&1
      sleep $delay
      $SSH $user@$hostname  cat $nm_home/nodemanager.out  >> $LOGDIR/start_nm_$hostsn.log 2>&1
      grep -q "Could not obtain exclusive lock"  $LOGDIR/start_nm_$hostsn.log 
      if [ $? -eq 0 ]
      then
         echo "Already Started"
      else
         grep -q "listener started"  $LOGDIR/start_nm_$hostsn.log 
         print_status $? $LOGDIR/start_nm_$hostsn.log
      fi

      ET=$(date +%s)
      print_time STEP "Stop Node Manager on $hostsn" $ST $ET >> $LOGDIR/timings.log

}

reconfig_nm()
{
      hostname=$1
      user=$2
      nm_home=$3
      domain_name=$4
      domain_homes=$5

      ST=$(date +%s)
      hostsn=$(echo $hostname | cut -f1 -d.)
      print_msg "Reconfiguring Node Manager on $hostsn"
      echo "$domain_name=$domain_homes" > $WORKDIR/nodemanager.domains.$hostsn
      $SCP $WORKDIR/nodemanager.domains.$hostsn $user@$hostname:$nm_home/nodemanager.domains >> $LOGDIR/recreate_nm.log 2>&1
      print_status $? $LOGDIR/recreate_nm.log

      ET=$(date +%s)
      print_time STEP "Reconfigure Node Manager on $hostname" $ST $ET >> $LOGDIR/timings.log

}



# Print a message in the timings.log to state how long a step has taken
#
print_time()
{
   type=$1
   descr=$2
   start_time=$3
   end_time=$4
   time_taken=$((end_time-start_time))
   if [ "$type" = "STEP" ]
   then
       eval "echo  Step $STEPNO : Time taken to execute step $descr: $(date -ud "@$time_taken" +' %H hours %M minutes %S seconds')"
   else
       echo
       eval "echo  Total Time taken to $descr: $(date -ud "@$time_taken" +' %H hours %M minutes %S seconds')"
   fi
     
}

# Print a message to show the step being executed
#
print_msg()
{
   msg=$1
   if [ "$STEPNO" = "" ]
   then
       printf "$msg - "
   else
       printf "Executing Step $STEPNO:\t$msg - " 
   fi
     
}

# Print Success/Failed Message dependent on status
#
print_status()
{
   statuscode=$1
   logfile=$2
   if [ $1 = 0 ]
   then
       echo "Success"
   else
     if [ "$logfile" = "" ]
     then
       echo "Failed"
     else
       echo "Failed - Check Logfile : $logfile"
     fi
     exit 1
   fi
}

# Obtain an SSL certificate from a load balancer
#
get_lbr_certificate()
{
     LBRHOST=$1
     LBRPORT=$2
    
     ST=$(date +%s)

     print_msg "Obtaining Load Balancer Certificate $LBRHOST:$LBRPORT"
     ST=$(date +%s)

     openssl s_client -connect ${LBRHOST}:${LBRPORT} -showcerts </dev/null 2>/dev/null| sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > $WORKDIR/${LBRHOST}.pem 2>$LOGDIR/lbr_cert.log 
     print_status $? $LOGDIR/lbr_cert.log

     ET=$(date +%s)
     print_time STEP "Obtaining Load Balancer Certificate $LBRHOST:$LBRPORT" $ST $ET >> $LOGDIR/timings.log
}

# Copy OHS config Files to OHS servers
#
copy_ohs_config()
{

     print_msg "Copying OHS configuration Files to OHS Servers"
     echo
     INSTANCE_NO=0
     for ohshost in $(echo $OHS_HOSTS | sed "s/,/ /g")
     do
	INSTANCE_NO=$((INSTANCE_NO+1))
	ohsInstance="ohs$INSTANCE_NO"
        printf "\t\t\tOHS Server $ohshost - "

        $SCP $LOCAL_WORKDIR/OHS/$ohshost/*vh.conf $OHS_OWNER@$ohshost:$OHS_DOMAIN/config/fmwconfig/components/OHS/$ohsInstance/moduleconf/ > $LOGDIR/copy_ohs.log 2>&1
        print_status $? $LOGDIR/copy_ohs.log

        if [ "$COPY_WG_FILES" = "true" ]
        then
           $SCP -r $LOCAL_WORKDIR/OHS/webgate/wallet ${OHS_OWNER}@$ohshost:$OHS_DOMAIN/config/fmwconfig/components/OHS/$ohsInstance/webgate/config >> $LOGDIR/copy_ohs.log 2>&1
           $SCP -r $LOCAL_WORKDIR/OHS/webgate/ObAccessClient.xml  ${OHS_OWNER}@$ohshost:$OHS_DOMAIN/config/fmwconfig/components/OHS/$ohsInstance/webgate/config >> $LOGDIR/copy_ohs.log 2>&1
           $SCP -r $LOCAL_WORKDIR/OHS/webgate/cwallet.sso  ${OHS_OWNER}@$ohshost:$OHS_DOMAIN/config/fmwconfig/components/OHS/$ohsInstance/webgate/config >> $LOGDIR/copy_ohs.log 2>&1
           $SCP -r $LOCAL_WORKDIR/OHS/webgate/password.xml  ${OHS_OWNER}@$ohshost:$OHS_DOMAIN/config/fmwconfig/components/OHS/$ohsInstance/webgate/config >> $LOGDIR/copy_ohs.log 2>&1
           $SCP -r $LOCAL_WORKDIR/OHS/webgate/aaa*  ${OHS_OWNER}@$ohshost:$OHS_DOMAIN/config/fmwconfig/components/OHS/$ohsInstance/webgate/config/simple >> $LOGDIR/copy_ohs.log 2>&1
        fi

        printf "\t\t\tStopping Oracle HTTP Server $ohshost - "
        $SSH ${OHS_OWNER}@$ohshost "$OHS_DOMAIN/bin/stopComponent.sh $ohsInstance" >> $LOGDIR/copy_ohs.log 2>&1
        echo "Success"
        printf "\t\t\tStarting Oracle HTTP Server $ohshost - "
        $SSH ${OHS_OWNER}@$ohshost "$OHS_DOMAIN/bin/startComponent.sh $ohsInstance" >> $LOGDIR/copy_ohs.log 2>&1
        print_status $? $LOGDIR/copy_ohs.log
     done

     ET=$(date +%s)
     print_time STEP "Copying OHS config" $ST $ET >> $LOGDIR/timings.log
}

# Determine where a script stopped to enable continuation
#
get_progress()
{
    if [ -f $LOGDIR/progressfile ]
    then
        cat $LOGDIR/progressfile
    else
        echo 0
    fi
}

# Increment Step count
#
new_step()
{
    STEPNO=$((STEPNO+1))
    if [ "$DEBUG_STEP" = "true" ]
    then
      echo "DEBUG:STEPNO $STEPNO PROGRESS $PROGRESS"
    fi
}

# Increment progress count
#
update_progress()
{
    PROGRESS=$((PROGRESS+1))
    echo $PROGRESS > $LOGDIR/progressfile
    if [ "$DEBUG_STEP" = "true" ]
    then
      echo "DEBUG: Updating PROGRESS to $PROGRESS"
    fi
}

# Check that a loadbalancer virtual host has been configured
#
function check_lbr()
{

    host=$1
    port=$2

    print_msg "Checking Loadbalancer $1 port $2 : "

    nc -z $host $port

    if [ $? = 0 ]
    then
       echo "Success"
       return 0
    else
       echo "Fail"
       return 1
    fi
}


# Check LDAP System user exists
#
check_ldap_sys_ext()
{
   LHOST=$1
   LPORT=$2
   USER=$3
   

   print_msg "Checking System $USER exists in LDAP : "

   if [ "$OUD_MODE" = "secure" ]
   then
       export LDAPTLS_REQCERT=never
       ldapsearch -v  -H  "ldaps://$LHOST:LPORT" -x -D $LDAP_ADMIN_USER -w $LDAP_ADMIN_PWD -b cn=$LDAP_SYSTEMIDS,$LDAP_SEARCHBASE  -s sub -b $LDAP_SEARCHBASE uid | grep -q $USER
   else
       ldapsearch -v  -H  "ldap://$LHOST:LPORT" -x -D $LDAP_ADMIN_USER -w $LDAP_ADMIN_PWD -b cn=$LDAP_SYSTEMIDS,$LDAP_SEARCHBASE  -s sub -b $LDAP_SEARCHBASE uid | grep -q $USER
   fi
   return $?

}

# Check LDAP Object Class exists
#
check_ldap_object_ext()
{
   LHOST=$1
   LPORT=$2
   OBJECT=$3
   

   print_msg "Checking users have OAM Object Classes : "

   ldapsearch -h $LHOST -p $LPORT -D $LDAP_ADMIN_USER -w $LDAP_ADMIN_PWD -b $LDAP_USER_SEARCHBASE  | grep -q oblixPersonPwdPolicy
   return $?

}

# Check LDAP user exists
#
check_ldap_user_ext()
{
   LHOST=$1
   LPORT=$2
   LDAPSSL=$3
   USER=$4
   

   print_msg "Checking $USER exists in LDAP : "

      if [ "$LDAPSSL" = "true" ]
   then
       export LDAPTLS_REQCERT=never
       ldapsearch -v  -H  "ldaps://$LHOST:LPORT" -x -D $LDAP_ADMIN_USER -w $LDAP_ADMIN_PWD -b cn=$LDAP_SYSTEMIDS,$LDAP_SEARCHBASE  -s sub -b $LDAP_SEARCHBASE uid | grep -q $USER
   else
       ldapsearch -v  -H  "ldap://$LHOST:LPORT" -x -D $LDAP_ADMIN_USER -w $LDAP_ADMIN_PWD -b cn=$LDAP_SYSTEMIDS,$LDAP_SEARCHBASE  -s sub -b $LDAP_SEARCHBASE uid | grep -q $USER
   fi
   return $?

}
# Check an LDAP User exists
#

check_ldap_user()
{
   userid=$1

   ST=$(date +%s)
   print_msg "Checking User $userid exists in LDAP"


   nc -z $LDAP_HOST $LDAP_PORT -w 2
   if [ $? -eq 0 ]
   then
      if [ "$LDAP_SSL" = "true" ]
      then
          export LDAPTLS_REQCERT=never
          LDAP_CMD="ldapsearch -LL -H \"ldaps://$LDAP_HOST:$LDAP_PORT\" -x -D $LDAP_ADMIN_USER -w $LDAP_ADMIN_PWD"
      else
          LDAP_CMD="ldapsearch -LL -H \"ldap://$LDAP_HOST:$LDAP_PORT\" -x -D $LDAP_ADMIN_USER -w $LDAP_ADMIN_PWD"
      fi
      LDAP_CMD="$LDAP_CMD -b ${LDAP_SYSTEMIDS} -s sub uid=${userid} "
 
      echo $LDAP_CMD > $LOGDIR/check_ldap.log
      USER=$(eval $LDAP_CMD | grep uid)

      if [ "$USER" = "" ]
      then
	 eval  $LDAP_CMD >>  $LOGDIR/check_ldap.log
         echo "User Does not exist - check $LOGDIR/check_ldap.log"
         exit 1
      else
         echo " Exists "
      fi
   else
      echo "Unable to connect LDAP server $LDAP_HOST on port $LDAP_PORT from setup host - continuing"
   fi

   ET=$(date +%s)

   print_time STEP "Checking user $userid exists in LDAP" $ST $ET >> $LOGDIR/timings.log
}

# Check LDAP Group Exists
#
check_ldap_group_ext()
{
   LHOST=$1
   LPORT=$2
   LGRP=$3
   

   print_msg "Checking $LGRP exists in LDAP : "

   ldapsearch -h $LHOST -p $LPORT -D $LDAP_ADMIN_USER -w $LDAP_ADMIN_PWD -b $LDAP_GROUP_SEARCHBASE  | grep -q $LGRP
   return $?

}

# Check LDAP search is installed
#
check_ldapsearch()
{

   print_msg "Checking ldapseach Installed : "

   which ldapsearch > /dev/null 2>&1
   return $?

}



# Check health-check is not being blocked
#
check_healthcheck_ok()
{
   ST=$(date +%s)
   print_msg "Checking Health-check is not blocked"
   echo 

   for ohshost in $(echo $OHS_HOSTS | sed 's/,/ /g')
   do
      hostsn=$(echo $ohshost | cut -f1 -d.)
      sleep 5
      printf "\t\t\t$hostsn - "
      blocked_ip=$( $SSH ${OHS_OWNER}@$ohshost grep health-check.html  $OHS_DOMAIN/servers/ohs?/logs/access_log | grep 403 | awk '{ print $1 }' | tail -1 )
      if [ "$blocked_ip" = "" ]
      then
        echo "Success"
      else
        printf "Blocked by IP Address: $blocked_ip - Fixing - "
        $SSH ${OHS_OWNER}@$ohshost -C sed -i \"/    require host/a "\\    require ip $blocked_ip"\" $OHS_DOMAIN/config/fmwconfig/components/OHS/ohs?/webgate.conf
        print_status $?
        printf "\t\t\tRestarting OHS $hostsn - "
        $SSH ${OHS_OWNER}@$ohshost "$OHS_DOMAIN/bin/restartComponent.sh $OHS1_NAME" > $LOGDIR/restart_$OHS_HOST1.log 2>&1
        print_status $? $LOGDIR/restart_$OHS_HOST1.log
      fi
   done
}

# Pack/Unpack Domain
#
pack_domain()
{
    dom_type=$1
    ST=$(date +%s)
    print_msg "Creating a Domain Archive"
    if [ "$dom_type" = "oam" ]
    then
       HOST=$OAM_ADMIN_HOST
       USER=$OAM_OWNER
       DOMAIN_NAME=$OAM_DOMAIN_NAME
    elif [ "$dom_type" = "oig" ]
    then
       HOST=$OIG_ADMIN_HOST
       USER=$OIG_OWNER
       DOMAIN_NAME=$OIG_DOMAIN_NAME
    else
       echo "Invalid domain type: $dom_type"
       exit 1
    fi

    $SSH $USER@$HOST $REMOTE_WORKDIR/pack_domain.sh > $LOGDIR/pack_domain.log 2>&1
    print_status $? $LOGDIR/pack_domain.log 2>&1
    printf "\t\t\tRetrieving Archive - "
    $SCP $USER@$HOST:$REMOTE_WORKDIR/$DOMAIN_NAME-domain.jar $WORKDIR >> $LOGDIR/pack_domain.log 2>&1
    print_status $? $LOGDIR/pack_domain.log 2>&1

    ET=$(date +%s)
    print_time STEP "Pack Domain" $ST $ET >> $LOGDIR/timings.log

}

unpack_domain()
{
    dom_type=$1
    HOST=$2
    ST=$(date +%s)
    print_msg "Creating a Managed Server Directory on $HOST"
    if [ "$dom_type" = "oam" ]
    then
       USER=$OAM_OWNER
       DOMAIN_NAME=$OAM_DOMAIN_NAME
       HOST1=$(echo $OAM_HOSTS| awk '{print $1}')
    elif [ "$dom_type" = "oig" ]
    then
       USER=$OIG_OWNER
       DOMAIN_NAME=$OIG_DOMAIN_NAME
       HOST1=$(echo $OIG_HOSTS| awk '{print $1}')
    else
       echo "Invalid domain type: $dom_type"
       exit 1
    fi

    if [ ! "$HOST" = "$HOST1" ]
    then
       printf "\n\t\t\tCopying Archive - "
       $SCP $WORKDIR/$DOMAIN_NAME-domain.jar $USER@$HOST:$REMOTE_WORKDIR  > $LOGDIR/unpack_domain.log 2>&1
       print_status $? $LOGDIR/unpack_domain.log 2>&1
       printf "\t\t\tCopying unpack command - "
       $SCP $WORKDIR/create_scripts/unpack_domain.sh $USER@$HOST:$REMOTE_WORKDIR  >> $LOGDIR/unpack_domain.log 2>&1
       print_status $? $LOGDIR/unpack_domain.log 2>&1
       printf "\t\t\tSetting Permissions - "
       $SSH  $USER@$HOST chmod 700 $REMOTE_WORKDIR/*.sh  >> $LOGDIR/unpack_domain.log 2>&1
       print_status $? $LOGDIR/unpack_domain.log 2>&1
       printf "\t\t\tExtracting Archive - "
    else
       printf "\n\t\t\tExtracting Archive - "
    fi

    $SSH $USER@$HOST $REMOTE_WORKDIR/unpack_domain.sh > $LOGDIR/unpack_domain.log 2>&1
    print_status $? $LOGDIR/unpack_domain.log 2>&1

    ET=$(date +%s)
    print_time STEP "Unpack Domain on $HOST" $ST $ET >> $LOGDIR/timings.log

}
