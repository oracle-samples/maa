#!/bin/sh
############################################################################
#
# File name:    enable_psft_rsync.sh    Version 1.0
#
# Copyright (c) 2024 Oracle and/or its affiliates
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
#
# Description:  Set the environment up so that the file system will be 
#               replicated
# 
# Usage:        enable_psft_rsync.sh <fully qualified path/name of run env file>
# 
# Errors:       No run environment file specified
#               Cannot find run environment file
#
# Revisions:
# Date       Who        What
# 7/1/2023   DPresley   Created
############################################################################

# Enable the PeopleSoft rsync job.

if [ $# -eq 0 ]
then
    echo "No run env file supplied.  Please provide a run env. file."
    echo "Usage:     enable_psft_rsync.sh <run env file>"
    echo "Example:   enable_psft_rsync.sh fs1"
    exit 1
fi

if  [ ! -f "$1" ]
then
     echo "File $1 does not exist."
     exit 1
fi

source ~/psft.env
source "$SCRIPT_DIR"/psrsync.env
source "$1"

if [ -f "${SCRIPT_DIR}/.${FS_ALIAS}_rsync_disabled" ]
then
     rm -f "${SCRIPT_DIR}"/."${FS_ALIAS}"_rsync_disabled
     echo "PeopleSoft rsync job for ${FS_ALIAS} enabled."
else
     echo "PeopleSoft rsync job for ${FS_ALIAS} already enabled."
fi

exit 0
