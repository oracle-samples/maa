hybrid_dr scripts version 1.0.

Copyright (c) 2022 Oracle and/or its affiliates
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/

Other scripts for WLS Hybrid DR
===================================
Additional util and example scripts to use as described in the playbooks:  
https://docs.oracle.com/en/solutions/soa-dr-on-cloud/index.html  
https://docs.oracle.com/en/solutions/weblogic-server-dr-on-cloud/index.html  

### update_dbconnect.sh
This script can be used to automatically replace the database connect string in the datasources and jps files (see the point
"1.	Prepare the datasources in primary" in the Hybrid DR documents for more details).
Usage:
- Edit the script and provide the values for ORIGINAL_STRING and NEW_STRING.
- Run the script in the admin server host (it makes the replacement in the ASERVER_HOME).
- A complete WLS domain restart is needed for the changes to take effect: 
    - stop managed servers and Admin server.
    - start the Admin server first, and once in running, start the managed servers.

