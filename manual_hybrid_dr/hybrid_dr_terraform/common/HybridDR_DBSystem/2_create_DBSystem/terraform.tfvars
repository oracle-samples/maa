## WLS Hybrid DR terraform scripts  
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

## These are sample values. Customize with the values of your environment

## OCI Provider details
tenancy_ocid     = "ocid1.tenancy.oc1..aaaaaaaa7dk7777777777777777777777777n3f2bxo6z6e2odqxsklgq"
user_ocid        = "ocid1.user.oc1..aaaaaaaa77pn6u6666666666666666666666666teepq6d7jqaubes3fsq4q"
fingerprint      = "5c:55:55:55:55:55:55:55:55:55:55:55:55:55:55:55"
private_key_path = "/home/opc/my_keys/oracleidentitycloudservice_user.name-02-28-08-31.pem"
region           = "us-ashburn-1"

# Compartment ocid, Availability Domain name, and Subnet ocid
compartment_id      = "ocid1.compartment.oc1..aaaaaaaa6zle1111111111111111111111faqfhi6x6qdtd2vathgya"
availability_domain = "efXT:US-ASHBURN-AD-1"
dbtier_subnet_id    = "ocid1.subnet.oc1.iad.aaaa222222222222222222222222222nnogg5ragtx5e2oa26qxttvdkq"

# DB System name
db_system_display_name = "hydb"

# Public ssh key file path
ssh_public_key_path = "/home/opc/my_keys/my_ssh_key.pub"

# DB node Shape. You can use "1_get_DBSystem_shapes_and_versions" to get the available shape names.
shape = "VM.Standard2.1"
# The number of CPU cores to enable for Bare Metal. This property will be ignored for VM (virtual machine DB systems have a fixed number of cores for each shape)
cpu_core_count = "1"
# Database version number. You  can use "1_get_DBSystem_shapes_and_versions" to get the available version numbers.
# Example: 19.12.0.0, 21.0.0.0
# NOTE: values XX.0.0.0 will provisiion the latest PSU available for the version XX.
db_version = "19.12.0.0"
# Licensing model: "BRING_YOUR_OWN_LICENSE" or "LICENSE_INCLUDED"
db_system_license_model = "BRING_YOUR_OWN_LICENSE"
# Database Edition. Accepted values are "STANDARD_EDITION", "ENTERPRISE_EDITION", "ENTERPRISE_EDITION_HIGH_PERFORMANCE", "ENTERPRISE_EDITION_EXTREME_PERFORMANCE"
# (for RAC "ENTERPRISE_EDITION_EXTREME_PERFORMANCE" is required)
db_system_database_edition = "ENTERPRISE_EDITION_EXTREME_PERFORMANCE"

# Number of nodes
node_count = "1"

# DB hostname prefix
db_hostname_prefix = "hydb"
# Database Name
DBName = "ORCL"
# Suffix for Database unique name. The db unique name will be <BName>_DB_unique_name_suffix>
DB_unique_name_suffix = "OCIDR"
# Prefix for database SID
#database_sid_prefix = "CDBSID"
# The name for the PDB
PDBName = "PDB1"

# Database user sys's password. If not set here, it will be interactively requested
sys_password = 

