## WLS Hybrid DR terraform scripts  
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



########################################################################################################
# Create the Load Balancer
########################################################################################################
resource "oci_load_balancer_load_balancer" "hydr_LBR" {
  #Required
  compartment_id = var.compartment_id
  display_name   = var.LBR_display_name
  shape          = var.LBR_shape
  subnet_ids     = [var.webtier_subnet_id]
  ip_mode        = "IPV4"
  is_private     = var.LBR_is_private

  #Optional
  #defined_tags = {"Operations.CostCenter"= "42"}
  #freeform_tags = {"Department"= "Finance"}
  #network_security_group_ids = var.load_balancer_network_security_group_ids
  #reserved_ips {
  #Optional
  #id = var.load_balancer_reserved_ips_id
  #}
  shape_details {
    #Required
    maximum_bandwidth_in_mbps = var.LBR_maxbw
    minimum_bandwidth_in_mbps = var.LBR_minbw
  }
}



