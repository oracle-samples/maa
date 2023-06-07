export basedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "*********FORCE STOP OF K8S CONTROL PLANE SERVICES *********"
. $basedir/maak8s.env

if [[ $# -eq 1 ]];
then
        #LIST OF CONTROL PLANE NODES
        export MNODE_LIST=$1
else
        echo ""
        echo "ERROR: Incorrect number of parameters used: Expected 1, got $#"
        echo ""
        echo "Usage:"
        echo "    $0 [LIST OF NODES]"
        echo ""
        echo "Example:  "
        echo "    $0 'olk8-m1 olk8-m2 olk8-m3'"
        exit 1
fi

for host in ${MNODE_LIST}; do
        echo "Stopping control plane in $host..."
	ssh -i $ssh_key $user@$host sudo systemctl stop kubelet
	export proc_list=$(ssh -i $ssh_key $user@$host "ps -ef | grep 'etcd\|kube-apiserver\|kube-scheduler\|kube-controller-manager'" | grep -v grep |grep -v maak8 | awk '{print $2}')	
	ssh -i $ssh_key $user@$host sudo kill -9 $proc_list
done
echo "All K8s control plane services stopped in $MNODE_LIST"


