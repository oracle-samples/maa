## WLS Hybrid DR terraform scripts  
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

########################################################################################################
# Configure Rule sets (headers, redirects)
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

