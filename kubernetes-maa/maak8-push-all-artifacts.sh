#!/bin/bash


## maak8-push-all-artifacts.sh script version 1.0.
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

### This script will apply all yaml artifacts/resources in a tar as created by the maak8-get-all-artifacts.sh script 
### The namespaces list is obtained from the directoy structure in the TAR
### Usage:
###
###      ./maak8-push-all-artifacts.sh [K8s TAR] [DIRECTORY]
### Where:
###	K8s TAR		
###			The tarball created with maak8-get-all-artifacts.sh that will be applied 
###     DIRECTORY:
###                  	The working directory where the backup tar will be expanded
export basedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"


if [[ $# -eq 2 ]]; 
then
	export artifacts_tar=$1
	export root_dir=$2
else
	echo ""
        echo "ERROR: Incorrect number of parameters used: Expected 2, got $#"
	echo ""
	echo "Usage:"
	echo "    $0 [TARBALL_FILE] [WORKING_DIRECTORY]"
	echo ""
	echo "Example:  "
	echo "    $0  /tmp/k8lbr.paasmaaoracle.com-6443.22-12-30-11-21-55.gz /tmp/test1/"
	exit 1
fi

echo "**** RESTORE OF K8s CLUSTER BASED ON YAML EXTRACTION AND APPLY ****"

dt=`date +%y-%m-%d-%H-%M-%S`
export root_dated_dir=${root_dir}/$dt
export working_dir=${root_dated_dir}/work
mkdir -p $working_dir
export backup_dir=${root_dated_dir}/before
mkdir -p $backup_dir
export oplog=$root_dated_dir/restore-operations.log
export images_log_name=images_reguired.log

cd $working_dir
echo "*******************STARTING RESTORE FOR $artifacts_tar *******************"
tar -xzf $artifacts_tar
echo ""
echo ""
echo "*********************************IMPORTANT********************************"
echo "The restore will create Kubernetes artifacts that will reference the "
echo "following images":
echo ""
echo ""
cat $working_dir/$images_log_name
echo ""
echo ""
echo "Make sure they are available in the target Kubernetes cluster's worker"
echo "nodes before starting this operation. Otherwise, restore will fail!!"
echo "**************************************************************************"

sleep 5
export nonnamespaces=`for i in $(ls *.yaml); do echo ${i%%/}; done`
echo "The non-namespaced artifacts are: $nonnamespaces" >> $oplog
export namespaces=`for i in $(ls -drt */); do echo ${i%%/}; done`
#export namespaces=$(echo "${namespaces//[$'\t\r\n']}")
export namespaces=$(echo "${namespaces}" | tr '\n' ' ')
echo "The namespaces that will be restored are: $namespaces"
echo "A log of restore operations can be found at $oplog"
echo "Restoring first the related non-namespaced artifacts in root..."
for artifact in ${nonnamespaces}; do
	for namespace in ${namespaces}; do
		#Only apply nonnamespace artifacts that reference the selectted namespaces
		if grep -q  "namespace: $namespace" $artifact; then
			$basedir/apply-artifacts.sh $artifact $oplog
		elif grep -q  "group: $namespace" $artifact; then
			$basedir/apply-artifacts.sh $artifact $oplog
		elif grep -q  "maak8sapply: $namespace" $artifact; then
                        $basedir/apply-artifacts.sh $artifact $oplog
		fi
	done
done
echo "Namespaces to restore are: $namespaces" >> $oplog
export pv_list=`kubectl get pv -A | grep -vw NAME | awk '{print $1}'  | awk -v RS=  '{$1=$1}1'`
for namespace in ${namespaces}; do
	echo "Restoring namespace $namespace ..."
	#May cause redundant ns creation, can be handled better
	kubectl create -f $working_dir/$namespace/$namespace.yaml  >> $oplog
	#kubectl create namespace $namespace >> $oplog
	cd $working_dir/$namespace
	#Firstly apply service accounts
	append="-I"
	serviceaccountartifacts=`grep -w "kind: ServiceAccount" * | awk -F':' '{print $1}'`
	echo "Original serviceaccountartifacts is : $serviceaccountartifacts"  >> $oplog
	serviceaccountartifacts=`echo ${serviceaccountartifacts} | tr -d '\n'`
	for serviceaccountartifact in ${serviceaccountartifacts}; do
        	$basedir/apply-artifacts.sh $serviceaccountartifact $oplog
        	contructignoresa+=" $append ${serviceaccountartifact}"
	done
	#Secondly apply services
	serviceartifacts=`grep -w "kind: Service" * | awk -F':' '{print $1}'`
	echo "Original serviceartifacts is : $serviceartifacts"  >> $oplog
	export serviceartifacts=`echo ${serviceartifacts} | tr -d '\n'`
	for serviceartifact in ${serviceartifacts}; do
        	$basedir/apply-artifacts.sh $serviceartifact $oplog
	        contructignoresvc+=" $append ${serviceartifact}"
	done
	pendingartifacts=`ls $contructignoresa $contructignoresvc -I $namespace.yaml`
	echo "The list of pending artifacts to apply is: $pendingartifacts"  >> $oplog
	for artifact in  ${pendingartifacts}; do
		#Check if this is a PVC
		artifactkind=$(cat $artifact | grep kind| awk -F'kind:' '{print $2}')
		echo "Let's go with artifact of type $artifactkind " >> $oplog
		if [[ "$artifactkind" == *"PersistentVolumeClaim"* ]]; then
			echo "Special PVC case: "  >> $oplog
			pvcinartifact=`cat $artifact | grep name| awk -F'name: ' '{print $2}' | awk -v RS=  '{$1=$1}1'`
			volume=`cat  $artifact | grep volumeName| awk -F'volumeName: ' '{print $2}' | awk -v RS=  '{$1=$1}1'`
			for pv in  ${pv_list}; do
				if [[ "$volume" == *"$pv"* ]]; then
					pvc=`kubectl get pv $pv -o yaml | grep claimRef: -A 3 | grep name | awk -F'name: ' '{print $2}'`
					if [[ "$pvc" == *"$pvcinartifact"* ]]; then
						echo "*****PVC was already there, so need to remove it first!****" >> $oplog
						#Need to improve to manage more claims than the one being added
						kubectl patch pv $pv  -p '{"spec":{"claimRef":null}}'
						
					fi
				fi
				
			done
		elif [[ "$artifactkind" == *"Secret"* ]]; then
			echo "Cleaning up token and ca for artifact $artifact ..."  >> $oplog
			sed -i '/token: /d' $artifact
			sed -i '/ca.crt: /d' $artifact
		elif [[ "$artifactkind" == *"Job"* ]]; then
			job_type=$(grep 'type:' $artifact | awk -F'type: ' '{print $2}')
			if [[ "$job_type" == *"Complete"* ]]; then
				 sed  -i 's/suspend: false/suspend: true/g' $artifact
			fi
		fi
		$basedir/apply-artifacts.sh $artifact $oplog
	done
	listofdeploy=`kubectl get deployments -n $namespace | grep -v NAME | awk '{print $1}'`
	for deploy in ${listofdeploy}; do
		kubectl rollout restart -n  $namespace  deployment/$deploy
		attempts=0
		rollout_status_command="kubectl rollout status deployment/$deploy -n $namespace"
		until $rollout_status_command || [ $attempts -eq 6 ]; do
  			$rollout_status_command
	 	 	attempts=$((attempts + 1))
  			sleep 10
		done
        done
#sleep 60
done
echo "Restore complete!"
echo "Final status of cluster is: "
kubectl get all -A | tee -a  $oplog
kubectl get pv -A  | tee -a  $oplog
kubectl get pvc -A  | tee -a  $oplog
echo "************ WARNING: PODS MAY NOT HAVE REACHED RUNNING STATE YET. PLEASE CHECK POD SATUS ************"
