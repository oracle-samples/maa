## SOA Hybrid dr terraform scripts v 1.0
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

variable "tenancy_ocid" {}
variable "user_ocid" {}
variable "fingerprint" {}
variable "private_key_path" {}
variable "region" {}

variable "compartment_id" {}

variable "vcn_name" {}

variable "webtier_subnet_name" {}
variable "midtier_subnet_name" {}
variable "dbtier_subnet_name" {}
variable "fsstier_subnet_name" {}

variable "webtier_is_private" {}
variable "midtier_is_private" {}
variable "dbtier_is_private" {}
variable "fsstier_is_private" {}

variable "vcn_CIDR" {}
variable "webtier_CIDR" {}
variable "midtier_CIDR" {}
variable "dbtier_CIDR" {}
variable "fsstier_CIDR" {}
variable "onprem_CIDR" {}

variable "ssh_port" { default = "22"}
variable "sqlnet_port" { default = "1521"}
variable "ons_port" { default = "6200"}

variable "add_internet_gateway" { default = "false" }

variable "frontend_https_port" { default = "443"}
variable "frontend_http_port" { default = "80"}
variable "frontend_admin_port" { default = "7001"}
variable "frontend_internal_port" { default = "8888"}

variable "adminserver_port" { default = "7001"}
variable "wlsservers_ports" {}

