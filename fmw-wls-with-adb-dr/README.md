Oracle FMW-WLS with Autonomous Database Shared's Remote Refreshable Clones Disaster Protection scripts  
Copyright (c) 2022 Oracle and/or its affiliates  
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/  

Using the Oracle FMW-WLS with Autonomous Database Shared's Remote Refreshable Clones Disaster Protection scripts  
=================================================================================================================

This directory contains scripts and utilities to configure and manage FMW DR with ADBS using Cross Region Refreshable Clones. Refer to the Oracle Architecture Center Playbook for details: https://docs.oracle.com/en/solutions/adb-refreshable-clones-dr/index.html 


IMPORTANT: Read and complete all the pre-requisites and steps per the isntructions in the paper above before using these scripts directly.

Usage 
--------------
  Each script provides automation for different parts of the DR setup and lifecycle of a disaster protection system. 
  The following table provides a summary of the utilities
  
  
  | Script name  | Description |
| ------------- | ------------- |
| [fmwadbs_change_to_tns_alias.sh](./fmwadbs_change_to_tns_alias.sh) | This script can be used to replace the connect strings used by WLS datasources and jps config files with a tns alias. |
| [fmwadbs_config_replica.sh](./fmwadbs_config_replica.sh) | This script is used to replicate configuration between sites. |
| [fmwadbs_dec_pwd.sh](./fmwadbs_dec_pwd.sh) | This script decrypts a WLS-encrypted password. |
| [fmwadbs_dr_prim.sh](./fmwadbs_dr_prim.sh) | Prepares a primary site for the DR setup. |
| [fmwadbs_dr_stby.sh](./fmwadbs_dr_stby.sh) | Prepares a secondary site for the DR setup. |
| [fmwadbs_enc_pwd.sh](./fmwadbs_enc_pwd.sh) | This script encrypts a password using WLS encryption. |
| [fmwadbs_get_connect_string.sh](./fmwadbs_get_connect_string.sh) | This script returns the connect string that a WLS/SOA/FMW datasource is using. |
| [fmwadbs_get_ds_property.sh](./fmwadbs_get_ds_property.sh) | This script returns the value of a specific datasource property. |
| [fmwadbs_rest_api_listabds.sh](./fmwadbs_rest_api_listabds.sh) | This script is used to obtain the Autonomous Database role base on the ADB ID and tenancy information. |
| [fmwadbs_switch_db_conn.sh](./fmwadbs_switch_db_conn.sh) | This script replaces the existing connect information with a new ADBS WALLET. |
