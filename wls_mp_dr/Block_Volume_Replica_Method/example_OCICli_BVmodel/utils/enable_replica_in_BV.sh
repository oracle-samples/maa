## ExampleBVReplicaOCICli
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

#Usage
# enable_replica_in_BV.sh <ioci_config_file_for_region_of_the_volume> <block_volume_id_to_be_replicated> <display_name_for_the_replica> <<availability_domain_for_the_replicated_bv>

export ociConfigFile=$1
export volumeId=$2
export replicaDisplayName=$3
export availabilityDomain=$4
export blockVolumeReplicas='[{"displayName":"'$replicaDisplayName'","availabilityDomain":"'$availabilityDomain'"}]'

oci --config-file $ociConfigFile bv volume update --volume-id $volumeId --block-volume-replicas $blockVolumeReplicas --force
