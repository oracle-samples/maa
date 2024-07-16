#!/bin/sh
############################################################################
#
# File name:    startPSFTAPP.sh    Version 1.0
#
# Copyright (c) 2024 Oracle and/or its affiliates
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
#
# Description:  Call the scripts to start the application server and process
#               scheduler on this server.
#               Start the rsync process for both types of file systems being 
#               replicated.
# 
# Usage:        startPSFTAPP.sh
# 
# Errors:
#
# Revisions:
# Date       Who       What
# 7/1/2023   DPresley  Created
############################################################################

source /u02/app/psft/PSFTRoleChange/psrsync.env
PS_DOMAIN=HR92U033

# Set the process scheduler report distribution node before starting the 
# app and process scheduler. 
# DO NOT run set_ps_rpt_node.sh in the background.  The set_ps_rpt_node.sh 
# script must complete before startPS.sh and startAPP.sh scripts are executed.

"$SCRIPT_DIR"/set_ps_rpt_node.sh
"$SCRIPT_DIR"/startPS.sh "$PS_DOMAIN"  &
"$SCRIPT_DIR"/startAPP.sh "$PS_DOMAIN" &

# Enable the rsync scripts.
# Uncomment the below lines when you are ready to integrate the replicaton rsync scripts.
# Change the file systems files (fs1, fs2...) per your environment.

# "$SCRIPT_DIR"/enable_psft_rsync.sh "$SCRIPT_DIR"/fs1
# "$SCRIPT_DIR"/enable_psft_rsync.sh "$SCRIPT_DIR"/fs2
