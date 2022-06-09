#!/bin/bash
## hybrid_dr scripts version 1.0.
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

###########################################################################
# INPUT PARAMETERS
###########################################################################
# Usage:
# rsync_copy_and_validate.sh [ORIGIN_FOLDER] [DEST_FOLDER] [REMOTE_NODE] "[EXCLUDE_LIST]"
# NOTE: "EXCLUDE_LIST" is optional parameter. If provided, it must be passed between double quotes 
# because it contains blank spaces.
# For example: "--exclude 'dir1/' --exclude 'dir2/'"

ORIGIN_FOLDER=$1
DEST_FOLDER=$2
REMOTE_NODE=$3
EXCLUDE_LIST=$4

###########################################################################
# END OF INPUT PARAMETERS
###########################################################################


###########################################################################
# Internal parametrizable values
###########################################################################
# If a ssh keyfile is used (recommended), provide here the path. 
# If ssh key is not used, and password is used instead, leave this empty and 
# you will be prompted for the password.
KEYFILE=/home/oracle/sshkeys/myprivatekey.id

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



###########################################################################
# Checks on input parameters
###########################################################################

if [ -z "${ORIGIN_FOLDER}" ]; then
        echo "Error: ORIGIN_FOLDER not passed as input parameter"
        exit 1
else
        echo "ORIGIN_FOLDER is ......$ORIGIN_FOLDER"
fi


if [ -z "${DEST_FOLDER}" ]; then
        echo "Error: DEST_FOLDER not passed as input parameter"
        exit 1
else
        echo "DEST_FOLDER is ......$DEST_FOLDER"
fi


if [ -z "${REMOTE_NODE}" ]; then
        echo "Error: REMOTE_NODE not passed as input parameter"
        exit 1
else
        echo "REMOTE_NODE is ......$REMOTE_NODE"
fi


if [ -z "${EXCLUDE_LIST}" ]; then
        echo "Note: EXCLUDE_LIST not passed as input parameter. No files will be excluded from the rsync copy"
elif [[ ${EXCLUDE_LIST} = "--exclude" ]] || [[ ${EXCLUDE_LIST} = "--exclude " ]];then
        echo "Error: EXCLUDE_LIST looks truncated. Pass the exclude list using double quotes"
        exit 1
elif [[ ${EXCLUDE_LIST} = "--exclude"* ]] || [[ ${EXCLUDE_LIST} = " --exclude"* ]];then
        echo "EXCLUDE_LIST is ..........$EXCLUDE_LIST"
else
        echo "Error: EXCLUDE_LIST does not have expected format"
        exit 1
fi

if [ ! -d "$LOGDIR" ]; then
	echo "Error: the folder $LOGDIR (for output logs) does not exist"
	exit 1
fi
	
###########################################################################





###########################################################################
# FUNCTIONS TO COPY A FOLDER TO REMOTE NODE AND VALIDATE THE COPY
###########################################################################
date_label=$(date '+%d-%m-%Y-%H-%M-%S')
LOG_FILE=${LOGDIR}/rsync_${date_label}.log


copy_to_remote(){
	if [ -z "$KEYFILE" ]; then
		SSH_OPTION=""
	else
		SSH_OPTION="-e \"ssh -i ${KEYFILE}\""
	fi
	
	if [ "$DELETE" = true ] ; then
		DELETE_OPTION="--delete"
	else
		DELETE_OPTION=""
	fi

	echo "" | tee -a ${LOG_FILE}
	echo "Copying ${ORIGIN_FOLDER} to ${REMOTE_NODE}:${DEST_FOLDER} ..."  | tee -a ${LOG_FILE}
	rsync_command="rsync ${SSH_OPTION} -avz ${DELETE_OPTION}  --stats --modify-window=1 ${EXCLUDE_LIST} ${ORIGIN_FOLDER}/ ${USER}@${REMOTE_NODE}:${DEST_FOLDER}/"
	echo $rsync_command
	eval $rsync_command >> ${LOG_FILE}
}

validate_copy(){
	echo "" | tee -a ${LOG_FILE}
	echo "Validating the copy.."  | tee -a ${LOG_FILE}
	max_rsync_retries=4
	stilldiff="true"
        diff_file=${LOG_FILE}_diffs
	rsync_compare_command="rsync ${SSH_OPTION} -niaHc ${EXCLUDE_LIST} ${ORIGIN_FOLDER}/ ${USER}@${REMOTE_NODE}:${DEST_FOLDER}/ --modify-window=1"
	rsync_pending_command="rsync ${SSH_OPTION} --stats --modify-window=1 --files-from=${diff_file}_pending ${ORIGIN_FOLDER}/ ${USER}@${REMOTE_NODE}:${DEST_FOLDER}/"
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
				echo "******************************WARNING:************************************************************" 2>&1 | tee -a ${LOG_FILE}
				echo "Copy retried $max_rsync_retries and there are still differences between" 2>&1 | tee -a ${LOG_FILE}
				echo "source and target directories (besides the explicitly excluded files)." 2>&1 | tee -a ${LOG_FILE}
				echo "It is recommended to verify that the copied domain files are valid in your secondary location." 2>&1 | tee -a ${LOG_FILE}
				echo "To perform this verification, convert the standby database to snapshot and start the secondary WLS domain servers" 2>&1 | tee -a ${LOG_FILE}
				echo "**************************************************************************************************" 2>&1 | tee -a ${LOG_FILE}
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

}

###########################################################
# Perform the copy and validation
###########################################################
copy_to_remote
if [ "$VALIDATE" = true ] ; then
	validate_copy
fi
