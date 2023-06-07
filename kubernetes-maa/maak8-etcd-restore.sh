#!/bin/bash


## maak8-etcd-restore.sh script version 1.0.
##
## Copyright (c) 2023 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

### This script restores an etcd snapshot of a K8s control plane.
### This snapshot should be created using the maak8-etcd-backup.sh script.
### It uses variables defined in maak8s.env
### It requires installation of etcdctl https://etcd.io/
### Usage:
###
###      ./maak8-etcd-restore.sh [BACKUP_DIRECTORY] [DATE]
### Where:
###     BACKUP_DIRECTORY:
###                     This is the directory where the etcd snapshot to be restored resides.
###			this needs to be either shared storage accessible by all control plane
###			nodes or a consistent directory present in all of them with the same backups.
###     DATE:
###                     This is the date identifying the snapsot inside the backup directory.
###                     It should be provided in the format YYYY-MM-DD_HH-mm-SS (+%F_%H-%M-%S)
###			For example:  2023-06-02_10-12-30

export basedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "********* RESTORE OF K8s CLUSTERS BASED ON ETCD SNAPSHOT *********"
echo "Make sure you have provided the required information in the env file $basedir/maak8-etcd-backup.env"
. $basedir/maak8s.env


export dt=`date "+%F_%H-%M-%S"`
if [[ $# -eq 2 ]];
then
 	#ROOT DIRECTORY HOSTING EXISTING BACKUPS
	export backup_root_dir=$1
	#DATE AND TIME MARKER FOR DIRECTORY THAT WILL HOST THE BACKUPS
	export backup_date=$2
else
        echo ""
        echo "ERROR: Incorrect number of parameters used: Expected 2, got $#"
        echo ""
        echo "Usage:"
        echo "    $0 [BACKUP_DIRECTORY] [DATE]"
        echo ""
        echo "Example:  "
        echo "    $0  /backups/ 2023-06-02_10-12-39"
        exit 1
fi

# Check dependencies
if [[ ! -x "${etcdctlhome}/etcdctl" ]]; then
        echo "Error. etcdctl not found or not executable. Make sure you have installed etcdctl and provided the right path to it."
        exit 1
fi

#BACKUP LOCATION ON SHARED STORAGE ACCESSIBLE BY ALL CONTROL PLANE NODES, to be provided by the user
export backup_dir=$backup_root_dir/etcd_snapshot_$backup_date

#List of control plane and worker nodes

if [[ ! -f "${backup_dir}/mnode.log" ]]; then
        echo "Error. List of control plane nodes cannot be found in backup! Exiting."
        exit 1
else
	export MNODE_LIST=$(cat ${backup_dir}/mnode.log)
fi

if [[ ! -f "${backup_dir}/wnode.log" ]]; then
        echo "Error. List of worker nodes cannot be found in backup! Exiting."
        exit 1
else
        export WNODE_LIST=$(cat ${backup_dir}/wnode.log)
fi

if [[ ! -f "${backup_dir}/etcd_master.log" ]]; then
        echo "Error. ETCD master log cannot be found in backup! Exiting."
        exit 1
else
        export ETCDMASTERNODE=$(cat ${backup_dir}/etcd_master.log)
fi


#Contruction of etcd URLS
INIT_URL=""

for I in $MNODE_LIST;do
    buff="$I=https://$I:2380,"
    INIT_URL=${INIT_URL:+$INIT_URL}$buff
done
INIT_URL=${INIT_URL:0:-1}

ADVERTISE_URL=""

for I in $MNODE_LIST;do
    buff="$I:2379,"
    ADVERTISE_URL=${ADVERTISE_URL:+$ADVERTISE_URL}$buff
done
ADVERTISE_URL=${ADVERTISE_URL:0:-1}

export backups_exist=false;

#TIMEOUT SETTINGS FOR RETRIES ON K8 CONTROL PLANE START
export stillnotup=true
export max_trycount=5
export trycount=0
export sleeplapse=10

for host in ${MNODE_LIST}; do
	if test -f "${backup_dir}/${host}/${host}-etc-kubernetes.gz" ; then
	    backups_exist=true
	else
	    echo "${backup_dir}/${host}/${host}-etc-kubernetes.gz backup doest not exist, can't continue..."
            backups_exist=false
	fi
done

if ($backups_exist == "true" ); then
	if test -f "${backup_dir}/${ETCDMASTERNODE}/etcd-snapshot-${ETCDMASTERNODE}.db" ; then
            backups_exist=true
        else
            echo "${backup_dir}/${ETCDMASTERNODE}/etcd-snapshot-${ETCDMASTERNODE}.db etcd snapshot does not exist, can't continue..."
            backups_exist=false
        fi
fi

if ($backups_exist == "true" ); then
	echo "Found all the required artifacts in the backup. Proceeding with restore..."
	export old_manifests_dir=${backup_dir}/restore_attempted_${dt}/manifests/old_manifests
	mkdir -p $old_manifests_dir
	export new_manifests_dir=${backup_dir}/restore_attempted_${dt}/manifests/new_manifests
	mkdir -p $new_manifests_dir
	restore_log=${backup_dir}/restore_attempted_${dt}/restore.log
	echo "A log from this restore can be found at $restore_log"
	etcd_op_log=${backup_dir}/restore_attempted_${dt}/etcd_op.log
	echo "Restore operation started at $dt" > $restore_log
	for host in ${MNODE_LIST}; do
		ssh -i $ssh_key $user@$host "mkdir -p $old_manifests_dir/$host" >> $restore_log
		ssh -i $ssh_key $user@$host "mkdir -p $new_manifests_dir/$host" >> $restore_log
		ssh -i $ssh_key $user@$host "sudo cp /etc/kubernetes/manifests/*.yaml $old_manifests_dir/$host/" >> $restore_log
		ssh -i $ssh_key $user@$host "cd $new_manifests_dir/$host; sudo tar -xzf ${backup_dir}/${host}/${host}-etc-kubernetes.gz etc/kubernetes/manifests --strip-components=2" >> $restore_log
	done
	#WE will support later moving etcd from the locaiton in current cluster to a different one
	#This is scenario is unlikely to happen 
	#$basedir/maak8s-stop-cp.sh  /tmp
	$basedir/maak8s-force-stop-cp.sh "$MNODE_LIST"
	for host in ${MNODE_LIST}; do
		export etcdlocation=$(ssh -i $ssh_key $user@$host "sudo cat $old_manifests_dir/$host/etcd.yaml" | grep volumes -A20 | grep etcd-data -B3 | grep "path:"  | awk -F'path: ' '{print $2}')
		echo "Node $host is hosting etcd under $etcdlocation" >> $restore_log
		ssh -i $ssh_key $user@$host "sudo systemctl stop kubelet">> $restore_log
		ssh -i $ssh_key $user@$host "mkdir -p ${backup_dir}/restore_attempted_${dt}/$host/etcd$dt" >> $restore_log
		ssh -i $ssh_key $user@$host "sudo mv $etcdlocation ${backup_dir}/restore_attempted_${dt}/$host/etcd$dt" >> $restore_log
		ssh -i $ssh_key $user@$host "sudo mkdir -p $etcdlocation" >> $restore_log
		ssh -i $ssh_key $user@$host "sudo tar -czf  ${backup_dir}/restore_attempted_${dt}/$host/pki.gz /etc/kubernetes/pki " > /dev/null 2>&1
		ssh -i $ssh_key $user@$host "cd /; sudo tar -xzf ${backup_dir}/${host}/${host}-etc-kubernetes.gz etc/kubernetes/pki/sa.key" >> $restore_log
		ssh -i $ssh_key $user@$host "cd /; sudo tar -xzf ${backup_dir}/${host}/${host}-etc-kubernetes.gz etc/kubernetes/pki/sa.pub" >> $restore_log
		ssh -i $ssh_key $user@$host "sudo rm -rf ${backup_dir}/restore_attempted_${dt}/$host/$host.etcd">> $restore_log
		ssh -i $ssh_key $user@$host "cd ${backup_dir}/restore_attempted_${dt}/$host && $etcdctlhome/etcdctl snapshot restore ${backup_dir}/${ETCDMASTERNODE}/etcd-snapshot-${ETCDMASTERNODE}.db --name $host  --initial-cluster $INIT_URL  --initial-cluster-token etcd-cluster-1  --initial-advertise-peer-urls https://$host:$init_port --cacert /etc/kubernetes/pki/etcd/ca.crt --key /etc/kubernetes/pki/etcd/server.key --cert /etc/kubernetes/pki/etcd/server.crt" > $etcd_op_log 2>&1
	        ssh -i $ssh_key $user@$host "sudo cp -R ${backup_dir}/restore_attempted_${dt}/$host/$host.etcd/member $etcdlocation" >> $restore_log
		#Need to implement replacement of old etcd host part with new one
		ssh -i $ssh_key $user@$host "sudo cp -R /${backup_dir}/restore_attempted_${dt}/manifests/new_manifests/$host/manifests /etc/kubernetes/" >> $restore_log
		#Restore manifests to bring back kube-api, etcd and sheduler
		#ssh -i $ssh_key $user@$host "sudo cp -R ${backup_dir}/restore_attempted_${dt}/$host/manifests /etc/kubernetes/"
		#ssh -i $ssh_key $user@$host "cd /; sudo tar -xzvf ${backup_dir}/${host}/${host}-etc-kubernetes.gz etc/kubernetes/manifests"
		ssh -i $ssh_key $user@$host "sudo systemctl restart kubelet" >> $restore_log
	done
	while [ $stillnotup == "true" ];do
		result=`ssh -i $ssh_key $user@$bastion_node "kubectl get nodes| grep 'Ready' |wc -l"`
                if [ $result -le 0 ]; then
                	stillnotup="true"
	        	echo "Kube-api not ready, retrying..."
        	        ((trycount=trycount+1))
                	sleep $sleeplapse
                        if [ "$trycount" -eq "$max_trycount" ];then
                               	echo "Maximum number of retries reached! Control plane not ready"
	                               exit
        	        fi
                else
                       	stillnotup="false"
			echo "Kube-api ready!"
                        echo "Control plane restore completed. Rolling deployments and kubelet in worker nodes..."
			for host in ${WNODE_LIST}; do
                       	        echo "Restarting kubelet in $host..."
                               	ssh -i $ssh_key $user@$host "sudo systemctl restart kubelet"
	                        sleep 3
        	        done
			listofns=$(ssh -i $ssh_key $user@$bastion_node "kubectl get ns" | grep -v NAME | awk '{print $1}')
			for ns in ${listofns}; do
				listofdeploy=$(ssh -i $ssh_key $user@$bastion_node "kubectl get deployments -n $ns" | grep -v NAME | awk '{print $1}')
	        		for deploy in ${listofdeploy}; do
					echo "Restarting deployment $deploy"
			        	ssh -i $ssh_key $user@$bastion_node "kubectl rollout restart -n $ns  deployment/$deploy" >> $restore_log
        			done
			done
			for infra_pod in ${infra_pod_list}; do
        	        	podlist=`ssh -i $ssh_key $user@$bastion_node "kubectl get pods -A " | grep $infra_pod | awk '{print $2}'`
                	        echo "Restarting $infra_pod pods..."
                        	echo "$podlist">> $restore_log
                                deletecommand="kubectl delete pod $podlist -n kube-system --wait=false"
	                        ssh -i $ssh_key $user@$bastion_node $deletecommand >> $restore_log
        	                sleep 5
                	done
			#App specific restarts
			echo "App specific ops for restore..."
			#ssh -i $ssh_key $user@$bastion_node "kubectl delete serviceaccount op-sa -n opns"
			#ssh -i $ssh_key $user@$bastion_node "kubectl create serviceaccount op-sa -n opns"
			#export command="kubectl get pods -n opns --template '{{range .items}}{{.metadata.name}}{{\"\n\"}}{{end}}'"
                        #operator_pod_name=`ssh -i $ssh_key $user@$bastion_node "$command"`
                        #ssh -i $ssh_key $user@$mnode1 "kubectl delete pod $operator_pod_name -n opns"
			echo "Restore completed, check pods' status and logs"
			ssh -i $ssh_key $user@$bastion_node "kubectl get pods -A" | tee -a ${backup_dir}/restore_attempted_${dt}/restore.log
			ssh -i $ssh_key $user@$bastion_node "sudo $etcdctlhome/etcdctl -w table endpoint status --endpoints $ADVERTISE_URL --cacert /etc/kubernetes/pki/etcd/ca.crt --key /etc/kubernetes/pki/etcd/server.key --cert /etc/kubernetes/pki/etcd/server.crt" | tee -a ${backup_dir}/restore_attempted_${dt}/restore.log
			ssh -i $ssh_key $user@$bastion_node "sudo $etcdctlhome/etcdctl -w table member list --endpoints $ADVERTISE_URL --cacert /etc/kubernetes/pki/etcd/ca.crt --key /etc/kubernetes/pki/etcd/server.key --cert /etc/kubernetes/pki/etcd/server.crt" | tee -a ${backup_dir}/restore_attempted_${dt}/restore.log
               	fi
        done
fi


export enddt=`date "+%F_%H-%M-%S"`
echo "Restore completed at $enddt" | tee -a ${backup_dir}/restore_attempted_${dt}/restore.log
