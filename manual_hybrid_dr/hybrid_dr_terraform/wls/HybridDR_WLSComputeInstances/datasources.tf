## WLS Hybrid DR terraform scripts  
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##


data "oci_marketplace_listings" "mp_listings" {
  name           = [var.wls_image_names[var.edition]]
  compartment_id = var.compartment_id
}

data "oci_marketplace_listing" "mp_listing" {
  listing_id     = data.oci_marketplace_listings.mp_listings.listings[0].id
  compartment_id = var.compartment_id
}

data "oci_marketplace_listing_packages" "mp_listing_packages" {
  #Required
  listing_id     = data.oci_marketplace_listings.mp_listings.listings[0].id
  compartment_id = var.compartment_id
  package_type   = "IMAGE"
}

data "template_file" "package_versions" {
  count    = length(data.oci_marketplace_listing_packages.mp_listing_packages.listing_packages)
  template = length(regexall("^.*ol8.5", lookup(data.oci_marketplace_listing_packages.mp_listing_packages.listing_packages[count.index], "package_version"))) > 0 ? lookup(data.oci_marketplace_listing_packages.mp_listing_packages.listing_packages[count.index], "package_version") : ""
}

data "oci_marketplace_listing_packages" "ol85_listing_package" {
  #Required
  listing_id      = data.oci_marketplace_listings.mp_listings.listings[0].id
  compartment_id  = var.compartment_id
  package_type    = "IMAGE"
  package_version = element(compact(data.template_file.package_versions.*.template), 0)
}


data "oci_marketplace_listing_package" "mp_listing_package" {
  #Required
  listing_id      = data.oci_marketplace_listing.mp_listing.id
  package_version = local.package_version

  #Optional
  compartment_id = var.compartment_id
}

data "oci_core_app_catalog_listing_resource_version" "mp_catalog_listing" {
  listing_id       = data.oci_marketplace_listing_package.mp_listing_package.app_catalog_listing_id
  resource_version = data.oci_marketplace_listing_package.mp_listing_package.app_catalog_listing_resource_version
}


data "oci_marketplace_listing_package_agreements" "mp_listing_package_agreements" {
  #Required
  listing_id      = data.oci_marketplace_listing.mp_listing.id
  package_version = local.package_version

  #Optional
  compartment_id = var.compartment_id
}


