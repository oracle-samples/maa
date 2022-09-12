## WLS Hybrid DR terraform scripts  
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

########################################################################################################
# Configure Listeners
# - Admin_listener
# - HTTPS_listener
# - HTTP_listener
# - (optional) HTTP_internal_listener
########################################################################################################
resource "oci_load_balancer_listener" "Admin_listener" {
  #Required
  default_backend_set_name = oci_load_balancer_backend_set.Admin_backendset.name
  load_balancer_id         = oci_load_balancer_load_balancer.hydr_LBR.id
  name                     = "Admin_listener"
  port                     = var.frontend_admin_port
  protocol                 = "HTTP"

  hostname_names      = [oci_load_balancer_hostname.adminconsole_frontend.name]
  routing_policy_name = oci_load_balancer_load_balancer_routing_policy.Admin_rules.name
  #rule_set_names = [oci_load_balancer_rule_set.test_rule_set.name]
}

resource "oci_load_balancer_listener" "HTTPS_listener" {
  #Required
  default_backend_set_name = oci_load_balancer_backend_set.Applications_backendsets[0].name
  load_balancer_id         = oci_load_balancer_load_balancer.hydr_LBR.id
  name                     = "HTTPS_listener"
  port                     = var.frontend_https_port
  protocol                 = "HTTP"

  hostname_names      = [oci_load_balancer_hostname.https_frontend.name]
  routing_policy_name = oci_load_balancer_load_balancer_routing_policy.Application_rules.name
  rule_set_names      = [oci_load_balancer_rule_set.SSLHeaders.name]

  ssl_configuration {
    #Optional
    #certificate_name = oci_load_balancer_certificate.hy_https_certificate.name
    certificate_name        = "hy_https_cert"
    verify_peer_certificate = "false"
  }

}

# This is only to redirect to 443
resource "oci_load_balancer_listener" "HTTP_listener" {
  #Required
  default_backend_set_name = oci_load_balancer_backend_set.empty_backendset.name
  load_balancer_id         = oci_load_balancer_load_balancer.hydr_LBR.id
  name                     = "HTTP_listener"
  port                     = var.frontend_http_port
  protocol                 = "HTTP"

  hostname_names = [oci_load_balancer_hostname.http_frontend.name]
  rule_set_names = [oci_load_balancer_rule_set.HTTP_to_HTTPS_redirect.name]
}

resource "oci_load_balancer_listener" "HTTP_internal_listener" {
  count = var.internal_frontend != "" ? 1 : 0
  #Required
  # If OHS is used, the default backendset points to OHS port for internal listener (is_secure=false)
  # If OHS is not used, the default backend points to the first backendset marked as internal (is_secure=false)
  #default_backend_set_name = var.there_is_OHS ? oci_load_balancer_backend_set.OHS_HTTP_internal_backendset[0].name : oci_load_balancer_backend_set.empty_backendset.name
  default_backend_set_name = var.there_is_OHS ? oci_load_balancer_backend_set.OHS_HTTP_internal_backendset[0].name : [for i in local.topology.clusters.* : i.cluster.name if i.cluster.internal == "yes"][0]
  load_balancer_id         = oci_load_balancer_load_balancer.hydr_LBR.id
  name                     = "HTTP_internal_listener"
  port                     = var.frontend_internal_port
  protocol                 = "HTTP"

  hostname_names      = [oci_load_balancer_hostname.internal_frontend[0].name]
  routing_policy_name = oci_load_balancer_load_balancer_routing_policy.Internal_rules[0].name
  #rule_set_names = [oci_load_balancer_rule_set.test_rule_set.name]
}


