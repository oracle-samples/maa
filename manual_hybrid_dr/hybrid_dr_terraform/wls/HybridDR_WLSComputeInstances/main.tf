## WLS Hybrid DR terraform scripts  
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

locals {
  package_version = var.os_version == "8.5" ? data.oci_marketplace_listing_packages.ol85_listing_package.package_version : data.oci_marketplace_listing.mp_listing.default_package_version
}

terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 4.0.0"
    }
    tls = {
      version = "~> 2.0"
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



resource "oci_core_app_catalog_listing_resource_version_agreement" "mp_image_agreement" {

  listing_id               = data.oci_core_app_catalog_listing_resource_version.mp_catalog_listing.listing_id
  listing_resource_version = data.oci_core_app_catalog_listing_resource_version.mp_catalog_listing.listing_resource_version
}

resource "oci_core_app_catalog_subscription" "mp_image_subscription" {
  compartment_id           = var.compartment_id
  eula_link                = oci_core_app_catalog_listing_resource_version_agreement.mp_image_agreement.eula_link
  listing_id               = oci_core_app_catalog_listing_resource_version_agreement.mp_image_agreement.listing_id
  listing_resource_version = oci_core_app_catalog_listing_resource_version_agreement.mp_image_agreement.listing_resource_version
  oracle_terms_of_use_link = oci_core_app_catalog_listing_resource_version_agreement.mp_image_agreement.oracle_terms_of_use_link
  signature                = oci_core_app_catalog_listing_resource_version_agreement.mp_image_agreement.signature
  time_retrieved           = oci_core_app_catalog_listing_resource_version_agreement.mp_image_agreement.time_retrieved

  timeouts {
    create = "20m"
  }
}
