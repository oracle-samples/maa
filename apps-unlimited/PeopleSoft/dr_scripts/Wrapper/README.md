# Oracle Peoplesoft MAA Wrapper Scripts

     Version 1.0

Copyright (c) 2024 Oracle and/or its affiliates.

Released under the Universal Permissive License v1.0 as shown at
<https://oss.oracle.com/licenses/upl/>.

## Overview

These wrapper scripts coordinate the execution of the basic task scripts.  They also coordinate enabling or disabling the replication using the rsync replication scripts.  They are designed to be called from external components such as Oracle Cloud Infrastructure (OCI) Full Stack Disaster Recovery but can be run manually if needed.  

The wrapper scripts currently have the calls to the rsync scripts commented out.  Once the rsync scripts under the Replication folder are running properly, uncomment out the calls to the rsync scripts.

> [!NOTE]
> If you need to stop or start PeopleSoft components without enabling or disabling the rsync replication process, then use the stand-alone scripts in the Basic Task folder. 


## Prerequisites

The following prerequisites must be met for the wrapper scripts as designed to run in Oracle Cloud Infrastructure.  

*  The OCI command-line interface (CLI) must be installed on each middle tier where the wrapper scripts will run. 
*  The wrapper scripts must be able to access and run the basic task scripts.
*  The wrapper scripts must be able to access and run the rsync_psft.sh script.  


### About the set_ps_rpt_node.sh Script

The set_ps_rpt_node.sh script will set the distribution node for the PeopleSoft report repository.  This is a site specific setting as it is based on the name of the PIA web server node at each site.  Below is the ps_rpt.env file that is used by the set_ps_rpt_node.sh script.  Place both the script and the ps_rpt.env files at each sites.  Edit the ps_rpt.env file according to each site.  

Example ps_rpt.env

<pre>
# The following environment variables are used by the set_ps_rpt_node.sh script. 
# 
# Modify the following environment variables accordingly. 
# Set the RPT_URL_HOST to the distribution hostname.network-domain of one of a PIA web servers e.g., myhost.mycompany.com 
RPT_URL_HOST=< PIA Web Server hostname.domain > 
# Set RPT_URI_PORT to the http or https port of the PIA web server. 
RPT_URI_PORT=< http port number >
# SITE_NAME is the PIA web deployment site typically 'ps'. 
SITE_NAME=ps 
# PSFT_DOMAIN is set per the product.  For HCM, it is HRMS. 
PSFT_DOMAIN=HRMS 
# Set the PDB_NAME to the name of the Pluggable Database Name in which the PeopleSoft schema is stored. 
PDB_NAME=< PDB_NAME >
# Set SCHEMA_NAME to the database schema name within the pluggable database where the PeopleSoft schema is stored. 
SCHEMA_NAME=< Schema name > 

# Adjust the following two environment variables IF AND ONLY IF required.  Otherwise, leve them as they are set.  
# If SSL is enabled on the PIA web server, then you will need to change the protocol scheme to https for both URL and RPT_URI.
# NOTE: if SSL termination is at the load balancer, then the protocol should be set to http. 
URL="http://${RPT_URL_HOST}:${RPT_URI_PORT}/psreports/${SITE_NAME}" 
RPT_URI="http://${RPT_URL_HOST}:${RPT_URI_PORT}/psc/${SITE_NAME}/EMPLOYEE/${PSFT_DOMAIN}/c/CDM_RPT.CDM_RPT.GBL?Page=CDM_RPT_INDEX&Action=U&CDM_ID=" 
</pre>

## Script Description

The table below provides the script name and its purpose.  

=====================================

| Script Name | Description |
| ------ | ------ |
| [startPSFTAPP.sh](./startPSFTAPP.sh) | Starts the PeopleSoft Application Server domain and enbles replication of the middle tier file system. |
| [stopPSFTAPP.sh](./stopPSFTAPP.sh) | Shuts down the PeopleSoft Application Server domain and coordinates a final rsync of the file system to the remote site once all applicaon sessions have been shut down. |
| [startPSFTWEB.sh](./startPSFTWEB.sh) | Starts the Coherence*WSeb cache servers and the PIA Web Server domain. |
| [stopPSFTWEB.sh](./stopPSFTWEB.sh) | Stops the Coherence*WSeb cache servers and the PIA Server domain. |
| [set_ps_rpt_node.sh](./set_ps_rpt_node.sh) | Before the application and PIA domains can be started, this script is called by startPSFTAPP.sh to set the report server node for the site. |


