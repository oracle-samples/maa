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

# Provide the path of the products folder 
PRODUCTS_FOLDER=/u01/oracle/products

# Provide custom exclude list. These folders/files will not be included in the rsync copy
#CUSTOM_EXCLUDE_LIST="--exclude 'dir1/' --exclude 'dir/'"
CUSTOM_EXCLUDE_LIST=""

###########################################################################
# END OF CUSTOM VALUES
###########################################################################

###########################################################################
# PREPARE VARIABLES AND RUN THE SCRIPT THAT PERFORMS THE COPY
###########################################################################
ORIGIN_FOLDER=${PRODUCTS_FOLDER}
DEST_FOLDER=${PRODUCTS_FOLDER}
EXCLUDE_LIST="${CUSTOM_EXCLUDE_LIST}"
./rsync_copy_and_validate.sh $ORIGIN_FOLDER $DEST_FOLDER $REMOTE_NODE "$EXCLUDE_LIST"

