## SOA Hybrid dr terraform scripts v 1.0
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

data "oci_identity_availability_domains" "ADs" {
  #Required
  #compartment_id = var.tenancy_ocid
  compartment_id = var.compartment_id
}

output "ADs" {
  value = data.oci_identity_availability_domains.ADs.availability_domains
}



# Create the Mount Target
########################################################################################################
resource "oci_file_storage_mount_target" "mount_target1" {
  #Required
  availability_domain = var.AD1_name
  compartment_id      = var.compartment_id
  subnet_id           = var.fss_subnet_id

  #Optional
  display_name   = var.mounttarget1_displayname
  hostname_label = var.mounttarget1_displayname
}


resource "oci_file_storage_mount_target" "mount_target2" {
  # This is created only if AD2 is provided
  count = var.AD2_name != "" ? 1 : 0
  #Required
  availability_domain = var.AD2_name
  compartment_id      = var.compartment_id
  subnet_id           = var.fss_subnet_id

  #Optional
  display_name   = var.mounttarget2_displayname
  hostname_label = var.mounttarget2_displayname
}


# Create the File Systems
########################################################################################################
resource "oci_file_storage_file_system" "shared_config_file_system" {
  #Required
  availability_domain = var.AD1_name
  compartment_id      = var.compartment_id

  #Optional
  #defined_tags = {"Operations.CostCenter"= "42"}
  display_name = var.sharedconfig_FSSname
  #freeform_tags = {"Department"= "Finance"}
  #kms_key_id = oci_kms_key.test_key.id
  #source_snapshot_id = oci_file_storage_snapshot.test_snapshot.id
}


resource "oci_file_storage_file_system" "runtime_file_system" {
  #Required
  availability_domain = var.AD1_name
  compartment_id      = var.compartment_id

  #Optional
  #defined_tags = {"Operations.CostCenter"= "42"}
  display_name = var.runtime_FSSname
  #freeform_tags = {"Department"= "Finance"}
  #kms_key_id = oci_kms_key.test_key.id
  #source_snapshot_id = oci_file_storage_snapshot.test_snapshot.id
}


resource "oci_file_storage_file_system" "products1_file_system" {
  #Required
  availability_domain = var.AD1_name
  compartment_id      = var.compartment_id

  #Optional
  #defined_tags = {"Operations.CostCenter"= "42"}
  display_name = var.products1_FSSname
  #freeform_tags = {"Department"= "Finance"}
  #kms_key_id = oci_kms_key.test_key.id
  #source_snapshot_id = oci_file_storage_snapshot.test_snapshot.id
}

resource "oci_file_storage_file_system" "products2_file_system" {
  #Required
  # If more than one AD is used, this is created in the second one
  availability_domain = var.AD2_name != "" ? var.AD2_name : var.AD1_name
  compartment_id      = var.compartment_id

  #Optional
  #defined_tags = {"Operations.CostCenter"= "42"}
  display_name = var.products2_FSSname
  #freeform_tags = {"Department"= "Finance"}
  #kms_key_id = oci_kms_key.test_key.id
  #source_snapshot_id = oci_file_storage_snapshot.test_snapshot.id
}


#Create the export sets
########################################################################################################

resource "oci_file_storage_export_set" "export_set1" {
  #Required
  mount_target_id = oci_file_storage_mount_target.mount_target1.id

  #Optional
  display_name      = "export_set1"
  max_fs_stat_bytes = 23843202333
  max_fs_stat_files = 223442
}

resource "oci_file_storage_export_set" "export_set2" {
  # This is created only if AD2 is provided
  count = var.AD2_name != "" ? 1 : 0
  #Required
  mount_target_id = oci_file_storage_mount_target.mount_target2[0].id

  #Optional
  display_name      = "export_set2"
  max_fs_stat_bytes = 23843202333
  max_fs_stat_files = 223442
}


#Create the exports
########################################################################################################

resource "oci_file_storage_export" "shared_config_export" {
  #Required
  export_set_id  = oci_file_storage_export_set.export_set1.id
  file_system_id = oci_file_storage_file_system.shared_config_file_system.id
  path           = var.sharedconfig_exportpath

  #Optional
  #export_options {
  #Required
  #    source = var.export_export_options_source
  #Optional
  #    access = var.export_export_options_access
  #    anonymous_gid = var.export_export_options_anonymous_gid
  #    anonymous_uid = var.export_export_options_anonymous_uid
  #    identity_squash = var.export_export_options_identity_squash
  #    require_privileged_source_port = var.export_export_options_require_privileged_source_port
  #}
}


resource "oci_file_storage_export" "runtime_export" {
  #Required
  export_set_id  = oci_file_storage_export_set.export_set1.id
  file_system_id = oci_file_storage_file_system.runtime_file_system.id
  path           = var.runtime_exportpath

  #Optional
  #export_options {
  #Required
  #    source = var.export_export_options_source
  #Optional
  #    access = var.export_export_options_access
  #    anonymous_gid = var.export_export_options_anonymous_gid
  #    anonymous_uid = var.export_export_options_anonymous_uid
  #    identity_squash = var.export_export_options_identity_squash
  #    require_privileged_source_port = var.export_export_options_require_privileged_source_port
  #}
}


resource "oci_file_storage_export" "products1_export" {
  #Required
  export_set_id  = oci_file_storage_export_set.export_set1.id
  file_system_id = oci_file_storage_file_system.products1_file_system.id
  path           = var.products1_exportpath

  #Optional
  #export_options {
  #Required
  #    source = var.export_export_options_source
  #Optional
  #    access = var.export_export_options_access
  #    anonymous_gid = var.export_export_options_anonymous_gid
  #    anonymous_uid = var.export_export_options_anonymous_uid
  #    identity_squash = var.export_export_options_identity_squash
  #    require_privileged_source_port = var.export_export_options_require_privileged_source_port
  #}
}

resource "oci_file_storage_export" "products2_export" {
  #Required
  # If more than one AD is used, this is created in the second one
  export_set_id  = var.AD2_name != "" ? oci_file_storage_export_set.export_set2[0].id : oci_file_storage_export_set.export_set1.id
  file_system_id = oci_file_storage_file_system.products2_file_system.id
  path           = var.products2_exportpath

  #Optional
  #export_options {
  #Required
  #    source = var.export_export_options_source
  #Optional
  #    access = var.export_export_options_access
  #    anonymous_gid = var.export_export_options_anonymous_gid
  #    anonymous_uid = var.export_export_options_anonymous_uid
  #    identity_squash = var.export_export_options_identity_squash
  #    require_privileged_source_port = var.export_export_options_require_privileged_source_port
  #}
}
