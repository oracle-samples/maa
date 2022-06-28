## SOA Hybrid dr terraform scripts v 1.0
###
### Copyright (c) 2022 Oracle and/or its affiliates
### Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
###

## These are sample values. Customize with the values of your environment

## OCI Provider details
tenancy_ocid     = "ocid1.tenancy.oc1..aaaaaaaa7dkeohv7777777777777777777kon3f2bxo6z6e2odqxsklgq"
user_ocid        = "ocid1.user.oc1..aaaaaaaa77pn6uke4z444444444444444444doteepq6d7jqaubes3fsq4q"
fingerprint      = "5c:55:55:55:55:55:55:55:55:55:55:55:55:55:55:55"
private_key_path = "/home/opc/my_keys/oracleidentitycloudservice_user.name-02-28-08-31.pem"
region           = "us-ashburn-1"
compartment_id   = "ocid1.compartment.oc1..aaaaaaaa6zlezuv22222222222222yl3faqfhi6x6qdtd2vathgya"


### Network resources
# Names
vcn_name            = "HyTestVCN"
webtier_subnet_name = "webtierSubnet"
midtier_subnet_name = "midtierSubnet"
dbtier_subnet_name  = "dbtierSubnet"
fsstier_subnet_name = "fsstierSubnet"

# Public or private
webtier_is_private = "false"
midtier_is_private = "false"
dbtier_is_private  = "true"
fsstier_is_private = "true"

# CIDR ranges
vcn_CIDR     = "10.1.112.0/24"
webtier_CIDR = "10.1.112.0/26"
midtier_CIDR = "10.1.112.64/26"
dbtier_CIDR  = "10.1.112.128/26"
fsstier_CIDR = "10.1.112.192/26"
onprem_CIDR  = "10.100.100.0/24"

# Set to true if you want to add internet gateway
add_internet_gateway = "true"

### Ports for communications
ssh_port            = "22"
sqlnet_port         = "1521"
ons_port            = "6200"
frontend_https_port = "443"
frontend_http_port  = "80"
frontend_admin_port = "7001"
frontend_internal_port = "8888"
adminserver_port    = "7001"
wsmcluster_port     = "7010"
soacluster_port     = "8001"
osbcluster_port     = "8011"
esscluster_port     = "8021"
bamcluster_port     = "9001"

