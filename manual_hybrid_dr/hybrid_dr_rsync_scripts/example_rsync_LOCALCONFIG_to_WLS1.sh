#!/bin/bash
## hybrid_dr scripts version 1.0.
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

###########################################################################
# CUSTOM VALUES
###########################################################################

# Provide the remote node hostname or IP
REMOTE_NODE=hostwls1.example.com

# Provide the path of the local config folder that containes the MSERVER and NM_HOME folders
LOCAL_CONFIG_FOLDER=/u02/oracle/config

# Provide custom exclude list. These folders/files will not be included in the rsync copy
#CUSTOM_EXCLUDE_LIST="--exclude dir1/ --exclude dir2/"
CUSTOM_EXCLUDE_LIST=""

###########################################################################
# END OF CUSTOM VALUES
###########################################################################


##########################################################################
# PREPARE VARIABLES AND RUN THE SCRIPT THAT PERFORMS THE COPY
###########################################################################
ORIGIN_FOLDER=$LOCAL_CONFIG_FOLDER
DEST_FOLDER=$LOCAL_CONFIG_FOLDER
EXCLUDE_LIST_MSERVER="--exclude '*/servers/*/data/nodemanager/*.lck' --exclude '*/servers/*/data/nodemanager/*.pid' --exclude '*/servers/*/data/nodemanager/*.state' --exclude 'servers/*/tmp' "
EXCLUDE_LIST_NM="--exclude 'nodemanager/*.id' --exclude 'nodemanager/*.lck'"
EXCLUDE_LIST="${CUSTOM_EXCLUDE_LIST} ${EXCLUDE_LIST_MSERVER} ${EXCLUDE_LIST_NM}"

# Run the script
./rsync_copy_and_validate.sh $ORIGIN_FOLDER $DEST_FOLDER $REMOTE_NODE "$EXCLUDE_LIST"
