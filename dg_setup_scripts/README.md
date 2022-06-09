dg_setup_scripts version 1.0.   
Copyright (c) 2022 Oracle and/or its affiliates  
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/  
  

### Scripts for configuring Oracle Data Guard
-------------------------------------------------------------------------------------------
These scripts setup a standby database for an existing primary database using the "restore from service" feature and Data Guard Broker.

#### Assumptions
-------------------------------------------------------------------------------------------
- The primary database already exists.
- The standby system already exists, with or without an existing database. If there is an existing database in the standby, the scripts will delete it before recreating the new one as standby.
- There is connectivity between primary and standby to the listener port. I.e:  
For single instances: primary db host must be able to connect to standby's listener's IP and port, and viceversa.  
For RAC: primary db hosts must be able to connect to standby's scan and vip IPs and ports, and viceversa.  
The command "nc -vw 5 -z IP PORT" can be used to verify remote connectivity.
- ASM is used for datafiles, archivelogs, etc.
- Primary and standby databases are managed by clusterware (i.e. there is a Grid Infrastructure installation, "srvctl" is used both in single and RAC topologies..)
- The parameters "db_create_file_dest", "db_create_online_log_dest_1", and "db_recovery_file_dest" are already defined in the primary DB.
- The RDBMS sofware owner (e.g. "oracle" user) loads the oracle environment variables (ORACLE_HOME, LD_LIBRARY_PATH, etc.) in its profile.
- It is assumed that a symmetric topology is used (i.e. if primary is single DB, standby is single DB; if primary is a RAC DB, standby is a RAC DB too).
- If the databases are RAC, it is assumed that each RAC has 2 nodes.
- The scripts are intended to add one standby DB (i.e. the scripts are not designed to add an additional standby DB to an existing Data Guard).

#### Features
-------------------------------------------------------------------------------------------
- The scripts can be re-executed (idem-potency).
- The operating system user names (e.g. oracle, grid) and folders (DB home, Grid home) are configurable.
- The Oracle and Grid OS user can be the same user or different users.
- Transparent Data Encryption (TDE) is optional: the scripts are valid for both cases (TDE and no TDE).
- Read Only Oracle Home (ROOH) can be used. The scripts are prepared to automatically work in environments with ROOH and with "traditional" Oracle homes.
- The scripts are validated in 12c (12.2), 18c, 19c and 21c RDBMS versions.
- The scripts are validated in Oracle Cloud Infrastructure (DB Systems) and in on-prem environment.
- The scripts are valid both for RAC and single environments (in a symmetric topology).

#### Scripts
-------------------------------------------------------------------------------------------
The following files are included:
- 1_prepare_primary_maa_parameters.sh  
This script prepares the primary database with the recommended MAA parameters for Data Guard (standby redolog, DB_BLOCK_CHECKSUM, etc.).
This is required to be run only one time, regardless primary is a RAC or a single instance.
- 2_dataguardit_primary.sh  
This script prepares the primary host(s) for the Data Guard (create the required tns aliases, check connectivity, create required output tar files, etc.).
- 3_dataguardit_standby_root.sh  
This script prepares the standby host(s) and creates the standby database using the "restore from service" feature and DG Broker.
- create_pw_tar_from_asm_root.sh  
This script is required only when the primary password file is stored in ASM.
- DG_properties.ini  
This is the property file. Is used by all the scripts both in primary and standby. It needs to be customized with the environment's specific values.

#### Instructions to run the scripts
-------------------------------------------------------------------------------------------
Steps to use the scripts for configuring Oracle Data Guard for an existing primary database:

##### 1.- Edit the DG_properties.ini file and customize it with the environment's specific values.
Each parameter is self-explained. The file contains all the input parameters required by the scripts.

##### 2.- Upload these files to the primary db host(s) (grant execute permissions for "oracle" OS user):
1_prepare_primary_maa_parameters.sh  
2_dataguardit_primary.sh  
create_pw_tar_from_asm_root.sh  
DG_properties.ini
 
##### 3.- Upload these files to the standby db host(s) (grant execute permissions for root OS user):  
3_dataguardit_standby_root.sh  
DG_properties.ini

##### 4.- Run the script "1_prepare_primary_maa_parameters.sh"
Where to run:     In PRIMARY db host1  
Run with user:    oracle  
This script will connect to primary database and configure the recommended MAA parameters for Data Guard. The parameters that are going to be set are listed at the beginning of the script.  
NOTE: DB_BLOCK_CHECKING on the PRIMARY is recommended to be set to MEDIUM or FULL. The script sets it to FULL. If the performance overhead of enabling DB_BLOCK_CHECKING to MEDIUM or FULL is unacceptable on your primary database, then set DB_BLOCK_CHECKING to MEDIUM or FULL for your standby database only.

##### 5.- Run the script "2_dataguardit_primary.sh"
Where to run:     In PRIMARY db host(s).  If RAC: run first in the primary db host 1, and then in the primary db host 2.  
Run with user:    oracle  
This script prepares the primary host(s) for the Data Guard. Only when it is required, the script's output will ask user to run the create_pw_tar_from_asm_root.sh.

##### 6.- Copy the output tar files generated in step 5 to the secondary db node(s).
These output files are: the TAR of the password file, and the TAR of the TDE wallet (when used).  

##### 7.- Run the script "3_dataguardit_standby_root.sh"
Where to run:     In STANDBY db host(s).  If RAC: run first in the standby db host 1, and then in standby db host 2.  
Run with user:    root  
This script prepares the standby host(s), creates the standby database using the "restore from service" feature, and configures the DG Broker.  
In case of a RAC, most of the actions are performed when it runs in the first node, and only a subset of the steps are performed when it runs in the secondary node of the RAC.
NOTE: in case there are environment values that differ from primary (i.e. the ORACLE_HOME path, the Grid OS user, etc.) make sure you update the DG_properties.ini file accordingly in the standby db hosts.
