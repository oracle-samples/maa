## WLS Hybrid DR terraform scripts  
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

## These are sample values. Customize with the values of your environment

## OCI Provider details
tenancy_ocid     = "ocid1.tenancy.oc1..aaaaaaaa7dkeohv77777777777777xrokon3f2bxo6z6e2odqxsklgq"
user_ocid        = "ocid1.user.oc1..aaaaaaaa77pn6uke4z44444444444444nsu5doteepq6d7jqaubes3fsq4q"
fingerprint      = "5c:55:55:55:55:55:55:55:55:55:55:55:55:55:55:55"
private_key_path = "/home/opc/my_keys/oracleidentitycloudservice_user.name-02-28-08-31.pem"
region           = "us-ashburn-1"

# Other
compartment_id = "ocid1.compartment.oc1..aaaaaaaa6zle33333333333333333333l3faqfhi6x6qdtd2vathgya"

# Images Operating System
# Options: "Windows", "Canonical Ubuntu", "CentOS", "Oracle Autonomous Linux", "Oracle Linux", "Oracle Linux Cloud Developer"
image_os = "Oracle Linux"
