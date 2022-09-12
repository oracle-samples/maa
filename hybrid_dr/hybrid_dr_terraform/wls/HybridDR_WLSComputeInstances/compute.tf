## WLS Hybrid DR terraform scripts  
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##


resource "oci_core_instance" "wlsoci_instance" {
  count = length(var.midtier_hostnames)
  #This will take alternative values from AD_names list in each iteration
  availability_domain = var.AD_names[count.index % length(var.AD_names)]

  compartment_id      = var.compartment_id
  display_name        = var.midtier_hostnames[count.index]
  shape               = var.shape

  shape_config {
    #Optional
    ocpus = var.ocpu_count
  }
  create_vnic_details {
    subnet_id                 = var.subnet_id
    display_name              = "Primaryvnic"
    assign_public_ip          = true
    assign_private_dns_record = true
    hostname_label            = var.midtier_hostnames[count.index]
  }

  source_details {
    source_id   = data.oci_core_app_catalog_listing_resource_version.mp_catalog_listing.listing_resource_id
    source_type = "image"
  }
  metadata = {
        ssh_authorized_keys = file(var.ssh_public_key_path)
    }
  timeouts {
    create = "60m"
  }
}
