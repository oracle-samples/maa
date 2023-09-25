hybrid_dr scripts version 1.0.

Copyright (c) 2023 Oracle and/or its affiliates
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/

Rsync scripts for WLS Hybrid DR
================================================================
Rsync util and example scripts to use as described in the playbooks:  
https://docs.oracle.com/en/solutions/soa-dr-on-cloud/index.html  
https://docs.oracle.com/en/solutions/weblogic-server-dr-on-cloud/index.html  

### rsync_copy_and_validate.sh
Main script that copies a folder to a remote host. It also performs a checksum validation of the copy.
Usage:
- Edit the script and customize the values in the "Internal parametrizable values" section (KEYFILE, USER, etc.).
- Run the script providing the required input parameters:
rsync_copy_and_validate.sh [ORIGIN_FOLDER] [DEST_FOLDER] [REMOTE_NODE] "[EXCLUDE_LIST]"

NOTE: "EXCLUDE_LIST" is an optional parameter. If provided, pass it between double quotas because it contains blank spaces. 
The format is the same than the exclude list of the rsync command.
For example: "--exclude 'dir1/' --exclude 'dir2/'"

###  example_rync_XXXXX.sh scripts
Example scripts that use the "rsync_copy_and_validate.sh" script to perform the copy of the FMW folders
from primary to standby:
- example_rsync_SHAREDCONFIG_to_WLS1.sh    Example script to copy the WLS shared config to a remote midtier node
- example_rsync_SHAREDRUNTIME_to_WLS1.sh   Example script to copy the shared runtime to a remote midtier node
- example_rsync_LOCALCONFIG_to_WLS1.sh     Example script to copy the local config to a remote midtier node
- example_rsync_PRODUCTS_to_WLS1.sh        Example script to copy the MW products folder to a remote midtier node
- example_rsync_orainventory_to_WLS1.sh    Example script to copy the orainventory folder to a remote midtier node
- example_rsync_OHSCONFIG_to_OHS1.sh       Example script to copy the OHS config to a remote webtier node
- example_rsync_PRODUCTS_to_OHS1.sh        Example script to copy the OHS products folder to a remote webtier node

These examples assume that the script runs in the host where the origin content resides.
These examples are provided for one host only (e.g. SOA1, OHS1, etc). To copy the non-shared folders (products, local config, orainventory) to other hosts (WLS2, OHS2, etc), create similar scripts (e.g. example_rsync_LOCALCONFIG_to_WLS2.sh, example_rsync_PRODUCTS_to_WLS2.sh) as per your needs. Then run them in the appropriate origin host.


Usage: 
- Edit each script and customize the values in the "CUSTOM VALUES" section (remote node, folders, etc.).
- Make sure that the script is located in the same folder than the script rsync_copy_and_validate.sh
- Run it from the appropriate host. No input parameters are required.
