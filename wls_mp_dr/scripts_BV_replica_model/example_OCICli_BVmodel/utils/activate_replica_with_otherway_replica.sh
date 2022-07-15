## ExampleBVReplicaOCICli
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

# USAge
# activate_replica_with_otherway_replica.sh <oci_config_for_region_where_replica_is> <AD_where_BV_is_created> <compartment_ocid> <source_volume_replica_id> <display_name_for_new_BV> <AD_for_replica> <display_name_for_replica>

export ociConfigFile=$1
export AvailabilityDomainForBV=$2
export compartmentID=$3
export SourceVolumeReplicaId=$4
export DisplayNameForBV=$5
export AvailabilityDomainForReplica=$6
export DisplayNameForReplica=$7

export blockVolumeReplicas='[{"displayName":"'$DisplayNameForReplica'","availabilityDomain":"'$AvailabilityDomainForReplica'"}]'


oci --config-file $ociConfigFile bv volume create --source-volume-replica-id $SourceVolumeReplicaId  --compartment-id $compartmentID --availability-domain $AvailabilityDomainForBV --display-name $DisplayNameForBV --block-volume-replicas $blockVolumeReplicas 
