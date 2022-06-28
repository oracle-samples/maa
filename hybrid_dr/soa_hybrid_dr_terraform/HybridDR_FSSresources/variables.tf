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

# Others
variable "compartment_id" {}
variable "fss_subnet_id" {}

# Availability domains
variable "AD1_name" {}
variable "AD2_name" {}

# Mount target names
variable "mounttarget1_displayname" { default = "SOADRmountTarget" }
variable "mounttarget2_displayname" {}

# Filesystem names
variable "sharedconfig_FSSname" { default = "soadrconfigFSS" }
variable "runtime_FSSname" { default = "soadrruntimeFSS" }
variable "products1_FSSname" { default = "soadrproducts1FSS" }
variable "products2_FSSname" { default = "soadrproducts2FSS" }

# Export Paths
variable "sharedconfig_exportpath" { default = "/export/soadrconfig" }
variable "runtime_exportpath" { default = "/export/soadrruntime" }
variable "products1_exportpath" { default = "/export/soadrproducts1" }
variable "products2_exportpath" { default = "/export/soadrproducts2" }

