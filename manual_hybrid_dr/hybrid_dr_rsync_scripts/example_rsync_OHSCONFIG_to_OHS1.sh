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
REMOTE_NODE=hydrohs1.webtiersubnet.hydrvcn.oraclevcn.com

# Provide the path of the local config folder that containes the MSERVER and NM_HOME folders
OHS_CONFIG_FOLDER=/u02/oracle/config/

# Provide custom exclude lists (e.g. other domains in the folder that should no be copied)
# Example: CUSTOM_EXCLUDE_LIST="--exclude 'dir1/' --exclude 'dir/'"
CUSTOM_EXCLUDE_LIST=""

###########################################################################
# END OF CUSTOM VALUES
###########################################################################


##########################################################################
# PREPARE VARIABLES AND RUN THE SCRIPT THAT PERFORMS THE COPY
###########################################################################
ORIGIN_FOLDER=$OHS_CONFIG_FOLDER
DEST_FOLDER=$OHS_CONFIG_FOLDER
EXCLUDE_LIST="${CUSTOM_EXCLUDE_LIST}"
# Run the script
./rsync_copy_and_validate.sh $ORIGIN_FOLDER $DEST_FOLDER $REMOTE_NODE "$EXCLUDE_LIST"
