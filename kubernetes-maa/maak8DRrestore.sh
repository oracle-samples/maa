#!/bin/bash
#SCRIPT TO RESTORE A BACKUP OF THE CONTROL PLANE 

export dt=`date "+%F_%H-%M-%S"`
basedir=$(dirname "$0")

#ROOT DIRECTORY HOSTING EXISTING BACKUPS
export backup_root_dir=/scratch/docker/backups
#DATE AND TIME MARKER FOR DIRECTORY THAT WILL HOST THE BACKUPS
export backup_date=$1
#BACKUP LOCATION ON SHARED STORAGE ACCESSIBLE BY ALL CONTROL PLANE NODES, to be provided by the user
export backup_dir=$backup_root_dir/controlplane_$backup_date
#sudo ready user, to be provided by the user
export user=opc
#ssh key, to be provided by the user
export ssh_key=/home/opc/KeyWithoutPassPhraseSOAMAA.ppk
#etcdctl executable home, to be provided by the user
export etcdctlhome=/scratch/docker/etcdctl/
#List of control plane nodes, to be provided by user, TBA get it from control plane
export mnode1=olk8-m1
export mnode2=olk8-m2
export mnode3=olk8-m3
#List of worker nodes, to be provided by user, TBA get it from control plane
export wnode1=olk8-w1
export wnode2=olk8-w2
export wnode3=olk8-w3

#Variables contruscted by the script
export mastenode=$mnode1
export NODE_LIST="$mnode1 $mnode2 $mnode3"
export WNODE_LIST="$wnode1 $wnode2 $wnode3"
export NOTMASTER_LIST="$mnode2 $mnode3"
export ADVERTISE_URL="$mnode1:2379,$mnode2:2379,$mnode3:2379"
export backups_exist=false;
#export initial-cluster_etcd="$mnode1=https://$mnode1:2380,$mnode2=https://$mnode2:2380,$mnode3=https://$mnode3:2380'"
export initialclusteretcd="'${mnode1}=https://${mnode1}:2380,${mnode2}=https://${mnode2}:2380,$mnode3=https://$mnode3:2380'"

#TIMEOUT SETTINGS FOR RETRIES ON K8 CONTROL PLANE START
export stillnotup=true
export max_trycount=15
export trycount=0
export sleeplapse=20


for host in ${NODE_LIST}; do
	if test -f "${backup_dir}/${host}/${host}-etc-kubernetes.gz" ; then
	    echo "${backup_dir}/${host}/${host}-etc-kubernetes.gz backup exists. Continuing..."
	    backups_exist=true
	else
	    echo "${backup_dir}/${host}/${host}-etc-kubernetes.gz backup doest not exist, can't continue..."
	    echo "Make sure you provide the date of the backup as argument to script in the YYYY-MM-DD_HH-MM-SS format. For example: 2021-02-02_12-16-42"
            backups_exist=false
	fi
done

if ($backups_exist == "true" ); then
	if test -f "${backup_dir}/${mnode1}/etcd-snapshot-${mnode1}.db" ; then
            echo "${backup_dir}/${mnode1}/etcd-snapshot-${mnode1}.db etcd snapshot exists. Continuing..."
            backups_exist=true
        else
            echo "${backup_dir}/${mnode1}/etcd-snapshot-${mnode1}.db etcd snapshot does not exist, can't continue..."
            backups_exist=false
        fi
fi

mkdir ${backup_dir}/restore_attempted_${dt}
echo "Restore operation started at $dt" > ${backup_dir}/restore_attempted_${dt}/restore.log
if ($backups_exist == "true" ); then
	echo "Restoring..."
	#Move manifest to stop etcd, kube-api, etcd and sheduler
	for host in ${NODE_LIST}; do
		mkdir ${backup_dir}/restore_attempted_${dt}/$host
		echo "Stopping control plane at $host..."
		ssh -i $ssh_key $user@$host "sudo mv /etc/kubernetes/manifests ${backup_dir}/restore_attempted_${dt}/$host"
        done
	#We need to give time for control plane pods to be shut down. TBA check for stop
	echo "Sleeping for etcd shutdown..."
	sleep 60
	for host in ${NODE_LIST}; do
		ssh -i $ssh_key $user@$host "sudo systemctl stop kubelet"
		ssh -i $ssh_key $user@$host "sudo mv /var/lib/etcd  /var/lib/etcd$dt"
		ssh -i $ssh_key $user@$host "sudo mkdir /var/lib/etcd"
 		ssh -i $ssh_key $user@$host "sudo tar -czvf ${backup_dir}/restore_attempted_${dt}/$host/pki.gz /etc/kubernetes/pki/ "
		ssh -i $ssh_key $user@$host "cd /; sudo tar -xzvf ${backup_dir}/${host}/${host}-etc-kubernetes.gz etc/kubernetes/pki/sa.key"
		ssh -i $ssh_key $user@$host "cd /; sudo tar -xzvf ${backup_dir}/${host}/${host}-etc-kubernetes.gz etc/kubernetes/pki/sa.pub"
		#ssh -i $ssh_key $user@$host "cd /; sudo tar -xzvf ${backup_dir}/${host}/${host}-etc-kubernetes.gz etc/kubernetes/pki --overwrite"
		#ssh -i $ssh_key $user@$host "cd /; sudo tar -xzvf ${backup_dir}/${host}/${host}-etc-kubernetes.gz etc/kubernetes/admin.conf --overwrite"
		#ssh -i $ssh_key $user@$host "cd /; sudo tar -xzvf ${backup_dir}/${host}/${host}-etc-kubernetes.gz etc/kubernetes/scheduler.conf --overwrite"
		#ssh -i $ssh_key $user@$host "cd /; sudo tar -xzvf ${backup_dir}/${host}/${host}-etc-kubernetes.gz etc/kubernetes/controller-manager.conf --overwrite"
		#ssh -i $ssh_key $user@$host "cd /; sudo tar -xzvf ${backup_dir}/${host}/${host}-etc-kubernetes.gz etc/kubernetes/kubelet.conf --overwrite"
  	 done
	 
	 for host in ${NODE_LIST}; do
		ssh -i $ssh_key $user@$host "sudo rm -rf ${backup_dir}/restore_attempted_${dt}/$host/$host.etcd"
	        #ssh -i $ssh_key $user@$host "cd /tmp && sudo $etcdctlhome/etcdctl snapshot restore --endpoints $ADVERTISE_URL --cacert /etc/kubernetes/pki/etcd/ca.crt --key /etc/kubernetes/pki/etcd/server.key --cert /etc/kubernetes/pki/etcd/server.crt ${backup_dir}/${host}/etcd-snapshot-${host}.db"
        	#ssh -i $ssh_key $user@$mnode1 "cd ${backup_dir}/restore_attempted_${dt}/$host && $etcdctlhome/etcdctl snapshot restore ${backup_dir}/${mnode1}/etcd-snapshot-${mnode1}.db --name $mnode1  --initial-cluster $mnode1=https://$mnode1:2380,$mnode2=https://$mnode2:2380,$mnode3=https://$mnode3:2380   --initial-cluster-token etcd-cluster-1  --initial-advertise-peer-urls https://$host:2380 --cacert /etc/kubernetes/pki/etcd/ca.crt --key /etc/kubernetes/pki/etcd/server.key --cert /etc/kubernetes/pki/etcd/server.crt"
		 ssh -i $ssh_key $user@$host "cd ${backup_dir}/restore_attempted_${dt}/$host && $etcdctlhome/etcdctl snapshot restore ${backup_dir}/${mnode1}/etcd-snapshot-${mnode1}.db --name $host  --initial-cluster $initialclusteretcd  --initial-cluster-token etcd-cluster-1  --initial-advertise-peer-urls https://$host:2380 --cacert /etc/kubernetes/pki/etcd/ca.crt --key /etc/kubernetes/pki/etcd/server.key --cert /etc/kubernetes/pki/etcd/server.crt" | tee -a ${backup_dir}/restore_attempted_${dt}/restore.log
	        ssh -i $ssh_key $user@$host "sudo cp -R ${backup_dir}/restore_attempted_${dt}/$host/$host.etcd/member /var/lib/etcd"
	done

	#Restore manifest etc to bring back kube-api, etcd and sheduler
        for host in ${NODE_LIST}; do
                #ssh -i $ssh_key $user@$host "cd /; sudo tar -xzvf ${backup_dir}/${host}/${host}-etc-kubernetes.gz etc/kubernetes/manifests --overwrite"
		ssh -i $ssh_key $user@$host "sudo cp -R ${backup_dir}/restore_attempted_${dt}/$host/manifests /etc/kubernetes/"
		ssh -i $ssh_key $user@$host "sudo systemctl restart kubelet"
        done
	
	while [ $stillnotup == "true" ]
        do
		result=`ssh -i $ssh_key $user@$mnode1 "kubectl get nodes| grep 'Ready' |wc -l"`
                if [ $result -le 0 ]; then
                        stillnotup="true"
                        echo "Kube-api not ready, retrying..."
                        ((trycount=trycount+1))
                        sleep $sleeplapse
                        if [ "$trycount" -eq "$max_trycount" ];then
                                echo "Maximum number of retries reached! Master node not ready"
                                exit
                        fi
                else
                        stillnotup="false"
			echo "Kube-api ready!"
			controllerpods=`ssh -i $ssh_key $user@$mnode1 "kubectl get pods -A " | grep controller | awk '{print $2}'`
                        echo "Removing Controller pods:"
                        echo "$controllerpods"
			controllercommand="kubectl delete pod $controllerpods -n kube-system --wait=false"
			ssh -i $ssh_key $user@$mnode1 $controllercommand
			sleep 5
			schedulerpods=`ssh -i $ssh_key $user@$mnode1 "kubectl get pods -A " | grep scheduler | awk '{print $2}'`
			echo "Removing Scheduler pods:"
                        echo "$schedulerpods"
                        schedulercommand="kubectl delete pod $schedulerpods -n kube-system --wait=false"
			ssh -i $ssh_key $user@$mnode1 $schedulercommand
                        sleep 5
			proxypods=`ssh -i $ssh_key $user@$mnode1 "kubectl get pods -A " | grep proxy | awk '{print $2}'`
                        echo "Proxy pods:"
                        echo "$proxypods"
                        proxypodcommand="kubectl delete pod ${proxypods} -n kube-system --wait=false"
			ssh -i $ssh_key $user@$mnode1 $proxypodcommand
                        sleep 5
                        echo "Control plane restore completed. Rolling flannel, coredns, kubelet in worker nodes..."
			ssh -i $ssh_key $user@$mnode1 "kubectl delete -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml"
			ssh -i $ssh_key $user@$mnode1 "kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml"
			echo "Waiting for flannel and coredns update to be rolled out..."
			sleep 5
			#ssh -i $ssh_key $user@$mnode1 "kubectl delete serviceaccounts coredns -n kube-system"
			#ssh -i $ssh_key $user@$mnode1 "kubectl apply -f $basedir/coredns-sa.yaml"
			#sleep 60
			#ssh -i $ssh_key $user@$mnode1 "kubectl delete  serviceaccount kube-proxy -n kube-system"
 			#ssh -i $ssh_key $user@$mnode1 "kubectl create  serviceaccount kube-proxy -n kube-system"
			#sleep 60
			ssh -i $ssh_key $user@$mnode1 "kubectl rollout restart -n kube-system deployment/coredns"
			sleep 5
			for host in ${WNODE_LIST}; do
				echo "Restarting kuebelet in $host..."
		                ssh -i $ssh_key $user@$host "sudo systemctl restart kubelet"
				sleep 5
        		done
			echo "Recreating operator pod..."
			ssh -i $ssh_key $user@$mnode1 "kubectl delete serviceaccount op-sa -n opns"
			ssh -i $ssh_key $user@$mnode1 "kubectl create serviceaccount op-sa -n opns"
			export command="kubectl get pods -n opns --template '{{range .items}}{{.metadata.name}}{{\"\n\"}}{{end}}'"
                        operator_pod_name=`ssh -i $ssh_key $user@$mnode1 "$command"`
                        ssh -i $ssh_key $user@$mnode1 "kubectl delete pod $operator_pod_name -n opns"
			echo "Restore completed, check pods' status and logs"
			ssh -i $ssh_key $user@$mnode1 "kubectl get pods -A" | tee -a ${backup_dir}/restore_attempted_${dt}/restore.log
			ssh -i $ssh_key $user@$mnode1 "sudo $etcdctlhome/etcdctl -w table endpoint status --endpoints $ADVERTISE_URL --cacert /etc/kubernetes/pki/etcd/ca.crt --key /etc/kubernetes/pki/etcd/server.key --cert /etc/kubernetes/pki/etcd/server.crt" | tee -a ${backup_dir}/restore_attempted_${dt}/restore.log
			 ssh -i $ssh_key $user@$mnode1 "sudo $etcdctlhome/etcdctl -w table member list --endpoints $ADVERTISE_URL --cacert /etc/kubernetes/pki/etcd/ca.crt --key /etc/kubernetes/pki/etcd/server.key --cert /etc/kubernetes/pki/etcd/server.crt" | tee -a ${backup_dir}/restore_attempted_${dt}/restore.log
                fi
        done
fi

export enddt=`date "+%F_%H-%M-%S"`
echo "Restore completed at $enddt" | tee -a ${backup_dir}/restore_attempted_${dt}/restore.log


