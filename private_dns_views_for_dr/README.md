private_dns_views_for_dr scripts version 1.0.  
Copyright (c) 2023 Oracle and/or its affiliates  
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/  

## DESCRIPTION
Terraform scripts to create private DNS views in primary and standby VCNs. These private DNS views contain the other site's host names, but resolved with local IPs. With this approach you don't need to add the names as aliases to the /etc/hosts of each midtier host.

This is typically used in **Disaster Recovery** environments like SOA Marketplace DR, WLS for OCI DR and WLS/SOA Hybrid DR.  

These scripts are applicable to Oracle Cloud Infrastructure only.  
These scripts are applicable when the DNS Type used in the VCN is "Internet and VCN resolver" (which is the default choice). Not applicable when using Custom resolver in the VCNs. 

## GETTING STARTED

In most of the Active-Pasive Disaster Recovery solutions, the secondary midtier is a mirror copy of the primary midtier.

The **PRIMARY**  midtier components listen in the hostnames configured as the listen addreses in the WebLogic configuration. For example:
- WLS managed server 1 in primary listens on apphost1.example.com address, which corresponds with the IP 111.111.111.111
- WLS managed server 2 in primary listens on apphost2.example.com address, which corresponds with the IP 111.111.111.112 
- WLS managed server 3 in primary listens on apphost3.example.com address, which corresponds with the IP 111.111.111.113

The **SECONDARY** midtier configuration is a copy of the primary configuration, so the listen addresses are the same.  
However, it is expected that the IPs of the secondary systems are different than the primary IPs. Secondary hosts must be able to resolve the hostnames used as listen addresses, but with the IPs of the equivalent secondary nodes.  
For example, the components in secondary:
- WLS managed server 1 in secondary listens on apphost1.example.com address, which corresponds with the IP 222.222.222.111
- WLS managed server 2 in secondary listens on apphost2.example.com address, which corresponds with the IP 222.222.222.112 
- WLS managed server 3 in secondary listens on apphost3.example.com address, which corresponds with the IP 222.222.222.113

The hostnames that the WLS components use as listen addresses can be:
- **Virtual names**.  
The names are different than the physical hostnames. This is normally the case of Disaster Recovery environments based on the **Enterprise Deployment Guide** systems. See:  
FMW Disaster Recovery Guide - https://docs.oracle.com/en/middleware/fusion-middleware/12.2.1.4/asdrg/index.html  
Hybrid DR solution for Oracle SOA Suite - https://docs.oracle.com/en/solutions/soa-dr-on-cloud/index.html  

- The **physical hostnames of the primary hosts**.  
This is the case of the **PaaS DR environments** like SOAMP, WLS for OCI.  See:  
SOA Marketplace Disaster Recovery - https://www.oracle.com/a/tech/docs/maa-soamp-dr.pdf  
Wls for OCI Disaster Recovery - https://www.oracle.com/a/otn/docs/middleware/maa-wls-mp-dr.pdf  


In any of these cases, the midtier hosts in each site must be able to resolve the hostnames used as listen addresses with their own IPs.

This can be implemented by adding the listen address hostnames to the /etc/hosts files of the WLS hosts: in primary hosts, the names point to the IP addresses of the primary WLS hosts; in secondary hosts, the names point to the IP addresses of the secondary WLS hosts. But this requires to manually add the entries to all the WLS hosts. And when you are adding new nodes to the cluster (e.g. in scale-out), the new node is not able to resolve the names until you modify its /etc/hosts.  

A better approach is to add these hostnames to private views of the DNS resolver of each site. The terraform scripts provided here help to configure this approach.

## USING PRIVATE DNS VIEWS FOR DR

In this approach, implemented by the terraform scripts in this folder, the hostnames used as listen addresses by WebLogic servers are added to the DNS server of each site and they resolve to the secondary's IPs.  
More specifically: the provided **primary hostnames** (listen addresses) are added to the **DNS resolver** of the secondary VCN, pointing to the **IP addresses of the secondary** WebLogic hosts.  
Also, the **secondary hostnames** are added to the **DNS resolver** of the primary VNC, pointing to the **IP addresses of the primary** WebLogic hosts. (Note that this is not essential, because it is expected that the WebLogic configuration don't use this names. But is done to avoid errors in primary, in case that any reference to secondary names was added to the config while the secondary site takes the primary role).
- Advantages:  
    - You can add all the entries in a unique place in each site, instead of adding them to all the /etc/hosts of all the WebLogic server hosts.
    - Any new host (e.g. when scaling-out) is able to resolve the names properly, hence the scale-out procedures are simplified. 
- Disadvantages:  
    - This mode is **valid only** when **separated DNS servers** are used in primary and secondary sites. Otherwise, it can cause conflicts in naming resolution. The server of each site should resolve these names with their own IPs.
    - When the **non-fully qualified hostnames** (e.g. “soahost1”) of the primary **listen addresses** do not exist in secondary, you need to add the domain name used by them to the "search" list in the /etc/resolv.conf file on each secondary host. This way, the secondary hosts will be able to search the non-fully qualified names of the listen addresses in the private DNS view. 
This scenario: 
        - is not a common practice: normally fully qualified hostnames are used as listen addresses, so you don't need to resolve the non-fully qualified hostnames used by primary.
        - does NOT apply to SOAMP DR and WLS for OCI DR scenarios. Because the values configured as the listen addresses for the WLS servers are the fully qualified names. Besides this, the non-fully qualified hostnames of primary and standby nodes are the same if you use the procedures described in their respective DR setup documents.  
> **NOTE**:  In OCI compute instances, manual changes made to the /etc/resolv.conf file are not persisted across reboots. To preserve these changes across reboots, you need to create an additional DHCP Option in the VNC's configuration. To do this: 
> In secondary region, navigate to "Networking" > "Virtual Cloud Networks" >  select the secondary VCN  
> Navigate to "DHCP Options" and click on "Create DHCP Options". Use:  
> - DNS Type:  "Internet and VCN Resolver"  
> - DNS Search Domain Type:    "Custom Search Domain"  
> - Search Domain:  \<the domain of the primary listen addresses\>  
>
> Then, navigate to the secondary midtier subnet. Edit the subnet and select the new created DHCP Option in "DHCP options".  
> This way, the domain name used by primary listen addresses will be added to the /etc/resolv.conf of the subnet's hosts when they start, along with the local subnet domain.  
> See https://docs.cloud.oracle.com/en-us/iaas/Content/Network/Tasks/managingDHCP.htm  and “OCI: /etc/resolv.conf Customizations Are Lost Periodically Or When Instance Is Rebooted (Doc ID 2705361.1)” for additional details.  


## HOW TO USE THESE TERRAFORM SCRIPTS

The Oracle Cloud Infrastructure (OCI) allows you to use Terraform to interact with Oracle Cloud Infrastructure resources. Terraform is an open source tool that allows you to programmatically manage, version, and persist infrastructure through the "infrastructure-as-code" model. For more information about Terraform and OCI see:  
https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/terraform.htm  
https://registry.terraform.io/providers/oracle/oci/latest/docs  

These terraform scripts create the DNS private views for each site, adding the entries of the other site midtier hostnames, but resolved with the local IPs. The private view of each site is added to the default DNS Resolver of the VCN in each site, so all the hosts in the VCN are able to use the private views.  

These scripts are applicable when the DNS Type used in the VCNs is "Internet and VCN resolver" (which is the default choice). Not applicable when using Custom resolver. Ref: https://docs.oracle.com/en-us/iaas/Content/Network/Concepts/dns.htm#Choices

### Input parameters:
This information must be provided in the **terraform.tfvars** file:
- Information to connect to OCI tenancy (tenancy_ocid, user_ocid, fingerprint, private_key_path)
- The names of the primary and secondary regions.
- 2 flags (true/false):
    - configure_in_primary : if false, the scripts do not create anything in primary region. 
    - configure_in_secondary : if false, the scripts do not create anything in secondary region.
- Primary and secondary compartments ocids.
- Primary and secondary VCNs ocids.
- The dns domain names of the primary and secondary subnets.
- The list of primary nodes hostnames and their IPs. These names must be the listen addresses used by the WLS components.
- The list of secondary nodes hostnames and their IPs.

<details><summary>Help to get the input parameter values</summary>

- To obtain the information to connect to OCI (tenancy_ocid, user_ocid, etc.):  
https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/terraformproviderconfiguration.htm#APIKeyAuth
- To obtain the OCID of a compartment: 
    - In OCI Console, top-Left hamburger > Identity > Compartments
    - Click on the compartment of interest.
    - Click the "Copy" link next to "OCID".
- To obtain the OCID of a VCN:
    - In OCI Console, top-Left hamburger > Network > Virtual Cloud Networks
    - Click on the VCN of interest.
    - Click the "Copy" link next to "OCID".
</details>

### These terraform scripts will:
- Create Private DNS zones:  
    - a private DNS zone in primary region compartment, with the secondary dns domain name.
    - a private DNS zone in secondary region compartment, with the primary dns domain name.
- Add dns records to the private DNS zones:  
    - these type A records are added to the zone created in **primary** region:
        - \<provided secondary node1 hostname\> \<provided primary node1 IP\>
        - \<provided secondary node2 hostname\> \<provided primary node2 IP\>
        - (...)
        - \<provided secondary node_N_ hostname\> <provided primary node_N_ IP\>
    - these type A records are added to the zone created in **secondary** region:
        - \<provided primary node1 hostname\> \<provided secondary node1 IP\>
        - \<provided primary node2 hostname\> \<provided secondary node2 IP\>
        - (...)
        - \<provided primary node_N_ hostname\> \<provided secondary node_N_ IP\>
- Create private DNS views that include the zones:  
    - a DNS private view in primary region that includes the zone created in primary. 
    - a DNS private view in secondary region that includes the zone created in secondary.
- Add private views to the apropriate DNS resolver:
    - the private view created in primary to the primary VCN's DNS resolver.
    - the private view created in secondary to the secondary VCN's DNS resolver.

These actions are performed by the **main.tf** file

### These terraform scripts will NOT:
- The scripts will not modify the DHCP Options of the VCNs.

### Steps to use:
- Edit **terraform.tfvars** file.
- Provide the customer values.
- Run "terraform init" to initialize and download required modules.
- Run "terraform plan" to review the resources that are going to be created.
- Run "terraform apply" to create the resources.  
- **IMPORTANT**: do **NOT** use "terraform destroy". It will remove the previously existing private views from the list of the private views attached to the DNS Resolvers.


### Limitations:
- These scripts are applicable only when the DNS Type used in the VCN is "Internet and VCN resolver" (which is the default choice). Not applicable when the VCNs are using Custom resolver by default. Ref: https://docs.oracle.com/en-us/iaas/Content/Network/Concepts/dns.htm#Choices


## EXAMPLES

### Example 1: SOAMP DR
<details><summary> Click to expand </summary>

Example of terraform.tfvars for the scenario that Primary and Secondary are SOA Marketplace instances in OCI.  
In primary, these are the hostnames and addresses of the WebLogic compute instances:  
111.111.111.111  soampdrenv-soa-0.subnetpri.vcnpri.oraclevcn.com  
111.111.111.112  soampdrenv-soa-1.subnetpri.vcnpri.oraclevcn.com  

In secondary, these are the hostnames and addresses of the WebLogic compute instances:  
222.222.222.111  soampdrenv-soa-0.subnetsec.vcnsec.oraclevcn.com  
222.222.222.112  soampdrenv-soa-1.subnetsec.vcnsec.oraclevcn.com  

You can use the terraform scripts to add the other site's names to each VCN's OCI dns resolver, pointing to the local  IPs.   
The terraform.tfvars would look like this:

> \## OCI Provider details  
> tenancy_ocid     = "ocid1.tenancy.oc1..aaaaaaaa7dke76767676767efxxrokon3f2bxo6z6e2odqxsklgq"  
> user_ocid        = "ocid1.user.oc1..aaaaaaaa77pn6uke898989898998nsu5doteepq6d7jqaubes3fsq4q"  
> fingerprint      = "5c:44:53:25:4d:a6:22:77:33:9c:0d:ae:98:28:e6:ba"  
> private_key_path = "/home/opc/oracleidentitycloudservice_username-02-28-08-31.pem"  
> primary_region          = "uk-london-1"  
> secondary_region        = "eu-frankfurt-1"  
> 
> \# Flags  
> configure_in_primary    = "true"  
> configure_in_secondary  = "true"  
> 
> \# Compartments  
> primary_compartment_id = "ocid1.compartment.oc1..aaaaaaaaigp2uohnf5656565626qg4yhnrdxdxkufjtefw53je5fz6eia"  
> secondary_compartment_id = "ocid1.compartment.oc1..aaaaaaaaigp2uohnf5656565626qg4yhnrdxdxkufjtefw53je5fz6eia"  
> 
> \# VCNs  
> primary_vcn_id  = "ocid1.vcn.oc1.uk-london-1.amaaaaaaj4y3nwqaehe65656e7qdoenh6sawqyat6vwr6xy23676a"  
> secondary_vcn_id = "ocid1.vcn.oc1.eu-frankfurt-1.amaaaaaaj4y3nwqad7687878p6wjbfc33isxmqzksnoixkihm45gmq"  
> 
> \# Primary domain, hosts fqdns and IPs. Order must be consistent  
> primary_domain="subnetpri.vcnpri.oraclevcn.com"  
> primary_nodes_fqdns=["soampdrenv-soa-0.subnetpri.vcnpri.oraclevcn.com","soampdrenv-soa-1.subnetpri.vcnpri.oraclevcn.com"]  
> primary_nodes_IPs=["111.111.111.111","111.111.111.112"]  
> 
> 
> \# Secondary domain, hosts fqdns and IPs. Order must be consistent  
> secondary_domain="subnetsec.vcnsec.oraclevcn.com"  
> secondary_nodes_fqdns=["soampdrenv-soa-0.subnetsec.vcnsec.oraclevcn.com","soampdrenv-soa-1.subnetsec.vcnsec.oraclevcn.com "]  
> secondary_nodes_IPs=["222.222.222.111","222.222.222.112"]  
> 
> \# Predefined values  
> primary_private_view_name    = "TESTS_Private_View_for_DR_in_Primary"  
> secondary_private_view_name  = "TESTS_Private_View_for_DR_in_Secondary"  

</details> 

### Example 2: HYBRID DR 
<details><summary> Click to expand </summary>
  
Example of terraform.tfvars for the following case:  
Primary is in on-prem. The WLS components listen in the following virtual hostnames and addresses (virtual names in this case, not the physical hostnames.):  
100.11.11.20   adminvhn.example.com  
100.11.11.13   soahost1.example.com  
100.11.11.14   soahost2.example.com  

Secondary is in OCI. The secondary WLS hosts physical hostnames and IPs are the following:  
100.22.22.20   hydrsoa-vip.midTiersubnet.hydrvcn.oraclevcn.com  
100.22.22.13   hydrsoa1.midTiersubnet.hydrvcn.oraclevcn.com  
100.22.22.14   hydrsoa2.midTiersubnet.hydrvcn.oraclevcn.com  

You can use these terraform scripts to add the virtual names to the OCI dns resolver, pointing to the equivalent secondary IPs.  
Instead of providing the primary physical hostnames in the "primary_nodes_fqdns" list, provide the virtual names used by WLS as listener addresses.
Also, set "configure_in_primary" flag to false, because the primary is in on-prem and the script can't perform modifications there.

The terraform.tfvars would look like this:
> \## OCI Provider details  
> tenancy_ocid     = "ocid1.tenancy.oc1..aaaaaaaa7dkeo7777777777777okon3f2bxo6z6e2odqxsklgq"  
> user_ocid        = "ocid1.user.oc1..aaaaaaaa77pn66666666666666665doteepq6d7jqaubes3fsq4q"  
> fingerprint      = "5c:44:53:23:4c:67:22:77:33:9h:0d:ae:98:28:e6:ba"  
> private_key_path = "/home/opc/my_keys/oracleidentitycloudservice_username-02-28-08-31.pem"  
> primary_region          = "uk-london-1"         (although primary OCI region not used in this case, a value needs to be provided)  
> secondary_region        = "eu-frankfurt-1"  
>   
> \# Flags  
> configure_in_primary    = "false"  
> configure_in_secondary  = "true"  
>   
> \# Compartments  
> primary_compartment_id = ""  
> secondary_compartment_id = "ocid1.compartment.oc1..aaaaaaaaigp2u747474747747474nrdxdxkufjtefw53je5fz6eia"  
>   
> \# VCNs  
> primary_vcn_id  = ""  
> secondary_vcn_id = "ocid1.vcn.oc1.eu-frankfurt-1.amaaaaaaj4y3nwqad767676767676767fc33isxmqzksnoixkihm45gmq"  
>   
> \# Primary domain, hosts fqdns and IPs. Order must be consistent  
> primary_domain="example.com"  
> primary_nodes_fqdns=["adminvhn.example.com","soahost1.example.com","soahost2.example.com"]  
> primary_nodes_IPs=["100.11.11.20","100.11.11.13","100.11.11.14"]  
> 
> \# Secondary domain, hosts fqdns and IPs. Order must be consistent  
> secondary_domain="midTiersubnet.hydrvcn.oraclevcn.com"  
> secondary_nodes_fqdns=["hydrsoa-vip.midTiersubnet.hydrvcn.oraclevcn.com","hydrsoa1.midTiersubnet.hydrvcn.oraclevcn.com","hydrsoa2.midTiersubnet.hydrvcn.oraclevcn.com"]  
> secondary_nodes_IPs=["100.22.22.20","100.22.22.13","100.22.22.14"]  
>   
> \# Predefined values
> primary_private_view_name    = "TESTS_Private_View_for_DR_in_Primary"  
> secondary_private_view_name  = "TESTS_Private_View_for_DR_in_Secondary"  


</details> 

## Configure using the OCI Console
<details><summary> Click to expand </summary>

You can perform the same changes using the OCI Console:
- Identify the hostnames (fqdn) and the IPs of the primary and secondary mid-tier hosts.
- For **PRIMARY region**. In OCI Console, go to primary region and:
    - Create the PRIVATE VIEW to resolve the names of the secondary hosts WITH THE PRIMARY IPS.
    Networking > DNS Management > Private Views > Create Private View.  E.g. NAME: SOAMPDR_SECONDARY_HOSTS
    - In the private view, click "Create Zone".  For the zone name, you must use the complete domain of the SECONDARY hosts. E.g.: "subnetsec.vncsec.oraclevcn.com" .
    - Add the secondary hostsnames as "A" type entries to this zone (provide the "shortname", becuse the domain is automatically added to the entry), resolved with PRIMARY IPS. 
    - Click "Publish changes".
    - Add the private view to the primary VCN's DNS resolver:
        - Click in PRIMARY VCN > Click in the "DNS resolver" resource.
        - Add the DNS private view to the list of private views. This way, the hosts in the primary VCN, will resolve the names of secondary midtier hosts using that private view.
    - Validate the resolution in the PRIMARY hosts, by doing nslookup of the SECONDARY midtier hostnames. They must be resolved with the primary hosts' IPs. 
    NOTE: it is not essential to add the secondary hostnames to the primary site. It is expected that only the primary hostnames appear in the WebLogic configuration. But this is to prevent issues, just in case any reference to secondary names is added in the config while the secondary site takes the primary role. But this is done to avoid errors in primary, in case that any reference to secondary names was added to the config while the secondary site takes the primary role.

- For **SECONDARY region**, do the same but in the other way.  In OCI Console, go to secondary region and:
    - Create the PRIVATE VIEW to resolve the names of the PRIMARY hosts WITH THE SECONDARY IPS
    Networking > DNS Management > Private Views > Create Private View. E.g.  NAME:    SOAMPDR_PRIMARY_HOSTS
    - In the private view, click "Create Zone". For the zone name, you must use the complete domain of the PRIMARY hosts. In this example, "subnetpri.vcnpri.oraclevcn.com"
    - Add the primary hosts names to this zone (provide the "shortname", becuse the domain is automatically added to the entry), but resolved with SECONDARY IPS.
    - Click "Publish changes".
    - Add the private view to the secondary VCN's DNS resolver:
        - Click in SECONDARY VCN > Click in th "DNS resolver" resource
        - Add the DNS private view to the list of the prviate views. This way, the hosts in the secondary VCN, will resolve the names of primary midtier hosts using that private view.
    - Validate the resolution in the SECONDARY hosts, by running nslookup of the PRIMARY midtir hostnames. They must be resolved with the equivalent SECONDARY IPs. 
</details>

## Authors and acknowledgment

Oracle Maximum Availability and Architecture (MAA) team

## External References
SOA Marketplace Disaster Recovery - https://www.oracle.com/a/tech/docs/maa-soamp-dr.pdf  
Wls for OCI Disaster Recovery - https://www.oracle.com/a/otn/docs/middleware/maa-wls-mp-dr.pdf  
Hybrid DR solution for Oracle SOA Suite - https://docs.oracle.com/en/solutions/soa-dr-on-cloud/index.html  
FMW Disaster Recovery Guide - https://docs.oracle.com/en/middleware/fusion-middleware/12.2.1.4/asdrg/index.html  
DNS Choices in VCNs: https://docs.oracle.com/en-us/iaas/Content/Network/Concepts/dns.htm#Choices  
OCI and Terraform:  https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/terraform.htm https://registry.terraform.io/providers/oracle/oci/latest/docs
