## WLS Hybrid DR terraform scripts  
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

## OCI Provider details
tenancy_ocid     = "ocid1.tenancy.oc1......................o6z6e2odqxsklgq"
user_ocid        = "ocid1.user.o..........oteepq6d7jqaubes3fsq4q"
fingerprint      = "5c:4..........e6:ba"
private_key_path = "/home/opc/my_keys/oracleidentitycloudservice_key-02-28-08-31.pem"
region           = "us-ashburn-1"
compartment_id   = "ocid1.compartment.oc1...............td2vathgya"


### Properties for the OCI Load Balancer
LBR_display_name  = "HyLBR"
webtier_subnet_id = "ocid1.subnet.oc1......................ytfl3ipd2gqlgvfkq"
LBR_is_private    = "false"
LBR_shape         = "flexible"
LBR_minbw         = "10"
LBR_maxbw         = "100"

### Frontend hostname and ports
https_frontend        = "myhydrfrontend.example.com"
http_frontend         = "myhydrfrontend.example.com"
adminconsole_frontend = "myadminhydrfrontend.example.com"
internal_frontend     = "myinternalfrontend.example.com"           # Set it to "" if not used

frontend_https_port    = "443"
frontend_http_port     = "80"
frontend_admin_port    = "7001"
frontend_internal_port = "80"	     # Set it to "" if not used

### The SSL certificate
certificate_private_key_file        = "/home/opc/TERRAFORM_TESTS/my_keys/my_private.key"
certificate_public_certificate_file = "/home/opc/TERRAFORM_TESTS/my_keys/my_cert.pem"
certificate_ca_certificate_file     = "/home/opc/TERRAFORM_TESTS/my_keys/my_cert.pem"
certificate_passphrase  = ""	# Set it to "" if passphrase is not used

### If OHS is used between the OCI LBR and the WLS servers, set it to "true". Otherwise, set it to "false"
there_is_OHS       = "true"

## The file that contains the information about clusters, nodes, ports and urls
clusters_definition_file = "clusters_SOA_example.yaml"


############# ONLY IF OHS IS USED ###########################
## The IPs of the OHS servers. Provide them as ["ip_of_ohs1","ip_of_ohs2"] (if there are more OHS nodes, add them to the list aswell).
ohs_nodes_ips 	   	= ["10.1.112.11","10.1.112.12"]
## The listen ports of the OHS servers
ohs_httpconsoles_port = "7001"
ohs_http_port         = "8090"
ohs_httpinternal_port = "8091"     # Set it to "" if not used
########################################################

############# ONLY IF OHS IS NOT USED #######################
## The IP where Administration server listens
admin_vip     = "10.1.112.70"
### The Administration server HTTP port
wls_adminserver_port = "7001"

