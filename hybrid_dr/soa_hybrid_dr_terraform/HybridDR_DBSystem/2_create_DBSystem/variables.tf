## SOA Hybrid dr terraform scripts v 1.0
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

# Provider required info
variable "tenancy_ocid" {}
variable "user_ocid" {}
variable "fingerprint" {}
variable "private_key_path" {}
variable "region" {}

#
variable "compartment_id" {}
variable "availability_domain" {}
variable "dbtier_subnet_id" {}

#
variable "db_system_display_name" {}
variable "ssh_public_key_path" {}

#
variable "shape" {}
variable "cpu_core_count" {}
variable "db_version" {}
variable "db_system_license_model" {}
variable "db_system_database_edition" {}

variable "node_count" {}

#
variable "db_hostname_prefix" {}
variable "DBName" {}
variable "DB_unique_name_suffix" {}
variable "PDBName" {}
#variable "database_sid_prefix" {}
#
variable "sys_password" {}
