## WLS Hybrid DR terraform scripts  
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##


#################################################################################################
# Locals definitions
#################################################################################################

# Get the clusters topology from the yaml file
locals {
  topology = merge(yamldecode(file(var.clusters_definition_file)))
}

output "Clusters_definition" {
  value = var.there_is_OHS ? null : local.topology.clusters

}

# Need to flatten the list of backends to be able to create the backend resources
locals {
  list_of_backends = var.there_is_OHS ? null : flatten([
    for cluster_key, clusters in local.topology.clusters : [
      for backend_key, backend in clusters.cluster.servers_IPs[*] : {
        backend_IP   = backend
        cluster_name = clusters.cluster.name
        backend_port = clusters.cluster.port
      }
    ]
  ])

}

output "list_of_backends" {
  value = local.list_of_backends

}

/* not used finally
# To convert the list of clusters to a tupple to create the application route rules
locals {
  list_of_clusters = var.there_is_OHS ? null :[
        for cluster_key, clusters in local.topology.clusters : {
                name = clusters.cluster.name
                servers_IPs = clusters.cluster.servers_IPs
                port = clusters.cluster.port
                uris = clusters.cluster.uris
        }
    ]

}

output "list_of_clusters" {
        value = local.list_of_clusters

}
*/

/* not used finally
# To construct the syntax of the routing policies for each cluster, using the list of uris
# As input we have:
# - the cluster name (used for the backend name)
# - the list of uris of each cluster
# Need to use this syntax for each cluster
# condition = "any(http.request.url.path sw (i '/uri1'), http.request.url.path sw (i '/uri2'), ..)"
locals {
  list_of_clusters_and_rulepolicy = [
        for cluster_key, clusters in local.topology.clusters : {
                cluster_name = clusters.cluster.name
                backend_port = clusters.cluster.port
                internal = clusters.cluster.internal
                #individual_rules = [ for uri_key, uri in clusters.cluster.uris[*] : [
                #        "http.request.url.path sw (i '${uri}')"
                #]
                #]
                individual_rules = formatlist( "http.request.url.path sw (i '%s')", clusters.cluster.uris[*])
                #joined_rules = join(",", individual_rules[*])
                #routing_policy = "any(${clusters.joined_rules})"
         }
        ]
}

output "list_of_clusters_and_rulepolicy" {
        value = local.list_of_clusters_and_rulepolicy
}
*/

