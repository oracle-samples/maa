## SOA Hybrid dr terraform scripts v 1.0
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

## These are sample values. Customize with the values of your environment

## OCI Provider details
tenancy_ocid     = "ocid1.tenancy.oc1..aaaaaaaa7dkeo77777777777777777777okon3f2bxo6z6e2odqxsklgq"
user_ocid        = "ocid1.user.oc1..aaaaaaaa77pn6uke444444444444444444445doteepq6d7jqaubes3fsq4q"
fingerprint      = "5c:55:55:55:55:55:55:55:55:55:55:55:55:55:55:55a"
private_key_path = "/home/opc/my_keys/oracleidentitycloudservice_user.names-02-28-08-31.pem"
region           = "us-ashburn-1"
compartment_id   = "ocid1.compartment.oc1..aaaaaaaa6zlezuvycwpmaiyuunyfqrunkcutyl3faqfhi6x6qdtd2vathgya"


### Properties fot the OCI Load Balancer
LBR_display_name  = "HyLBR"
webtier_subnet_id = "ocid1.subnet.oc1.iad.aaaaaaaayzh2f222222222222222pj67kbb7job4cgrpxfqnwsujfkqq"
LBR_is_private    = "false"
LBR_shape         = "flexible"
LBR_minbw         = "10"
LBR_maxbw         = "100"

### Backends IPs
admin_vip     = "10.1.112.70"
# The IPs of the midtier nodes. Provide them as ["ip_of_midtier1","ip_of_midtier2"] (if there are more midtier nodes, add them to the list aswell.)
midtier_nodes_ips = ["10.1.112.65","10.1.112.66"]

### Ports
adminserver_port = "7001"
wsmcluster_port  = "7010"
soacluster_port  = "8001"
osbcluster_port  = "8011"
esscluster_port  = "8021"
bamcluster_port  = "9001"

### Frontend hostname and ports
https_frontend        = "myhydrfrontend.example.com"
http_frontend         = "myhydrfrontend.example.com"
adminconsole_frontend = "myhydrfrontend.example.com"
internal_frontend     = "myhydrfrontend.example.com"

frontend_https_port    = "443"
frontend_http_port     = "80"
frontend_admin_port    = "7001"
frontend_internal_port = "8888"

### The SSL certificate
certificate_private_key_file        = "/home/opc/my_keys/my_private.key"
certificate_public_certificate_file = "/home/opc/my_keys/my_cert.pem"
certificate_ca_certificate_file     = "/home/opc/my_keys/my_cert.pem"
certificate_passphrase  = ""	# Leave it empty if passphrase is not used

###
there_is_WSM = "true"
there_is_SOA = "true"
there_is_OSB = "true"
there_is_ESS = "true"
there_is_BAM = "true"
