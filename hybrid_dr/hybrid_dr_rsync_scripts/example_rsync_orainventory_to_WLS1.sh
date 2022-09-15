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

# Provide the path of the ORAINVENTORY FOLDER
ORAINVENTORY_FOLDER=/u01/app/oraInventory

# Provide custom exclude list. Not needed for this case
CUSTOM_EXCLUDE_LIST=""

###########################################################################
# END OF CUSTOM VALUES
###########################################################################

###########################################################################
# PREPARE VARIABLES AND RUN THE SCRIPT THAT PERFORMS THE COPY
###########################################################################
ORIGIN_FOLDER=$ORAINVENTORY_FOLDER
DEST_FOLDER=$ORAINVENTORY_FOLDER
EXCLUDE_LIST="${CUSTOM_EXCLUDE_LIST}"
./rsync_copy_and_validate.sh $ORIGIN_FOLDER $DEST_FOLDER $REMOTE_NODE "$EXCLUDE_LIST"


