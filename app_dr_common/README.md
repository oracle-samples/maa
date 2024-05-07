Application DR common scripts  
Copyright (c) 2024 Oracle and/or its affiliates  
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/  
  

Using the Application DR common scripts  
==============================================
These are common scripts referenced by different Disaster Recovery documents.

 
  
  | Script name  | Description |
| ------------- | ------------- |
| [dbfs_dr_setup_root.sh](./dbfs_dr_setup_root.sh) | This script is needed ONLY when DBFS is used as a staging directory for WLS domain configuration. It sets up a DBFS mount point in a hosts: it installs Oracle Database Client, installs fuse, creates DBFS DB schemas, configures wallet and mounts DBFS file system. |
| [fmw_change_to_tns_alias.sh](./fmw_change_to_tns_alias.sh) | This script is used to replace current db connect string in datasources with a TNS alias. |
| [fmw_enc_pwd.sh](./fmw_enc_pwd.sh) | _Referenced by other scripts_. This script encrypts a password using WebLogic encryption. |
| [fmw_dec_pwd.sh](./fmw_dec_pwd.sh) | _Referenced by other scripts_. This script decrypts a password using WebLogic encryption. |
| [fmw_get_connect_string.sh](./fmw_get_connect_string.sh) | _Referenced by other scripts_. This script gets the connect string from a datasource file. |
| [fmw_get_dbrole_wlst.sh](./fmw_get_dbrole_wlst.sh) | _Referenced by other scripts_. This script gets the role of the database using WLST command. |
| [fmw_get_ds_property.sh](./fmw_get_ds_property.sh) | _Referenced by other scripts_. This script gets the value of a property from a datasource file. |
