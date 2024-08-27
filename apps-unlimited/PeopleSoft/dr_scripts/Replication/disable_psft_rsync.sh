#!/bin/bash
############################################################################
#
# File name:     disable_psft_rsync.sh    Version 1.0
#
# Copyright (c) 2024 Oracle and/or its affiliates
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
#
# Description: Set the file system up to disable rsync.  Do this when
#              switching the roles of primary and standby sites
# 
# Usage:        disable_psft_rsync.sh <full path/name of fs env file>
# Example:      disable_psft_rsync.sh /<path>/fs1
# 
# Errors:       No run environment file specified
#               Cannot find run environment file
#
############################################################################

if [ $# -eq 0 ]
then
    echo "No run env file supplied.  Please provide a run env. file."
    echo "Usage:     disable_psft_rsync.sh <run env file>"
    echo "Example:   disable_psft_rsync.sh fs1"
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
     echo "PeopleSoft rsync job for ${FS_ALIAS} already disabled."
else
     touch "${SCRIPT_DIR}"/."${FS_ALIAS}"_rsync_disabled
     echo "PeopleSoft rsync job for ${FS_ALIAS} disabled."
fi

exit 0
