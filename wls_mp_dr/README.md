Oracle WebLogic for OCI Disaster Protection scripts  
Copyright (c) 2023 Oracle and/or its affiliates  
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/  
  

Using the Oracle WebLogic for OCI Disaster Protection scripts  
==============================================

Please refer to the following whitepaper for details about the topology and set up automated by these scripts:
https://www.oracle.com/a/otn/docs/middleware/maa-wls-mp-dr.pdf

IMPORTANT: Verify that you have completed all the pre-requisites listed in paper above before using this scripts. 
These scripts depend on the common scripts of app_dr_common.


Usage 
--------------
  Each script provides automation for different parts of the DR setup and lifecycle of a disaster protection system. 
  The following table provides a summary of the utilities
  
  
  | Script name  | Description |
| ------------- | ------------- |
| [fmw_dr_setup_primary.sh](./fmw_dr_setup_primary.sh) | This script prepares the WLS for OCI primary system for Disaster Protection .|
| [fmw_dr_setup_standby.sh](./fmw_dr_setup_standby.sh) | This script prepares the WLS for OCI secondary system for Disaster Protection. |
| [config_replica.sh](./config_replica.sh) | This script is used to replicate WLS domain configuration from primary to standby. It runs in primary and secondary. |
| [fmw_sync_in_primary.sh](./fmw_sync_in_primary.sh) | _Referenced by other scripts_. This script copies the WebLogic domain contents from the domain folder to the staging folder. Used by **config_replica.sh** when the system is PRIMARY role. |
| [fmw_sync_in_standby.sh](./fmw_sync_in_standby.sh) | _Referenced by other scripts_. This script copies the WebLogic domain contents from the staging folder to the domain folder. Used by **config_replica.sh** when the system is STANDBY role. |
| [Block_Volume_Replica_Method/](./Block_Volume_Replica_Method/) | This folder contains scripts specific to the Block Volume Cross-region replica DR model. |
