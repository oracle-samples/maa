#!/bin/bash
## rsync_copy_and_validate.sh version 1.0.
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##
### This script is used to perform an rsync copy "from" or "to" a remote node and validate the contets replicated.
### In context of a Oracle FMW 14.1.2 Disaster Recovery sytem, this scripts is invoked by rsync_for_WLS
### to replicate the OHOME, WebLogic Domain Direcotry etc.

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


if [ -z "${REMOTE_NODE}" ]; then
        echo "Error: REMOTE_NODE not passed as input parameter"
        exit 1
else
        echo "-REMOTE_NODE:"
     	echo "			$REMOTE_NODE"
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

copy_from_remote(){
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
	echo ""
        echo "" | tee -a ${LOG_FILE}
        echo "Copying from ${REMOTE_NODE}:${DEST_FOLDER} to ${ORIGIN_FOLDER}..."  | tee -a ${LOG_FILE}
        rsync_command="rsync ${SSH_OPTION} -avz ${DELETE_OPTION}  --stats --modify-window=1 ${EXCLUDE_LIST} ${USER}@${REMOTE_NODE}:${DEST_FOLDER}/ ${ORIGIN_FOLDER}/"
	echo "(You can check rsync command and exclude list in ${LOG_FILE})"
        eval $rsync_command >> ${LOG_FILE}
	echo ""
}




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
	echo ""
	echo "" | tee -a ${LOG_FILE}
	echo "Copying ${ORIGIN_FOLDER} to ${REMOTE_NODE}:${DEST_FOLDER}..."  | tee -a ${LOG_FILE}
	echo ""
	rsync_command="rsync ${SSH_OPTION} -avz ${DELETE_OPTION}  --stats --modify-window=1 ${EXCLUDE_LIST} ${ORIGIN_FOLDER}/ ${USER}@${REMOTE_NODE}:${DEST_FOLDER}/"
	echo ""
	echo "(Check rsync command nd exclud elist used in ${LOG_FILE})"
	eval $rsync_command >> ${LOG_FILE}
	echo ""
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
				echo ""
				echo "Check log file at ${LOG_FILE}"
				echo "The differences reported are :"
				cat $diff_file
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

#copy_to_remote
copy_from_remote

echo "rsync copy complete! "
echo ""

if [ "$VALIDATE" = true ] ; then
	echo "Running rsync validation..."
	validate_copy
	echo " rsync validation complete!"

fi
