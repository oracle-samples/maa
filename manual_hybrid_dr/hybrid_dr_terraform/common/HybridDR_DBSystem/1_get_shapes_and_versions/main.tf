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




data "oci_database_db_system_shapes" "my_db_system_shapes" {
    #Required
    compartment_id = var.compartment_id

    #Optional
    availability_domain = var.availability_domain
}

output "shapes" {
    value = distinct(data.oci_database_db_system_shapes.my_db_system_shapes.db_system_shapes[*].name)
}


data "oci_database_db_versions" "my_db_versions" {
    #Required
    compartment_id = var.compartment_id

    #Optional
    #db_system_id = oci_database_db_system.test_db_system.id
    #db_system_shape = var.db_version_db_system_shape
    #is_database_software_image_supported = var.db_version_is_database_software_image_supported
    #is_upgrade_supported = var.db_version_is_upgrade_supported
    #storage_management = var.db_version_storage_management
}

output "versions" {
    value = data.oci_database_db_versions.my_db_versions.db_versions
}




