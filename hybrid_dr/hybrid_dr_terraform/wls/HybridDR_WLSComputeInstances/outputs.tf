## WLS Hybrid DR terraform scripts  
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

output "instance_id" {
  value = oci_core_instance.wlsoci_instance[*].id
}


output "package_version" {
  value = local.package_version
}
