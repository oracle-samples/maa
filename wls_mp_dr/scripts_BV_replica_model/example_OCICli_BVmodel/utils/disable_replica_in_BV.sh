## ExampleBVReplicaOCICli
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

# disable_replica_in_BV.sh <region> <volumeId>
export ociConfigFile=$1
export volumeId=$2

oci --config-file $ociConfigFile bv volume update --volume-id $volumeId --block-volume-replicas '[]' --force 
