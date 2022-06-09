hybrid_dr scripts version 1.0.

Copyright (c) 2022 Oracle and/or its affiliates
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/


Summary of the scripts for Hybrid DR
=====================================

rsync_copy_and_validate.sh
---------------------------
Script that copies a folder to a remote host. It also performs a checksum validation of the copy.
Usage:
- Edit the script and customize the values in the "Internal parametrizable values" section (KEYFILE, USER, etc.).
- Run the script providing the required input parameters:
rsync_copy_and_validate.sh [ORIGIN_FOLDER] [DEST_FOLDER] [REMOTE_NODE] "[EXCLUDE_LIST]"

NOTE: "EXCLUDE_LIST" is an optional parameter. If provided, it must be passed between double quotas because it contains blank spaces. 
The format is the same than the exclude list of the rsync command.
For example: "--exclude 'dir1/' --exclude 'dir2/'"

example_rync_XXXXX.sh scripts
------------------------------
These are example scripts that use the generic "rsync_copy_and_validate.sh" script to perform the copy of the FMW folders
from primary midtiers to standby midtiers:
- example_rsync_SHAREDCONFIG_to_SOA1.sh    Example script to copy the WLS shared config to a remote node
- example_rsync_SHAREDRUNTIME_to_SOA1.sh   Example script to copy the shared runtime to a remote node
- example_rsync_LOCALCONFIG_to_SOA1.sh     Example script to copy the local config to a remote node
- example_rsync_PRODUCTS_to_SOA1.sh        Example script to copy the products folder to a remote node
- example_rsync_orainventory_to_SOA1.sh    Example script to copy the orainventory folder to a remote node

These examples are provided for 1 soa host. To copy the private folders (products, local config, orainventory) to other soa hosts,
create similar scripts (example_rsync_LOCALCONFIG_to_SOA2.sh, example_rsync_PRODUCTS_to_SOA2.sh) as per your needs.

Usage: 
- Edit each script and customize the values in the "CUSTOM VALUES" section (remote node, folders,etc.).
- Make sure that the scripts are located in the same folder than the script rsync_copy_and_validate.sh
- Run it from the appropriate host. No input parameters are required.

update_dbconnect.sh
----------------------
This script can be used to automatically replace the database connect string in the datasources and jps files (see the point
"1.	Prepare the datasources in primary" in the Hybrid DR document for more details).
Usage:
- Edit the script and provide the values for ORIGINAL_STRING and NEW_STRING.
- Run the script in the admin server host (it makes the replacement in the ASERVER_HOME).
- A complete WLS domain restart is needed for the changes to take effect: 
    - stop managed servers and Admin server.
    - start the Admin server first, and once in running, start the managed servers.
