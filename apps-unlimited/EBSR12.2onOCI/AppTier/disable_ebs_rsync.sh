#!/bin/sh
############################################################################
# File name:     disable_ebs_rsync.sh
#
# Copyright (c) 2025 Oracle and/or its affiliates
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/ 
# 
# Description:  Create the *_rsync_disabled file, showing file system
#               replication is not active at this site.  This must be set 
#               at the standby site.
# 
# Usage:        disable_ebs_rsync.sh <fully qualified name of run env file>
#               Can be called directly, but is called by stopEBS.sh
# 
# Errors:       No run environment file specified
#               Cannot find run environment file
#
# Revisions:
# Date       What
# 7/1/2023   Created
############################################################################
 
. ./ebsRsync.env

if [ $# -eq 0 ]
then
    echo "No run environment file supplied.  Please provide a run env file."
    echo "Usage:     disable_ebs_rsync.sh <run env file>"
    echo "Example:   disable_ebs_rsync.sh fastFiles.env"
    exit 1
fi

if  [ ! -f "$1" ]
then
    echo "File $1 does not exist."
    exit 1
fi
 
source $1

if [ -f "${SCRIPT_DIR}/.${fsAlias}_rsync_disabled" ]
then
    echo "EBS rsync job for ${fsAlias} already disabled."
else
    touch ${SCRIPT_DIR}/.${fsAlias}_rsync_disabled
    echo "EBS rsync job for ${fsAlias} disabled."
fi


