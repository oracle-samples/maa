Oracle WebLogic for OCI Disaster Protection scripts  
Copyright (c) 2022 Oracle and/or its affiliates  
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/  
  

Using the Oracle WebLogic for OCI Disaster Protection scripts  
==============================================

Please refer to the following whitepaper for details about the topology and set up automated by these scripts:
https://www.oracle.com/a/otn/docs/middleware/maa-wls-mp-dr.pdf

IMPORTANT: Verify that you have completed all the pre-requisites listed in paper above
 before using this scripts.


Usage 
--------------
  Each script provides automation for different parts of the DR setup and lifecycle of a disaster protection system. 
  The following table provides a summary of the utilities
  
  
  | Script name  | Description |
| ------------- | ------------- |
| [dbfs_dr_setup_root.sh](./dbfs_dr_setup_root.sh) | This scripts is needed ONLY when DBFS is used as a staging directory for WLS domain configuration. It sets up a DBFS mount point for a table in the Database used by WLS. |
| [fmw_dr_setup_primary.sh](./fmw_dr_setup_primary.sh) | This script prepares the WLS for OCI primary system for Disaster Protection .|
| [fmw_dr_setup_standby.sh](./fmw_dr_setup_standby.sh) | This script prepares the WLS for OCI secondary system for Disaster Protection. |
| [config_replica.sh](./config_replica.sh) | This script is used to replicate WLS domain configuration from primary to secondary. |
| [updateDBServiceName.sh](./updateDBServiceName.sh) | This script updates the connection string in the datasources and in jps files.. |
| [scripts_BV_replica_model](./scripts_BV_replica_model) | This folder contains scripts specific to the Block Volume Cross-region replica DR model.. |


