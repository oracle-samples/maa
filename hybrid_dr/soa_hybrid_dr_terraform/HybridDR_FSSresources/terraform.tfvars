## SOA Hybrid dr terraform scripts v 1.0
###
### Copyright (c) 2022 Oracle and/or its affiliates
### Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
###

## These are sample values. Customize with the values of your environment

## OCI Provider details
tenancy_ocid     = "ocid1.tenancy.oc1..aaaaaaaa7dkeohv7arjwvdgobyqml2vefxxrokon3f2bxo6z6e2odqxsklgq"
user_ocid        = "ocid1.user.oc1..aaaaaaaa77pn6uke4zyxeumfxv4tfyveensu5doteepq6d7jqaubes3fsq4q"
fingerprint      = "5c:44:53:23:4c:a6:20:76:34:9c:0d:ae:98:28:e6:ba"
private_key_path = "/home/opc/TERRAFORM_TESTS/my_keys/oracleidentitycloudservice_iratxe.etxebarria-02-28-08-31.pem"
region           = "us-ashburn-1"

# Other
compartment_id = "ocid1.compartment.oc1..aaaaaaaa6zlezuvycwpmaiyuunyfqrunkcutyl3faqfhi6x6qdtd2vathgya"
fss_subnet_id  = "ocid1.subnet.oc1.iad.aaaaaaaaumvx7pap2ujt46quweatpgogxybvgdtz2dj2kztyqr6c46osa4kq"

# Availability Domain(s) of th eSOA midtiers
AD1_name = "efXT:US-ASHBURN-AD-1"
AD2_name = "efXT:US-ASHBURN-AD-2" # Leave this empty if all the SOA hosts are in the same AD

# Mount target names
mounttarget1_displayname = "SOADRmountTarget"
mounttarget2_displayname = "SOADRmountTarget2" # Leave this empty if all the SOA hosts are in the same AD

# Filesystem names
sharedconfig_FSSname = "soadrconfigFSS"
runtime_FSSname      = "soadrruntimeFSS"
products1_FSSname    = "soadrproducts1FSS"
products2_FSSname    = "soadrproducts2FSS"

# Export Paths
sharedconfig_exportpath = "/export/soadrconfig"
runtime_exportpath      = "/export/soadrruntime"
products1_exportpath    = "/export/soadrproducts1"
products2_exportpath    = "/export/soadrproducts2"

