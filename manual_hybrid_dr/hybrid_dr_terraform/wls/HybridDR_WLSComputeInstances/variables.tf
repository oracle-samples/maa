## WLS Hybrid DR terraform scripts  
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

variable "tenancy_ocid" {
  type = string
}

variable "user_ocid" {
  type = string
}

variable "fingerprint" {
  type = string
}

variable "private_key_path" {
  type = string
}

variable "region" {
  type = string
}

variable "compartment_id" {
  type = string
}

variable "hostname" {
  type    = string
  default = "wlsoci-instance"
}

variable "shape" {
  type    = string
  default = "VM.Standard.E3.Flex"
}

variable "subnet_id" {
  type = string
}

variable "ocpu_count" {
  type    = number
  default = 1
}

variable "edition" {
  type        = string
  description = "Name of the marketplace image listings"
}

variable "wls_image_names" {
  type = map(any)
  default = {
    "EE"    = "Oracle WebLogic Server Enterprise Edition UCM Image"
    "Suite" = "Oracle WebLogic Suite UCM Image"
  }
  description = "Name of the marketplace image listings"
}

variable "build_version" {
  type        = string
  default     = ""
  description = "Marketplace image build version"
}

variable "os_version" {
  type        = string
  default     = "7.9"
  description = "Weblogic OCI os version [7.9, 8.5]"
}


variable "AD_names" {
  type        = list(any)
  description = "List of the Availability Domains where the instances are created"
}


variable "midtier_hostnames" {
  type        = list(any)
  description = "List of the display names for the compute instances"
}

variable "ssh_public_key_path" {
  type        = string
  default     = ""
  description = "Path to the ssh public key file"
}
