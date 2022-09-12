WLS Hybrid DR terraform scripts  
Copyright (c) 2022 Oracle and/or its affiliates  
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/  

# Terraform code for creating network resources for Hybrid DR
-----------------------------------------------------------------
This terraform code is referenced in the section "Configure the Network" of the playbooks:  
"Configure a hybrid DR solution for Oracle SOA Suite" https://docs.oracle.com/en/solutions/soa-dr-on-cloud  
"Configure a hybrid DR solution for WebLogic" https://docs.oracle.com/en/solutions/weblogic-server-dr-on-cloud/index.html    

This terraform code will create: 
- A NEW VCN in the compartment. 
- 4 subnets in the VCN, one per each layer: webtier subnet, midtier subnet, fsstier subnet, dbtier subnet. 
- The network security rules to allow traffic between them and with on-prem as described in the Hybrid DR document. 
- (Optional) An Internet Gateway to the VCN. 
 
This terraform code will NOT create: 
- This does not create Fast Connect nor Site-to-Site related configuration. 
- This does not enable incoming SSH traffic from 0.0.0.0/0 to the subnets. If needed, add the rule manually to the subnet's security list after provisioning. 
 
 
Steps to use: 
- Edit terraform.tfvars file. 
- Provide the customer values. 
- Run "terraform plan" to review the resources that are going to be created. 
- Run "terraform apply" to create the resources.

