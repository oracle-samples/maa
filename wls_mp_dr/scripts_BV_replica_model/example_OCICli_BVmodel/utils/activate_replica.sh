## ExampleBVReplicaOCICli
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

# USAge
# activate_replica.sh <region_where_replica_is> <AD_where_BV_is_created> <compartment_ocid> <source_volume_replica_id> <display_name_for_new_BV>
#Sample
#activate_replica.sh /home/opc/oci-profiles/config_us-phoenix-1_iratxe "efXT:PHX-AD-1" ocid1.compartment.oc1..aaaaaaaabqxjyjhl6cx7q3cugmqxrrd2r3yw6bogy62733bchwodbil7guvq ocid1.blockvolumereplica.oc1.phx.abyhqljt3ydr5ultopegij77mquqmx3xlfg3qxy2iznxqjo5xmqlloytrtua soampdr16-block-0_replicated

export ociConfigFile=$1
export AvailabilityDomain=$2
export compartmentID=$3
export volumeReplicaId=$4
export DisplayName=$5

#Sample values

oci --config-file $ociConfigFile bv volume create --source-volume-replica-id $volumeReplicaId  --compartment-id $compartmentID --availability-domain $AvailabilityDomain --display-name $DisplayName

