## private_dns_views_for_dr terraform scripts
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
  alias		   = "Primary_Region"
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.primary_region
}

provider "oci" {
  alias            = "Secondary_Region"
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.secondary_region
}


# Data retrieval
#####################################################################################################
data "oci_core_vcn" "primary_vcn" {
    count =  var.configure_in_primary ? 1 : 0
    provider = oci.Primary_Region
    #Required
    vcn_id = var.primary_vcn_id
}

data "oci_core_vcn" "secondary_vcn" {
    count =  var.configure_in_secondary ? 1 : 0
    provider = oci.Secondary_Region
    #Required
    vcn_id = var.secondary_vcn_id
}

data "oci_core_vcn_dns_resolver_association" "primary_dns_resolver_association" {
    count =  var.configure_in_primary ? 1 : 0
    provider = oci.Primary_Region
    #Required
    vcn_id = var.primary_vcn_id
}

data "oci_core_vcn_dns_resolver_association" "secondary_dns_resolver_association" {
    count =  var.configure_in_secondary ? 1 : 0
    provider = oci.Secondary_Region
    #Required
    vcn_id = var.secondary_vcn_id
}


data "oci_dns_resolver" "primary_dns_resolver" {
    count =  var.configure_in_primary ? 1 : 0
    provider = oci.Primary_Region
    #Required
    resolver_id = data.oci_core_vcn_dns_resolver_association.primary_dns_resolver_association[0].dns_resolver_id
    scope = "PRIVATE"
}

data "oci_dns_resolver" "secondary_dns_resolver" {
    count =  var.configure_in_secondary ? 1 : 0
    provider = oci.Secondary_Region
    #Required
    resolver_id = data.oci_core_vcn_dns_resolver_association.secondary_dns_resolver_association[0].dns_resolver_id
    scope = "PRIVATE"
}

data "oci_dns_view" "existing_views_in_primary_resolver" {
    #Required
    provider = oci.Primary_Region
    count =  var.configure_in_primary ? length(data.oci_dns_resolver.primary_dns_resolver[0].attached_views[*]) : 0
    view_id = data.oci_dns_resolver.primary_dns_resolver[0].attached_views[count.index].view_id
    scope = "PRIVATE"
}

data "oci_dns_view" "existing_views_in_secondary_resolver" {
    #Required
    provider = oci.Secondary_Region
    count =  var.configure_in_secondary ? length(data.oci_dns_resolver.secondary_dns_resolver[0].attached_views[*]) : 0
    view_id = data.oci_dns_resolver.secondary_dns_resolver[0].attached_views[count.index].view_id
    scope = "PRIVATE"
}


# Outputs
#######################################################################################################
output "PRIMARY_VCN___________________Name" {
#    value = var.configure_in_primary ? data.oci_core_vcn.primary_vcn[0].* : null
    value = var.configure_in_primary ? data.oci_core_vcn.primary_vcn[0].display_name : null
}

output "SECONDARY_VCN_________________Name" {
#    value = var.configure_in_secondary ? data.oci_core_vcn.secondary_vcn[0].* : null
     value = var.configure_in_secondary ? data.oci_core_vcn.secondary_vcn[0].display_name : null
}


#output "primary_dns_resolver" {
#    value = var.configure_in_primary ? data.oci_dns_resolver.primary_dns_resolver[0].* : null
#}

#output "secondary_dns_resolver" {
#    value = var.configure_in_secondary ? data.oci_dns_resolver.secondary_dns_resolver[0].* : null
#}

output "PRIMARY_VCN_DNS_RESOLVER______Existing_Private_views" {
    value = var.configure_in_primary ? data.oci_dns_view.existing_views_in_primary_resolver[*].display_name : null
}

output "SECONDARY_VCN_DNS_RESOLVER____Existing_Private_views" {
    value = var.configure_in_secondary ? data.oci_dns_view.existing_views_in_secondary_resolver[*].display_name : null

}

output "PRIMARY_VCN_DNS_RESOLVER______New_private_view_that_will_be_added" {
    value = var.configure_in_primary ? oci_dns_view.private_view_in_primary[0].display_name : null

}

output "SECONDARY_VCN_DNS_RESOLVER____New_private_view_that_will_be_added" {
    value = var.configure_in_secondary ? oci_dns_view.private_view_in_secondary[0].display_name : null
}



# Create the private view and zone in Primary
########################################################################################################

resource "oci_dns_view" "private_view_in_primary" {
    count =  var.configure_in_primary ? 1 : 0
    provider = oci.Primary_Region

    #Required
    compartment_id = var.primary_compartment_id
    scope = "PRIVATE"

    #Optional
    #defined_tags = var.view_defined_tags
    display_name = var.primary_private_view_name
    #freeform_tags = var.view_freeform_tags
}


resource "oci_dns_zone" "zone_in_primary" {
    count =  var.configure_in_primary ? 1 : 0
    provider = oci.Primary_Region

    #Required
    compartment_id = var.primary_compartment_id
    name = var.secondary_domain
    zone_type = "PRIMARY"

    #Optional
    scope = "PRIVATE"
    # Tis zone must be added to the private view
    view_id = oci_dns_view.private_view_in_primary[0].id
}


# Create the private view and zone in Secondary
########################################################################################################
resource "oci_dns_view" "private_view_in_secondary" {
    count =  var.configure_in_secondary ? 1 : 0
    provider = oci.Secondary_Region

    #Required
    compartment_id = var.secondary_compartment_id
    scope = "PRIVATE"

    #Optional
    #defined_tags = var.view_defined_tags
    display_name = var.secondary_private_view_name
    #freeform_tags = var.view_freeform_tags
}


resource "oci_dns_zone" "zone_in_secondary" {
    count =  var.configure_in_secondary ? 1 : 0
    provider = oci.Secondary_Region

    #Required
    compartment_id = var.secondary_compartment_id
    name = var.primary_domain
    zone_type = "PRIMARY"

    #Optional
    scope = "PRIVATE"
    # This zone must be added to the private view
    view_id = oci_dns_view.private_view_in_secondary[0].id


}


# Add the entries to zone_in_primary (secondary names with primary IPs)
########################################################################################################
resource "oci_dns_rrset" "new_rrset_in_primary" {
    count =  var.configure_in_primary ? length(var.secondary_nodes_fqdns) : 0
    provider = oci.Primary_Region

    #Required
    domain = var.secondary_nodes_fqdns[count.index]
    rtype = "A"
    zone_name_or_id = oci_dns_zone.zone_in_primary[0].id

    #Optional
    compartment_id = var.primary_compartment_id
    items {
        #Required
        domain = var.secondary_nodes_fqdns[count.index]
        rdata = var.primary_nodes_IPs[count.index]
        rtype = "A"
        ttl = "120"
    }
    scope = "PRIVATE"
    view_id = oci_dns_view.private_view_in_primary[0].id
}

# Add the entries to zone_in_secondary (primary names with secondary IPs)
########################################################################################################
resource "oci_dns_rrset" "new_rrset_in_secondary" {
    count =  var.configure_in_secondary ? length(var.primary_nodes_fqdns) : 0
    provider = oci.Secondary_Region

    #Required
    domain = var.primary_nodes_fqdns[count.index]
    rtype = "A"
    zone_name_or_id = oci_dns_zone.zone_in_secondary[0].id

    #Optional
    compartment_id = var.secondary_compartment_id
    items {
        #Required
        domain = var.primary_nodes_fqdns[count.index]
        rdata = var.secondary_nodes_IPs[count.index]
        rtype = "A"
        ttl = "120"
    }
    scope = "PRIVATE"
    view_id = oci_dns_view.private_view_in_secondary[0].id
}




# Add the primary private view to primary VCN resolver
########################################################################################################
# CAUTION!!!! NOT PROVIDING THE LIST OF THE EXISTING VIEWS REPLACES THE ATTACHED VIEWS WITH THE NEW ONE ONLY (does not add it)
resource "oci_dns_resolver" "primary_resolver" {
    count =  var.configure_in_primary ? 1 : 0
    provider = oci.Primary_Region

    #Required
    resolver_id = data.oci_dns_resolver.primary_dns_resolver[0].id
    scope = "PRIVATE"

    #With this we list the existing views, if not, they are removed
    dynamic attached_views {
    	for_each = data.oci_dns_resolver.primary_dns_resolver[0].attached_views[*].view_id
	content {
        view_id = attached_views.value
        }
    }
    #Then add the new one
    attached_views {
        view_id= oci_dns_view.private_view_in_primary[0].id
    }
}

# Add the secondary private view to secondary VCN resolver
########################################################################################################

# CAUTION!!!! NOT PROVIDING THE LIST OF THE EXISTING VIEWS REPLACES THE ATTACHED VIEWS WITH THE NEW ONE ONLY (does not add it)
resource "oci_dns_resolver" "secondary_resolver" {
    count =  var.configure_in_secondary ? 1 : 0
    provider = oci.Secondary_Region

    #Required
    resolver_id = data.oci_dns_resolver.secondary_dns_resolver[0].id
    scope = "PRIVATE"

    #With this we list the existing views, if not, they are removed
    dynamic attached_views {
        for_each = data.oci_dns_resolver.secondary_dns_resolver[0].attached_views[*].view_id
        content {
        view_id = attached_views.value
        }
    }
    #Then add the new one
    attached_views {
        view_id= oci_dns_view.private_view_in_secondary[0].id
    }
}

