# Oracle Peoplesoft MAA Disaster Recovery Scripts

     Version 1.0

Copyright (c) 2022, 2024 Oracle and/or its affiliates.

Released under the Universal Permissive License v1.0 as shown at
<https://oss.oracle.com/licenses/upl/>.

## Using the PeopleSoft MAA DR Scripts

Please refer to the following playbooks for details about the PeopleSoft topology, set up and how these scripts are to be used.

* PeopleSoft Planning Playbook (Link to be added)

* PeopleSoft Deployment Playbook (Link to be added)

> [!IMPORTANT] 
> Verify that you have completed all the pre-requisites listed in the appropriate playbooks above before using these scripts.

## Scrips Overview

The scripts for this project fall into one of the following categories:

1.	Basic task stand-alone PeopleSoft startup and shutdown scripts
2.	Rsync scripts that replicate middle tier file system contents from one site to another 
3.	Wrapper scripts that call the stand-alone scripts plus enable or disable rsync replication, depending on which wrapper script is run

These scripts can be used by OCI Full Stack DR Cloud Service (FSDR) to automate switchover and failover.  The rsync scripts will handle file system role transition for the application and web tiers.

The scripts should be placed in a common location at each site that all application and web tier compute instances can access.  In this project, we created the following directory location on each site’s shared storage, and labeled it $SCRIPT_DIR in our .env file:
/u02/app/psft/pt/custom_admin_scripts

As these scripts are used by administrators, it is advisable to add the scripts directory to the administrator account’s PATH.

ALWAYS test these scripts on a test environment before promoting them to a production environment.

## Summary of the Scripts

The scripts are grouped in folders as shown in the table below.  

=====================================

| Folder | Content |
| ------ | ------ |
| Basic Tasks | Startup and shutdown scripts for PeopleSoft component e.g., applicaiotn server, process scheduler, PIA web server, Coherence Web*Cache. |
| Replication | Scripts that replicate the middle tier file sstems from the primary to the DR site using rsync. |
| Wrapper | Scrips that auomate the startup, shutdown and redirect replication. |

