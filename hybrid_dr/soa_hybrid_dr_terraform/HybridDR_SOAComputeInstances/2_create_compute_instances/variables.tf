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
variable "midtier_subnet_id" {}

# Availability domains
variable "AD_names" {}

# Shape and images
variable "shape"  {}
variable "image_id" {} 

# Compute node names
variable "midtier_hostnames" {}

# Publich ssh key
variable "ssh_public_key_path" {}
