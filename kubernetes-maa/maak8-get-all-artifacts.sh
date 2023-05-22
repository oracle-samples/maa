#!/bin/bash


## maak8-get-all-artifacts.sh script version 1.0.
##
## Copyright (c) 2023 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

### This script creates a yaml copy of all the artifacts in precise namespaces.It stores all of them in 
### separate folders per namespace in the provided directory. It creates also a tar that can be used in a secondary
### or test K8s cluster with the equivalent  ./maak8-push-all-artifacts.sh script.
### If executed with a single argument assumes that argument to be the backup directory and will backup ALL namespaces
### If executed with 2 arguments, it assuments the first one to be the backup directory and the following list the 
### precise namespaces to be backed up
### Usage:
###
###      ./maak8-get-all-artifacts.sh [DIRECTORY] [NAMESPACE LIST (optional)]
### Where:
###	DIRECTORY:
###			This is the directory where all the yamls and tar snapshot will be stored.
###     NAMESPACE LIST
###                     Is an optional parameter that allows specifying a list of namespaces to be replicated
### 			If no list is provided, the script will replicate all namespaces except the infrastructure
###			ones listed in the exclude_list provided in the maak8DR-apply.env file

export basedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [[ $# -eq 1 ]]; then
	export root_dir=$1
	export namespace_list="-A"
	echo "Creating yaml back up of all namespaces except $exclude_list ..."
elif [[ $# -eq 2 ]]; then
	export root_dir=$1
	if [ -z "$2" ] ; then
                export namespace_list="-A"
		echo "Creating yaml back up of all namespaces except $exclude_list ..."
        else
                export namespace_list=$2
		echo "Creating yaml back up of $namespace_list namespaces ..."

        fi
else
	echo ""
        echo "ERROR: Incorrect number of parameters used: Expected 1 or 2 got $#"
	echo ""
	echo "Usage:"
	echo "    $0 [DIRECTORY]"
	echo ""
	echo "Example:  "
	echo "    $0  /u01/backups/backup1"
	echo "Backups all namespaces and non-namespaced artifacts in k8s cluster except $exclude_list"
	echo "Example:  "
        echo "    $0  /u01/backups/backup1 'ns1 ns2 ns3'"
        echo "Backups namespaces ns1, ns2, ns3 and non-namespaced artifacts $nons_artifacts_types"
	exit 1
fi

echo "**** BACKUP OF K8s CLUSTER BASED ON YAML EXTRACTION AND APPLY ****"
echo "Make sure you have provided the required information in the env file $basedir/maak8DR-apply.env"
. $basedir/maak8DR-apply.env

#The list of all artifact types to be backed up explicit or obtained form the cluster as api-resources
#export ns_artifacts_types="cm cronjob crd daemonset deployment ingress job pod pvc replicaset replicationcontroller role rolebinding secret service sa statefulset"
export ns_artifacts_types=`kubectl api-resources | grep true | grep -v events | awk '{print $1}' | awk -v RS=  '{$1=$1}1'`
export dt=`date +%y-%m-%d-%H-%M-%S`
export results_dir=$root_dir/$dt
mkdir -p $results_dir
export oplog=$results_dir/backup-operations.log
echo "Log of backup operations can be found at $oplog"

if [[ "$namespace_list" == "-A" ]]; then
	append="-e"
	for exclude_namespace in ${exclude_list}; do
        	exclude_string+=" $append ${exclude_namespace}"
	done
	namespace_list=$(kubectl get ns |awk '{print $1}' | grep -v $exclude_string | grep -v NAME)
fi

for namespace_selected in $namespace_list;do
	echo "***************STARTING BACKUP FOR NAMESPACE $namespace_selected***************"
	mkdir -p $results_dir/${namespace_selected}
	kubectl get ns $namespace_selected -o yaml > $results_dir/$namespace_selected/$namespace_selected.yaml
	for artifacts_type in  ${ns_artifacts_types}; do
		echo "Gathering artifacts of type $artifacts_type in namespace $namespace_selected..."
		export all_artifacts_list=$results_dir/artifacts_list.${artifacts_type}.${namespace_selected}.${dt}.log
		kubectl get ${artifacts_type} -n $namespace_selected 2>/dev/null | grep -wv 'NAMESPACE\|NAME' | grep -v  "^[[:blank:]]*$" | awk -v buf="$namespace_selected" '{print buf,$1}'> $all_artifacts_list
		declare -A matrix
		echo "Gathering initial K8 cluster information for artifact of type ${artifacts_type} in namespace $namespace_selected ..." >>$oplog
		export num_artifacts=`cat $all_artifacts_list | wc -l`
		for ((j=1;j<=num_artifacts;j++)) do
        		matrix[$j,1]=`cat $all_artifacts_list | awk '{print $1}' | sed ''"$j"'!d'`
        		matrix[$j,2]=`cat $all_artifacts_list | awk '{print $2}' | sed ''"$j"'!d'`
			echo "Namespace: ${matrix[$j,1]}" >>$oplog
			echo "Artifact: ${matrix[$j,2]}"  >>$oplog
			echo "Type of artifact: $artifacts_type"  >>$oplog
			kubectl get $artifacts_type ${matrix[$j,2]} -n ${matrix[$j,1]} -o yaml > $results_dir/${matrix[$j,1]}/${matrix[$j,2]}.$artifacts_type.yaml
		done
	done
done

echo "***************STARTING BACKUP FOR NON-NAMESPACED ARTIFACTS OF TYPE: $nons_artifacts_types *************** "
for artifacts_type in  ${nons_artifacts_types}; do
        export all_nonns_artifacts_list=$results_dir/artifacts_list.${artifacts_type}.${dt}.log
        declare -A matrix
        echo "Gathering initial K8 cluster information for non-namespaced artifact of type ${artifacts_type}..."
        kubectl get ${artifacts_type} -A 2>/dev/null | awk {'print $1'} |grep -wv kube-system | grep -wv 'NAME' | grep -v  "^[[:blank:]]*$" > $all_nonns_artifacts_list
        export num_nonns_artifacts=`cat $all_nonns_artifacts_list | wc -l`
        for ((j=1;j<=num_nonns_artifacts;j++)) do
                matrix[$j,1]="none"
                matrix[$j,2]=`cat $all_nonns_artifacts_list | awk '{print $1}' | sed ''"$j"'!d'`
                echo "Namespace: ${matrix[$j,1]}">>$oplog
                echo "Artifact: ${matrix[$j,2]}">>$oplog
                echo "Type of artifact: $artifacts_type">>$oplog
                kubectl get $artifacts_type ${matrix[$j,2]} -o yaml > $results_dir/${matrix[$j,2]}.$artifacts_type.yaml
        done
done
export cluster_name=`kubectl cluster-info  | awk -F"//" '{print $2;exit}' | tr -d '[:cntrl:]'  | awk -F '[' '{print $1}'`
export clean_cluster_name=${cluster_name/:/-}
export tar_file="/tmp/${dt}.gz"
echo "All artifacts gathered for ${clean_cluster_name}. Creating tar at $tar_file ." >>$oplog
cd $results_dir
find . -name '*.yaml' | xargs grep ' image: ' -sl | xargs cat | grep ' image: ' | awk -F 'image: ' '{print $2}' | sort -u > $results_dir/images_reguired.log
echo "***************LIST OF IMAGES USED BY THE BACKUP:***************"
cat  $results_dir/images_reguired.log 
echo "****************************************************************"
tar -czf  $tar_file .
mv $tar_file $results_dir/${clean_cluster_name}.${dt}.gz
echo "Backup complete!"
echo "Cluster $clean_cluster_name packaged at $results_dir/${clean_cluster_name}.${dt}.gz"
