SOA Hybrid dr terraform scripts v 1.0  
Copyright (c) 2022 Oracle and/or its affiliates  
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/   

#Terraform code for creating midtier compute instances for SOA Hybrid DR
----------------------------------------------------------------------
This terraform code is referenced in the section "Provision the Compute Instances for the SOA Mid-tier Nodes" 
of the playbook "Configure a hybrid DR solution for Oracle SOA Suite".  
Reference: https://docs.oracle.com/en/solutions/soa-dr-on-cloud 

This terraform code will create: 
- N compute instances for the midtier nodes 
 
Steps to use: 
- Terraform code in folder "1_get_shapes_and_images" can be used to get the list of images and shapes available.
	- Edit terraform.tfvars file. 
	- Provide the customer values. 
	- Run "terraform plan" to get the info. 
	- Choose the OS image ocid and compute shape that are similar to the image and shape used by the on-premises hosts. 
 
- Terraform code in folder "2_create_compute_instances" is used to provision the midtier compute instances with the values provided.
	- Edit terraform.tfvars file. 
	- Provide the customer values. 
	- Run "terraform plan" to review the resources that are going to be created. 
	- Run "terraform apply" to create the resources. 

