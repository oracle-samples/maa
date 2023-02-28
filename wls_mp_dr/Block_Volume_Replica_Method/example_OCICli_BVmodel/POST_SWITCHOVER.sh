## ExampleBVReplicaOCICli
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

# SCRIPT FOR POST STEPS AFTER A SWITCHOVER FROM SITE1 to SITE2
# It performs the following actions:
# - It enables the replica from SITE2 (new primary) to SITE1 (new standby)
# - It disables the replica from SITE1 (new standby) to SITE2 (new primary)

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

echo ################################################
echo ### POST $SITE1 to $SITE2 SWITCHOVER STEPS 
echo ################################################

#Load DR env properties
. DRenv.properties
declare -i i=0

#Assign the values from DRenv.properties to SITE1 and SITE2 accordingly
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



echo "################################################"
echo "### POST $SITE1 to $SITE2 SWITCHOVER STEPS"
echo "################################################"

echo "1) Enabling BV replica from $SITE2 (new primary) to $SITE1 (new standby)"
###############################################################################
i=0
while (($i < $num_nodes)); do

	# Get the cid of the SITE2 BV (given the BV displaynames)
	# Display names: BV_1_displayname BV_2_displayname
	# list_BV.sh <oci_config_file_for_region> <compartmentId> <AvailabilityDomain> <displayName>
	result=$(${UTILS_DIR}/list_BV.sh ${SITE2_oci_config_file} ${compartment_cid} ${SITE2_compute_instance_AD[$i]} ${BV_displayname[$i]} | grep ocid1.volume)
	BV_SITE2_cid[$i]=$(echo $result | awk -F ': ' '{print $2}' | awk -F '"' '{print $2}')
	# Enable the replica for them (from SITE2 to SITE1)
	# enable_replica_in_BV.sh <region_of_the_volume> <block_volume_id_to_be_replicated> <display_name_for_the_replica> <<availability_domain_for_the_replicated_bv>
	${UTILS_DIR}/enable_replica_in_BV.sh ${SITE2_oci_config_file} ${BV_SITE2_cid[$i]} ${BV_replica_displayname[$i]} ${SITE1_compute_instance_AD[$i]}
	echo "Enabled replica for ${BV_displayname[$i]} to $SITE1"
	echo ""

	# If mw block volumes are also replicated, do the same for them
	if [[ $mw_blocks_replicated = "yes" ]] ; then
		result_mw=$(${UTILS_DIR}/list_BV.sh ${SITE2_oci_config_file} ${compartment_cid} ${SITE2_compute_instance_AD[$i]} ${BV_mw_displayname[$i]} | grep ocid1.volume)
		BV_MW_SITE2_cid[$i]=$(echo $result_mw | awk -F ': ' '{print $2}' | awk -F '"' '{print $2}')
		${UTILS_DIR}/enable_replica_in_BV.sh ${SITE2_oci_config_file} ${BV_MW_SITE2_cid[$i]} ${BV_mw_replica_displayname[$i]} ${SITE1_compute_instance_AD[$i]}
		echo "Enabled replica for ${BV_mw_displayname[$i]} to $SITE1"
		echo ""
	fi
	i+=1
done

echo "2) Disable BV replica from $SITE1 (new standby) to $SITE2 (new primary)"
###############################################################################
# Get the cid of the SITE1 BV (given the BV displaynames)
# Display names: BV_1_displayname BV_2_displayname
i=0
while (($i < $num_nodes)); do
	result=$(${UTILS_DIR}/list_BV.sh ${SITE1_oci_config_file} ${compartment_cid} ${SITE1_compute_instance_AD[$i]} ${BV_displayname[$i]} | grep ocid1.volume)
	BV_SITE1_cid[$i]=$(echo $result | awk -F ': ' '{print $2}' | awk -F '"' '{print $2}')

	# Disable the replica for them (from SITE2 to SITE1)
	# disable_replica_in_BV.sh <oci_cli_for_region> <volumeId>
	${UTILS_DIR}/disable_replica_in_BV.sh ${SITE1_oci_config_file} ${BV_SITE1_cid[$i]} 
	echo "Disabled replica for ${BV_displayname[$i]} in $SITE1. You can detach this Block Volume in $SITE1 and then delete or rename"
	echo ""

	# If mw block volumes are also replicated, do the same for them
	if [[ $mw_blocks_replicated = "yes" ]] ; then
		result_mw=$(${UTILS_DIR}/list_BV.sh ${SITE1_oci_config_file} ${compartment_cid} ${SITE1_compute_instance_AD[$i]} ${BV_mw_displayname[$i]} | grep ocid1.volume)
		BV_MW_SITE1_cid[$i]=$(echo $result_mw | awk -F ': ' '{print $2}' | awk -F '"' '{print $2}')

		${UTILS_DIR}/disable_replica_in_BV.sh ${SITE1_oci_config_file} ${BV_MW_SITE1_cid[$i]}
		echo "Disabled replica for ${BV_mw_displayname[$i]} in $SITE1. You can detach this Block Volume in $SITE1 and then delete or rename"
		echo ""
	fi
	i+=1
done

# MANUAL/EXTERNAL COMMAND
##############################################################################
echo "Please complete the POST-Switchover by performing these steps:"
echo "3) Unmount, Disconnect and Detach the Block Volumes in $SITE1 (new standby)"
echo "4) (optional recommended) Delete the detached BV in $SITE1 (new standby)"
