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


# Create the DB System
########################################################################################################

resource "oci_database_db_system" "my_db_system" {
  #Required
  availability_domain = var.availability_domain
  compartment_id      = var.compartment_id
  db_home {
    #Required
    database {
      #Required
      admin_password = var.sys_password

      #Optional
      #backup_id = oci_database_backup.test_backup.id
      #backup_tde_password = var.db_system_db_home_database_backup_tde_password
      #character_set = var.db_system_db_home_database_character_set
      #database_id = oci_database_database.test_database.id
      #database_software_image_id = oci_database_database_software_image.test_database_software_image.id
      #db_backup_config {

      #Optional
      #auto_backup_enabled = var.db_system_db_home_database_db_backup_config_auto_backup_enabled
      #auto_backup_window = var.db_system_db_home_database_db_backup_config_auto_backup_window
      #backup_destination_details {

      #Optional
      #id = var.db_system_db_home_database_db_backup_config_backup_destination_details_id
      #type = var.db_system_db_home_database_db_backup_config_backup_destination_details_type
      #    }
      #recovery_window_in_days = var.db_system_db_home_database_db_backup_config_recovery_window_in_days
      #}
      #db_domain = var.db_system_db_home_database_db_domain
      db_name     = var.DBName
      db_workload = "OLTP"
      pdb_name    = var.PDBName
      #defined_tags = var.db_system_db_home_database_defined_tags
      #freeform_tags = var.db_system_db_home_database_freeform_tags
      #ncharacter_set = var.db_system_db_home_database_ncharacter_set
      #sid_prefix = var.database_sid_prefix
      #tde_wallet_password = var.db_system_db_home_database_tde_wallet_password
      #time_stamp_for_point_in_time_recovery = var.db_system_db_home_database_time_stamp_for_point_in_time_recovery
    }

    #Optional
    #database_software_image_id = 
    db_version = var.db_version
    #defined_tags = var.db_system_db_home_defined_tags
    #display_name = var.db_system_db_home_display_name
    #freeform_tags = var.db_system_db_home_freeform_tags
  }
  hostname        = var.db_hostname_prefix
  shape           = var.shape
  ssh_public_keys = [file(var.ssh_public_key_path)]
  subnet_id       = var.dbtier_subnet_id

  #Optional
  #backup_network_nsg_ids = var.db_system_backup_network_nsg_ids
  #backup_subnet_id = oci_core_subnet.test_subnet.id
  #cluster_name = var.db_system_cluster_name
  cpu_core_count = var.cpu_core_count
  #data_storage_percentage = var.db_system_data_storage_percentage
  data_storage_size_in_gb = "256"
  database_edition        = var.db_system_database_edition
  db_system_options {

    #Optional
    storage_management = "ASM"
  }
  #defined_tags = var.db_system_defined_tags
  #disk_redundancy = var.db_system_disk_redundancy
  display_name = var.db_system_display_name
  #domain = var.db_system_domain
  #fault_domains = var.db_system_fault_domains
  #freeform_tags = {"Department"= "Finance"}
  #kms_key_id = oci_kms_key.test_key.id
  #kms_key_version_id = oci_kms_key_version.test_key_version.id
  license_model = var.db_system_license_model
  #maintenance_window_details {

  #Optional
  #custom_action_timeout_in_mins = var.db_system_maintenance_window_details_custom_action_timeout_in_mins
  #days_of_week {

  #Optional
  #name = var.db_system_maintenance_window_details_days_of_week_name
  #}
  #hours_of_day = var.db_system_maintenance_window_details_hours_of_day
  #is_custom_action_timeout_enabled = var.db_system_maintenance_window_details_is_custom_action_timeout_enabled
  #lead_time_in_weeks = var.db_system_maintenance_window_details_lead_time_in_weeks
  #months {

  #Optional
  #name = var.db_system_maintenance_window_details_months_name
  #}
  #patching_mode = var.db_system_maintenance_window_details_patching_mode
  #preference = var.db_system_maintenance_window_details_preference
  #weeks_of_month = var.db_system_maintenance_window_details_weeks_of_month
  #}
  node_count = var.node_count
  #nsg_ids = var.db_system_nsg_ids
  #private_ip = var.db_system_private_ip
  #source = var.db_system_source
  #source_db_system_id = oci_database_db_system.test_db_system.id
  #sparse_diskgroup = var.db_system_sparse_diskgroup
  #time_zone = var.db_system_time_zone
}
