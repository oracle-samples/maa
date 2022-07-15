## ExampleBVReplicaOCICli
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

# SCRIPT TO SWITCHOVER from SITE1 to SITE2
# It performs the following actions:
# - It activates the BV replicas in SITE2, so cloned BV are created
# - It attaches the cloned BV to the midtier compute instances in SITE2

if [[ $# -ne 2 ]]; then
	echo ""
	echo "ERROR: Incorrect number of parameters passed. Expected 2, got $#"
	echo "Usage:" 
	echo "      $0  <region_from> <region_to> "
	echo "Example: "
	echo "      $0 "us-ashburn-1" "us-phoenix-1" "
	echo ""
	exit 1
fi

export SITE1=$1
export SITE2=$2
export UTILS_DIR="utils"

# Load DR env properties
. DRenv.properties

echo "#####################################################"
echo "### Switchover from $SITE1 to $SITE2 ###"
echo "#####################################################"

# Assign the values from DRenv.properties to SITE1 and SITE2 accordingly
# SITE1 is the primary before the switchover
# SITE2 will be primary after switchover
declare -a SITE1_compute_instance_ocid
declare -a SITE1_compute_instance_AD
declare -a SITE1_compute_instance_ssh_IP
declare -a SITE2_compute_instance_ocid
declare -a SITE2_compute_instance_AD
declare -a SITE2_compute_instance_ssh_IP
declare -i i=0

if  [[ ${SITE1} = ${regionA} ]]; then
	# In this case SITE1 is regionA and SITE2 is regionB
	export SITE1_oci_config_file=${regionA_oci_config_file}
        export SITE2_oci_config_file=${regionB_oci_config_file}
	i=0
	while (($i < $num_nodes)); do
		SITE1_compute_instance_ocid[$i]=${regionA_compute_instance_ocid[$i]}
		SITE1_compute_instance_AD[$i]=${regionA_compute_instance_AD[$i]}
		SITE1_compute_instance_ssh_IP[$i]=${regionA_compute_instance_ssh_IP[$i]}
		
		SITE2_compute_instance_ocid[$i]=${regionB_compute_instance_ocid[$i]}
                SITE2_compute_instance_AD[$i]=${regionB_compute_instance_AD[$i]}
                SITE2_compute_instance_ssh_IP[$i]=${regionB_compute_instance_ssh_IP[$i]}
		i+=1
	done

elif  [[ ${SITE1} = ${regionB} ]]; then
	# In this case SITE1 is regionB and SITE2 is regionA
        export SITE1_oci_config_file=${regionB_oci_config_file}
        export SITE2_oci_config_file=${regionA_oci_config_file}
        i=0
        while (($i < $num_nodes)); do
                SITE1_compute_instance_ocid[$i]=${regionB_compute_instance_ocid[$i]}
                SITE1_compute_instance_AD[$i]=${regionB_compute_instance_AD[$i]}
                SITE1_compute_instance_ssh_IP[$i]=${regionB_compute_instance_ssh_IP[$i]}

                SITE2_compute_instance_ocid[$i]=${regionA_compute_instance_ocid[$i]}
                SITE2_compute_instance_AD[$i]=${regionA_compute_instance_AD[$i]}
                SITE2_compute_instance_ssh_IP[$i]=${regionA_compute_instance_ssh_IP[$i]}
                i+=1
        done
else
	echo "Error: unexpected value for region"
	exit 1
fi

###################################################
# EXTERNAL STEPS TO BE PERFORMED MANNUALLY
###################################################
echo "Perform the following steps before running this script:"
echo "1) Stop WLS processes in $SITE1"
echo "   Are the WLS and NM processes stopped in $SITE1? (y/n) "
read -s SITE1_STOPPED
if  [[ ${SITE1_STOPPED} = "n" ]]; then
	echo "Stop wls and NM processes in $SITE1 and rerun this script"
	exit 0
elif [[ ${SITE1_STOPPED} = "y" ]]; then
	echo "Continuing with the switchover..."
else
	exit 1
fi

###################################################
# AUTOMATED STEPS IN THIS SCRIPT
###################################################

####################################################################################
echo "2) Activating BV replicas in $SITE2"
####################################################################################
# Get the BV cid from the SITE2 Volume Replicas dynamically 
# this value is different in each switchover and must be provided to the oci command that activates the replica
# We maintain the same "displayName" to be able to gather the ocid
# list_BV_replicas.sh <oci_config_file_for_region> <compartmentId> <AvailabilityDomain> <replicadisplayName>
date
i=0
while (($i < $num_nodes)); do
	AD=${SITE2_compute_instance_AD[$i]}
        replica_displayname=${BV_replica_displayname[$i]}
	result=$(${UTILS_DIR}/list_BV_replicas.sh ${SITE2_oci_config_file} ${compartment_cid} ${AD} ${replica_displayname} | grep "ocid1.blockvolumereplica")
	SITE2_BVReplica_cid[$i]=$(echo $result | awk -F ': ' '{print $2}' | awk -F '"' '{print $2}')
	if [[ $mw_blocks_replicated = "yes" ]];then
	  replica_mw_displayname=${BV_mw_replica_displayname[$i]}
	  result_mw=$(${UTILS_DIR}/list_BV_replicas.sh ${SITE2_oci_config_file} ${compartment_cid} ${AD} ${replica_mw_displayname} | grep "ocid1.blockvolumereplica")
	  SITE2_MW_BVReplica_cid[$i]=$(echo ${result_mw} | awk -F ': ' '{print $2}' | awk -F '"' '{print $2}')
	fi
	i+=1
done

# Using the obtained replicas cids, activate them in SITE2 
# activate_replica.sh <oci_config_for_region_where_replica_is> <AD_where_replica_is_created> <compartment_ocid> <source_volume_replica_id> <display_name_for_new_volume>
i=0
while (($i < $num_nodes)); do
	AD=${SITE2_compute_instance_AD[$i]}
	displayname=${BV_displayname[$i]}
	replica_cid=${SITE2_BVReplica_cid[$i]}
	result=$(${UTILS_DIR}/activate_replica.sh ${SITE2_oci_config_file} ${AD} ${compartment_cid} ${replica_cid} ${displayname} | grep "ocid1.volume")
	SITE2_BV_cid[$i]=$(echo $result | awk -F ': ' '{print $2}' | awk -F '"' '{print $2}')
	echo "Activated the replica ${BV_replica_displayname[$i]}: created a cloned BV ${displayname}"
	echo " cid of the created Block Volume:" ${SITE2_BV_cid[$i]} 
	echo " cid of the from replica: ${replica_cid}"

	echo ""
	if [[ $mw_blocks_replicated = "yes" ]];then
		mw_displayname=${BV_mw_displayname[$i]}
		mw_replica_cid=${SITE2_MW_BVReplica_cid[$i]}
    		result_mw=$(${UTILS_DIR}/activate_replica.sh ${SITE2_oci_config_file} ${AD} ${compartment_cid} ${mw_replica_cid} ${mw_displayname} | grep "ocid1.volume")
		SITE2_MW_BV_cid[$i]=$(echo $result_mw | awk -F ': ' '{print $2}' | awk -F '"' '{print $2}')
		echo "Activated the replica ${BV_mw_replica_displayname[$i]}: created a cloned BV ${mw_displayname}"
		echo " cid of the created Block Volume:" ${SITE2_MW_BV_cid[$i]} 
		echo " cid of the replica:" ${mw_replica_cid}
		echo ""
	fi
	i+=1
done

echo ""
echo "Waiting 3 minutes to let the activation to finish...."
sleep 180
echo ""


####################################################################################
echo "3.1) Attaching the activated BV replicas to $SITE2 mid-tier hosts"
####################################################################################
date
i=0
while (($i < $num_nodes)); do
	# ./attach_BV_to_compute_instance.sh <oci_config_file_for_region> <compute_instance_id> <volumeId>
	${UTILS_DIR}/attach_BV_to_compute_instance.sh ${SITE2_oci_config_file} ${SITE2_compute_instance_ocid[$i]} ${SITE2_BV_cid[$i]}
	echo "Attached the BV ${BV_displayname[$i]} with cid ${SITE2_BV_cid[$i]}"
	echo "to compute instance ${SITE2_compute_instance_ocid[$i]}"

	if [[ $mw_blocks_replicated = "yes" ]];then
		${UTILS_DIR}/attach_BV_to_compute_instance.sh ${SITE2_oci_config_file} ${SITE2_compute_instance_ocid[$i]} ${SITE2_MW_BV_cid[$i]}
		echo "Attached the BV ${BV_mw_displayname[$i]} with cid ${SITE2_MW_BV_cid[$i]}"
		echo "to compute instance ${SITE2_compute_instance_ocid[$i]}"
	fi
	i+=1
done



####################################################################################
# EXTERNAL STEPS THAT NEED TO BE PERFORMED AT THIS POINT TO COMPLETE THE SWITCHOVER
####################################################################################
echo "Please complete the Switchover by performing these steps:"
echo " 3.2) Run icsi commands and mount the attached BV in the $SITE2 hosts" # This cannot be automatized: iscsci commands are provided in the OCI Consol
echo " 4) Run the db url replacement script in $SITE2 mid-tier hosts"
echo " 5) Switchover the DATABASE from $SITE1 to $SITE2"
echo " 6) Switchover frontend name IP in DNS from $SITE1 LBR IP to $SITE LBR IP "
echo " 7) Start the NM and WLS processes in $SITE2"
echo " 8) Run the post-switchover actions"

