#!/bin/bash
## rsync_copy_and_validate.sh version 1.0.
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##
### This script is used to perform an rsync copy "from" or "to" a remote node and validate the contets replicated.
### In context of a Oracle FMW 14.1.2 Disaster Recovery sytem, this script is invoked by rsync_for_WLS.sh
### to replicate the OHOME, WebLogic Private Configuration and Shared configuration 
### Refer to the Oracle® Fusion Middleware EDG for directory and storage configurattion details: 
### https://docs.oracle.com/en/middleware/fusion-middleware/12.2.1.4/soedg/.
### TBA Link to DR Guide.
### If the SSH_KEYFILE env variable is set, it uses it for a key-based rsync over ssh
### If the SSH_KEYFILE env variable is not set, it uses a password-based rsync over ssh
### Usage:
###
###      	./rsync_copy_and_validate.sh [ORIGIN_FOLDER] [DEST_FOLDER] [REMOTE_NODE_IP] [COPY_FROM] "[EXCLUDE_LIST]" 
### Where:
###		ORIGIN_FOLDER:
###			The folder in the source to copy from.
###		DEST_FOLDER:
###			The folder in the target to copy to.
###		REMOTE_NODE_IP:
###			The remote node's IP.
###		COPY_FROM:
###			TRUE/FALSE param. If TRUE, the script copies from a remote node, if FALSE it copies to that node.
###		EXCLUDE_LIST
###			Optional parameter. If provided, it must be passed between double quotes because it contains blank spaces.
###  		For example: "--exclude 'dir1/' --exclude 'dir2/'"
### Examples:
###		-To copy from node 172.11.2.113's folder /u01/oracle/config to this node's (executing the script) folder /u01/stage
### 	excluding directories tmp and logs 
###			./rsync_copy_and_validate.sh /u01/oracle/config /u01/oracle/config/stage 172.11.2.113 true "--exclude 'tmp/' --exclude 'logs/'"
###		-To copy to node 172.11.2.113's folder /u01/oracle/config from this node's (executing the script) folder /u01/stage
### 	excluding directories tmp and logs 
###			./rsync_copy_and_validate.sh /u01/oracle/config/stage /u01/oracle/config 172.11.2.113 false"

if [[ $# -eq 5 ]];
then
	ORIGIN_FOLDER=$1
	DEST_FOLDER=$2
	REMOTE_NODE_IP=$3
	COPY_FROM=$4
	EXCLUDE_LIST=$5
elif [[ $# -eq 4 ]];
then
	ORIGIN_FOLDER=$1
	DEST_FOLDER=$2
	REMOTE_NODE_IP=$3
	COPY_FROM=$4
else
	echo ""
    echo "ERROR: Incorrect number of parameters used: Expected 4 or 5, got $#"
    echo ""
    echo "Usage:"
	echo ""
	echo "$0 [ORIGIN_FOLDER] [DEST_FOLDER] [REMOTE_NODE_IP] [COPY_FROM] \"[EXCLUDE_LIST]\""
	echo ""
	echo "-To copy from node REMOTE_NODE_IP folder REMOTE_FOLDER to this node's (executing the script) folder DEST_FOLDER with EXCLUDE_LIST"
  	echo "    $0 [ORIGIN_FOLDER] [DEST_FOLDER] [REMOTE_NODE_IP] true \"[EXCLUDE_LIST]\""
	echo ""
	echo "-To copy to node REMOTE_NODE_IP folder REMOTE_FOLDER from this node's (executing the script) folder DEST_FOLDER without a EXCLUDE_LIST"
	echo "    $0 [ORIGIN_FOLDER] [DEST_FOLDER] [REMOTE_NODE_IP] false"
	echo ""
    echo "Examples:  "
    echo "    $0  /u01/oracle/config /u01/oracle/config/stage 172.11.2.113 true \"--exclude 'tmp/' --exclude 'logs/'\" "
	echo "    $0  /u01/oracle/config/stage /u01/oracle/config 172.11.2.113 false "
	exit 1
fi


###########################################################################
# END OF INPUT PARAMETERS
###########################################################################


###########################################################################
# Internal parametrizable values
###########################################################################
# If a ssh keyfile is used (recommended), provide here the path. 
# If ssh key is not used, and password is used instead, leave this empty and 
# you will be prompted for the password.

# Provide the username that connects to remote node
USER=oracle

# True for validating the rsync copy
VALIDATE=true

# True for using "--delete" in rsync commands
# If true, files on the target destination side will be deleted if they do not exist at the source.
DELETE=true

# Provide the folder name for the output logs (it can be absolute or relative path)
LOGDIR=logs
###########################################################################
# END of internal parametrizable values
###########################################################################
export exec_path="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export LOGDIR=$exec_path/logs
mkdir -p $LOGDIR

###########################################################################
# Checks on input parameters
###########################################################################
date_label=$(date '+%d-%m-%Y-%H-%M-%S')
LOG_FILE=${LOGDIR}/rsync_${date_label}.log

echo ""
echo "##########################################################################"
echo "############### RSYNC COPY AND VALIDATION SCRIPT #########################"
echo "##########################################################################"



if [ -z "${ORIGIN_FOLDER}" ]; then
        echo "Error: ORIGIN_FOLDER not passed as input parameter"
        exit 1
else
        echo "-ORIGIN_FOLDER:"
	echo "			$ORIGIN_FOLDER"
fi


if [ -z "${DEST_FOLDER}" ]; then
        echo "Error: DEST_FOLDER not passed as input parameter"
        exit 1
else
        echo "-DEST_FOLDER:"
       	echo "			$DEST_FOLDER"
fi


if [ -z "${REMOTE_NODE_IP}" ]; then
        echo "Error: REMOTE_NODE_IP not passed as input parameter"
        exit 1
else
        echo "-REMOTE_NODE_IP:"
     	echo "			$REMOTE_NODE_IP"
fi

if [ -z "${EXCLUDE_LIST}" ]; then
        echo "Note: EXCLUDE_LIST not passed as input parameter. No files will be excluded from the rsync copy"
elif [[ ${EXCLUDE_LIST} = "--exclude" ]] || [[ ${EXCLUDE_LIST} = "--exclude " ]];then
        echo "Error: EXCLUDE_LIST looks truncated. Pass the exclude list using double quotes"
        exit 1
elif [[ ${EXCLUDE_LIST} = "--exclude"* ]] || [[ ${EXCLUDE_LIST} = " --exclude"* ]];then
        echo "-EXCLUDE_LIST:" >> ${LOG_FILE}
	echo "			$EXCLUDE_LIST" >> ${LOG_FILE}
else
        echo "Error: EXCLUDE_LIST does not have expected format"
        exit 1
fi

if [ ! -d "$LOGDIR" ]; then
	echo "Error: the folder $LOGDIR (for output logs) does not exist"
	exit 1
fi
echo "##########################################################################"

echo ""


###########################################################################
# FUNCTIONS TO COPY A FOLDER TO REMOTE NODE AND VALIDATE THE COPY
###########################################################################

rsync_copy(){
        echo ""
	rsync_command="rsync ${SSH_OPTION} -avz ${DELETE_OPTION}  --stats --modify-window=1 ${SOURCE} ${TARGET}"
        echo "" | tee -a ${LOG_FILE}
        echo "(You can check rsync command and exclude list in ${LOG_FILE})"
        eval $rsync_command >> ${LOG_FILE}
        echo ""
}


validate_copy(){
	echo "" | tee -a ${LOG_FILE}
	echo "Validating the copy.."  | tee -a ${LOG_FILE}
	max_rsync_retries=4
	stilldiff="true"
        diff_file=${LOG_FILE}_diffs
	rsync_compare_command="rsync ${SSH_OPTION} -niaHc ${EXCLUDE_LIST} ${SOURCE} ${TARGET} --modify-window=1"
	rsync_pending_command="rsync ${SSH_OPTION} --stats --modify-window=1 --files-from=${diff_file}_pending ${SOURCE} ${TARGET}"
	while [ $stilldiff == "true" ]
	do
		eval $rsync_compare_command > $diff_file 
		echo "Checksum comparison of source and target dir completed." >> ${LOG_FILE}
		compare_result=$(cat $diff_file | grep -v  '.d..t......' | grep -v  'log' | grep -v  'DAT' | wc -l)
		echo "$compare_result number of differences found" >> ${LOG_FILE}
		if [ $compare_result -gt 0 ]; then
			((rsynccount=rsynccount+1))
			if [ "$rsynccount" -eq "$max_rsync_retries" ];then
				stilldiff="false"
				echo "Maximum number of retries reached" 2>&1 | tee -a $rsync_log_file
				echo "******************************WARNING:*********************************************************************" 2>&1 | tee -a ${LOG_FILE}
				echo "Copy retried $max_rsync_retries time and there are still differences between" 2>&1 | tee -a ${LOG_FILE}
				echo "source and target directories (besides the explicitly excluded files)." 2>&1 | tee -a ${LOG_FILE}
				echo "It is recommended to verify that the copied domain files are valid in your secondary location." 2>&1 | tee -a ${LOG_FILE}
				echo "To perform this verification, convert the standby database to snapshot and start the secondary WLS servers" 2>&1 | tee -a ${LOG_FILE}
				echo "***********************************************************************************************************" 2>&1 | tee -a ${LOG_FILE}	
				echo "Check log file at ${LOG_FILE}" 2>&1 | tee -a ${LOG_FILE}
				echo "The differences reported are :" 2>&1 | tee -a ${LOG_FILE}
				cat $diff_file 2>&1 | tee -a ${LOG_FILE}
			else
				stilldiff="true"
				echo "Differences are: " >> ${LOG_FILE}
				cat $diff_file >> ${LOG_FILE}
				cat $diff_file |grep -v  '.d..t......'  |grep -v  'log' | grep -v  'DAT' | awk '{print $2}' > ${diff_file}_pending
				echo "Trying to rsync again the differences" >> ${LOG_FILE}
				echo "Rsyncing the pending files..." >> ${LOG_FILE}
				eval $rsync_pending_command >> ${LOG_FILE}
				echo "RSYNC RETRY NUMBER $rsynccount" >> ${LOG_FILE}
			fi
		else
			stilldiff="false"
			echo "Source and target directories are in sync. ALL GOOD!" 2>&1 | tee -a ${LOG_FILE}
			echo ""
		fi
	done
	echo "Validation complete!"

}

###########################################################
# Perform the copy and validation
###########################################################

echo "Starting rsync copy..."

if [ -z "$SSH_KEYFILE" ]; then
	export SSH_OPTION=""
else
        export SSH_OPTION="-e \"ssh -i ${SSH_KEYFILE}\""
fi

if [ "$COPY_FROM" = true ] ; then
        echo "Copying from remote location..." 2>&1 | tee -a ${LOG_FILE}
        export SOURCE="${USER}@${REMOTE_NODE_IP}:${ORIGIN_FOLDER}/"
        export TARGET="${DEST_FOLDER}/"
	if [ -z "$SSH_KEYFILE" ]; then
        	export SSH_OPTION=""
	else
        	export SSH_OPTION="-e \"ssh -i ${SSH_KEYFILE}\""
	fi
	mkdir -p $TARGET

elif [ "$COPY_FROM" = false ] ; then
        echo "Copying to remote location..." 2>&1 | tee -a ${LOG_FILE}
        export SOURCE="${ORIGIN_FOLDER}/"
        export TARGET="${USER}@${REMOTE_NODE_IP}:${DEST_FOLDER}/"
	if [ -z "$SSH_KEYFILE" ]; then
                export SSH_OPTION=""
                ssh ${USER}@${REMOTE_NODE_IP} "mkdir -p ${DEST_FOLDER}"
        else
                export SSH_OPTION="-e \"ssh -i ${SSH_KEYFILE}\""
		ssh -i $SSH_KEYFILE ${USER}@${REMOTE_NODE_IP} "mkdir -p ${DEST_FOLDER}"
        fi
else
        echo "Incorrect value/syntax provided for parameter COPY_FROM."
        echo "Check scripts syntax!"
        exit
fi

echo "Will transfer from $SOURCE to $TARGET..."

if [ "$DELETE" = true ] ; then
	export DELETE_OPTION="--delete"
else
        export DELETE_OPTION=""
fi

rsync_copy
if [ "$VALIDATE" = true ] ; then
	echo "Running rsync validation..." 2>&1 | tee -a ${LOG_FILE}
	validate_copy
elif [ "$VALIDATE" = false ] ; then
	echo "Validate parameter is $VALIDATE" 2>&1 | tee -a ${LOG_FILE}
	echo "Will not run detailed validation" 2>&1 | tee -a ${LOG_FILE}
else 
	echo "Incorrect value/syntax provided for parameter VALIDATE." 2>&1 | tee -a ${LOG_FILE}
	echo "Check scripts syntax!"2>&1 | tee -a ${LOG_FILE}
	exit
fi

echo "Rsync operations complete!" 2>&1 | tee -a ${LOG_FILE}

