## WLS Hybrid DR terraform scripts  
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

## These are sample values. Customize with the values of your environment

## OCI Provider details
tenancy_ocid     = "ocid1.tenancy.oc1..aaaaaaaa7dkeohv777777777777777xxrokon3f2bxo6z6e2odqxsklgq"
user_ocid        = "ocid1.user.oc1..aaaaaaaa77pn6uke4z444444444444444nsu5doteepq6d7jqaubes3fsq4q"
fingerprint      = "5c:55:55:55:55:55:55:55:55:55:55:55:55:55:55:55"
private_key_path = "/home/opc/my_keys/oracleidentitycloudservice_user.name-02-28-08-31.pem"
region           = "us-ashburn-1"

# Other
compartment_id = "ocid1.compartment.oc1..aaaaaaaa6zlez1111111111111111113faqfhi6x6qdtd2vathgya"
midtier_subnet_id  = "ocid1.subnet.oc1.iad.aaaaaaaavjs3j44444444444444ilgcfvwu36c4mwwerz6s6bkkq"

# Availability Domain(s) list, where you want the SOA midtiers to be provisioned. You can provide 1 AD or more.
AD_names = [ "efXT:US-ASHBURN-AD-1", "efXT:US-ASHBURN-AD-2"]
#AD_names = [ "efXT:US-ASHBURN-AD-1" ]

# Shape and images
shape    = "VM.Standard2.1"
image_id = "ocid1.image.oc1.iad.aaaaaaaapfdqrbk6n4txcqv5h5da3d5wyfi4h7jweomf4y5wb3tw2mfmn4dq" 

# Compute node names list. You can provide 1 or more.
midtier_hostnames   = [ "soanode1", "soanode2"]

# Public ssh key file path
ssh_public_key_path = "/home/opc/my_keys/my_ssh_key.pub" 

