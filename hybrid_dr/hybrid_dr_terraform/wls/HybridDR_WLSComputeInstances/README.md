WLS Hybrid DR terraform scripts  
Copyright (c) 2022 Oracle and/or its affiliates  
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/   

Terraform code to create midtier compute instances for WLS Hybrid DR
----------------------------------------------------------------------
This terraform code is referenced in the section "Provision the Compute Instances for the Mid-tier Nodes" of the playbook  
 "Configure a hybrid DR solution for WebLogic" https://docs.oracle.com/en/solutions/weblogic-server-dr-on-cloud

This terraform code will create: 
- N compute instances for the midtier nodes, using WLS OCI EE/Suite UCM images. The public images are built using OL7.9 and OL8.5 os versions.
 
Steps to use: 
- Edit terraform.tfvars file. 
- Provide the customer values. 
- Run "terraform plan" to review the resources that are going to be created. 
- Run "terraform apply" to create the resources. 


