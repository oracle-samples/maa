## SOA Hybrid dr terraform scripts v 1.0
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

terraform {
    required_providers {
        oci = {
            source  = "oracle/oci"
            version = ">= 4.0.0"
        }
    }
}


provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}


# Create the VCN
########################################################################################################
resource "oci_core_vcn" "my_vcn" {
  #Required
  compartment_id = var.compartment_id
  cidr_blocks    = [var.vcn_CIDR]
  display_name   = var.vcn_name
  dns_label      = var.vcn_name
}

# Create the subnets
########################################################################################################
resource "oci_core_subnet" "webtier_subnet" {
  #Required
  cidr_block                 = var.webtier_CIDR
  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.my_vcn.id
  display_name               = var.webtier_subnet_name
  prohibit_public_ip_on_vnic = var.webtier_is_private
  security_list_ids          = [oci_core_security_list.web_tier_security_list.id]

  #Other optional
  dns_label = var.webtier_subnet_name
  #availability_domain = var.subnet_availability_domain
  #defined_tags = {"Operations.CostCenter"= "42"}
  #dhcp_options_id = oci_core_dhcp_options.test_dhcp_options.id
  #freeform_tags = {"Department"= "Finance"}
  #ipv6cidr_block = var.subnet_ipv6cidr_block
  #prohibit_internet_ingress = var.subnet_prohibit_internet_ingress
  #route_table_id = oci_core_route_table.test_route_table.id

}

resource "oci_core_subnet" "midtier_subnet" {
  #Required
  cidr_block                 = var.midtier_CIDR
  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.my_vcn.id
  display_name               = var.midtier_subnet_name
  prohibit_public_ip_on_vnic = var.midtier_is_private
  security_list_ids          = [oci_core_security_list.mid_tier_security_list.id]

  #Other optional
  dns_label = var.midtier_subnet_name
  #availability_domain = var.subnet_availability_domain
  #defined_tags = {"Operations.CostCenter"= "42"}
  #dhcp_options_id = oci_core_dhcp_options.test_dhcp_options.id
  #freeform_tags = {"Department"= "Finance"}
  #ipv6cidr_block = var.subnet_ipv6cidr_block
  #prohibit_internet_ingress = var.subnet_prohibit_internet_ingress
  #route_table_id = oci_core_route_table.test_route_table.id
}

resource "oci_core_subnet" "dbtier_subnet" {
  #Required
  cidr_block                 = var.dbtier_CIDR
  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.my_vcn.id
  display_name               = var.dbtier_subnet_name
  prohibit_public_ip_on_vnic = var.dbtier_is_private
  security_list_ids          = [oci_core_security_list.db_tier_security_list.id]

  #Other optional
  dns_label = var.dbtier_subnet_name
  #availability_domain = var.subnet_availability_domain
  #defined_tags = {"Operations.CostCenter"= "42"}
  #dhcp_options_id = oci_core_dhcp_options.test_dhcp_options.id
  #freeform_tags = {"Department"= "Finance"}
  #ipv6cidr_block = var.subnet_ipv6cidr_block
  #prohibit_internet_ingress = var.subnet_prohibit_internet_ingress
  #route_table_id = oci_core_route_table.test_route_table.id
}

resource "oci_core_subnet" "fsstier_subnet" {
  #Required
  cidr_block                 = var.fsstier_CIDR
  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.my_vcn.id
  display_name               = var.fsstier_subnet_name
  prohibit_public_ip_on_vnic = var.fsstier_is_private
  security_list_ids = [oci_core_security_list.fss_tier_security_list.id]

  #Other optional    
  dns_label = var.fsstier_subnet_name
  #availability_domain = var.subnet_availability_domain
  #defined_tags = {"Operations.CostCenter"= "42"}
  #dhcp_options_id = oci_core_dhcp_options.test_dhcp_options.id
  #dns_label = var.subnet_dns_label
  #freeform_tags = {"Department"= "Finance"}
  #ipv6cidr_block = var.subnet_ipv6cidr_block
  #prohibit_internet_ingress = var.subnet_prohibit_internet_ingress
  #route_table_id = oci_core_route_table.test_route_table.id
  #security_list_ids = var.subnet_security_list_ids
}


# Create the security lists, one for each subnet.
########################################################################################################

resource "oci_core_security_list" "web_tier_security_list" {
  #Required
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.my_vcn.id
  display_name   = "web_tier_security_list"

  #Optional
  #defined_tags = {"Operations.CostCenter"= "42"}
  #freeform_tags = {"Department"= "Finance"}

  # Allow access to all inside this subnet's CIDR
  ingress_security_rules {
    #Required
    protocol = "all"
    source   = var.webtier_CIDR
    #Optional
    description = "Allow all inside this web-tier subnet"
    source_type = "CIDR_BLOCK"
    stateless   = "false"
  }

  # Allow access from on-prem to frontend ports (HTTP, HTTPS, internal, and Administration console)
  dynamic ingress_security_rules {
    for_each = [var.frontend_https_port, var.frontend_http_port, var.frontend_internal_port, var.frontend_admin_port]
    content {
    #Required
    protocol = "6" // TCP
    source   = var.onprem_CIDR
    #Optional
    description = "Allow access from on-prem network to frontend ${ingress_security_rules.value} port"
    source_type = "CIDR_BLOCK"
    stateless   = "false"
    tcp_options {
      min = ingress_security_rules.value
      max = ingress_security_rules.value
    }
    }
  }

  # Allow access from mid-tier to frontend ports (HTTPS, HTTP)
  dynamic ingress_security_rules {
    for_each = [ var.frontend_https_port, var.frontend_http_port ]
    content {
    #Required
    protocol = "6" // TCP
    source   = var.midtier_CIDR
    #Optional
    description = "Allow access from mid-tier network to frontend ${ingress_security_rules.value} port"
    source_type = "CIDR_BLOCK"
    stateless   = "false"
    tcp_options {
      min = ingress_security_rules.value
      max = ingress_security_rules.value
    }
    }
  }
  # Egresss rules from web-tier to mid-tier
  dynamic egress_security_rules {
    for_each = [ var.adminserver_port, var.wsmcluster_port, var.soacluster_port, var.osbcluster_port, var.esscluster_port, var.bamcluster_port ]
    content {
    #Required
    destination = var.midtier_CIDR
    protocol    = "6" // TCP

    #Optional
    description      = "Allow outgoing access from web-tier to mid-tier ${egress_security_rules.value} port "
    destination_type = "CIDR_BLOCK"
    stateless        = "false"
    tcp_options {
      min = egress_security_rules.value
      max = egress_security_rules.value
    }
    }
  }
}


resource "oci_core_security_list" "mid_tier_security_list" {
  #Required
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.my_vcn.id
  display_name   = "mid_tier_security_list"

  #Optional
  #defined_tags = {"Operations.CostCenter"= "42"}
  #freeform_tags = {"Department"= "Finance"}

  # Allow access to all inside this subnet's CIDR
  ingress_security_rules {
    #Required
    protocol = "all"
    source   = var.midtier_CIDR
    #Optional
    description = "Allow all inside this mid-tier subnet"
    source_type = "CIDR_BLOCK"
    stateless   = "false"
  }

  # Allow from on-prem to different ports
  dynamic ingress_security_rules {
    for_each = [ var.ssh_port, var.adminserver_port, var.wsmcluster_port, var.soacluster_port, var.osbcluster_port, var.esscluster_port, var.bamcluster_port ]
    content {
    #Required
    protocol = "6" // TCP
    source   = var.onprem_CIDR
    #Optional
    description = "Allow access from on-prem network to ${ingress_security_rules.value} port"
    source_type = "CIDR_BLOCK"
    stateless   = "false"
    tcp_options {
      min = ingress_security_rules.value
      max = ingress_security_rules.value
    }
    }
  }

  # Allow from we-tier to different ports
  dynamic ingress_security_rules {
    for_each = [ var.adminserver_port, var.wsmcluster_port, var.soacluster_port, var.osbcluster_port, var.esscluster_port, var.bamcluster_port ]
    content {
    #Required
    protocol = "6" // TCP
    source   = var.webtier_CIDR
    #Optional
    description = "Allow access from web-tier network to ${ingress_security_rules.value} port"
    source_type = "CIDR_BLOCK"
    stateless   = "false"
    tcp_options {
      min = ingress_security_rules.value
      max = ingress_security_rules.value
    }
    }
  }

  # Rules to access to FSS subnet
  # Stateful ingress from source mount target CIDR block TCP ports 111, 2048, 2049, and 2050 to ALL ports.
  # Stateful ingress from source mount target CIDR block UDP port 111 to ALL ports.
  ingress_security_rules {
    #Required
    protocol = "6" // TCP
    source   = var.fsstier_CIDR
    #Optional
    description = "Allow access from FSS-tier network  ports 111 to ALL (TCP)"
    source_type = "CIDR_BLOCK"
    stateless   = "false"
    tcp_options {
      source_port_range {
        min = "111"
        max = "111"
      }
    }
  }
  ingress_security_rules {
    #Required
    protocol = "6" // TCP
    source   = var.fsstier_CIDR
    #Optional
    description = "Allow access from FSS-tier network ports 2048, 2049, and 2050 to ALL ports (TCP)"
    source_type = "CIDR_BLOCK"
    stateless   = "false"
    tcp_options {
      source_port_range {
        min = "2048"
        max = "2050"
      }
    }
  }
  ingress_security_rules {
    #Required
    protocol = "17" // UDP
    source   = var.fsstier_CIDR
    #Optional
    description = "Allow access from FSS-tier network ports 111 to ALL (UDP)"
    source_type = "CIDR_BLOCK"
    stateless   = "false"
    udp_options {
      source_port_range {
        min = "111"
        max = "111"
      }
    }
  }
  # Stateful egress from ALL ports to destination mount target CIDR block TCP ports 111, 2048, 2049, and 2050.
  # Stateful egress from ALL ports to destination mount target CIDR block UDP ports 111 and 2048.
  egress_security_rules {
    #Required
    destination = var.fsstier_CIDR
    protocol    = "6" // TCP

    #Optional
    description      = "Allow outgoing access from ALL ports to FSS-tier network ports 111 (TCP)"
    destination_type = "CIDR_BLOCK"
    stateless        = "false"
    tcp_options {
      min = "111"
      max = "111"
    }
  }
  egress_security_rules {
    #Required
    destination = var.fsstier_CIDR
    protocol    = "6" // TCP

    #Optional
    description      = "Allow outgoing access from ALL ports to FSS-tier network ports 2048, 2049, and 2050 (TCP)"
    destination_type = "CIDR_BLOCK"
    stateless        = "false"
    tcp_options {
      min = "2048"
      max = "2050"
    }
  }

  egress_security_rules {
    #Required
    destination = var.fsstier_CIDR
    protocol    = "17" // UDP

    #Optional
    description      = "Allow outgoing access from ALL ports to FSS-tier network port 111(UDP)"
    destination_type = "CIDR_BLOCK"
    stateless        = "false"
    udp_options {
      min = "111"
      max = "111"
    }
  }

  egress_security_rules {
    #Required
    destination = var.fsstier_CIDR
    protocol    = "17" // UDP

    #Optional
    description      = "Allow outgoing access from ALL ports to FSS-tier network port 2048 (UDP)"
    destination_type = "CIDR_BLOCK"
    stateless        = "false"
    udp_options {
      min = "2048"
      max = "2048"
    }
  }
  # Egress rules from mid-tier to db-tier
  dynamic egress_security_rules {
    for_each = [ var.sqlnet_port, var.ons_port ]
    content {
    #Required
    destination = var.dbtier_CIDR
    protocol    = "6" // TCP

    #Optional
    description      = "Allow outgoing access from mid-tier to db-tier Database listener and ons ports "
    destination_type = "CIDR_BLOCK"
    stateless        = "false"
    tcp_options {
      min = egress_security_rules.value
      max = egress_security_rules.value
    }
    }
  }

  # Egress rules from mid-tier to on-prem SSH
  egress_security_rules {
    #Required
    destination = var.onprem_CIDR
    protocol    = "6" // TCP

    #Optional
    description      = "Allow outgoing access from mid-tier to on-prem SSH port "
    destination_type = "CIDR_BLOCK"
    stateless        = "false"
    tcp_options {
      min = var.ssh_port
      max = var.ssh_port
    }
  }

  # Egress rules from mid-tier to HTTPS (needed for SOA Callbacks to LBR )
  egress_security_rules {
    #Required
    destination = var.webtier_is_private ? var.webtier_CIDR : "0.0.0.0/0"
    protocol    = "6" // TCP

    #Optional
    description      = "Allow outgoing access from mid-tier to web-tier HTTPS port "
    destination_type = "CIDR_BLOCK"
    stateless        = "false"
    tcp_options {
      min = var.frontend_https_port
      max = var.frontend_https_port
    }
  }

}

resource "oci_core_security_list" "db_tier_security_list" {
  #Required
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.my_vcn.id
  display_name   = "db_tier_security_list"

  #Optional
  #defined_tags = {"Operations.CostCenter"= "42"}
  #freeform_tags = {"Department"= "Finance"}

  # Allow access to all inside this subnet's CIDR
  ingress_security_rules {
    #Required
    protocol = "all"
    source   = var.dbtier_CIDR
    #Optional
    description = "Allow all inside this db-tier subnet"
    source_type = "CIDR_BLOCK"
    stateless   = "false"
  }

  # Allow access from on-prem to SSH and SQLNET port
  dynamic ingress_security_rules {
    for_each = [ var.ssh_port, var.sqlnet_port ]
    content {
    #Required
    protocol = "6" // TCP
    source   = var.onprem_CIDR
    #Optional
    description = "Allow access from on-prem network to ${ingress_security_rules.value} port"
    source_type = "CIDR_BLOCK"
    stateless   = "false"
    tcp_options {
      min = ingress_security_rules.value
      max = ingress_security_rules.value
    }
    }
  }

  # Allow access from mid-tier to SQLNET and ONS ports
  dynamic ingress_security_rules {
    for_each = [ var.sqlnet_port, var.ons_port ]
    content {
    #Required
    protocol = "6" // TCP
    source   = var.midtier_CIDR
    #Optional
    description = "Allow access from mid-tier network to SQLNET and ONS ports"
    source_type = "CIDR_BLOCK"
    stateless   = "false"
    tcp_options {
      min = ingress_security_rules.value
      max = ingress_security_rules.value
    }
    }
  }

  # Egress rules from db-tier to on-prem
  egress_security_rules {
    #Required
    destination = var.dbtier_CIDR
    protocol    = "6" // TCP

    #Optional
    description      = "Allow outgoing access from db-tier to on-prem Database listener port "
    destination_type = "CIDR_BLOCK"
    stateless        = "false"
    tcp_options {
      min = var.sqlnet_port
      max = var.sqlnet_port
    }
  }

}


resource "oci_core_security_list" "fss_tier_security_list" {
  #Required
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.my_vcn.id
  display_name   = "fss_tier_security_list"

  #Optional
  #defined_tags = {"Operations.CostCenter"= "42"}
  #freeform_tags = {"Department"= "Finance"}

  # Allow access to all inside this subnet's CIDR
  ingress_security_rules {
    #Required
    protocol = "all"
    source   = var.fsstier_CIDR
    #Optional
    description = "Allow all inside this fss-tier subnet"
    source_type = "CIDR_BLOCK"
    stateless   = "false"
  }

  # Stateful ingress allow access from mid-tier to FSS (from ALL ports in the source instance CIDR block to TCP ports 111, 2048, 2049, and 2050)
  # Stateful ingress allow access from mid-tier to FSS (from ALL ports in the source instance CIDR block to UDP ports 111 and 2048)
  ingress_security_rules {
    #Required
    protocol = "6" // TCP
    source   = var.midtier_CIDR
    #Optional
    description = "Allow access from ALL ports in the mid-tier network to port 111 (TCP)"
    source_type = "CIDR_BLOCK"
    stateless   = "false"
    tcp_options {
      min = "111"
      max = "111"
    }
  }
  ingress_security_rules {
    #Required
    protocol = "6" // TCP
    source   = var.midtier_CIDR
    #Optional
    description = "Allow access from ALL ports in the mid-tier network to ports 2048, 2049, and 2050 (TCP)"
    source_type = "CIDR_BLOCK"
    stateless   = "false"
    tcp_options {
      min = "2048"
      max = "2050"
    }
  }
  ingress_security_rules {
    #Required
    protocol = "17" // UDP
    source   = var.midtier_CIDR
    #Optional
    description = "Allow access from ALL ports in mid-tier network to port 111 (UDP)"
    source_type = "CIDR_BLOCK"
    stateless   = "false"
    udp_options {
      min = "111"
      max = "111"
    }
  }
  ingress_security_rules {
    #Required
    protocol = "17" // UDP
    source   = var.midtier_CIDR
    #Optional
    description = "Allow access from ALL ports in mid-tier network to port 2048 (UDP)"
    source_type = "CIDR_BLOCK"
    stateless   = "false"
    udp_options {
      min = "2048"
      max = "2048"
    }
  }
  # Stateful egress from TCP ports 111, 2048, 2049, and 2050 to ALL ports in the destination instance CIDR block
  # Stateful egress from UDP port 111 ALL ports in the destination instance CIDR block.
  egress_security_rules {
    #Required
    destination = var.midtier_CIDR
    protocol    = "6" // TCP

    #Optional
    description      = "Allow outgoing from ports 111 to mid-tier network ALL ports (TCP)"
    destination_type = "CIDR_BLOCK"
    stateless        = "false"
    tcp_options {
      source_port_range {
        min = "111"
        max = "111"
      }
    }
  }
  egress_security_rules {
    #Required
    destination = var.midtier_CIDR
    protocol    = "6" // TCP

    #Optional
    description      = "Allow outgoing from ports 2048, 2049, and 2050 to mid-tier network ALL ports (TCP)"
    destination_type = "CIDR_BLOCK"
    stateless        = "false"
    tcp_options {
      source_port_range {
        min = "2048"
        max = "2050"
      }
    }
  }
  egress_security_rules {
    #Required
    destination = var.midtier_CIDR
    protocol    = "17" // UDP

    #Optional
    description      = "Allow outgoing from ALL ports to to mid-tier network ports 111 (UDP)"
    destination_type = "CIDR_BLOCK"
    stateless        = "false"
    udp_options {
      source_port_range {
        min = "111"
        max = "111"
      }
    }
  }


}

# (Optional) Create the Internet Gateway and route to the default route table
resource "oci_core_internet_gateway" "internet_gateway" {
    count = var.add_internet_gateway ? 1 : 0
    #Required
    compartment_id = var.compartment_id
    vcn_id = oci_core_vcn.my_vcn.id

    #Optional
    enabled = var.add_internet_gateway
    #defined_tags = {"Operations.CostCenter"= "42"}
    display_name = "Internet Gateway"
    #freeform_tags = {"Department"= "Finance"}
}

resource "oci_core_default_route_table" "default_route_table" {
    count = var.add_internet_gateway ? 1 : 0
    manage_default_resource_id = oci_core_vcn.my_vcn.default_route_table_id
    route_rules {
      #Required
      network_entity_id = oci_core_internet_gateway.internet_gateway[0].id
      destination = "0.0.0.0/0"
    }
}
