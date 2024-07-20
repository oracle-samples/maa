#!/bin/sh
############################################################################
#
#
# File name:    stopPSFTWEB.sh    Version 1.0
#
# Copyright (c) 2024 Oracle and/or its affiliates
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
#
# Description: Stop the PIA web server then the Coherence*Web cache server
# 
# Usage:       stopPSFTWEB.sh
# 
# Errors:
#
# Revisions:
# Date       Who
# 7/1/2023   DPresley
############################################################################

source ~/psft.env
source "${SCRIPT_DIR}"/psrsync.env

HOSTNAME="$(hostname)"
DATE_TIME="$(date +"%Y%m%d_%H%M%S")"

# Stop the PIA web server
"${SCRIPT_DIR}"/stopWS.sh "${PS_PIA_DOMAIN}" > "${LOG_DIR}"/"${HOSTNAME}"_stopWS_"${DATE_TIME}".log 2>&1

# Stop the Coherence*Web cache server
"${SCRIPT_DIR}"/stopCacheServer.sh "${PS_PIA_DOMAIN}" > "${LOG_DIR}"/"${HOSTNAME}"_stopCacheServer_"${DATE_TIME}".log 2>&1


