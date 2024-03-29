## DNS update sample scripts
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

Example for updating the front-end virtual hostname in the Oracle Cloud DNS service
####################################################################################

It is assumed a PaaS DR setup based on one of the following documents:
"SOA Suite on Oracle Cloud Infrastructure Marketplace Disaster Recovery" (https://www.oracle.com/a/tech/docs/maa-soamp-dr.pdf)
"Oracle WebLogic Server for Oracle Cloud Infrastructure Disaster Recovery" (https://www.oracle.com/a/otn/docs/middleware/maa-wls-mp-dr.pdf)

In this example, the DNS frontend virtual hostname is registered in an Oracle DNS Zone, and the updates are performed using an OCI client script.
If Oracle Site Guard is used, these scripts can be also invoked by Site Guard during a switchover/failover procedure.

Steps:

##########################################################################
1) SETUP AND CONFIGURE OCI CLIENT
##########################################################################
In the host that will run the scripts to invoke the DNS change. 
If the scripts are going to be run from SiteGuard, perform this in a server that is auxiliary host for the Siteguard Sites. 
- Setup an configure OCI Client as per https://docs.cloud.oracle.com/iaas/Content/API/SDKDocs/cliinstall.htm
- Use "oci setup config" to create an oci client config file specific for the dns change. 
If there is any existing configuration, do not use default locations to prevent from overriding it.
Alternatively,  you can set up the API public/private keys yourself and write your own config file, 
see SDK and Tool Configuration (https://docs.cloud.oracle.com/iaas/Content/API/Concepts/sdkconfig.htm)
- Add the the public key to the oci user in the OCI console as explained in point "How to Upload the Public Key" 
(https://docs.cloud.oracle.com/iaas/Content/API/Concepts/apisigningkey.htm)

##########################################################################
2) PREPARE THE OCI CLIENT SCRIPTS 
##########################################################################
- Prepare oci client scripts for the DNS entry update. 
The oci client command to replace a DNS record is the following syntax:
   oci dns record rrset update  -  Replaces records in the specified RRSet.
    --config_file
    --zone-name-or-id [text]  The name or OCID of the target zone.
    --domain [text]           The target fully-qualified domain name (FQDN) within the target zone that is going to be updated (virtual frontend name).
    --rtype [text]            The type of the target RRSet within the target zone. 
    --items                   This option is a JSON list with items of type RecordDetails. 
                              For documentation on RecordDetails please see our API reference: 
                              https://docs.cloud.oracle.com/api/#/en/dns/20180115/datatypes/RecordDetails. 
    --force

- See the examples "virtual_frontend_DNS_entry_to_SITE1.sh" and "virtual_frontend_DNS_entry_to_SITE2.sh" included in this zip.



References: 
OCI CLI Command Reference (DNS) https://docs.cloud.oracle.com/iaas/tools/oci-cli/latest/oci_cli_docs/cmdref/dns/record/zone/update.html
"SOA Suite on Oracle Cloud Infrastructure Marketplace Disaster Recovery" (https://www.oracle.com/a/tech/docs/maa-soamp-dr.pdf)
"Oracle WebLogic Server for Oracle Cloud Infrastructure Disaster Recovery" (https://www.oracle.com/a/otn/docs/middleware/maa-wls-mp-dr.pdf)

