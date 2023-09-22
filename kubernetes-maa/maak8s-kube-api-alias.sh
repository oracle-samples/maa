#!/bin/bash


## maak8s-kube-api-alias.sh script version 1.0.
##
## Copyright (c) 2023 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

### This script adds an additional hostname alias to the control plane KUBE-API
### It updates certificvates in all control plane nodes, the kubeadm config map and also the kubeconfig file in the
### current node

### Usage:
###
###      ./maak8s-kube-api-alias.sh [HOSTANAME_ALIAS] [KUBECONFIG]
### Where:
###	HOSTANAME_ALIAS:
###			This is the new hostname to be added to the control plane "resolvable" addresses. 
###			This alias needs to be a valid DNS name or solved locally with /etc/hosts.
###	KUBECONFIG:
###			This is the complete path to the kubeconfig file used to execute kubectl commands
if [[ $# -eq 2 ]]; 
then
	export hnalias=$1
	export kcfg=$2
else
	echo ""
        echo "ERROR: Incorrect number of parameters used: Expected 3, got $#"
	echo ""
	echo "Usage:"
	echo "    $0 [HOSTANAME_ALIAS] [KUBECONFIG]"
	echo ""
	echo "Example:  "
	echo "    $0   \"newk8slbr.mycompany.com \" /home/opc/.kube/config "
	exit 1
fi
#DATE AND TIME MARKER FOR BACKUPS
export dt=`date "+%F_%H-%M-%S"`
export basedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "********* ADDITION OF A NEW HOSTNAME ALIAS TO KUBE-API FRONTEND *********"
echo "Make sure you have provided the required information in the env file $basedir/maak8s.env"
echo ""
. $basedir/maak8s.env

export MNODE_LIST=$(kubectl --kubeconfig=$kcfg get nodes | grep 'master\|control' | grep -v NAME | awk '{print $1}')
export first_node=$(echo $MNODE_LIST  | awk '{print $1;}')

export kubeadmyaml=/tmp/kubeadm-$dt.yaml
export noderegyaml=$kubeadmyaml.nodereg.yaml
#export kubeadmyaml=/scratch/docker/kubeadm.yaml.test
kubectl --kubeconfig=$kcfg -n kube-system get configmap kubeadm-config -o jsonpath='{.data.ClusterConfiguration}' > $kubeadmyaml

if grep -q certSANs "$kubeadmyaml"; then
	echo "Some previous alias existed, adding the new one..."
	sed -i "s/  certSANs:/  certSANs:\n  - \"$hnalias\"/g" $kubeadmyaml
else 
	echo "No previous alias found, adding certSANS section..."
	sed -i "s/  extraArgs:/  certSANs:\n  - \"$hnalias\"\n  extraArgs:/g" $kubeadmyaml
fi

#Workaround for cert modificatoin detecting endpoints
export endpoint=$(tr \\0 ' ' < /proc/"$(pgrep kubelet)"/cmdline | awk -F'--container-runtime-endpoint=' '{print $2}' |awk '{print $1}')
export apiver=$(grep apiVersion $kubeadmyaml)
sed "s|apiServer:|kind: InitConfiguration\n$apiver\nnodeRegistration:\n  criSocket: \"$endpoint\"\n---\napiServer:|g" $kubeadmyaml > $noderegyaml

for host in ${MNODE_LIST}; do
	ssh -i $ssh_key $user@$host "sudo mv /etc/kubernetes/pki/apiserver.crt /etc/kubernetes/pki/apiserver-$dt.crt && sudo mv /etc/kubernetes/pki/apiserver.key /etc/kubernetes/pki/apiserver-$dt.key" 
	scp -q -i  $ssh_key $kubeadmyaml $user@$host:$kubeadmyaml
	scp -q -i  $ssh_key $noderegyaml $user@$host:$noderegyaml
	ssh -i $ssh_key $user@$host "sudo kubeadm init phase certs apiserver --config $noderegyaml"
done

ssh -i $ssh_key $user@$host "sudo kubeadm init phase certs apiserver --config $noderegyaml"
echo "Restarting control plane..."
$basedir/maak8s-force-stop-cp.sh "$MNODE_LIST"
sleep 5
for host in ${MNODE_LIST}; do
	echo "Restarting kubelet in $host"
	ssh -i $ssh_key $user@$host "sudo systemctl restart kubelet"
	sleep 5
done

echo "Refreshing information in kubeadm config map form first node..."
ssh -i $ssh_key $user@$first_node "sudo kubeadm init phase upload-config kubeadm --config $noderegyaml"

echo "Done!"
echo "To verify the corect behavior with the new alias, you can replace the server entry in your kubeconfig"
export current_server=`grep server $kcfg |awk -F'//' '{print $2}' |awk -F':' '{print $1}'`
echo "Your current API front end is: $current_server" 
echo "You can replace it executing sed -i 's/$current_server/$hnalias/g' $kcfg"

