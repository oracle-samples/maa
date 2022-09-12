WLS Hybrid DR terraform scripts  
Copyright (c) 2022 Oracle and/or its affiliates  
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/  

# Terraform code for WLS Hybrid DR

This project contains the following code to create resources as described in the playbooks:  
https://docs.oracle.com/en/solutions/soa-dr-on-cloud/index.html  
https://docs.oracle.com/en/solutions/weblogic-server-dr-on-cloud/index.html     

| Folder  | Description |
| ------------- | ------------- |
| [common/](./common) | This folder contains common terraform scripts.
| [wls/](./wls) | This folder contains terraform scripts specific to WLS Hybrid DR.
| [soa/](./soa) | This folder contains terraform scripts specific to SOA Hybrid DR.


# Recommended order to use them is: 
1) [common/HybridDR_NetworkResources](./common/HybridDR_NetworkResources), to create the network resources.
2) [common/HybridDR_DBSystem](./common/HybridDR_DBSystem), to create the DB system.
3) [common/HybridDR_FSSresources](./common/HybridDR_FSSresources), to create the OCI FS resources.
4) [wls/HybridDR_WLSComputeInstances](./wls/HybridDR_WLSComputeInstances) or [soa/HybridDR_SOAComputeInstances](./soa/HybridDR_SOAComputeInstances) to create the midtier nodes.
5) [common/HybridDR_OCILoadBalancer](./common/HybridDR_OCILoadBalancer) to create the OCI Load Balancer (which requires the midtier nodes).

