Oracle FMW-WLS with Autonomous Database Disaster Protection scripts  
Copyright (c) 2022 Oracle and/or its affiliates  
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/  

Using the Oracle FMW-WLS with Autonomous Database Disaster Protection scripts  
=================================================================================================================

This directory contains scripts and utilities to configure and manage FMW DR with ADB. Refer to the Oracle Architecture Center Playbook for details: https://docs.oracle.com/en/solutions/adb-refreshable-clones-dr/index.html 


IMPORTANT: Read and complete all the pre-requisites and steps per the isntructions in the paper above before using these scripts directly.  
These scripts depend on the common scripts of app_dr_common.

Usage 
--------------
  Each script provides automation for different parts of the DR setup and lifecycle of a disaster protection system. 
  The following table provides a summary of the utilities
  
  
  | Script name  | Description |
| ------------- | ------------- |
| [fmwadb_config_replica.sh](./fmwadb_config_replica.sh) | This script is used to replicate configuration between sites. |
| [fmwadb_dr_prim.sh](./fmwadb_dr_prim.sh) | Prepares a primary site for the DR setup. |
| [fmwadb_dr_stby.sh](./fmwadb_dr_stby.sh) | Prepares a secondary site for the DR setup. |
| [fmwadb_rest_api_listabds.sh](./fmwadb_rest_api_listabds.sh) | This script is used to obtain the Autonomous Database role base on the ADB ID and tenancy information. |
| [fmwadb_switch_db_conn.sh](./fmwadb_switch_db_conn.sh) | This script replaces the existing connect information with a new ADBS WALLET. |
