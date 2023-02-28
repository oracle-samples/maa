## ExampleBVReplicaOCICli
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

#Usage
# ./attach_BV_to_compute_instance.sh <region> <compute_instance_id> <volumeId>

export ociConfigFile=$1
export instanceId=$2
export volumeId=$3

oci --config-file $ociConfigFile compute volume-attachment attach-iscsi-volume --instance-id $instanceId --volume-id $volumeId 

