Copyright (c) 2024 Oracle and/or its affiliates
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/

WLS_HYDR FRAMEWORK
==================================================
This framework **creates and configures a symmetric Disaster Recovery system in the Oracle Cloud Infrastructure** (OCI) for a given on-premises Oracle WebLogic domain environment that follows the Enterprise Deployment Guide best practices. The framework implements the procedure described in these playbooks:
- https://docs.oracle.com/en/solutions/weblogic-server-dr-on-cloud/index.html 
- https://docs.oracle.com/en/solutions/soa-dr-on-cloud/index.html

What the framework **DOES**:
-	It creates and configures a secondary environment in OCI (the compute instances for mid-tier and web-tier, the OCI Load Balancer, the storage artifacts, the network resources, etc.), based on the user input and the information discovered from primary. To get the complete list of the resources this framework creates, see the point [LIST OF THE RESOURCES](#list-of-the-resources). 
-	It copies the content (Oracle products, Oracle HTTP and WebLogic configuration) from the on-premises primary hosts to the OCI compute instances.  

What the framework **DOES NOT**:
-	It doesn’t create the database in OCI.
-	It doesn’t configure Oracle Data Guard between on-prem and OCI databases.
-	It doesn’t configure connectivity between on-prem and OCI.

Alternatively, you can take advantage of this framework in the following scenarios:
- To create an environment in OCI from zero, without having any on-premises system as a reference. In this scenario, the discovery phase doesn’t apply: you have to provide all the input properties. The replication phases don’t apply either: you will have to install the products and configure the WebLogic domain at your own. But can use the framework to create the infrastructure resources that you need for a WebLogic EDG-like system in OCI: compute instances for WebLogic and for OHS, storage artifacts, OCI Load Balancer, and network infrastructure. 
- To migrate your on-premises environment to OCI. In this scenario, you have the on-premises system as a reference, but you may not have direct connectivity between the on-premises datacenter and OCI. You can still use this framework to create the symmetric resources in OCI with some considerations: you will have to manually upload the contents to OCI and provide all the input properties for the provisioning.

## Topology Diagram
The following diagram is a typical Hybrid Disaster Recover topology for an Oracle WebLogic Server system.
![maa-wls-hybrid-dr-tool.png ](/images/maa-wls-hybrid-dr-tool.png)

This framework creates the components highlighted in green.

![maa-wls-hybrid-dr-tool-highlights.png ](/images/maa-wls-hybrid-dr-tool-highlights.png) 

> (*) FastConnect is the preferred connectivity for Data Guard between your on-premises datacenter and OCI. Alternatively, you can use Site-to-Site VPN as long as it meets your bandwith and latency needs.  
> The tool can take advantage of this connectivity to establish SSH connections from the bastion host to the primary on-premises hosts, for the initial setup and the lifecycle.  
> In scenarios without connectivity between the on-premises datacenter and your OCI VCN (for example, when using this tool to migrate a WebLogic system to OCI), you don't require FastConnect or Site-to-Site VPN. You can run this tool to create resources in OCI with some considerations: you must manually upload the file system contents and skip the discovery phase.


## Requirements
Your system must comply the following requirements to use this framework:
-   A **compartment** in OCI must already exist.
-	The **Virtual Cloud Network (VCN)** for the OCI resources must already exist.
-	A Linux OEL8 or OEL9 **bastion host** in OCI **in the same VCN** than the OCI resources _(if the bastion host isn’t located in the same VCN than the OCI resources, then the resources’ VCN and the bastion’s VCN need to be configured to communicate via local peering and this is user responsibility)._ The bastion host is a key component to run the framework: it connects to on-premises hosts to copy the content to an stage location, it runs the OCI client commands to provision the resources in OCI, and it copies the content from the stage to the OCI compute instances.
> INTERNAL COMMENT TO REVIEW AND REMOVE: The spreadsheet has a question "Create VCN? YES/NO". 
We should remove/hide this question, because we already require that the VCN exists. The VCN must exist, because the bastion must exist and it must be in the same VCN than the resources. Hence, the only posible answer that  makes sense is "NO". 
Side note: if the bastion was in a different VCN, hence its VCN would require local peering with the new VCN created for the resources. We don’t' do local peering config in the tool. It is complex to manage this if we have to create the new VCN in the tool: it will require more info, we will have to create local peering on the fly between bastion and the new VCN, etc. Even for this hipotetical case, if customer configures the local peering, it would be needed before running the tool. Hence, the VCN must exist before too.
So, as we require the bastion to be in the same VCN than the resources, hence the VCN must already exist. Let's remove that question. update: we have decided to hide the property

-	**Connectivity** is required between the **OCI** bastion host and the **on-premises** hosts.  On-premises and OCI networks can be interconnected with Oracle Cloud Infrastructure FastConnect (preferred) or Site-to-Site VPN. 
-	Direct **SSH access** is required **from the bastion** host **to the primary** OHS and WLS **hosts** with the owner user (e.g. oracle). The SSH authentication must use an **SSH key**. Authentication based in password is not supported. 
> NOTE: The **connectivity** and **direct SSH** are required for the replication and discovery phases. If these requirements are not met, then you can manually upload the file system contents to the bastion host, skip the discovery phase, and use the tool to perform the rest of the actions. 

-	The **Operating System versions** supported for the primary hosts are **OEL7.X, OEL8.x, RHEL7.x and RHEL8.x**. If the primary hosts are OEL7 or RHEL7, then the  compute instances in OCI will be created with OEL7 image. If the primary hosts are OEL8 or RHEL8, then the compute instances in OCI will be created with OEL8 image.
-	**Oracle HTTP Servers (OHS)** are used to access to the system, to send the requests to the WebLogic servers.
-	A **Load Balancer** is used in front of the OHS hosts.
-   The **SSL certificate** (public and private keys) used by the Load Balancer.
-	At least **2 nodes** for OHS and 2 nodes for WLS (High availability).
-	The components (WebLogic Servers, OHS instances) **do not use IPs as listen addresses**.
-	The clients use **frontend names** (a.k.a vanity urls) to access to the applications through the Load Balancer (not IPs).
-	There is a **Database in OCI**, configured as standby for the primary database. This Data Guard setup can be done before or after running the tool, but it is a requirement for the OCI system to work.


## Assumptions
It's assumed that:
-	The system uses one virtual host for the HTTPS access.
-	(Optional) The system uses a dedicated virtual host with HTTP for accesing to the WLS Admin console.
-	(Optional) The system can use an additional internal virtual host with HTTP (for example to access to WSM).
-   The OHS configuration is under "moduleconf" folder.
-	The same SSH key is used to connect to all the on-premises OHS nodes with the software owner user (e.g. oracle).
-	The same SSH key is used to connect to all the on-premises WLS nodes with the software owner user (e.g. oracle).
-   Every WebLogic Server, including the Admin Server, listen explicitly in a hostname listen address. The listen address is not blank or IP.
-	There is one WebLogic listen address per host (which may be resolved with a different IP than the one provided for SSH in the prem.env), except for the Admin Server, who can listen in an additional virtual name (VIP). (INTERNAL NOTE: right now the VIP is not created in OCI. The listen address of the admin server is just ignored for now)
-	There is one Weblogic shared config folder shared by all the WebLogic hosts.
-	There is one WebLogic private config folder for each WebLogic host, which is not directly in the default volume /. Each private config folder can be an NFS private mount or a Block Volume, mounted in each WebLogic host.
-	The Oracle products in the WebLogic hosts are installed under a folder that is not directly in the default volume /. The tool assumes that there are 2 redundant shared binary homes (NFS) in primary: one mounted by half of the nodes and the other mounted by the other half. This is the topology that is created in OCI and replication logic is based on this. A different approach can also work, with some considerations (refer to "ABOUT TOPOLOGY VARIATIONS" point 5).
-	TNS alias is used in the connection strings of the on-premises WebLogic's datasources.
-   The WebLogic Administration server runs collocated, in the same host than other or others managed servers (>this assumption can be removed, depending on how we implement the ER for the vip.)

Se below point [ABOUT TOPOLOGY VARIATIONS](#about-topology-variations) if your system does not honor these assumptions/requirements.

Users and roles required
--------------------------------------
This solution requires the following services and roles:

| Service Name: Role                             | Required to...                                                                                                                                         |
|------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------|
| Oracle Cloud Infrastructure: administrator     | Create the required resources in the OCI tenancy with the tool (compute instances, storage, Load Balancer, networking resources)                       |
| Network: administrator                         | Configure the required network resources both in on-premises and OCI: Fast Connect, VCNs and subnets in OCI, network security rules and routing rules. |
| Oracle WebLogic Server: root, oracle           | Use the tool to configure the secondary hosts: OS level configuration, add host aliases, mount file systems, and replication.    |
| Oracle WebLogic Server: Weblogic Administrator | Manage Oracle WebLogic Server: stop, start, and apply WebLogic configuration changes.                                                                  |
| Oracle HTTP Server: root, oracle               | Use the tool to configure the secondary OHS hosts: perform the OS level configuration, add host aliases, mount file systems, and replication.    |


FRAMEWORK OVERVIEW
==================================================
The wls_hydr framework consists of three main components:  
![tool-main-modules.png ](/images/tool-main-modules.png) 

|What|Description
|---|---|
|wls-hydr|Basedir|
|├── config|Directory where sysconfig.json files are saved|
|├── lib|Lib directory where class files and template files are located|
|│   ├── Logger.py| Logger class file. Handles logging|
|│   ├── OciManager.py| OCI manager class file. Imported by wls_hydr.py and used to interact with OCI|
|│   ├── Utils.py|Various utility functions required by wls_hydr.py (eg data validation functions)|
|│   └── templates|Script templates directory. These are parameterized scripts that are processed by wls_hydr.py with dynamic data. Output scripts will be stored in lib/|
|│       ├── ohs_node_init.sh|Template script for OHS. Processed by wls_hydr.py with OHS information and handles matching OHS UIDs and GIDs with on-prem ones and opening required ports| 
|│       └── wls_node_init.sh|Template script for WLS. Processed by wls_hydr.py with WLS information and handles matching WLS UIDs and GIDs with on-prem ones, opening required ports and mounting filesystems| 
|├── log|Execution logs will be stored here|
|└── wls_hydr.py|Main script|


END-TO-END PROCEDURE
==================================================
The following diagram summarizes the **main** flow execution of the framework. This procedure **creates a secondary system in OCI for a given on-prem system based on the EDG best practices**. All the steps are run separately. The execution of each one depends on the results of the previous one.
![Flow diagram to create a secondary system in OCI for a given on-prem environment. ](/images/Main_flow_diagram.png)

Additional scenarios that can take advantage of this framework:

- **To create the resources in OCI from zero**, without having any environment as reference. You only need to prepare and run the provisioning phase:  
![Flow diagram to create a system in OCI from zero (without any primary system) ](/images/flow_diagram_create_from_zero.png)


- **To migrate on-premises system, and there is no connectivity** between OCI bastion and on-premises hosts. You can't run pull and discovery phases:
![Flow diagram to migrate on-prem system to OCI (without connectivity) ](/images/flow_migrate.png)

## Prepare
1. Create the Virtual Cloud Network (VCN) for the resources in OCI in the region where you want to create the resources.
2. Create a subnet in the VCN for the bastion. 
3. Provision a bastion host in the subnet. Bastion host must be OEL8 or OEL9. For the shape, VM.Standard.E4.Flex with 1 OCPU and 16GB memory is enough to run the framework.
4. Setup the connectivity between on-premises hosts and bastion host.
5. Prepare the bastion host to run the framework:
    1. Make sure the following python modules are installed:  
    oci sdk (this package should come pre-installed on OCI OL9 images):  `rpm -qa | grep -i python.*oci `   
    paramiko:     `rpm -qa | grep -i python3-paramiko`   
    Install with the following command if missing:  
    `sudo yum --enablerepo="ol9_developer_EPEL" install python3-paramiko`  
    or  
    `sudo yum --enablerepo="ol8_developer_EPEL" install python3-paramiko`
    2. Add the OCI config to the bastion server, to connect with OCI API to the OCI tenancy and region where you want to create the resources. Complete instructions can be found [here](https://docs.oracle.com/en-us/iaas/Content/API/Concepts/apisigningkey.htm#apisigningkey_topic_How_to_Generate_an_API_Signing_Key_Console). Then, when you run the provision phase, you can supply the path of the oci config file using -c/--oci-config FILE_PATH. If no path is supplied, the default path is assumed `<HOME>/.oci/config` 
7. Transfer the wls_hydr code to the bastion server (example location <HOME>/wls_hydr) 
8. (Optional) Create a subnet for the database.
9. (Optional) Create a DB system and configure Oracle Data Guard between the primary. You can do this before or after executing the framework.


## Pull (initial replication from primary)
### Using the framework
In the initial pull step, the file system contents are copied from primary hosts to an stage folder in the bastion host. You provide the connection details to the on-premises hosts and the folders names. Then, the tool copies the contents from the OHS and the WebLogic hosts to the bastion node. In the next phases, the tool will introspect this information and push it to the OCI compute instances once they are created.

- Prepare: 
    - Prepare the stage folder in the bastion. The amount of information that is copied can be high, so you may require to add additional storage to the bastion. To have enough disk space for the copies, you can create an OCI FSS or a new block volume and mount it on the bastion.
    - Edit the `<WLS-HYDR_BASE>/config/prem.env` and provide the values used by your system (user, group, SSH keys, on-premises hosts IPs, etc.)
    - Edit the replication.properties and provide the values for the folders.

- Run:
    - `<WLS-HYDR_BASE>/lib/DataReplication.py pull`
- Validate:
    - Verify the output log.
    - Verify that the copied contents are in the stage folder.

The following table summarizes how each item is copied to the stage folder.

| Item    | Pull | Location of the copy under the STAGE_GOLD_COPY_BASE folder |
| -------- | ------- | ------- |
| OHS_PRODUCTS | Regardless the number of OHS nodes, it performs just 2 copies (one copy from OHS node 1 and other copy from OHS node 2). It is trade-off to provide redundancy and minimize disk size.  |  webtier/ohs_products_home/ohs_products_home1 <br>webtier/ohs_products_home/ohs_products_home2  |
| OHS_PRIVATE_CONFIG_DIR   | One copy from per OHS node.    |  webtier/ohs_private_config/ohsnodeN_private_config  |
| WLS_PRODUCTS  | Regardless the number of WLS nodes, it performs 2 copies (one from node 1 and other from node 2). This approach provides redundancy and minimize disk size. It is valid for cases where redundant shared products folders are used, and for cases where each node has private products folder |  midtier/wls_products_home/wls_products_home1<br> midtier/wls_products_home/wls_products_home2  |
| WLS_PRIVATE_CONFIG_DIR    | One copy from per WLS node.     |  midtier/wls_private_config/wlsnodeN_private_config/  |
| WLS_SHARED_CONFIG_DIR | It is assumed that this shared folder could contain external content from other environments. So only these subfolders are copied: <br>- the domain home <br>- the applications home (where the em.ear file resides). <br>These items are copied only from the first node, as this is expected to be shared folder. |  appropriate subfolders under midtier/wls_shared_config/  |
| WLS_SHARED_RUNTIME_DIR    | The content in this folder is not copied. The value is used to prepare the mount in OCI.    |  N/A  |
| WLS_CONFIG_PATH    | The location of the config.xml file. The tool gathers the domain home and applications home from this file    |  N/A  |
| WLS_DP_DIR    | Copied only from the first WLS node. Assumed it is shared.     |  appropriate subfolder under midtier/wls_shared_config  |
| WLS_ADDITIONAL_SHARED_DIRS    | Additional shared dirs that need to be copied. They are copied from node 1    |  The complete path is stored under midtier/wls_shared_config/additional_dirs/  |

### Manual copy
If you don't have SSH connectivity from the bastion to the on-premises hosts, you can manually copy the items to the bastion's stage, as long as you honor the staging structure.
(provide details?)

## Discovery
As part of the discovery phase process, the tool automatically finds relevant information of the system. It obtains this information in two ways: by introspecting it from the pulled information and by connecting via SSH to the on-prem hosts. It will use this information to create the resources in OCI in the next phases.
- Prepare:
    - Edit the `<WLS-HYDR_BASE>/config/prem.env`. If you ran the pull replication phase, this file should be already customized.
- Run:
    - `<WLS-HYDR_BASE>/lib/Discovery.py`
- Validate:
    - The discovery tool stores the results in the output file `<WLS-HYDR_BASE>/config/discovery_results.csv`. Review that they are according to your environment.
    - If needed, you can re-reun the discovery. The output file will be overriden with the new results.

## Provision in OCI 
In the provisioning phase, the tool creates the resources in OCI. They are created according to the input properties provided by the user and the results obtained in the discovery phase. 
- Prepare:
    - If you have run the discovery phase, then you need to complete the excel **sysconfig_discovery.xlsx**.
    - If you haven't run the discovery phase, then you need to complete the excel **sysconfig.xlsx**.
    - Export the excel to .CSV format and upload it to the bastion.
    - Upload the keys and certs files to the bastion. Place them in the appropriate path, according with the inputs in the spreadsheet.
- Run:
    - If you previously ran the discovery phase, use the flag "-a":  `<WLS-HYDR_BASE>/wls_hydr.py -i <XXX_discovery.csv> -a`
    - If you didn't run the discovery phase:     `<WLS-HYDR_BASE>/wls_hydr.py -i <XXX.csv>`
- Validate:
    - Verify that the resources have been created. To get the complete list of the resources, [see the point LIST OF THE RESOURCES](#list-of-the-resources).

## Push (initial replication to OCI)
In the push phase, the tool copies the contents from the bastion stage to the OCI compute instances. The following table describes how each item is copied to the OCI hosts.
| Item    | Location of the copy under the STAGE_GOLD_COPY_BASE folder  | Push|
| -------- | ------- | ------- |
| OHS_PRODUCTS | webtier/ohs_products_home/ohs_products_home1 <br>webtier/ohs_products_home/ohs_products_home2  | The ohs_products_home1 to all odd nodes, the ohs_products_home2 to all even nodes  |  
| OHS_PRIVATE_CONFIG_DIR   | webtier/ohs_private_config/ohsnodeN_private_config  |  Each node copy to each OHS peer node.    |
| WLS_PRODUCTS  |  midtier/wls_products_home/wls_products_home1<br> midtier/wls_products_home/wls_products_home2  |  The wls_products_home1 is copied  to node 1, the wls_products_home2 is copied to node 2. If there are more WLS nodes, they share the sames product folder, so no more copies needed |
| WLS_PRIVATE_CONFIG_DIR     |  midtier/wls_private_config/wlsnodeN_private_config/  | Each node copy to each WLS peer node. |
| WLS_SHARED_CONFIG_DIR |   appropriate subfolders under midtier/wls_shared_config/  | The domain home and the applications home (where the em.ear file resides) are copied to the first OCI WLS node, as this is placed in a shared folder. |
| WLS_SHARED_RUNTIME_DIR    |  N/A  | The content in this folder is not copied.   |
| WLS_DP_DIR    |  appropriate subfolder under midtier/wls_shared_config  | Copied only to the first WLS node. Assumed it is shared.     |
| WLS_ADDITIONAL_SHARED_DIRS    | The complete path is stored under midtier/wls_shared_config/additional_dirs/    |  Copied only to the first WLS node. Assumed it is shared.  |

- Prepare:
    - verify the `<WLS-HYDR_BASE>/config/oci.env` file. This file is pre-propulated in the provisioning phase, so just verify that the values are accurate.
- Run:
    - `<WLS-HYDR_BASE>/lib/DataReplication.py push`
- Validate:
    - Verify the output.
    - Verify that the contents are present in the expected locations in the OCI hosts.

## Push tnsnames.ora 
In this step, the tool retrieves the tnsnames.ora file from on-premises domain, it performs a replacement of the scan address and service name to point to secondary database, and it copies the new file to the OCI WebLogic hosts. The tnsnames.ora file is skipped from the regular pull and push replications, because this file is different in each site (the entry in the tnsnames.ora must point to the local database in each site). Hence, this replication action is needed only during the initial setup. 
- Prepare:
    - Verify that the section "JDBC" in the file `<WLS-HYDR_BASE>/config/replication.properties` contains the appropriate values.
- Run:
    - `<WLS-HYDR_BASE>/lib/DataReplication.py tnsnames`
- Validate:
    - Verify that the tnsnames.ora file exists in the appropriate path in the OCI WebLogic hosts. 
    - Verify that its content is correct.

## Replication during lifecycle (TBD)

(add also a note about how to remove WLS_ADDITIONAL_SHARED_DIRS: remove from replication.properties, remove from primary, remove from secondary. it will remain in stage)


ABOUT TOPOLOGY VARIATIONS 
==================================================

#### 1. Not using wls shared config folder (wls using only private folders)
> THIS IS INTERNAL CONTENT TO DISCUSS  ---> ALREADY DISCUSSED, PENDING TO UPDATE WHEN IMPLEMENTED  
Right now, the tool will fail at some point because this folder is expected.
To support this scenario, we first have to define the desired behavior (something like "if wls private folder not provided, do not create related resources/copies, etc."?) and create ER to implement it.  
Until then: users can follow manual procedure described in https://docs.oracle.com/en/solutions/weblogic-server-dr-on-cloud/index.html adapting the examples to meet their environment specifics. 
#### 2. Not using wls private config folder (wls using only shared config)
> THIS IS INTERNAL CONTENT TO DISCUSS  --> ALREADY DISCUSSED, PENDING TO UPDATE WHEN IMPLEMENTED  
Same as before, the tool will fail at some point because this folder is expected.
To support this scenario, we first have to define the desired behavior (something like "if wls private folder not provided, do not create related resources/copies, etc."?) and create ER to implement it.  
Until then: users can follow manual procedure described in https://docs.oracle.com/en/solutions/weblogic-server-dr-on-cloud/index.html  adapting the examples to meet their environment specifics.
#### 3. Private wls config is not in a separate mount point, it's directly in a subfolder under / 
> THIS IS INTERNAL CONTENT TO DISCUSS  --> ALREADY DISCUSSED, PENDING TO UPDATE WHEN IMPLEMENTED  
It will fail. The tools creates Block Volumes for this in OCI. It gets the mount point value from primary hosts. If it returns /, the tool can't mount them. To support this scenario, we first have to define the desired behavior and then add enhancements (for example: if mount point for the private config is /, thenit means it is directly in boot. Then, do not create BV for wls private config and just crate a folder under / like we do in OHS hosts).  
Until then: follow manual procedure described in https://docs.oracle.com/en/solutions/weblogic-server-dr-on-cloud/index.html adapting the examples to meet your environment specifics.
#### 4. The wls products folder is not in a separate mount point, it's directly in a subfolder under / 
> THIS IS INTERNAL CONTENT TO DISCUSS  --> ALREADY DISCUSSED, PENDING TO UPDATE WHEN IMPLEMENTED  
The tool executionwt will fail. The tools creates 2 FSS for this in OCI, and we can't mount the FSS under /. To support this scenario, we first have to define the desired behavior and then add enhancements in the app.   
Until then: follow manual procedure described in https://docs.oracle.com/en/solutions/weblogic-server-dr-on-cloud/index.html  adapting the examples to meet their environment specifics.
#### 5. More than 2 WLS nodes and not using redundant shared folders for products (e.g. each node using its private products home )
> THIS IS INTERNAL CONTENT TO DISCUSS  --> ALREADY DISCUSSED, PENDING TO UPDATE WHEN IMPLEMENTED  
I think all will work ok in the tool setup, initial pull and push, etc. In the direction onprem --> oci replication will work ok. In OCI, the WLS nodes will use 2 redundant products homes: one mounted by the half of the nodes and the other mounted by the rest. We will copy binaries to these 2 redundant: from onprem primary node 1 to the home 1 and from onprem primary node 2 to the home 2.  
But a problem arises in the replication after a switchover, when replicating from OCI to onprem. The tool assumes that there are 2 redundant wls products home shared between the wls nodes, so it will perform only 2 copies of the binaries: to the node 1 and to the node 2. No copies will be performed to the rest of the nodes (it is assumed that they are sharing the same product homes with the first two).
The binaries do not frecuently change, so this is not a big issue. We cant just document it here.
#### 6. More than one listen address per host (besides the AS VIP)
> THIS IS INTERNAL CONTENT TO DISCUSS  
I think (we could test) that everything should work fine except the entries in the private view we create in OCI, which will be inaccurate. If the problem is just that, the user could correct the private view entries manually post provisioning (if he realizes). Alternatively, we can change the tool code to manage a N-to-one relation between listen addresses and wls hosts (now it is aone-to-one I think).
#### 7. Not using OHS (LBR connects directly to WLS)
> THIS IS INTERNAL CONTENT TO DISCUSS   --> ALREADY DISCUSSED, PENDING TO UPDATE WHEN IMPLEMENTED  
Right now the tool will fail. We should define what is the behavior that we want (fail?, ignore and do not create OHS?, completely support this ad add config in LBR, or just create a simple LBR config and let the user to finish it post provisioning?)
In the mean time, customers can follow the manual procedure playbook https://docs.oracle.com/en/solutions/weblogic-server-dr-on-cloud, where we provide the steps for this scenario.
#### 8. Not using OHS (using other Web server product) 
> THIS IS INTERNAL CONTENT TO DISCUSS   
Right now the tool will fail. Our tool expects the config syntax and folders used by OHS. We should define what is the behavior that we want (fail?, ignore and do not create OHS?.
Until then: users can follow manual procedure described in https://docs.oracle.com/en/solutions/weblogic-server-dr-on-cloud/index.html by configuring the web servers in OCI at their own.
#### 9. Not using LBR
> THIS IS INTERNAL CONTENT TO DISCUSS  --> ALREADY DISCUSSED, PENDING TO UPDATE  
The execution of the tool will fail as we expect an LBR. I think we should not support this scenario in the automation, it is probably unusual becase an LBR is the most common way to load balance requests between the OHS servers.
The customer can follow the manual procedure described in https://docs.oracle.com/en/solutions/weblogic-server-dr-on-cloud/index.html , adapting the examples to meet their environment specifics. 
#### 10. Using additional virtual servers to access to the system
> THIS IS INTERNAL CONTENT TO DISCUSS  
The tool will not add them. But the user can add them manually, as a post step.
#### 11. The Admin Server running in its own host 
> THIS IS INTERNAL CONTENT TO DISCUSS  
As the tool is right now, I think everything should work fine EXCEPT the entries in the private view, that will be inaccurate. But not sure if the tool will give an error and stop or continue.
But the behavior for this scenario depends on how we finally implement the ER about the VIP.
#### 12. There is no virtual server to expose the WLS Admin Console
> THIS IS INTERNAL CONTENT TO DISCUSS  --> ALREADY DISCUSSED, PENDING TO UPDATE  
If the customer is not exposing the WLS Admin console in the LBR, the tool will fail at some point during provisioning. The tool tries to create this (listener, backend, hostname, etc. in lbr), and gathers for related info (frontend name/LBR port/OHS port for this). Not sure how "ignorable" this failure is right now (the whole provisioning fails? or only the creation of these resources fails?).  
To support this without failures, we can consider to create this virtual server as optional, like the "internal virtual host". This requires enhacements in the tool.
#### 13. The WLS Admin Console is exposed in LBR with HTTPS (instead of in HTTP)
> THIS IS INTERNAL CONTENT TO DISCUSS  --> ALREADY DISCUSSED, PENDING TO UPDATE  
The tool currently configures the listener for the WebLogic Admin Console in HTTP.  
If the customer is exposing it in HTTPS, I think that the provisioning will NOT fail. But the customer will have to modify manually the listener for the WLS Admin Console in the LBR to configure it as HTTPS (add cert, change protocol).   
To support this in the tool, enhacement request are needed to support the creation of this virtual server in HTTP or HTTPS, depending on the primary config.
#### 14. The operating systems of primary are not OEL7,OEL8,RHEL7,RHEL8
> THIS IS INTERNAL CONTENT TO DISCUSS  
If an equivalent image exits in OCI, then the user can follow manual procedure described in https://docs.oracle.com/en/solutions/weblogic-server-dr-on-cloud/index.html . When they create the compute instances, they must choose the equivalent image, if such  image is available OCI.

KNOWN ISSUES/ OTHER LIMITATIONS ?
==================================================




LIST OF THE RESOURCES
==================================================
This table lists all the resources that this framework creates in OCI.

<details><summary>Click to expand</summary>

| Category                     | Resource                                                    | Name                                       | Additional details                                                                |
|------------------------------|-------------------------------------------------------------|--------------------------------------------|-----------------------------------------------------------------------------------|
| Network resources            | subnet for webtier                                          | custom name                                | Created if it doesn't already exist                                               |
|                              | subnet for midtier                                          | custom name                                | Created if it doesn't already exist                                               |
|                              | subnet for FSS                                              | custom name                                | Created if it doesn't already exist                                               |
|                              | subnet for dbtier                                           | custom name                                | Created if it doesn't already exist                                               |
|                              | private route table                                         | HyDR_private_subnet_route_table            |                                                                                   |
|                              | public route table                                          | HyDR_public_subnet_route_table             | Created if there is a public subnet                          |
|                              | security list for webtier subnet                            | \<webtier_subnet_name\>_security_list        |                                                                                   |
|                              | security list for midtier subnet                            | \<midtier_subnet_name\>_security_list        |                                                                                   |
|                              | secuirty list for FSS tier subnet                           | \<fsstier_subnet_name\>_security_list        |                                                                                   |
|                              | security list for dbtier subnet                             | \<dbtier_subnet_name\>_security_list         |                                                                                   |
|                              | Internet Gateway                                            | HyDR_SG_Gateway                            | Created if it doesn't exist and there is a public subnet                          |
|                              | Service Gateway                                             | HyDR_SG_Gateway                            | Created if it doesn't already exist                                               |
|                              | NAT Gateway                                                 | HyDR_NAT_Gateway                           | Created if it doesn't already exist                                               |
|                              | DNS Private View                                                | HYBRID_DR_VIRTUAL_HOSTNAMES                |                                                                                   |
|                              | DHCP Options                                                | HyDR-DHCP                                  |                                                                                   |
|                              | Virtual IP Address for AS **(TBD)**                             | \<the listen address of the Admin Server\>   | Created only if AS listens in a VIP                                               |
| Compute Instances            | N compute instances for OHS                                 | \<custom ohs prefix\>-N                      | Created using WLS for OCI images                                                  |
|                              | N compute instances for WLS                                 | \<custom wls prefix\>-N                      | Created using WLS for OCI images                                                  |
| Storage Resources            | FSS Mount target                                            | \<custom_prefix\>Target1 (2)                 | 1 (or 2 if using 2 availability domains).                                         |
|                              | FSS File System for WLS shared config                       | \<custom_prefix\>configFSS                   |                                                                                   |
|                              | FSS File System for WLS products 1                          | \<custom_prefix\>productsFSS1                |                                                                                   |
|                              | FSS File System for WLS products 2                          | \<custom_prefix\>productsFSS2                |                                                                                   |
|                              | FSS File System for WLS shared runtime                      | <\<ustom_prefix\>runtimeFSS                  |                                                                                   |
|                              | N Block Volumes                                             | wlsdrbvN                                   | One per WLS node, for the private config                                          |
| Load Balancer resources      | Load Balancer                                               | custom name                                |                                                                                   |
|                              | Ruleset                                                     | HTTP_to_HTTPS_redirect                     |                                                                                   |
|                              | Ruleset                                                     | SSLHeaders                                 |                                                                                   |
|                              | Listener (for HTTPS)                                        | HTTPS_APP_listener                         |                                                                                   |
|                              | Listener (for HTTP)                                         | HTTP_APP_listener                          | In port 80 and same hostname than "Listener (for HTTPS)", redirects all to "Listener (for HTTPS)" |
|                              | Listener (for WLS Admin Console, HTTP)                      | Admin_listener                             |                                                                                   |
|                              | Listener (for internal accesses, HTTTP)                     | HTTP_internal_listener                     | Optional                                                                          |
|                              | Certificate                                                 | HyDR_lbr_cert                              |                                                                                   |
|                              | Hostname (frontend for HTTPS access)                        | HyDR_LBR_virtual_hostname                  |                                                                                   |
|                              | Hostname (frontend for accesing to WLS Admin Console)       | HyDR_LBR_admin_hostname                    |                                                                                   |
|                              | Hostname (frontend for Internal HTTP acccess)               | HyDR_LBR_internal_hostname                 | Optional                                                                          |
|                              | Backendset for the "Listener (for HTTPS)"                   | OHS_HTTP_APP_backendset                    |                                                                                   |
|                              | Backendset for the "Listener (for WLS Admin Console, HTTP)" | OHS_Admin_backendset                       |                                                                                   |
|                              | Beackenset for the "Listener (for HTTP)"                    | empty_backendset                           |                                                                                   |
|                              | Backendset for the Listener (for internal access, HTTP)  | OHS_HTTP_internal_backendset_XX            | Optional                                                                          |
| Additional actions performed | In the OHS compute instances                                    | Create user/group as primary               |                                                                                   |
|                              |                                                             | Configure ssh access for user              |                                                                                   |
|                              |                                                             | Create folders                             |                                                                                   |
|                              |                                                             | Open required ports in OS FW               |                                                                                   |
|                              |                                                             | Add OHS listen addresses to the /etc/hosts |                                                                                   |
|                              |                                                             | Add frontend names to the /etc/hosts       |                                                                                   |
|                              | In the WLS compute instances                                    | Create user/group as primary               |                                                                                   |
|                              |                                                             | Configure ssh access for user              |                                                                                   |
|                              |                                                             | Install package compat-libstdc++-33 if OEL7        |                                                                                   |
|                              |                                                             | Create folders                             |                                                                                   |
|                              |                                                             | Open required ports in OS FW               |                                                                                   |
|                              |                                                             | Mount storage artifacts (FSS and BV)       |                                                                                   |
|                              |                                                             | Add frontend names to the /etc/hosts       |                                                                                   |

</details>
