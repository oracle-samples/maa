## ExampleBVReplicaOCICli
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

#Usage
# list_BV.sh <config_file_for_region> <compartmentId> <AvailabilityDomain> <displayName>
export ociConfigFile=$1
export compartmentId=$2
export AvailabilityDomain=$3
export displayName=$4

oci --config-file $ociConfigFile bv volume list --compartment-id $compartmentId --availability-domain $AvailabilityDomain --lifecycle-state AVAILABLE --display-name $displayName
