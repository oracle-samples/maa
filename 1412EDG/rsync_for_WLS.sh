#!/bin/bash
## rsync_for_WLS.sh version 1.0.
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##
### This script is used to perform an rsync (over ssh) copy of the required directories for a FMW Disaster Recovery system.
### Refer to the Oracle FMW 14.1.2 Disaster Recovery Guide for details on the different replication approaches that
### can be used for FMW Disaster Recovery topology.  
### This script is a wrapper that invokes rsync_copy_and_validate.sh. This second script contains the real logic to perform 
### rysnc copies with the recommended rsync configuration and also executes a thorough validation of files after the copy.
### If any differences are detected after several validations retries, these are logged so that they can be acted upon.
### By default the script performs a pull from a remote node and copies the pertaining directory to the same folder in the node where it is executed.
### It can be customizez together with rsync_copy_and_validate.sh to operate in a "push" model copying local folder to remote nodes.
### Usage:
###
###      	./rsync_for_WLS.sh [REMOTE_NODE_IP] [REMOTE_FOLDER] [SSH_SSH_KEYFILE]
### Where:
###		REMOTE_NODE_IP:
###			The IP of the nodes where things are copied from.
###		REMOTE_FOLDER:
###			The directory that will be copied n the exact same path in this node.
###		SSH_SSH_KEYFILE:
###			The ssh key file to be used for the ssh connection used by rsync (can be skiped if password-based ssh is used)
### Use the script separately for each type of data in your WebLogic Domain. 
### For example:
### -To replicate the primary system's ORACLE_HOME and JDK location used in the Enteprise Deployment Guide:
### rsync_for_WLS.sh 172.11.2.113 /u01/oracle/products /home/oracle/keys/SSHKey.priv"
### -To replicate the primary system's WebLogic Domain shared configuration used in the Enteprise Deployment Guide:
### rsync_for_WLS.sh 172.11.2.113 /u01/oracle/config /home/oracle/keys/SSHKey.priv"
### -To replicate the primary system's WebLogic Domain private configuration used in the Enteprise Deployment Guide:
### rsync_for_WLS.sh 172.11.2.113 /u02/oracle/config /home/oracle/keys/SSHKey.priv"


if [[ $# -eq 3 ]];
then
	REMOTE_NODE=$1
	LOCAL_CONFIG_FOLDER=$2
	SSH_KEYFILE=$3
	export SSH_KEYFILE
elif [[ $# -eq 2 ]];
then
	REMOTE_NODE=$1
        LOCAL_CONFIG_FOLDER=$2
else
    	echo ""
    	echo "ERROR: Incorrect number of parameters used: Expected 2 or 3, got $#"
    	echo ""
    	echo "Usage:"
	echo ""
	echo "-To run rsync using a keyfile for the ssh connection use this syntax: (ssh key-file needs to be set up before running the script)"
    	echo "    $0 [REMOTE_NODE_IP] [REMOTE_FOLDER] [SSH_SSH_KEYFILE]"
	echo ""
	echo "-To run rsync using a password-based ssh connection use this syntax: (password-based ssh needs to be set up before running the script)"
	echo "    $0 [REMOTE_NODE] [DIRECTORY]"
	echo ""
    	echo "Examples:  "
    	echo "    $0 172.11.2.113 /u01/oracle/products /home/oracle/keys/SSHKey.priv"
	echo ""
	echo "    $0 172.11.2.113 /u01/oracle/products"
    	exit 1
fi
###########################################################################
# CUSTOM VALUES
###########################################################################


ORIGIN_FOLDER=$LOCAL_CONFIG_FOLDER

if [ -z "${DEST_FOLDER}" ]; then
	echo ""
	echo "(Variable DEST_FOLDER is not set so will use same path in target as in source for the copy.)"
	DEST_FOLDER=$LOCAL_CONFIG_FOLDER
else
        echo "WIll use $DEST_FOLDER as local path for copy"
fi

# Provide custom exclude list. These folders/files will not be included in the rsync copy
#CUSTOM_EXCLUDE_LIST="--exclude dir1/ --exclude dir2/"
CUSTOM_EXCLUDE_LIST=""

###########################################################################
# END OF CUSTOM VALUES
###########################################################################
export exec_path="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

##########################################################################
# PREPARE VARIABLES AND RUN THE SCRIPT THAT PERFORMS THE COPY
###########################################################################

EXCLUDE_LIST_MSERVER="--exclude .snapshot --exclude '*/servers/*/data/nodemanager/*.lck' --exclude '*/servers/*/data/nodemanager/*.pid' --exclude '*/servers/*/data/nodemanager/*.state' --exclude 'servers/*/tmp' "
EXCLUDE_LIST_NM="--exclude 'nodemanager/*.id' --exclude 'nodemanager/*.lck'"
EXCLUDE_LIST="${CUSTOM_EXCLUDE_LIST} ${EXCLUDE_LIST_MSERVER} ${EXCLUDE_LIST_NM}"

# Run the script
mkdir -p $LOCAL_CONFIG_FOLDER
$exec_path/rsync_copy_and_validate.sh $ORIGIN_FOLDER $DEST_FOLDER $REMOTE_NODE true "$EXCLUDE_LIST"
