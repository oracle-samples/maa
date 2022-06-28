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

########################################################################################################
# Create the Load Balancer
########################################################################################################
resource "oci_load_balancer_load_balancer" "hydr_LBR" {
  #Required
  compartment_id = var.compartment_id
  display_name   = var.LBR_display_name
  shape          = var.LBR_shape
  subnet_ids     = [var.webtier_subnet_id]
  ip_mode        = "IPV4"
  is_private     = var.LBR_is_private

  #Optional
  #defined_tags = {"Operations.CostCenter"= "42"}
  #freeform_tags = {"Department"= "Finance"}
  #network_security_group_ids = var.load_balancer_network_security_group_ids
  #reserved_ips {
  #Optional
  #id = var.load_balancer_reserved_ips_id
  #}
  shape_details {
    #Required
    maximum_bandwidth_in_mbps = var.LBR_maxbw
    minimum_bandwidth_in_mbps = var.LBR_minbw
  }
}


########################################################################################################
# Create the Backend Sets
# - Admin_backendset
# - WSM_backendset
# - SOA_backendset
# - OSB_backendset
# - ESS_backendset
# - BAM_backendset
########################################################################################################
resource "oci_load_balancer_backend_set" "Admin_backendset" {
  #Required
  health_checker {
    #Required
    protocol = "HTTP"
    #Optional
    interval_ms       = "10000"
    port              = var.adminserver_port
    retries           = "3"
    timeout_in_millis = "3000"
    url_path          = "/"
    #response_body_regex = var.backend_set_health_checker_response_body_regex
    return_code = "404"
  }
  load_balancer_id = oci_load_balancer_load_balancer.hydr_LBR.id
  name             = "Admin_backendset"
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

resource "oci_load_balancer_backend_set" "WSM_backendset" {
  count = var.there_is_WSM ? 1 : 0
  #Required
  health_checker {
    #Required
    protocol = "HTTP"
    #Optional
    interval_ms       = "10000"
    port              = var.wsmcluster_port
    retries           = "3"
    timeout_in_millis = "3000"
    url_path          = "/"
    #response_body_regex = var.backend_set_health_checker_response_body_regex
    return_code = "404"
  }
  load_balancer_id = oci_load_balancer_load_balancer.hydr_LBR.id
  name             = "WSM_backendset"
  policy           = var.backend_set_policy

  #Optional
  lb_cookie_session_persistence_configuration {
    #Optional
    cookie_name  = "X-Oracle-LBR-WSM-Backendset"
    is_http_only = "true"
    is_secure    = "false"
    #disable_fallback = var.backend_set_lb_cookie_session_persistence_configuration_disable_fallback
    #domain = var.backend_set_lb_cookie_session_persistence_configuration_domain
    #max_age_in_seconds = var.backend_set_lb_cookie_session_persistence_configuration_max_age_in_seconds
    #path = var.backend_set_lb_cookie_session_persistence_configuration_path
  }
}


resource "oci_load_balancer_backend_set" "SOA_backendset" {
  count = var.there_is_SOA ? 1 : 0
  #Required
  health_checker {
    #Required
    protocol = "HTTP"
    #Optional
    interval_ms       = "10000"
    port              = var.soacluster_port
    retries           = "3"
    timeout_in_millis = "3000"
    url_path          = "/"
    #response_body_regex = var.backend_set_health_checker_response_body_regex
    return_code = "404"
  }
  load_balancer_id = oci_load_balancer_load_balancer.hydr_LBR.id
  name             = "SOA_backendset"
  policy           = var.backend_set_policy

  #Optional
  lb_cookie_session_persistence_configuration {
    #Optional
    cookie_name  = "X-Oracle-LBR-SOA-Backendset"
    is_http_only = "true"
    is_secure    = "true"
    #disable_fallback = var.backend_set_lb_cookie_session_persistence_configuration_disable_fallback
    #domain = var.backend_set_lb_cookie_session_persistence_configuration_domain
    #max_age_in_seconds = var.backend_set_lb_cookie_session_persistence_configuration_max_age_in_seconds
    #path = var.backend_set_lb_cookie_session_persistence_configuration_path
  }
}


resource "oci_load_balancer_backend_set" "OSB_backendset" {
  count = var.there_is_OSB ? 1 : 0
  #Required
  health_checker {
    #Required
    protocol = "HTTP"
    #Optional
    interval_ms       = "10000"
    port              = var.osbcluster_port
    retries           = "3"
    timeout_in_millis = "3000"
    url_path          = "/"
    #response_body_regex = var.backend_set_health_checker_response_body_regex
    return_code = "404"
  }
  load_balancer_id = oci_load_balancer_load_balancer.hydr_LBR.id
  name             = "OSB_backendset"
  policy           = var.backend_set_policy

  #Optional
  lb_cookie_session_persistence_configuration {
    #Optional
    cookie_name  = "X-Oracle-LBR-OSB-Backendset"
    is_http_only = "true"
    is_secure    = "true"
    #disable_fallback = var.backend_set_lb_cookie_session_persistence_configuration_disable_fallback
    #domain = var.backend_set_lb_cookie_session_persistence_configuration_domain
    #max_age_in_seconds = var.backend_set_lb_cookie_session_persistence_configuration_max_age_in_seconds
    #path = var.backend_set_lb_cookie_session_persistence_configuration_path
  }
}

resource "oci_load_balancer_backend_set" "ESS_backendset" {
  count = var.there_is_ESS ? 1 : 0
  #Required
  health_checker {
    #Required
    protocol = "HTTP"
    #Optional
    interval_ms       = "10000"
    port              = var.esscluster_port
    retries           = "3"
    timeout_in_millis = "3000"
    url_path          = "/"
    #response_body_regex = var.backend_set_health_checker_response_body_regex
    return_code = "404"
  }
  load_balancer_id = oci_load_balancer_load_balancer.hydr_LBR.id
  name             = "ESS_backendset"
  policy           = var.backend_set_policy

  #Optional
  lb_cookie_session_persistence_configuration {
    #Optional
    cookie_name  = "X-Oracle-LBR-ESS-Backendset"
    is_http_only = "true"
    is_secure    = "true"
    #disable_fallback = var.backend_set_lb_cookie_session_persistence_configuration_disable_fallback
    #domain = var.backend_set_lb_cookie_session_persistence_configuration_domain
    #max_age_in_seconds = var.backend_set_lb_cookie_session_persistence_configuration_max_age_in_seconds
    #path = var.backend_set_lb_cookie_session_persistence_configuration_path
  }
}

resource "oci_load_balancer_backend_set" "BAM_backendset" {
  count = var.there_is_BAM ? 1 : 0
  #Required
  health_checker {
    #Required
    protocol = "HTTP"
    #Optional
    interval_ms       = "10000"
    port              = var.bamcluster_port
    retries           = "3"
    timeout_in_millis = "3000"
    url_path          = "/"
    #response_body_regex = var.backend_set_health_checker_response_body_regex
    return_code = "404"
  }
  load_balancer_id = oci_load_balancer_load_balancer.hydr_LBR.id
  name             = "BAM_backendset"
  policy           = var.backend_set_policy

  #Optional
  lb_cookie_session_persistence_configuration {
    #Optional
    cookie_name  = "X-Oracle-LBR-BAM-Backendset"
    is_http_only = "true"
    is_secure    = "true"
    #disable_fallback = var.backend_set_lb_cookie_session_persistence_configuration_disable_fallback
    #domain = var.backend_set_lb_cookie_session_persistence_configuration_domain
    #max_age_in_seconds = var.backend_set_lb_cookie_session_persistence_configuration_max_age_in_seconds
    #path = var.backend_set_lb_cookie_session_persistence_configuration_path
  }
}

resource "oci_load_balancer_backend_set" "empty_backendset" {
  count = 1
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
# Create the Backends for each backedn set
# - Admin_backendset: admin_backend
# - WSM_backendset: wsm1_backend and wsm2_backend
# - SOA_backendset: soa1_backend and soa2_backend
# - OSB_backendset: osb1_backend and osb2_backend
# - ESS_backendset: ess1_backend and ess2_backend
# - BAM_backendset: bam1_backend and bam2_backend
########################################################################################################

resource "oci_load_balancer_backend" "admin_backend" {
  #Required
  backendset_name  = oci_load_balancer_backend_set.Admin_backendset.name
  ip_address       = var.admin_vip
  load_balancer_id = oci_load_balancer_load_balancer.hydr_LBR.id
  port             = var.adminserver_port

}

resource "oci_load_balancer_backend" "wsm_backend" {
  count = var.there_is_WSM ? length(var.midtier_nodes_ips) : 0
  #Required
  backendset_name  = oci_load_balancer_backend_set.WSM_backendset[0].name
  ip_address       = var.midtier_nodes_ips[count.index]
  load_balancer_id = oci_load_balancer_load_balancer.hydr_LBR.id
  port             = var.wsmcluster_port

}

resource "oci_load_balancer_backend" "soa_backend" {
  count = var.there_is_SOA ? length(var.midtier_nodes_ips) : 0
  #Required
  backendset_name  = oci_load_balancer_backend_set.SOA_backendset[0].name
  ip_address       = var.midtier_nodes_ips[count.index]
  load_balancer_id = oci_load_balancer_load_balancer.hydr_LBR.id
  port             = var.soacluster_port
}

resource "oci_load_balancer_backend" "osb_backend" {
  count = var.there_is_OSB ? length(var.midtier_nodes_ips) : 0
  #Required
  backendset_name  = oci_load_balancer_backend_set.OSB_backendset[0].name
  ip_address       = var.midtier_nodes_ips[count.index]
  load_balancer_id = oci_load_balancer_load_balancer.hydr_LBR.id
  port             = var.osbcluster_port
}

resource "oci_load_balancer_backend" "ess_backend" {
  count = var.there_is_ESS ? length(var.midtier_nodes_ips) : 0
  #Required
  backendset_name  = oci_load_balancer_backend_set.ESS_backendset[0].name
  ip_address       = var.midtier_nodes_ips[count.index]
  load_balancer_id = oci_load_balancer_load_balancer.hydr_LBR.id
  port             = var.esscluster_port
}

resource "oci_load_balancer_backend" "bam_backend" {
  count = var.there_is_BAM ? length(var.midtier_nodes_ips) : 0
  #Required
  backendset_name  = oci_load_balancer_backend_set.BAM_backendset[0].name
  ip_address       = var.midtier_nodes_ips[count.index]
  load_balancer_id = oci_load_balancer_load_balancer.hydr_LBR.id
  port             = var.bamcluster_port
}

########################################################################################################
# Configure routing policies, with rules
# - Admin_rules : Admin_routerule
# - Internal_Rules: WMS_routerule
# - SOA_Rules:	SOA_routerule, ESS_routerule, BAM_routerule, B2B_routerule, OSB_routerule
########################################################################################################

resource "oci_load_balancer_load_balancer_routing_policy" "Admin_rules" {
  #Required
  condition_language_version = "V1"
  load_balancer_id           = oci_load_balancer_load_balancer.hydr_LBR.id
  name                       = "Admin_rules"
  rules {
    #Required
    actions {
      #Required
      name = "FORWARD_TO_BACKENDSET"
      #Optional
      backend_set_name = oci_load_balancer_backend_set.Admin_backendset.name
    }
    condition = "any(http.request.url.path sw (i '/console'), http.request.url.path sw (i '/em'), http.request.url.path sw (i '/sbconsole'), http.request.url.path sw (i '/servicebus'))"
    name      = "Admin_routerules"
  }
}

resource "oci_load_balancer_load_balancer_routing_policy" "Internal_rules" {
  #Required
  condition_language_version = "V1"
  load_balancer_id           = oci_load_balancer_load_balancer.hydr_LBR.id
  name                       = "Internal_rules"
  rules {
    #Required
    actions {
      #Required
      name = "FORWARD_TO_BACKENDSET"
      #Optional
      backend_set_name = oci_load_balancer_backend_set.WSM_backendset[0].name
    }
    condition = "any(http.request.url.path sw (i '/wsm-pm'))"
    name      = "WSM_routerules"
  }
}

resource "oci_load_balancer_load_balancer_routing_policy" "SOA_rules" {
  count = var.there_is_SOA ? 1 : 0
  #Required
  condition_language_version = "V1"
  load_balancer_id           = oci_load_balancer_load_balancer.hydr_LBR.id
  name                       = "SOA_rules"
  rules {
    #Required
    actions {
      #Required
      name = "FORWARD_TO_BACKENDSET"
      #Optional
      backend_set_name = oci_load_balancer_backend_set.SOA_backendset[0].name
    }
    condition = "any(http.request.url.path sw (i '/soa-infra'), http.request.url.path sw (i '/inspection.wsil'), http.request.url.path sw (i '/integration'), http.request.url.path sw (i '/sdpmessaging/userprefs-ui'), http.request.url.path sw (i '/DefaultToDoTaskFlow'), http.request.url.path sw (i '/workflow'), http.request.url.path sw (i '/ADFAttachmentHelper'), http.request.url.path sw (i '/soa/composer'), http.request.url.path sw (i '/bpm/composer'), http.request.url.path sw (i '/bpm/workspace'), http.request.url.path sw (i '/bpm/casemgmt'))"
    name      = "SOA_routerules"
  }
  rules {
    #Required
    actions {
      #Required
      name = "FORWARD_TO_BACKENDSET"
      #Optional
      backend_set_name = oci_load_balancer_backend_set.SOA_backendset[0].name
    }
    condition = "any(http.request.url.path sw (i '/b2bconsole'), http.request.url.path sw (i '/b2b/services'), http.request.url.path sw (i '/b2b/httpreceiver'))"
    name      = "B2B_routerules"
  }
  rules {
    #Required
    actions {
      #Required
      name = "FORWARD_TO_BACKENDSET"
      #Optional
      backend_set_name = var.there_is_OSB ? oci_load_balancer_backend_set.OSB_backendset[0].name : oci_load_balancer_backend_set.empty_backendset[0].name
    }
    condition = "any(http.request.url.path sw (i '/sbinspection.wsil'), http.request.url.path sw (i '/sbresource'), http.request.url.path sw (i '/osb'), http.request.url.path sw (i '/alsb'))"
    name      = var.there_is_OSB ? "OSB_routerules" : "OSB_routerules_Not_used"
  }
  rules {
    #Required
    actions {
      #Required
      name = "FORWARD_TO_BACKENDSET"
      #Optional
      backend_set_name = var.there_is_ESS ? oci_load_balancer_backend_set.ESS_backendset[0].name : oci_load_balancer_backend_set.empty_backendset[0].name
    }
    condition = "any(http.request.url.path sw (i '/ess'), http.request.url.path sw (i '/EssHealthCheck'), http.request.url.path sw (i '/ess-async'), http.request.url.path sw (i '/ess-wsjob'))"
    name      = var.there_is_ESS ? "ESS_routerules" : "ESS_routerules_Not_used"
  }
  rules {
    #Required
    actions {
      #Required
      name = "FORWARD_TO_BACKENDSET"
      #Optional
      backend_set_name = var.there_is_BAM ? oci_load_balancer_backend_set.BAM_backendset[0].name : oci_load_balancer_backend_set.empty_backendset[0].name
    }
    condition = "any(http.request.url.path sw (i '/bam/composer'), http.request.url.path sw (i '/OracleBAMWS'), http.request.url.path sw (i '/oracle/bam'))"
    name      = var.there_is_BAM ? "BAM_routerules" : "BAM_routerules_Not_used"
  }
}

########################################################################################################
# Configure the hostnames
########################################################################################################

resource "oci_load_balancer_hostname" "adminconsole_frontend" {
  #Required
  hostname         = var.adminconsole_frontend
  load_balancer_id = oci_load_balancer_load_balancer.hydr_LBR.id
  name             = "adminconsole_frontend"
}

resource "oci_load_balancer_hostname" "internal_frontend" {
  #Required
  hostname         = var.internal_frontend
  load_balancer_id = oci_load_balancer_load_balancer.hydr_LBR.id
  name             = "internal_frontend"
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


########################################################################################################
# Configure SSL certificatein th eLBR
########################################################################################################
resource "oci_load_balancer_certificate" "hy_https_certificate" {
  # This is when the cert has no passphrase
  count = var.certificate_passphrase == "" ? 1 : 0
  #Required
  certificate_name = "hy_https_cert"
  load_balancer_id = oci_load_balancer_load_balancer.hydr_LBR.id

  #Optional
  ca_certificate = file(var.certificate_ca_certificate_file)
  private_key        = file(var.certificate_private_key_file)
  public_certificate = file(var.certificate_public_certificate_file)

  lifecycle {
    create_before_destroy = true
  }
}

resource "oci_load_balancer_certificate" "hy_https_certificate_withpass" {
  # This is in case the cert has passwphrase
  count = var.certificate_passphrase != "" ? 1 : 0
  #Required
  certificate_name = "hy_https_cert"
  load_balancer_id = oci_load_balancer_load_balancer.hydr_LBR.id

  #Optional
  ca_certificate = file(var.certificate_ca_certificate_file)
  passphrase = var.certificate_passphrase
  private_key        = file(var.certificate_private_key_file)
  public_certificate = file(var.certificate_public_certificate_file)

  lifecycle {
    create_before_destroy = true
  }
}


########################################################################################################
# Configure Listeners
# - Admin_listener
# - Internal_listener
# - SOA_listener
# - HTTP_listener
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

resource "oci_load_balancer_listener" "Internal_listener" {
  #Required
  default_backend_set_name = oci_load_balancer_backend_set.WSM_backendset[0].name
  load_balancer_id         = oci_load_balancer_load_balancer.hydr_LBR.id
  name                     = "Internal_listener"
  port                     = var.frontend_internal_port
  protocol                 = "HTTP"

  hostname_names      = [oci_load_balancer_hostname.internal_frontend.name]
  routing_policy_name = oci_load_balancer_load_balancer_routing_policy.Internal_rules.name
  #rule_set_names = [oci_load_balancer_rule_set.test_rule_set.name]
}


resource "oci_load_balancer_listener" "SOA_listener" {
  #Required
  default_backend_set_name = oci_load_balancer_backend_set.SOA_backendset[0].name
  load_balancer_id         = oci_load_balancer_load_balancer.hydr_LBR.id
  name                     = "SOA_listener"
  port                     = var.frontend_https_port
  protocol                 = "HTTP"

  hostname_names      = [oci_load_balancer_hostname.https_frontend.name]
  routing_policy_name = oci_load_balancer_load_balancer_routing_policy.SOA_rules[0].name
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
  default_backend_set_name = oci_load_balancer_backend_set.WSM_backendset[0].name
  load_balancer_id         = oci_load_balancer_load_balancer.hydr_LBR.id
  name                     = "HTTP_listener"
  port                     = var.frontend_http_port
  protocol                 = "HTTP"

  hostname_names = [oci_load_balancer_hostname.http_frontend.name]
  rule_set_names = [oci_load_balancer_rule_set.HTTP_to_HTTPS_redirect.name]
}

########################################################################################################
# Configure Rule set (headers, redirects)
########################################################################################################
resource "oci_load_balancer_rule_set" "HTTP_to_HTTPS_redirect" {
  #Required
  items {
    #Required
    action = "REDIRECT"

    conditions {
      #Required
      attribute_name  = "PATH"
      attribute_value = "/"
      #Optional
      operator = "FORCE_LONGEST_PREFIX_MATCH"
    }
    #Optional
    redirect_uri {
      #Optional
      host     = "{host}"
      path     = "/{path}"
      port     = var.frontend_https_port
      protocol = "HTTPS"
      query    = "?{query}"
    }
    response_code = "301"
  }
  load_balancer_id = oci_load_balancer_load_balancer.hydr_LBR.id
  name             = "HTTP_to_HTTPS_redirect"
}


resource "oci_load_balancer_rule_set" "SSLHeaders" {
  #Required
  items {
    #Required
    action = "ADD_HTTP_REQUEST_HEADER"
    header = "is_ssl"
    value  = "ssl"
  }
  items {
    #Required
    action = "ADD_HTTP_REQUEST_HEADER"
    header = "WL-Proxy-SSL"
    value  = "true"
  }
  load_balancer_id = oci_load_balancer_load_balancer.hydr_LBR.id
  name             = "SSLHeaders"
}
