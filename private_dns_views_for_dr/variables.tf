## private_dns_views_for_dr terraform scripts
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

# Provider required info
variable "tenancy_ocid" {}
variable "user_ocid" {}
variable "fingerprint" {}
variable "private_key_path" {}
variable "primary_region" { default = ""}
variable "secondary_region" { default = ""}

# Flags
variable "configure_in_primary" { default = "true"}
variable "configure_in_secondary" { default = "true"}

# Compartments
variable primary_compartment_id { default =""}
variable secondary_compartment_id { default =""}

# VCNs
variable primary_vcn_id { default = ""}
variable secondary_vcn_id { default =""}

# Primary domain, host fqdn and IPS
variable primary_domain { default =""}
variable primary_nodes_fqdns { default = ""}
variable primary_nodes_IPs { default = ""}

# Secondary domain, host fqdns and IPs
variable secondary_domain { default = ""}
variable secondary_nodes_fqdns { default = ""}
variable secondary_nodes_IPs { default = ""}

# Predefined values
variable primary_private_view_name { default = "Private_View_for_DR_in_Primary"}
variable secondary_private_view_name { default = "Private_View_for_DR_in_Secondary"}



