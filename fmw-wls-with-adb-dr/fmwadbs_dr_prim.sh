#!/bin/bash

## fmwadbs_dr_prim.sh script version 1.0.
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##
### This script repares a primary site for the DR setup.
### This script should be executed in the PRIMARY Weblogic Administration server node
### Usage:
###
###      ./fmwadbs_dr_prim.sh [REMOTE_ADMIN_NODE_IP] [REMOTE_SSH_PRIV_KEYFILE] [FSS_MOUNT]
### Where:
###	REMOTE_ADMIN_NODE_IP:
###					This is the IP address of the secondary Weblogic Administration server node.
###					This IP needs to be reachable from this host. 
###					It is recommended to use Dynamic Routing Gateway to interconnect primary and secondary sites, hence you can provide the private IP.
###	REMOTE_SSH_PRIV_KEYFILE:
###		                        The private ssh keyfile to connect to remote Weblogic Administration server node.
###	FSS_MOUNT:
###					This is the OCI File Storage Mounted directory that will be used to stage the WLS domain configuration

export wls_domain_name=$(echo ${DOMAIN_HOME} |awk -F '/u01/data/domains/' '{print $2}')
export date_label=$(date '+%d-%m-%Y-%H-%M-%S')
export datasource_name=opss-datasource-jdbc.xml
export datasource_file="$DOMAIN_HOME/config/jdbc/$datasource_name"

if [[ $# -eq 3 ]]; then
	export REMOTE_ADMIN_NODE_IP=$1
        export REMOTE_SSH_PRIV_KEYFILE=$2
	export FSS_MOUNT=$3
	export copy_folder=${FSS_MOUNT}/domain_config_copy
else
	echo ""
	echo "ERROR: Incorrect number of parameters used. Expected 3, got $#"
	echo "Usage :"
	echo "    $0  REMOTE_ADMIN_NODE_IP REMOTE_KEYFILE FSS_MOUNT"
	echo "Example:  "
	echo "    $0  '10.1.2.43' '/u01/install/KeyWithoutPassPhraseSOAMAA.ppk' /u01/soacs/dbfs/share"
	echo ""
	exit 1
fi


checks_in_primary_rsync(){
        # Check connectivity to remote Weblogic Administration server node and show its hostname
        echo "Checking ssh connectivity to remote Weblogic Administration server node...."
        export result=$(ssh -o ConnectTimeout=100 -o StrictHostKeyChecking=no -i $REMOTE_SSH_PRIV_KEYFILE opc@${REMOTE_ADMIN_NODE_IP} "echo 2>&1" && echo "OK" || echo "NOK" )
        if [ $result == "OK" ];then
                echo "Connectivity to ${REMOTE_ADMIN_NODE_IP} is OK"
                export REMOTE_ADMIN_HOSTNAME=$(ssh -i $REMOTE_SSH_PRIV_KEYFILE opc@${REMOTE_ADMIN_NODE_IP} 'hostname --fqdn')
                echo "REMOTE_ADMIN_HOSTNAME......" ${REMOTE_ADMIN_HOSTNAME}
        else
                echo "Error: Failed to connect to ${REMOTE_ADMIN_NODE_IP}"
                exit 1
        fi
	
	# Check local mount  directory
        echo "Checking local FSS ${FSS_MOUNT} folder readiness..."
        if [ -d "${FSS_MOUNT}" ];then
                echo "${FSS_MOUNT} exists."
		echo "Will use ${copy_folder} to stage the domain configuration."
		mkdir -p  ${copy_folder} 
        else
                echo "Error: local FSS mount ${FSS_MOUNT} does not exists."
                exit 1
        fi

        # Check remote mount is ready
        echo "Checking remote FSS mount folder readiness..,"
        if ssh -i $REMOTE_SSH_PRIV_KEYFILE opc@${REMOTE_ADMIN_NODE_IP} [ -d ${copy_folder} ];then
                echo "Remote folder ${REMOTE_ADMIN_NODE_IP}:${copy_folder} exists."
        else
                echo "Error: remote folder  ${REMOTE_ADMIN_NODE_IP}:${copy_folder} does not exist."
                exit 1
        fi
	export tns_admin=$( grep tns_admin -A1 $datasource_file | grep value | awk -F '<value>' '{print $2}' | awk -F '</value>' '{print $1}')
	export rel_tns_admin=$(echo $tns_admin | awk -F"$DOMAIN_HOME/" '{print $2}')
}

sync_in_primary_rsync(){
        export exclude_list="--exclude '$rel_tns_admin' --exclude 'dbfs/tnsnames.ora' --exclude 'soampRebootEnv.sh' --exclude 'servers/*/data/nodemanager/*.lck' --exclude 'servers/*/data/nodemanager/*.pid' --exclude 'servers/*/data/nodemanager/*.state' --exclude 'servers/*/tmp'  --exclude 'servers/*/adr/diag/ofm/*/*/lck/*.lck' --exclude 'servers/*/adr/oracle-dfw-*/sampling/jvm_threads*' --exclude 'tmp'"

        # First, a copy to local FSS mount folder
        echo ""
        echo "Rsyncing from local domain to local FSS folder..."
        echo ""
        export rsync_log_file=${copy_folder}/last_primary_update_local_${date_label}.log
        export diff_file=${copy_folder}/last_primary_update_local_${date_label}_diff.log
        echo "Local rsync output to ${rsync_log_file}."
        export local_rsync_command="rsync -avz --stats --modify-window=1 $exclude_list ${DOMAIN_HOME}/  ${copy_folder}/${wls_domain_name}"
        eval $local_rsync_command >> ${rsync_log_file}
        export local_rsync_compare_command="rsync -niaHc ${exclude_list} ${DOMAIN_HOME}/ ${copy_folder}/$wls_domain_name/ --modify-window=1"
        export local_sec_rsync_command="rsync --stats --modify-window=1 --files-from=${diff_file}_pending ${DOMAIN_HOME}/ ${copy_folder}/$wls_domain_name "
        export rsync_compare_command=${local_rsync_compare_command}
        export sec_rsync_command=${local_sec_rsync_command}
        compare_rsync_diffs
        rm -rf ${copy_folder}/$wls_domain_name/nodemanager
        echo ""
        echo "Local rsync complete"
        echo ""
        # Then, copy from the local FSS mount folder to remote node(no risk of in-flight changes)
        echo "Rsyncing from local FSS folder to remote site..."
        export rsync_log_file=${copy_folder}/last_primary_update_remote_${date_label}.log
        export diff_file=${copy_folder}/last_primary_update_remote_${date_label}_diff.log
        echo "Remote rsync output to ${rsync_log_file}."
        # We need to do sudo to oracle because if not, the files are created with the user opc
        export remote_rsync_command="rsync --rsync-path \"sudo -u oracle rsync\" -e \"ssh -i ${REMOTE_SSH_PRIV_KEYFILE}\" -avz --stats --modify-window=1 $exclude_list ${copy_folder}/${wls_domain_name}/ opc@${REMOTE_ADMIN_NODE_IP}:${copy_folder}/${wls_domain_name}"
        eval $remote_rsync_command >> $rsync_log_file
        export remote_rsync_compare_command="rsync --rsync-path \"sudo -u oracle rsync\"  -e \"ssh -i ${REMOTE_SSH_PRIV_KEYFILE}\" -niaHc ${exclude_list}  ${copy_folder}/${wls_domain_name}/ opc@${REMOTE_ADMIN_NODE_IP}:${copy_folder}/${wls_domain_name} --modify-window=1"
        export remote_sec_rsync_command="rsync --rsync-path \"sudo -u oracle rsync\" -e \"ssh -i ${REMOTE_SSH_PRIV_KEYFILE}\" --stats --modify-window=1 --files-from=${diff_file}_pending ${copy_folder}/${wls_domain_name}/ opc@${REMOTE_ADMIN_NODE_IP}:${copy_folder}/${wls_domain_name} "
        export rsync_compare_command=${remote_rsync_compare_command}
        export sec_rsync_command=${remote_sec_rsync_command}
export sec_rsync_command=${remote_sec_rsync_command}
        compare_rsync_diffs
        echo ""
        echo "Remote rsync complete."
        echo ""
}

compare_rsync_diffs(){
        export max_rsync_retries=4
        stilldiff="true"
        while [ $stilldiff == "true" ]
        do
                eval $rsync_compare_command > $diff_file  # DEINFE THIS COMMAN BEFORE CALLING THIS FUNCTION
                echo "Checksum comparison of source and target dir completed." >> $rsync_log_file
                compare_result=$(cat $diff_file | grep -v  '.d..t......' | grep -v  'log' | grep -v  'DAT' | wc -l)
                echo "$compare_result number of differences found" >> $rsync_log_file
                if [ $compare_result -gt 0 ]; then
                        ((rsynccount=rsynccount+1))
                        if [ "$rsynccount" -eq "$max_rsync_retries" ];then
                                stilldiff="false"
                                echo "Maximum number of retries reached" 2>&1 | tee -a $rsync_log_file
                                echo "******************************WARNING:***********************************************" 2>&1 | tee -a $rsync_log_file
                                echo "Copy of config was retried $max_rsync_retries and there are still differences between" 2>&1 | tee -a $rsync_log_file
                                echo "source and target directories (besides the explicitly excluded files)." 2>&1 | tee -a $rsync_log_file
                                echo "This may be caused by logs and/or DAT files being modified by the source domain while performing the rsync operation." 2>&1 | tee -a $rsync_log_file
                                echo "You can continue with the DR setup." 2>&1 | tee -a $rsync_log_file
                                echo "Once DR setup is completed (after running DR setup scripts in the standby servers)," 2>&1 | tee -a $rsync_log_file
                                echo "it is recommended to verify that the copied domain files are valid in your secondary location." 2>&1 | tee -a $rsync_log_file
                                echo "To perform this verification, convert the standby database to snapshot and start the secondary WLS domain servers." 2>&1 | tee -a $rsync_log_file
                                echo "*************************************************************************************" 2>&1 | tee -a $rsync_log_file

                        else
                                stilldiff="true"
                                echo "Differences are: " >> $rsync_log_file
                                cat $diff_file >> $rsync_log_file
                                cat $diff_file |grep -v  '.d..t......'  |grep -v  'log' | awk '{print $2}' > ${diff_file}_pending
                                echo "Trying to rsync again the differences" >> $rsync_log_file
                                echo "Rsyncing the pending files..." >> $rsync_log_file
                                eval $sec_rsync_command >> $rsync_log_file  # dEFINE this command before calling this function
                                echo "RSYNC RETRY NUMBER $rsynccount" >> $rsync_log_file
                        fi
                else
			stilldiff="false"
                        echo "Source and target directories are in sync. ALL GOOD!" 2>&1 | tee -a $rsync_log_file
                fi
        done
}

checks_in_primary_rsync
sync_in_primary_rsync

