## private_dns_views_for_dr terraform scripts
###
### Copyright (c) 2022 Oracle and/or its affiliates
### Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
###

## OCI Provider details
tenancy_ocid     = "ocid1.tenancy.oc1..aaaaaaaa7dkeohjhfyhsi888888888883f2bxo6z6e2odqxsklgq"
user_ocid        = "ocid1.user.oc1..aaaaaaaa77pn6uke4zyxeu7777777777777eepq6d7jqaubes3fsq4q"
fingerprint      = "5c:44:53:23:4J:a6:20:77:33:9c:9f:ae:98:28:e6:ba"
private_key_path = "/home/opc/my_keys/oracleidentitycloudservice_user.name-02-28-08-31.pem"
primary_region		= "uk-london-1"
secondary_region	= "eu-frankfurt-1"

# Flags
configure_in_primary	= "true"
configure_in_secondary	= "true"

# Compartments
primary_compartment_id = "ocid1.compartment.oc1..aaaaaaaaigp2uohnf76yogdrew5id656565656xdxkufjtefw53je5fz6eia"
secondary_compartment_id = "ocid1.compartment.oc1..aaaaaaaaigp2uohnf76yogdre787787878787878xkufjtefw53je5fz6eia"

# VCNs
primary_vcn_id  = "ocid1.vcn.oc1.uk-london-1.amaaaaaaj4y3nwqaehecgek67g2l787878787878787t6vwr6xy23676a"
secondary_vcn_id = "ocid1.vcn.oc1.eu-frankfurt-1.amaaaaaaj4y3nwqadefr454545454545isxmqzksnoixkihm45gmq"

# Primary domain, hosts fqdns and IPs. Order must be consistent
# If the WLS servers listen in virtual hostnames instead of in the physical hostnames, provide the virtual names here.
# Otherwise, provide the physical hostnames.
primary_domain="primsubnet.primvcn.oraclevcn.com"
primary_nodes_fqdns=["mynode1.primsubnet.primvcn.oraclevcn.com","mynode2.primsubnet.primvcn.oraclevcn.com"]
primary_nodes_IPs=["111.111.111.111","111.111.111.112"]


# Secondary domain, hosts fqdns and IPs. Order must be consistent
secondary_domain="secsubnet.secvcn.oraclevcn.com"
secondary_nodes_fqdns=["mynode1.secsubnet.secvcn.oraclevcn.com","mynode2.secsubnet.secvcn.oraclevcn.com"]
secondary_nodes_IPs=["222.222.222.221","222.222.222.222"]

# Predefined values
primary_private_view_name    = "TESTS_Private_View_for_DR_in_Primary"
secondary_private_view_name  = "TESTS_Private_View_for_DR_in_Secondary"

