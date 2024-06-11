############################################################################
#!/bin/sh
#
# File name:    stopPSFTWEB.sh    Version 1.0
#
# Copyright (c) 2022 Oracle and/or its affiliates
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

PS_DOMAIN=HR92U033

# Stop the PIA web server
$SCRIPT_DIR/stopWS.sh $PS_DOMAIN 

# Stop the Coherence*Web cache server
$SCRIPT_DIR/stopCacheServer.sh $PS_DOMAIN 

