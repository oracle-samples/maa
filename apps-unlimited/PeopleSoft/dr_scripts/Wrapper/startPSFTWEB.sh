#!/bin/sh
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
# Errors:
#
# Revisions:
# Date       Who
# 7/1/2023   DPresley
############################################################################

SCRIPT_DIR=/u02/app/psft/PSFTRoleChange
PS_DOMAIN=HR92U033

# Start the Coherence*Web cache server first.  
"$SCRIPT_DIR"/startCacheServer.sh "$PS_DOMAIN" 

# Start the PIA web server.
"$SCRIPT_DIR"/startWS.sh "$PS_DOMAIN" 

# Don't return control until Coherence and the web server have started
wait
