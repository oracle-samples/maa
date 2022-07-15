## DNS update sample scripts
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

# OCI client script that updates the frontend  dns entry (example "soacsdroci.domainexample.com") to Site1 LBR's public IP (example: 111.111.111.123)
oci dns record rrset update --config-file /home/opc/scripts/.oci_soacsdr/config --zone-name-or-id "domainexample.com" --domain  "soacsdroci.domainexample.com" --rtype "A" --items '[{"domain":"soacsdroci.domainexample.com","rdata":"111.111.111.123","rtype":"A","ttl":60}]' --force
