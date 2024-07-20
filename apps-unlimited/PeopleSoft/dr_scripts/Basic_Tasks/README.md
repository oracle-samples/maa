# Oracle Peoplesoft MAA Basic Task Scripts

     Version 1.0

Copyright (c) 2024 Oracle and/or its affiliates.

Released under the Universal Permissive License v1.0 as shown at
<https://oss.oracle.com/licenses/upl/>.


## Overview

These are simple scripts to start and stop the application server domain, the process scheduler domains, the PIA webserver domains and the Coherence*Web cache server.  These are stand-alone scripts that are run on each PeopleSoft middle tier node.  You can specify the domain name as a parameter to these scripts.

## Prerequisite

Ensure that the environment variables required for PeopleSoft applicaiton servers and web servers are properly defined.  These scripts must run on the appropriate PeopleSoft server.  


## Script Description

The table below provides the script name and its purpose.  

=====================================

| Script Name | Description |
| ------ | ------ |
| [startAPP.sh](./startAPP.sh) | Starts the PeopleSosft Applicaton Server domain. |
| [stopAPP.sh](./stopAPP.sh) | Shuts down the PeopleSoft Application Server domain. |
| [startPS.sh](startPS.sh) | Starts the PeopleSoft Process Scheduler domain. |
| [stopPS.sh](./stopPS.sh) | Shuts down the PeopleSoft Process Scheduler domain. |
| [startCacheServer.sh](./startCacheServer.sh) | Starts the Coherence*Web cache server.   |
| [stopCacheServer.sh](./stopCacheServer.sh) | Stops / kills the Coherence*Web cache server.   |
| [startWS.sh](./startWS.sh) | Starts the PIA web server domain.   |
| [stopWS.sh](./stopWS.sh) | Shuts down the PIA web server domain.  |
| [get_ps_domain.sh](./get_ps_domain.sh) | This script is called by the start and stop scripts listed above to determine the PeopleSoft domain for the application server, process scheduler and web servers. 

