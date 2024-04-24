## WLS Hybrid DR terraform scripts
###
### Copyright (c) 2022 Oracle and/or its affiliates
### Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
###

## OCI Provider details
tenancy_ocid     = "ocid1.tenancy.oc1................kon3f2bxo6z6e2odqxsklgq"
user_ocid        = "ocid1.user.oc1..................eepq6d7jqaubes3fsq4q"
fingerprint      = "5c:44:53:.....98:28:e6:ba"
private_key_path = "/home/opc/my_keys/oracleidentitycloudservice_user.name-02-28-08-31.pem"
region           = "us-ashburn-1"

# Compartment and subnet
compartment_id = "ocid1.compartment....................fhi6x6qdtd2vathgya"
subnet_id      = "ocid1.subnet.oc1.iad...........................wb5iereqryqfbiafguba"

# Availability Domain list, where the midtiers compute will be provisioned. You can provide 1 AD or more.
AD_names = ["efXT:US-ASHBURN-AD-1", "efXT:US-ASHBURN-AD-2"]
#AD_names = [ "efXT:US-ASHBURN-AD-1" ]

# Shape and images
shape      = "VM.Standard2.1"

# The WebLogic edition (EE, Suite) for UCM images
edition    = "Suite"

# The os version(7.9 or 8.5) for the images
os_version = "8.5"

# Compute node names list. You can provide 1 or more.
midtier_hostnames = ["hywlsnode1", "hywlsnode2"]

# Public ssh key file path
ssh_public_key_path = "/home/opc/TERRAFORM_TESTS/my_keys/my_ssh_key.pub"

