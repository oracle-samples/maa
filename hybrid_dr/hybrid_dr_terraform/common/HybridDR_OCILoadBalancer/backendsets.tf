## WLS Hybrid DR  terraform scripts  
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

########################################################################################################
# Create the Backend Sets
########################################################################################################

########################################################################################################
# - 1 backendset for the administration access: 
# - N backendsets for the applications access: 1 if OHS is used, N if OHS not used (1 per cluster)
# - (optional) 1 backendset for internal accesses. Only if OHS is used. If not, it is implicitly created as a cluster backendset

########################################################################################################

# Backendset name: "OHS_Admin_backendset" if OHS is used, "Admin_backendset" if OHS not useddd
resource "oci_load_balancer_backend_set" "Admin_backendset" {
  #Required
  health_checker {
    #Required
    protocol = "HTTP"
    #Optional
    interval_ms       = "10000"
    port              = var.there_is_OHS ? var.ohs_httpconsoles_port : var.wls_adminserver_port
    retries           = "3"
    timeout_in_millis = "3000"
    url_path          = "/"
    #response_body_regex = var.backend_set_health_checker_response_body_regex
    return_code = "404"
  }
  load_balancer_id = oci_load_balancer_load_balancer.hydr_LBR.id
  name             = var.there_is_OHS ? "OHS_Admin_backendset" : "Admin_backendset"
  policy           = var.backend_set_policy

  #Optional
  lb_cookie_session_persistence_configuration {
    #Optional
    cookie_name  = "X-Oracle-LBR-ADMIN-Backendset"
    is_http_only = "true"
    is_secure    = "false"
    #disable_fallback = var.backend_set_lb_cookie_session_persistence_configuration_disable_fallback
    #domain = var.backend_set_lb_cookie_session_persistence_configuration_domain
    #max_age_in_seconds = var.backend_set_lb_cookie_session_persistence_configuration_max_age_in_seconds
    #path = var.backend_set_lb_cookie_session_persistence_configuration_path
  }
}

# Backendset name: 1 "OHS_HTTP_backendset" if OHS is used, N "<Cluster_name>" if OHS not used
resource "oci_load_balancer_backend_set" "Applications_backendsets" {
  count = var.there_is_OHS ? 1 : length(local.topology.clusters)
  #Required
  health_checker {
    #Required
    protocol = "HTTP"
    #Optional
    interval_ms       = "10000"
    port              = var.there_is_OHS ? var.ohs_http_port : local.topology.clusters[count.index].cluster.port
    retries           = "3"
    timeout_in_millis = "3000"
    url_path          = "/"
    #response_body_regex = var.backend_set_health_checker_response_body_regex
    return_code = "404"
  }
  load_balancer_id = oci_load_balancer_load_balancer.hydr_LBR.id
  name             = var.there_is_OHS ? "OHS_HTTP_backendset" : local.topology.clusters[count.index].cluster.name
  policy           = var.backend_set_policy

  #Optional
  lb_cookie_session_persistence_configuration {
    #Optional
    #cookie_name  = "X-Oracle-LBR-${each.value.name}-Backendset"
    cookie_name  = var.there_is_OHS ? "X-Oracle-LBR-Cluster_OHS_HTTP_backendset" : "X-Oracle-LBR-${local.topology.clusters[count.index].cluster.name}"
    is_http_only = "true"
    # If the cluster is exposed in the internal frontend (HTTP), this must be false. Otherwise, it is exposed in HTTPS so this must be true:
    is_secure = var.there_is_OHS ? "true" : (local.topology.clusters[count.index].cluster.internal == "yes" ? "false" : "true")
    #disable_fallback = var.backend_set_lb_cookie_session_persistence_configuration_disable_fallback
    #domain = var.backend_set_lb_cookie_session_persistence_configuration_domain
    #max_age_in_seconds = var.backend_set_lb_cookie_session_persistence_configuration_max_age_in_seconds
    #path = var.backend_set_lb_cookie_session_persistence_configuration_path
  }
}


# Only created separatedly when OHS is used. If OHS is not used, internal backendsets are implicitily created in the Applications_backends
resource "oci_load_balancer_backend_set" "OHS_HTTP_internal_backendset" {
  count = var.there_is_OHS ? (var.internal_frontend != "" ? 1 : 0) : 0
  #Required
  health_checker {
    #Required
    protocol = "HTTP"
    #Optional
    interval_ms       = "10000"
    port              = var.ohs_httpinternal_port
    retries           = "3"
    timeout_in_millis = "3000"
    url_path          = "/"
    #response_body_regex = var.backend_set_health_checker_response_body_regex
    return_code = "200"
  }
  load_balancer_id = oci_load_balancer_load_balancer.hydr_LBR.id
  name             = "OHS_HTTP_internal_backendset"
  policy           = var.backend_set_policy

  #Optional
  lb_cookie_session_persistence_configuration {
    #Optional
    cookie_name  = "X-Oracle-LBR-Cluster_OHS_HTTP_internal_backendset"
    is_http_only = "true"
    is_secure    = "false"
    #disable_fallback = var.backend_set_lb_cookie_session_persistence_configuration_disable_fallback
    #domain = var.backend_set_lb_cookie_session_persistence_configuration_domain
    #max_age_in_seconds = var.backend_set_lb_cookie_session_persistence_configuration_max_age_in_seconds
    #path = var.backend_set_lb_cookie_session_persistence_configuration_path
  }
}

# Regardless OHS is used or not
# Empty backend set for the HTTP listener (which only redirects to port HTTPS)
resource "oci_load_balancer_backend_set" "empty_backendset" {
  #Required
  health_checker {
    #Required
    protocol = "HTTP"
    #Optional
    interval_ms       = "10000"
    port              = "80"
    retries           = "3"
    timeout_in_millis = "3000"
    url_path          = "/"
    #response_body_regex = var.backend_set_health_checker_response_body_regex
    return_code = "404"
  }
  load_balancer_id = oci_load_balancer_load_balancer.hydr_LBR.id
  name             = "empty_backendset"
  policy           = var.backend_set_policy
}


########################################################################################################
# Create the Backends for each Backend set
########################################################################################################

########################################################################################################
# Backends if OHS is used
# - OHS_Admin_backendset: one backend for each OHS node IP, with the OHS admin port. 
# - OHS_HTTP_backendset:  one backend for each OHS node IP, with the OHS HTTP port.
# - (optional) OHS_HTTP_internal_backendset : one " OHS_HTTP_internal_backend" backend for each OHS node IP, with the internal HTTP port.
# Backends if OHS is not used:
# - Admin_backendset: one backend, pointing to the WLS administration server IP and port
# - Cluster_1 backendset: one "cluster_backend" for each WLS managed server IP and port in the Cluster_1
# - Cluster_2 backendset: one "cluster_backend" for each WLS managed server IP and port in the Cluster_2
# - (..)


########################################################################################################

resource "oci_load_balancer_backend" "Admin_backend" {
  count = var.there_is_OHS ? (length(var.ohs_nodes_ips)) : 1
  #Required
  backendset_name  = oci_load_balancer_backend_set.Admin_backendset.name
  ip_address       = var.there_is_OHS ? var.ohs_nodes_ips[count.index] : var.admin_vip
  load_balancer_id = oci_load_balancer_load_balancer.hydr_LBR.id
  port             = var.there_is_OHS ? var.ohs_httpconsoles_port : var.wls_adminserver_port
}

resource "oci_load_balancer_backend" "node_backends" {
  count = var.there_is_OHS ? (length(var.ohs_nodes_ips)) : length(local.list_of_backends)
  #Required
  backendset_name  = var.there_is_OHS ? oci_load_balancer_backend_set.Applications_backendsets[0].name : local.list_of_backends[count.index].cluster_name
  ip_address       = var.there_is_OHS ? var.ohs_nodes_ips[count.index] : local.list_of_backends[count.index].backend_IP
  load_balancer_id = var.there_is_OHS ? oci_load_balancer_load_balancer.hydr_LBR.id : oci_load_balancer_load_balancer.hydr_LBR.id
  port             = var.there_is_OHS ? var.ohs_http_port : local.list_of_backends[count.index].backend_port
}

resource "oci_load_balancer_backend" "OHS_HTTP_internal_backend" {
  count = var.there_is_OHS ? (var.internal_frontend != "" ? (length(var.ohs_nodes_ips)) : 0) : 0
  #Required
  backendset_name  = oci_load_balancer_backend_set.OHS_HTTP_internal_backendset[0].name
  ip_address       = var.ohs_nodes_ips[count.index]
  load_balancer_id = oci_load_balancer_load_balancer.hydr_LBR.id
  port             = var.ohs_httpinternal_port
}



