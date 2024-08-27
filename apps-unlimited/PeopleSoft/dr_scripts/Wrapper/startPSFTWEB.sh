#!/bin/bash
############################################################################
#
#
# File name:    startPSFTWEB.sh    Version 1.0
#
# Copyright (c) 2024 Oracle and/or its affiliates
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
#
# Description:  Start the Coherence*Web cache server then the PIA web server
# 
# Usage:        startPSFTWEB.sh
# 
# Errors:       Any errors from dependent scripts.
#
############################################################################

source ~/psft.env
source "${SCRIPT_DIR}"/psrsync.env

HOSTNAME="$(hostname)"
DATE_TIME="$(date +"%Y%m%d_%H%M%S")"

# Start the Coherence*Web cache server first. 
"${SCRIPT_DIR}"/startCacheServer.sh "${PS_PIA_DOMAIN}" > "${LOG_DIR}"/"${HOSTNAME}"_startCacheServer_"${DATE_TIME}".log 2>&1

# Start the PIA web server.
"${SCRIPT_DIR}"/startWS.sh "${PS_PIA_DOMAIN}"  > "${LOG_DIR}"/"${HOSTNAME}"_startWS_"${DATE_TIME}".log 2>&1

# Don't return control until Coherence and the web server have started
wait
