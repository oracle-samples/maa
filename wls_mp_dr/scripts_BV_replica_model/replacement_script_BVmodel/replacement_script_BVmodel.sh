## replacement_script_BVmodel.sh
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

##############################################################################################################
# Replacement script for Disaster Recovery based on Block Volume Cross-region Replication
# After a switchover, once the replicated block volumes have been attached and mounted to the mid-tier hosts,
# this script performs the required replacements of the Database connect string 
# in the WebLogic Domain configuration
##############################################################################################################

##############################################################################################################
# Customize the following values

# Provide the PDB service name used by the datasources in THIS site
LOCAL_PDB_SERVICE="PDB1.mysubnet1.myvcn1.oraclevcn.com"
# Provide the PDB service name used by the datasources in the REMOTE site
REMOTE_PDB_SERVICE="PDB1.mysubnet2.myvnc2.oraclevcn.com"

# Provide the database scan name used by the datasources in THIS site
LOCAL_DB_SCAN_NAME="mydbhosta-scan.mysubnet1.myvnc1.oraclevcn.com"
# Provide the database scan name used by the datasources in the REMOTE site
REMOTE_DB_SCAN_NAME="mydbhostb-scan.mysubnet2.myvcn2.oraclevcn.com"

##############################################################################################################


# Check that this is running by oracle
if [ "$(whoami)" != "oracle" ]; then
	echo "Script must be run as user: oracle"
	exit 1
fi


replace_connect_info(){
        echo ""
        echo "************** REPLACE INSTANCE SPECIFIC DB CONNECT INFORMATION ***************************"
        cd ${DOMAIN_HOME}/config/
        echo "String for remote PDB service ...................." ${REMOTE_PDB_SERVICE}
        echo "String for local PDB service .................." ${LOCAL_PDB_SERVICE}
        find . -name '*.xml' | xargs sed -i 's|'${REMOTE_PDB_SERVICE}'|'${LOCAL_PDB_SERVICE}'|gI'

        echo "String for remote SCAN name ...................." ${REMOTE_DB_SCAN_NAME}
        echo "String for local SCAN name .................." ${LOCAL_DB_SCAN_NAME}
        find . -name '*.xml' | xargs sed -i 's|'${REMOTE_DB_SCAN_NAME}'|'${LOCAL_DB_SCAN_NAME}'|gI'

        echo "Replacement in ${DOMAIN_HOME}/config/ complete!"
        echo ""
}

replace_tnsnamesora(){
	if [ -d "${DOMAIN_HOME}/dbfs" ]; then
	        cd ${DOMAIN_HOME}/dbfs/
        	echo "Replacing instance specific in tnsnames.ora..."
        	sed -i 's|'${REMOTE_PDB_SERVICE}'|'${LOCAL_PDB_SERVICE}'|g' tnsnames.ora
        	sed -i 's|'${REMOTE_DB_SCAN_NAME}'|'${LOCAL_DB_SCAN_NAME}'|g' tnsnames.ora
        	echo "Replacement complete!"
	fi
}
remove_tmp_lck_files(){
	rm ${DOMAIN_HOME}/servers/*/data/nodemanager/*.lck
	rm ${DOMAIN_HOME}/servers/*/data/nodemanager/*.state
}


replace_connect_info
replace_tnsnamesora
remove_tmp_lck_files
