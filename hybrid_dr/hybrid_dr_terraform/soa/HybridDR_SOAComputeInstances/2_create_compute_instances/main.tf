## WLS Hybrid DR terraform scripts  
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}


# Create the compute instances
########################################################################################################

resource "oci_core_instance" "midtier_instance" {
    count = length(var.midtier_hostnames)
    #Required
    #This will take alternative values from AD_names list in each iteration
    availability_domain = var.AD_names[count.index % length(var.AD_names)]
    compartment_id = var.compartment_id
    shape = var.shape

    create_vnic_details {
        #Optional
        #assign_private_dns_record = var.instance_create_vnic_details_assign_private_dns_record
        #assign_public_ip = var.instance_create_vnic_details_assign_public_ip
        #defined_tags = {"Operations.CostCenter"= "42"}
        #display_name = var.midtier_hostnames[count.index]
        #freeform_tags = {"Department"= "Finance"}
        hostname_label = var.midtier_hostnames[count.index]
        subnet_id = var.midtier_subnet_id
    }
    display_name = var.midtier_hostnames[count.index]
    #hostname_label = var.midtier_hostnames[count.index]
    source_details {
        #Required
        source_id = var.image_id
        source_type = "image"
    }
    metadata = { 
	ssh_authorized_keys = file(var.ssh_public_key_path)
    }
}

