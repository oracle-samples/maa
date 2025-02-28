## WLS Hybrid DR terraform scripts  
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

########################################################################################################
# Configure the hostnames
########################################################################################################

resource "oci_load_balancer_hostname" "adminconsole_frontend" {
  #Required
  hostname         = var.adminconsole_frontend
  load_balancer_id = oci_load_balancer_load_balancer.hydr_LBR.id
  name             = "adminconsole_frontend"
}

resource "oci_load_balancer_hostname" "https_frontend" {
  #Required
  hostname         = var.https_frontend
  load_balancer_id = oci_load_balancer_load_balancer.hydr_LBR.id
  name             = "https_frontend"
}

resource "oci_load_balancer_hostname" "http_frontend" {
  #Required
  hostname         = var.http_frontend
  load_balancer_id = oci_load_balancer_load_balancer.hydr_LBR.id
  name             = "http_frontend"
}

resource "oci_load_balancer_hostname" "internal_frontend" {
  count = var.internal_frontend != "" ? 1 : 0
  #Required
  hostname         = var.internal_frontend
  load_balancer_id = oci_load_balancer_load_balancer.hydr_LBR.id
  name             = "internal_frontend"
}

