## SOA Hybrid dr terraform scripts v 1.0
###
### Copyright (c) 2022 Oracle and/or its affiliates
### Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
###
#
## OCI Provider details
tenancy_ocid     = "ocid1.tenancy.oc1..aaaaaaaa7dkeo77777777777777777777okon3f2bxo6z6e2odqxsklgq"
user_ocid        = "ocid1.user.oc1..aaaaaaaa77pn6uke444444444444444444445doteepq6d7jqaubes3fsq4q"
fingerprint      = "5c:55:55:55:55:55:55:55:55:55:55:55:55:55:55:55a"
private_key_path = "/home/opc/my_keys/oracleidentitycloudservice_user.names-02-28-08-31.pem"
region           = "us-ashburn-1"

# Other
compartment_id = "ocid1.compartment.oc1..aaaaaaaa6zlezuvy333333333333333333yl3faqfhi6x6qdtd2vathgya"
fss_subnet_id  = "ocid1.subnet.oc1.iad.aaaaaaaamoieko4dy44444444444444444njfuju5py2ibfa2z6cespsovma"

# Availability Domain(s) of the WLS midtiers
AD1_name = "efXT:US-ASHBURN-AD-1"
AD2_name = "efXT:US-ASHBURN-AD-2" # Leave this empty if all the midtier hosts are in the same AD

# Mount target names
mounttarget1_displayname = "WLSDRmountTarget1"
mounttarget2_displayname = "WLSDRmountTarget2" # Leave this empty if all the midtier hosts are in the same AD

# Filesystem names
sharedconfig_FSSname = "wlsdrconfigFSS"
runtime_FSSname      = "wlsdrruntimeFSS"
products1_FSSname    = "wlsdrproducts1FSS"
products2_FSSname    = "wlsdrproducts2FSS"

# Export Paths
sharedconfig_exportpath = "/export/wlsdrconfig"
runtime_exportpath      = "/export/wlsdrruntime"
products1_exportpath    = "/export/wlsdrproducts1"
products2_exportpath    = "/export/wlsdrproducts2"

