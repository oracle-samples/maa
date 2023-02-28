#!/bin/bash

## fmw_sync_in_primary.sh script version 1.0.
##
## Copyright (c) 2023 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/

## This script returns the oracle.net.tnsadmin directory that a WLS/SOA/FMW datasource is using if any
##
## Usage:
##         ./fmw_sync_in_primary.sh DR_METHOD DOMAIN_HOME STAGE_FOLDER TNS_ADMIN [REMOTE_ADMIN_NODE_IP] [REMOTE_KEYFILE]
##
## Where:
##	DR_METHOD 	The DR method used in the environment (DBFS / RSYNC)
##	
##	DOMAIN_HOME     The path to the domain folder. Example: '/u01/data/domains/mydomain_domain'
##	
##	STAGE_FOLDER    The path of the folder that is used for the copy. The folder can be in DBFS or in FSS. 
##			Example: '/u01/shared/domain_copy_folder'
##	
##	TNS_ADMIN       The path to the TNS admin folder. This folder will no be included in the copy.
##	                Example: '/u01/data/domains/mydomain_domain/config/tnsadmin'
##
##     REMOTE_ADMIN_NODE_IP    [ONLY WHEN DR_METHOD IS RSYNC] 
##				This is the IP address of the secondary Weblogic Administration server node.
##				This IP needs to be reachable from this host. 
##				It is recommended to use Dynamic Routing Gateway to interconnect primary and secondary sites, 
##				hence you can provide the private IP.
##				Example: 10.1.2.1
##
##	REMOTE_KEYFILE  [ONLY WHEN DR_METHOD IS RSYNC] 
##			The complete path to the ssh private keyfile used to connect to secondary Weblogic Administration server node.
##			Example: '/u01/install/myprivatekey.key'


if [[ $# -ne 0 ]]; then
        export DR_METHOD=$1
        if  [[ $DR_METHOD = "DBFS" ]]; then
                if [[ $# -eq 4 ]]; then
                        export DOMAIN_HOME=$2
			export STAGE_FOLDER=$3
			export TNS_ADMIN=$4
                else
                        echo ""
                        echo "ERROR: Incorrect number of parameters used for DR_METHOD $1. Expected 2, got $#"
                        echo "Usage for DR_METHOD=DBFS:"
                        echo "      $0  DR_METHOD DOMAIN_HOME STAGE_FOLDER TNS_ADMIN"
                        echo "Example: "
                        echo "      $0 'DBFS' '/u01/data/domains/soampdr_domain'  '/u01/shared/domain_copy_folder' '/u01/data/domains/soampdr_domain/config/tnsadmin'"
                        echo ""
                        exit 1
                fi

        elif [[ $DR_METHOD = "RSYNC" ]]; then
                if [[ $# -eq 6 ]]; then
			export DOMAIN_HOME=$2
                        export STAGE_FOLDER=$3
			export TNS_ADMIN=$4
                        export REMOTE_ADMIN_NODE_IP=$5
                        export REMOTE_KEYFILE=$6
                else
                        echo ""
                        echo "ERROR: Incorrect number of parameters used for DR_METHOD $1. Expected 5, got $#"
                        echo "Usage for DR_METHOD=RSYNC:"
                        echo "    $0  DR_METHOD DOMAIN_HOME STAGE_FOLDER TNS_ADMIN [REMOTE_ADMIN_NODE_IP] [REMOTE_KEYFILE]"
                        echo "Example:  "
                        echo "    $0  'RSYNC' '/u01/data/domains/soampdr_domain' '/u01/share/domain_copy_folder' '/u01/data/domains/soampdr_domain/config/tnsadmin' '10.1.2.43' '/u01/install/KeyWithoutPassPhraseSOAMAA.ppk'"
                        echo ""
                        exit 1
                fi
        else
                echo ""
                echo "ERROR: Incorrect value for input variable DR_METHOD passed to $0. Expected DBFS or RSYNC, got $1"
                echo "Usage: "
                echo "  $0 DR_METHOD STAGE_FOLDER TNS_ADMIN [REMOTE_ADMIN_NODE_IP] [REMOTE_KEYFILE] "
                echo ""
                exit 1
        fi

else
        echo
        echo "No parameters passed as argument."
	exit 1
fi


sync_in_primary_to_local_folder(){
	export date_label=$(date '+%Y-%m-%d-%H_%M_%S')
	export wls_domain_name=$(basename ${DOMAIN_HOME})
	export rel_tns_admin=$(echo $TNS_ADMIN | awk -F"$DOMAIN_HOME/" '{print $2}')

	# To prevent errors in case that TNS_ADMIN folder is out from the domain
	if [[ ! -z "${rel_tns_admin}" ]];then
	        export exclude_list="--exclude $rel_tns_admin"
	fi
	# If WLSMP, in RSYNC method there is no dbfs folder
	# If SOAMP, in RSYNC method there is dbfs folder and but it is not modified during DR setup.We can replicate it except the tnsnames.ora (which is and must be
	# different in each site)
	if  [[ ${DR_METHOD} = "RSYNC" ]]; then
	        export exclude_list="$exclude_list --exclude 'dbfs/tnsnames.ora'"
	elif [[ ${DR_METHOD} = "DBFS" ]];then
		export exclude_list="$exclude_list --exclude 'dbfs'"
	else
		echo "Error. DR topology unknown"
		exit 1
	fi

	export exclude_list="$exclude_list --exclude 'soampRebootEnv.sh' "
        export exclude_list="$exclude_list --exclude 'servers/*/data/nodemanager/*.lck' --exclude 'servers/*/data/nodemanager/*.pid' "
        export exclude_list="$exclude_list --exclude 'servers/*/data/nodemanager/*.state' --exclude 'servers/*/tmp' "
        export exclude_list="$exclude_list --exclude 'servers/*/adr/diag/ofm/*/*/lck/*.lck' --exclude 'servers/*/adr/oracle-dfw-*/sampling/jvm_threads*' "
        export exclude_list="$exclude_list --exclude 'tmp'"
        export exclude_list="$exclude_list --exclude '/nodemanager'"

        echo "Rsyncing from local domain to local stage folder..."
        export rsync_log_file=${STAGE_FOLDER}/last_primary_update_local_${date_label}.log
        export diff_file=${STAGE_FOLDER}/last_primary_update_local_${date_label}_diff.log
        echo "Local rsync output to ${rsync_log_file} ...."
        export local_rsync_command="rsync -avz --stats --modify-window=1 $exclude_list ${DOMAIN_HOME}/  ${STAGE_FOLDER}/${wls_domain_name}"
        eval $local_rsync_command >> ${rsync_log_file}

        export local_rsync_compare_command="rsync -niaHc ${exclude_list} ${DOMAIN_HOME}/ ${STAGE_FOLDER}/$wls_domain_name/ --modify-window=1"
        export local_sec_rsync_command="rsync --stats --modify-window=1 --files-from=${diff_file}_pending ${DOMAIN_HOME}/ ${STAGE_FOLDER}/$wls_domain_name "
        export rsync_compare_command=${local_rsync_compare_command}
        export sec_rsync_command=${local_sec_rsync_command}
        compare_rsync_diffs

        echo "Local rsync complete."
        echo ""
}

sync_in_primary_to_remote_folder(){
	# Only for RSYNC with FSS method
	# Then, copy from the local FSS mount folder to remote node(no risk of in-flight changes)
        echo "Rsyncing from local folder to remote site..."
        export rsync_log_file=${STAGE_FOLDER}/last_primary_update_remote_${date_label}.log
        export diff_file=${STAGE_FOLDER}/last_primary_update_remote_${date_label}_diff.log
        echo "Remote rsync output to ${rsync_log_file} ...."
        # We need to do sudo to oracle because if not, the files are created with the user opc
        export remote_rsync_command="rsync --rsync-path \"sudo -u oracle rsync\" -e \"ssh -i ${REMOTE_KEYFILE}\" -avz --stats --modify-window=1 $exclude_list ${STAGE_FOLDER}/${wls_domain_name}/ opc@${REMOTE_ADMIN_NODE_IP}:${STAGE_FOLDER}/${wls_domain_name}"
        eval $remote_rsync_command >> $rsync_log_file

        export remote_rsync_compare_command="rsync --rsync-path \"sudo -u oracle rsync\"  -e \"ssh -i ${REMOTE_KEYFILE}\" -niaHc ${exclude_list}  ${STAGE_FOLDER}/${wls_domain_name}/ opc@${REMOTE_ADMIN_NODE_IP}:${STAGE_FOLDER}/${wls_domain_name} --modify-window=1"
        export remote_sec_rsync_command="rsync --rsync-path \"sudo -u oracle rsync\" -e \"ssh -i ${REMOTE_KEYFILE}\" --stats --modify-window=1 --files-from=${diff_file}_pending ${STAGE_FOLDER}/${wls_domain_name}/ opc@${REMOTE_ADMIN_NODE_IP}:${STAGE_FOLDER}/${wls_domain_name} "
        export rsync_compare_command=${remote_rsync_compare_command}
        export sec_rsync_command=${remote_sec_rsync_command}
        compare_rsync_diffs
        echo "Remote rsync complete."
        echo ""
}

compare_rsync_diffs(){
        export max_rsync_retries=4
        stilldiff="true"
        while [ $stilldiff == "true" ]
        do
                eval $rsync_compare_command > $diff_file  # DEFINE THIS COMMAN BEFORE CALLING THIS FUNCTION
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


######################################################################################################################
# END OF FUNCTIONS
######################################################################################################################

sync_in_primary_to_local_folder
if  [[ ${DR_METHOD} = "RSYNC" ]]; then
	sync_in_primary_to_remote_folder
elif [[ ${DR_METHOD} = "DBFS" ]];then
        echo "In DBFS method, the copy to remote folder is performed by the underlying Data Guard replica"
else
	echo "Error. DR topology unknown"
        exit 1
fi



