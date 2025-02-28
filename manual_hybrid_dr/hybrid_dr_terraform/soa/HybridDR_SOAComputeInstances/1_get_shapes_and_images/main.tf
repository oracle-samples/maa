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

data "oci_core_shapes" "available_shapes" {
    #Required
    compartment_id = var.compartment_id

    #Optional
    #availability_domain = var.shape_availability_domain
    #image_id = oci_core_image.test_image.id
}

output "shapes" {
    value = distinct(data.oci_core_shapes.available_shapes.shapes[*].name)
}

data "oci_core_images" "available_images" {
    #Required
    compartment_id = var.compartment_id

    #Optional
    #display_name = var.image_display_name
    operating_system = var.image_os
    #operating_system_version = var.image_operating_system_version
    #shape = var.image_shape
    state = "AVAILABLE"
    #sort_by = "DISPLAYNAME"
    #sort_order = "ASC"
}



output "images_and_ids" {
    value = [ for x in data.oci_core_images.available_images.images :  "IMAGE DISPLAY NAME: ${x.display_name} ----> OCID: ${x.id}" ]
}


#output "all" {
#	value  = data.oci_core_images.available_images
#}
