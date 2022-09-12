## WLS Hybrid DR terraform scripts  
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

########################################################################################################
# Configure routing policies and route rules
# - Admin_rules : Admin_routerule, to route to OHS_Admin_backendset (if OHS) or Admin_backendset (if no OHS)
# - Application_rules_OHS: (if OHS) Application_routerules, to route to OHS_HTTP_backendset
# - Application_rules:     (if no OHS) <cluster_name>_routetules, to route to each cluster backendset
# - (optional) Internal_rules: Internal_routerule, to route to OHS_Admin_backendset (if OHS) or internal clusters backendsets (if no OHS)
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
    condition = "any(http.request.url.path sw (i '/console'), http.request.url.path sw (i '/em'))"
    name      = "Admin_routerules"
  }
}

resource "oci_load_balancer_load_balancer_routing_policy" "Application_rules" {
  #  count =  var.there_is_OHS ? 0 : 1
  #Required
  condition_language_version = "V1"
  load_balancer_id           = oci_load_balancer_load_balancer.hydr_LBR.id
  name                       = "Application_rules"
  dynamic "rules" {
    for_each = { for i in local.topology.clusters.* : i.cluster.name => i if i.cluster.internal == "no" }
    content {
      #Required
      actions {
        #Required
        name = "FORWARD_TO_BACKENDSET"
        #Optional
        backend_set_name = var.there_is_OHS ? oci_load_balancer_backend_set.Applications_backendsets[0].name : rules.value.cluster.name
        #backend_set_name = rules.value.cluster_name
      }
      #name = "${rules.value.cluster_name}_routerules"
      #condition = format ("any(%s)", join(",", rules.value.individual_rules))
      #name      = "${rules.value.cluster.name}_routerules"
      name      = format("%s_routerules", replace(rules.value.cluster.name,"-","_"))
      condition = format("any(%s)", join(",", formatlist("http.request.url.path sw (i '%s')", rules.value.cluster.uris[*])))
    }
  }
  depends_on = [
    oci_load_balancer_backend.node_backends
  ]

}

resource "oci_load_balancer_load_balancer_routing_policy" "Internal_rules" {
  count = var.internal_frontend != "" ? 1 : 0
  #Required
  condition_language_version = "V1"
  load_balancer_id           = oci_load_balancer_load_balancer.hydr_LBR.id
  name                       = "Internal_rules"
  dynamic "rules" {
    for_each = { for i in local.topology.clusters.* : i.cluster.name => i if i.cluster.internal == "yes" }
    #for_each = { for i in local.list_of_clusters_and_rulepolicy[*] : i.cluster_name => i if i.internal == "yes"} 
    content {
      #Required
      actions {
        #Required
        name = "FORWARD_TO_BACKENDSET"
        #Optional
        backend_set_name = var.there_is_OHS ? oci_load_balancer_backend_set.OHS_HTTP_internal_backendset[0].name : rules.value.cluster.name
      }
      #name      = "${rules.value.cluster_name}_routerules"
      #condition = format ("any(%s)", join(",", rules.value.individual_rules))
      name      = format("%s_routerules", replace(rules.value.cluster.name,"-","_"))
      condition = format("any(%s)", join(",", formatlist("http.request.url.path sw (i '%s')", rules.value.cluster.uris[*])))
    }
  }
  depends_on = [
    oci_load_balancer_backend.node_backends
  ]

}




