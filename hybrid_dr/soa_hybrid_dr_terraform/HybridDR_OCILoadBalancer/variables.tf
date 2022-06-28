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

variable "LBR_display_name" {}
variable "webtier_subnet_id" {}
variable "LBR_is_private" {}

variable "backend_set_policy" { default = "ROUND_ROBIN" }
variable "LBR_shape" { default = "flexible" }
variable "LBR_minbw" { default = "10" }
variable "LBR_maxbw" { default = "100" }


variable "admin_vip" {}
variable "midtier_nodes_ips" {}

variable "adminserver_port" {}
variable "wsmcluster_port" {}
variable "soacluster_port" {}
variable "osbcluster_port" {}
variable "esscluster_port" {}
variable "bamcluster_port" {}

variable "https_frontend" {}
variable "http_frontend" {}
variable "adminconsole_frontend" {}
variable "internal_frontend" {}

variable "frontend_https_port" {}
variable "frontend_http_port" {}
variable "frontend_internal_port" {}
variable "frontend_admin_port" {}

variable "certificate_passphrase" {}
variable "certificate_private_key_file" {}
variable "certificate_public_certificate_file" {}
variable "certificate_ca_certificate_file" {}


variable "there_is_WSM" { default = "true" }
variable "there_is_SOA" {}
variable "there_is_OSB" {}
variable "there_is_ESS" {}
variable "there_is_BAM" {}


