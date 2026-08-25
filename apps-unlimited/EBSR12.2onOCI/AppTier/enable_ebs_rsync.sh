#!/bin/sh
############################################################################
# File name:    enable_ebs_rsync.sh
#
# Copyright (c) 2025 Oracle and/or its affiliates
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/ 
# 
# Description:  Remove the *_rsync_disabled file, thus telling the rsync 
#               script to be active here.
# 
# Usage:        enable_ebs_rsync.sh <fully qualified name of run env file>
#               Can be called directly, but is called by the startEBS.sh 
#               script.
# 
# Errors:       No run environment file specified
#               Cannot find run environment file
#
# Revisions:
# Date       What
# 9/26/2024  Base updates
# 7/1/2023   Created
############################################################################

# Enable the EBS rsync job.

. ./ebsRsync.env

if [ $# -eq 0 ]
then
    echo "No run env file supplied.  Please provide a run env. file."
    echo "Usage:     enable_ebs_rsync.sh <run env file>"
    echo "Example:   enable_ebs_rsync.sh fastFiles.env"
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
    rm -f ${SCRIPT_DIR}/.${fsAlias}_rsync_disabled
    echo "EBS rsync job for ${fsAlias} enabled."
else
    echo "EBS rsync job for ${fsAlias} already enabled."
fi


