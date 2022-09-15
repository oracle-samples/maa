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

# Provide the path of the shared config folders to copy
ASERVER_HOME=/u01/oracle/config/domains/mydomain
APPLICATION_HOME=/u01/oracle/config/applications/mydomain
DEPLOY_PLAN_HOME=/u01/oracle/config/dp/mydomain
KEYSTORE_HOME=/u01/oracle/config/keystores

# NOTE: this script performs the copy of each artifact in separated steps to provide more granularity.
# Alternatively, you could copy the whole /u01/oracle/config in one step.

###########################################################################
# END OF CUSTOM VALUES
###########################################################################


# Copy the ASERVER
##################################
ORIGIN_FOLDER=$ASERVER_HOME
DEST_FOLDER=$ASERVER_HOME
CUSTOM_EXCLUDE_LIST=""
EXCLUDE_LIST="${CUSTOM_EXCLUDE_LIST} --exclude 'servers/*/data/nodemanager/*.lck' --exclude 'servers/*/data/nodemanager/*.pid' --exclude 'servers/*/data/nodemanager/*.state' --exclude 'servers/*/tmp' "

./rsync_copy_and_validate.sh $ORIGIN_FOLDER $DEST_FOLDER $REMOTE_NODE "$EXCLUDE_LIST"


# Copy the APPLICATION_HOME
####################################
ORIGIN_FOLDER=${APPLICATION_HOME}
DEST_FOLDER=${APPLICATION_HOME}
EXCLUDE_LIST=""

./rsync_copy_and_validate.sh $ORIGIN_FOLDER $DEST_FOLDER $REMOTE_NODE "$EXCLUDE_LIST"

# Copy the Deploy plan home
##################################
ORIGIN_FOLDER=${DEPLOY_PLAN_HOME}
DEST_FOLDER=${DEPLOY_PLAN_HOME}
EXCLUDE_LIST=""

./rsync_copy_and_validate.sh $ORIGIN_FOLDER $DEST_FOLDER $REMOTE_NODE "$EXCLUDE_LIST"


# Copy the keystore home
##################################
ORIGIN_FOLDER=${KEYSTORE_HOME}
DEST_FOLDER=${KEYSTORE_HOME}
EXCLUDE_LIST=""

./rsync_copy_and_validate.sh $ORIGIN_FOLDER $DEST_FOLDER $REMOTE_NODE "$EXCLUDE_LIST"

