# Automating the Identity and Access Management Enterprise Deployment

A number of sample scripts have been developed which allow you to deploy Oracle Identity and Access Management 14c. These scripts are provided as samples for you to use to develop your own applications.

You must ensure that you are using Identity and Access Management 14c with the October 2025 or later Stack Bundle Patch for this utility to work.

The scripts can be run from any host which has access to your servers, for example a bastion node. 

You must have passwordless ssh set up from the deployment host to each of your hosts so that commands can be executed on those hosts without having to provide a password each time.

You must have the Oracle Binaries available on each of your hosts, this can be via shared storage.

These scripts are provided as examples and can be customized as desired.

## Obtaining the Scripts

The automation scripts are available for download from GitHub.

To obtain the scripts, use the following command:

```
git clone https://github.com/oracle-samples/maa.git
```

The scripts appear in the following directory:

```
maa/1412EDG/IDM
```

Move these template scripts to your working directory. For example:

```
cp -R maa/1412EDG/IDM/* /workdir/scripts
```

You must also download the Oracle Binaries and latest Bundle Patch Sets as described in [Identifying and Obtaining Software Distribution for an Enterprise Deployment](https://docs.oracle.com/en/middleware/fusion-middleware/14.1.2/imedg/procuring-resources-premises-enterprise-deployment.html#GUID-5D38B09D-6A0B-4304-B8F9-8006F91E82F3)

If you are provisioning Oracle Identity Governance you must also Download the Oracle connector Bundle for OUD and extract it to a location which is accessible by the provisioning scripts.  For example, /workdir/connectors/OID-12.2.1.3.0.    The connector directory name must start with OID-12.2.1.

## Scope
This section lists the actions that the scripts perform as part of the deployment process. It also lists the tasks the scripts do not perform.

### What the Scripts Will do

The scripts will deploy Oracle HTTP Server, Oracle Unified Directory (OUD), Oracle Access Manager (OAM), and Oracle Identity Governance (OIG). They will integrate each of the products. You can choose to integrate one or more products.

The scripts perform the following actions:

* Generate self-issued SSL certificates as described in [Obtaining SSL Certificates](https://docs.oracle.com/en/middleware/fusion-middleware/14.1.2/imedg/procuring-resources-premises-enterprise-deployment.html#GUID-CC4649FA-3163-4F11-89F6-D8B3426C155D).
* Install and configure Oracle HTTP Server as described in [Configuring Oracle HTTP Server for an Enterprise Deployment](https://docs.oracle.com/en/middleware/fusion-middleware/14.1.2/imedg/installing-and-configuring-oracle-http-server.html).
* Deploy and configure Oracle WebGate as described in [Configuring Single Sign-On for an Enterprise Deployment](https://docs.oracle.com/en/middleware/fusion-middleware/14.1.2/imedg/configuring-single-sign-enterprise-deployment.html#GUID-10906355-241B-4B74-B8A9-39721E1F6CA0).
* Install and Configure Oracle Unified Directory as described in [Configuring Oracle LDAP for an Enterprise Deployment](https://docs.oracle.com/en/middleware/fusion-middleware/14.1.2/imedg/installing-and-configuring-oracle-unified-directory.html#GUID-1BDDB9EF-76EE-4BC2-ABA4-F785F9B28746). 
* Optionally nable OUD SSL.
* Seed the directory with users and groups required by Oracle Identity and Access Management as described in [Preparing an Existing LDAP Directory](https://docs.oracle.com/en/middleware/fusion-middleware/14.1.2/imedg/installing-and-configuring-oracle-unified-directory.html#GUID-65D1626D-9716-4526-AE5B-F6B9BEF0D495).
* Create indexes and ACI’s in OUD as described in [Granting OUD changelog access](https://docs.oracle.com/en/middleware/fusion-middleware/14.1.2/imedg/installing-and-configuring-oracle-unified-directory.html#GUID-8966D329-3BAD-45C6-8FE6-993E29EC7B5F).
* Set up replication agreements between different OUD instances.
* Install and Configure Oracle Unified Directory Service Manager as described in [Configuring Oracle Unified Directory Service Manager](https://docs.oracle.com/en/middleware/fusion-middleware/14.1.2/imedg/installing-and-confguring-oracle-unified-directory-service-manager.html#GUID-33F09B97-DDC1-4007-9A61-61CA9389305A)
* Create the RCU schema objects for the product being installed. 
* Install and Configure Oracle Access Manager as described in [Configuring Oracle Access Management](https://docs.oracle.com/en/middleware/fusion-middleware/14.1.2/imedg/installing-and-configuring-oracle-access-manager.html).
* Optionally enable OAM Secure Mode.
* Integrate OAM with LDAP.
* Install and Configure Oracle Identity Governance as described in [Configuring Oracle Identity Governance](https://docs.oracle.com/en/middleware/fusion-middleware/14.1.2/imedg/configuring-infrastructure-oracle-identity-governance.html).
* Optionally enable OIG Secure Mode.
* Integrate OIG and SOA.
* Integrate OIG with LDAP.
* Integrate OIG and OAM.
* Configure SSO integration in the Governance domain.
* Enable OAM Notifications.
* Copy the WebGate artefacts to Oracle HTTP Server, if desired.
* Run Reconciliation Jobs.
* Configure Oracle Unified Messaging with Email/SMS server details.
* Set up the Business Intelligence Reporting links.
* Configure OIM to use BIP.
* Store the BI credentials in OIG.

### What the Scripts Will Not Do

While the scripts perform the majority of the deployment, they do not perform the following tasks:

* Configure the Host Servers.
* Configure load balancer.
* Tune the WebLogic Server.
* Configure OAM One Time Pin (OTP) forgotten password functionality
* Set up OIM challenge questions.
* Provision Business Intelligence Publisher (BIP).
* Set up the links to the Oracle BI Publisher environment. However, the scripts will deploy reports into the environment.
* Enable BI certification reports in OIG.


## Key Concepts of the Scripts

To make things simple and easy to manage the scripts are based around two concepts:

* A response file with details of your environment.
* Template files you can easily modify or add to as required.

> Note: Provisioning scripts are re-entrant, if something fails it can be restarted at the point at which it failed.


## Getting Started

If you are provisioning Oracle Identity Governance, you must also download the Oracle Connector Bundle for OUD and extract it to a location which is accessible by the provisioning scripts. For example, `/workdir/connectors/OID-12.2.1.3.0`. The connector directory name must start with `OID-12.2.1.`

You must download the Oracle software binaries and patches, and place them in an accessible location on the server hosts.

You must setup passwordless SSH from the deployment host, during the provisioning.

## Creating a Response File

Sample response and password files are created for you in the `responsefile` directory. You can edit these files or create your own file in the same directory using these files as templates.

Values are read from the file `idm.rsp` and passwords from the file `.idmpwds` unless the provisioning commands are started with the -r and -p options in which case the files associated with those options will be used.

> Note: 
> * The file consists of key/value pairs. There should be no spaces between the name of the key and its value. For example:
> `Key=value`
>* If you are using complex passwords, that is, passwords which contain characters such as `!`, `*`, and `$`, then these characters must be separated by a `\`. For example: 'hello!$' should be entered as `hello\!\$`. 

## Validating Your Environment

Run the `prereqchecks.sh` script, which exists in the script's home directory, to check your environment. The script is based on the response file you create. 

The script performs several checks such as (but not limited to) the following:

* Ensures that the software images are available on each node.
* Checks that the NFS file shares have been created.
* Ensures that the Load balancers are reachable.
* Ensures that firewall ports are open.

To invoke the script use the following command:

`cd <SCRIPTDIR>`

`./prereqchecks.sh [ -r responsefile -p passwordfile ]`

-r and -p are optional.

## Provisioning the Environment

There are a number of provisioning scripts located in the script directory:

| **File** | **Purpose** | 
| --- | --- | 
|provision.sh | Umbrella script that invokes each of the scripts (which can be invoked manually) mentioned in the following rows.|
|provision_ohs.sh| Installs Oracle HTTP Server and Deploys WebGate. |
|provision_oud.sh | Deploys Oracle Unified Directory. |
|provision_oudsm.sh | Deploys Oracle Unified Directory Services Manager. |
|provision_oam.sh | Deploys Oracle Access Manager. |
|provision_oig.sh | Deploys Oracle Identity Governance. |

These scripts will use a working directory defined in the response file for temporary files. 

Each of the above commands can be provided with a specific responsefile (default is idm.rsp) and passwordfile (default is .idmpwds), by appending:

-r responsefile -p passwordfile

Examples: 

`./provision.sh`

`./provision.sh -r my.rsp -p .mypwds`

These files must exist in the responsefile directory.

Note: provision_<product>.sh files can be invoked directly to install/configure a specific product.

## Log Files

The provisioning scripts create log files for each product inside the working directory in a `logs` sub-directory. This directory also contains the following two files:

* `progressfile` – This file contains the last successfully executed step. If you want to restart the process at a different step, update this file.

* `timings.log` – This file is used for informational purposes to show how much time was spent on each stage of the provisioning process.


## After Installation/Configuration
As part of running the scripts, a number of working files are created in the `WORKDIR` directory prior to copying to the host server in `/home/user/workdir`. Many of these files contain passwords required for the setup. You should archive these files after completing the deployment. 

The responsefile uses a hidden file in the responsefile directory to store passwords.

## Oracle HTTP Server Configuration Files

Each provisioning script creates sample files for configuring your Oracle HTTP server. These files are generated and stored in the working directory under the `OHS` subdirectory. If required, the scripts can also copy these configuration files to Oracle HTTP server and restart it.


## Utilities

In the `scripts` directory there is a subdirectory called `utils` . This directory contains sample utilities you may find useful. Utilities for:

* Creating self-issued load balancer certificates and certificate authority.
* Creating self-issued certificates and certificate authority for the Oracle Identity and Access Manager deployment.
* Deleting deployments.

## Reference – Response File

The following sections describe the parameters in the response file that is used to control the provisioning of the various products in the deployment. The parameters are divided into generic and product-specific parameters.

Note: This is a complete list, however password entries should appear in the passwords responsefile (.idmpwds)

### Products to Deploy
These parameters determine which products the deployment scripts attempt to deploy.

| **Parameter** | **Sample Value** | **Comments** |
| --- | --- | --- |
| **INSTALL\_OHS** | `true` | Set to `true` to Install Oracle HTTP Server. |
| **INSTALL\_OUD** | `true` | Set to `true` to configure OUD. |
| **INSTALL\_OUDSM** | `true` | Set to `true` to configure OUDSM. |
| **INSTALL\_OAM** | `true` | Set to `true` to configure OAM. |
| **INSTALL\_OIG** | `true` | Set to `true` to configure OIG. |



### Generic Parameters
These parameters are used to specify the type of deployment and the names of the temporary directories you want the deployment to use, during the provisioning process.

| **Parameter** | **Sample Value** | **Comments** |
| --- | --- | --- |
|**GEN\_SHIPHOME\_DIR** | `/shiphomes` | The location where you have downloaded the Oracle Binaries.  This location must exist on each host.|
|**GEN\_JDK\_VER** | `21.0.4` | The version of the Java JDK to use.|
|**GEN\_PATCH** | `/shiphomes/p38162798_141210_Linux-x86-64.zip` | The location of the Stack Patch Bundle you wish to apply.|
| **LOCAL\_WORKDIR** | `/workdir` | The location where you want to create the working directory.|
| **REMOTE\_WORKDIR** | `/home/oracle/workdir` | The location where you want to create the working directory on each host.|


### GENERIC LDAP Parameters
This table lists the parameters which are common to all LDAP type of deployments, they are also used in integrating OAM and OIG to LDAP.

| **Parameter** | **Sample Value** | **Comments** |
| --- | --- | --- |
|**LDAP\_HOST** | `idstore.example.com` | The name of the virtual or physical host where LDAP requests will be directed.|
|**LDAP\_PORT** | `1636` | The port to use when connecting to the LDAP directory for runtime operations.|
|**LDAP\_SSL** | `true` | Specify true if the LDAP\_PORT is an SSL enabled port.|
|**LDAP\_ADMIN\_USER** | `cn=oudadmin` | The name of the OUD administrator user.|
|**LDAP\_ADMIN\_PWD** | *`<password>`* | The password you want to use for the OUD administrator user.|
|**LDAP\_SEARCHBASE** | `dc=example,dc=com` | The OUD search base.|
|**LDAP\_GROUP\_SEARCHBASE** | `cn=Groups,dc=example,dc=com` | The search base where names of groups are stored in the LDAP directory.|
|**LDAP\_USER\_SEARCHBASE** | `cn=Users,dc=example,dc=com` | The search base where names of users are stored in the LDAP directory.|
|**LDAP\_RESERVE\_SEARCHBASE** | `cn=Reserve,dc=example,dc=com` | The search base where reservations are stored in the LDAP directory.|
|**LDAP\_SYSTEMIDS** | `cn=systemids,dc=example,dc=com` | The special directory tree inside the OUD search base to store system user names, which will not be managed through OIG.|
|**LDAP\_OAMADMIN\_USER** | `oamadmin` | The name of the user you want to create for the OAM administration tasks.|
|**LDAP\_OAMADMIN\_GRP** | `OAMAdministrators` | The name of the group you want to use for the OAM administration tasks.|
|**LDAP\_OIGADMIN\_GRP** | `OIMAdministrators` | The name of the group you want to use for the OIG administration tasks.|
|**LDAP\_WLSADMIN\_GRP** | `WLSAdministrators` | The name of the group you want to use for the WebLogic administration tasks.|
|**LDAP\_OAMLDAP\_USER** | `oamLDAP` | The name of the user you want to use to connect the OAM domain to LDAP for user validation.|
|**LDAP\_OIGLDAP\_USER** | `oimLDAP` | The name of the user you want to use to connect the OIG domain to LDAP for integration. This user will have read/write access.|
|**LDAP\_WLSADMIN\_USER** | `weblogic_iam` | The name of a user to use for logging in to the WebLogic Administration Console and Fusion Middleware Control.|
|**LDAP\_XELSYSADM\_USER** |`xelsysadm` | The name of the user to administer OIG.|
|**LDAP\_USER\_PWD** |*`<userpassword>`* | The password to be assigned to all the LDAP user accounts.|

### OUD Parameters
These parameters are specific to OUD. When deploying OUD, you also require the generic LDAP parameters.

| **Parameter** | **Sample Value** | **Comments** |
| --- | --- | --- |
|**OUD\_HOSTS** | `ldaphost1.example.com,ldaphost2.example.com` | A comma separated list of the hosts which you wish to deploy OUD on.|
|**OUD\_OWNER** | `oracle` | The operating system account which will be used to install the OUD binaries.|
|**OUD\_GROUP** | `oinstall` | The operating system group which will own the OUD binaries.|
|**OUD\_MODE** | `secure` | Specify secure when you wish OUD SSL to be the default connection, otherwise specify nonsecure.|
|**OUD\_SHIPHOME\_DIR** | `$GEN_SHIPHOME_DIR`| The location of the OUD installation software, defaults to the Generic Location specified above.|
|**OUD\_PATCHES** | `/shiphomes/OUD/p38047590_141210.zip`| Comma separated list of patches you wish to apply to the OUD shiphome.|
|**OUD\_KEYSTORE\_LOC** | `/u02/oracle/config/keystores` | The location of the certificates you wish OUD to use whilst running.|
|**OUD\_CERT\_STORE** | `/home/opc/certs/idmcerts` | The location of the certificates you wish OUD to use on the deployment host. The certificates will be copied from here to OUD\_KEYSTORE\_LOC|
|**OUD\_CERT\_TYPE** | `host or SAN` | The type of certificate you are using, either host or SAN.|
|**OUD\_CERT\_PWF** | `/u01/oracle/config/keystores/oud.pin` | The location of the password file that contains the password of your keystore.  This file will be created for you based on the responsefile.|
|**OUD\_TRUST\_STORE** | `/home/opc/certs/idmcerts/idmTrustStore.p12` | The location of the certificates trust store you wish OUD to use on the deployment host. The truststore will be copied from here to OUD\_KEYSTORE\_LOC this file must be in PKCS12 format|
|**OUD\_TRUST\_PWF** | `/u02/oracle/config/keystores/oudTrust.pin` | The location of the password file that contains the password of your truststore.  This file will be created for you based on the responsefile.|
|**OUD\_CERT\_NAME** | `idmcerts` | The alias of the certificate you wish OUD to use as appears in the keystore.|
|**OUD\_ORACLE\_HOME** | `/u02/oracle/products/dir`| The location where you wish OUD to be installed.|
|**OUD\_INST\_LOC** | `/u02/oracle/config/instances`| The location where you wish the OUD instance to be created.|
|**OUD\_ENABLE\_LDAP** | `false`| Set to true if you wish to enable the non-secure LDAP port.|
|**OUD\_ENABLE\_LDAPS** | `true`| Set to true if you wish to enable the secure LDAPS port.|
|**OUD\_ADMIN\_PORT** | `4444` | The port you wish to use for OUD administration operations.
|**OUD\_LDAP\_PORT** | `1389`| The port you wish to use for non-ssl LDAP queries.|
|**OUD\_LDAPS\_PORT** | `1636`| The port you wish to use for ssl LDAP queries.|
|**OUD\_REPLICATION\_PORT** | `8989`| The port you wish to use for replication.|
|**OUDOUDSERVER\_PCT** | `75%`| Amount of server memory to assign to the OUD instance.|

### OUDSM Parameters
List of parameters used to determine how Oracle Directory Services Manager will be deployed.

| **Parameter** | **Sample Value** | **Comments** |
| --- | --- | --- |
|**OUDSM\_HOST** | `ldaphost1` | The The host that you wish to install OUDSM on.|
|**OUDSM\_ORACLE\_HOME** | `/u02/oracle/products/oudsm`| The location where you wish OUDSM to be installed.|
|**OUDSM\_OWNER** | `oracle` | The operating system account which will be used to install the OUDSM binaries.|
|**OUDSM\_SSL\_ENABLED** | `true` | Specify true to create OHS entries which are SSL enabled. Note: This is not the OUDSM weblogic domain|
|**OUDSM\_WLSUSER** | `weblogic` | The name of the administration user you want to use for the WebLogic domain that is created when you install OUDSM.|
|**OUDSM\_PWD** | *`<password>`* | The password you want to use for **OUDSM_WLSUSER**.|
|**OUDSM\_DOMAIN\_HOME** | `/u02/oracle/config/domains/OUDSM` |  The location where the OUDSM domain is to be created.|
|**OUDSM\_SHIPHOME\_DIR** | `$GEN_SHIPHOME_DIR`| The location of the OUDSM installation software, defaults to the Generic Location specified above.|
|**OUDSM\_PORT** | `7001` | The WebLogic Port to use for the OUDSM WebLogic Domain.|
|**OUDSM\_SSL\_PORT** | `7002` | The WebLogic SSL Port to use for the OUDSM WebLogic Domain.|


### Oracle HTTP Server Parameters
These parameters are specific to OHS.  These parameters are used to construct the Oracle HTTP Server configuration files and Install the Oracle HTTP Server if requested. 

| **Parameter** | **Sample Value** | **Comments** |
| --- | --- | --- |
|**UPDATE\_OHS** |`true`| Set this to true if you wish the scripts to automatically copy the generated OHS configuration files.  Once copied the Oracle HTTP server will be restarted. `Note: This is independent of whether you are installing the Oracle HTTP server or not`|
|**DEPLOY\_WG** |`true`| Deploy WebGate in the `OHS_ORACLE_HOME`.|
|**COPY\_WG\_FILES** |`true`| Set this to true if you wish the scripts to automatically copy the generated WebGate Artefacts to your OHS Server.  Note: You must first have deployed your WebGate.|
|**OHS\_OWNER** | `oracle` | The operating system account which will be used to install the OHS binaries.|
|**OHS\_GROUP** | `oinstall` | The operating system group which will own the OHS binaries.|
|**OHS\_HOSTS** | `webhost1.ohssn.example.com,webhost2.ohssn.example.com` | A comma separated list of the hosts which you wish to deploy OHS on.|
|**OHS\_LBR\_NETWORK** |`ohssn.example.com`| The network subnet that the OHS hosts reside in.  Used to add a WebGate exclusion for health-checks.|
|**OHS\_SHIPHOME\_DIR** | `$GEN_SHIPHOME_DIR`| The location of the OHS installation software, defaults to the Generic Location specified above.|
|**OHS\_INSTALLER** |`fmw_14.1.2.0.0_ohs_linux64.bin`| The name of the OHS installer file.|
|**OHS\_ORACLE\_HOME** |`/u02/oracle/products/ohs`| The location where you wish OHS to be installed.|
|**OHS\_DOMAIN** |`/u02/oracle/config/domains/ohsDomain`| The location where you wish OHS domain to be created.|
|**OHS\_SSL\_ENABLED** | `true` | Specify true to create enable the OHS SSL Listener.|
|**OHS\_WALLETS** |`/u02/oracle/config/keystores/orapki`| The location of your OHS Wallets.  If your OHS is SSL Enabled then certificates will be converted to wallets and placed in this location.|
|**OHS\_CAS** |`/home/oracle/certs/idmcerts/idmCA.crt`| Comma separated list of certificates which will be added to your OHS Trust Store|
|**OHS\_CERT\_TYPE** |`host or SAN`| The type of certificates you will be assigning to OHS virtual hosts, if SSL Enabled.|
|**OHS\_OAM\_ADMIN\_CERT** |`/home/oracle/certs/idmcerts/iadadmin.example.com.p12`| The location of the certificate which you wish to use for the OHS iadadmin virtual host.|
|**OHS\_OAM\_LOGIN\_CERT** |`/home/oracle/certs/idmcerts/login.example.com.p12`| The location of the certificate which you wish to use for the OHS login virtual host.|
|**OHS\_OIG\_ADMIN\_CERT** |`/home/oracle/certs/idmcerts/igdadmin.example.com.p12`| The location of the certificate which you wish to use for the OHS igdadmin virtual host.|
|**OHS\_OIG\_OIM\_CERT** |`/home/oracle/certs/idmcerts/oim.example.com.p12`| The location of the certificate which you wish to use for the OHS oim virtual host.|
|**OHS\_OIG\_INT\_CERT** |`/home/oracle/certs/idmcerts/igdinternal.example.com.p12`| The location of the certificate which you wish to use for the OHS igdinternal virtual host.|
|**NM\_ADMIN\_USER** |`admin`| The name of the admin user you wish to assign to Node Manager if Installing the Oracle HTTP Server.|
|**NM\_ADMIN\_PWD** |`password`| The password of the admin user you wish to assign to Node Manager if Installing the Oracle HTTP Server.|
|**OHS\_PORT** |`7777`| The port your Oracle HTTP Servers listen on.|
|**OHS\_HTTPS\_PORT** |`4443`| The SSL port your Oracle HTTP Servers listen on.|
|**NM\_PORT** |`5556`| The port to use for Node Manager.|
|**OAM\_OHS\_ADMIN\_PORT** | `4445` | The port to assign to OHS for the OAM administration virtual host (iadadmin.example.com). |
|**OIG\_OHS\_ADMIN\_PORT** | `4446` | The port to assign to OHS for the OIG administration virtual host (igdadmin.example.com). |
|**OAM\_OHS\_LOGIN\_PORT** | `4447` | The port to assign to OHS for the OAM administration virtual host (login.example.com). |
|**OIG\_OHS\_OIM\_PORT** | `4448` | The port to assign to OHS for the OIG OIM virtual host (oim.example.com). |
|**OIG\_OHS\_INT\_PORT** | `4449` | The port to assign to OHS for the OIG Internal virtual host (igdinternal.example.com). |

### OAM Parameters
These parameters determine how OAM is deployed and configured.

| **Parameter** | **Sample Value** | **Comments** |
| --- | --- | --- |
|**OAM\_SHIPHOME\_DIR** | `$GEN_SHIPHOME_DIR`| The location of the OAM installation software, defaults to the Generic Location specified above.|
|**OAM\_KEYSTORE\_LOC** | `/u01/oracle/config/keystores` | The location of the certificates you wish OAM to use whilst running.|
|**OAM\_ORACLE\_HOME** |`/u01/oracle/products/idm`| The location where you wish OAM to be installed.|
|**OAM\_CERT\_STORE** | `/home/opc/certs/idmcerts/wlscerts.p12` | The location of the certificate keystore you wish OAM to use on the deployment host. The certificates will be copied from here to OAM\_KEYSTORE\_LOC|
|**OAM\_CERT\_TYPE** | `host or SAN` | The type of certificate you are using, either host or SAN.|
|**OAM\_TRUST\_STORE** | `/home/opc/certs/idmcerts/idmTrustStore.p12` | The location of the certificate trust store you wish OAM to use on the deployment host. The truststore will be copied from here to OAM\_KEYSTORE\_LOC this file must be in PKCS12 format.|
|**OAM\_CERT\_NAME** | `idmcerts` | The alias of the certificate you wish OAM to use as appears in the keystore.|
|**OAM\_DOMAIN\_NAME** | `oam` | The name of the OAM domain you want to create.|
|**OAM\_MSERVER\_HOME** | `/u02/oracle/config/domains/oam` | The location on local storage where OAM managed servers run from.|
|**OAM\_DOMAIN\_HOME** | `/u01/oracle/config/domains/oam` | The location on shared storage where the OAM Domain will be created.|
|**OAM\_NM\_HOME** | `/u02/oracle/config/nodemanager` | The location on local storage where the OAM nodemanager will be created.|
|**OAM\_OWNER** | `oracle` | The operating system account which will be used to install the OAM binaries.|
|**OAM\_GROUP** | `oinstall` | The operating system group which will own the OAM binaries.|
|**OAM\_MODE** | `secure or prod` | Set to secure if you wish to enable WebLogic Secure mode for the domain.|
|**OAM\_DOMAIN\_SSL\_ENABLED** | `true or false` | Set to true if you wish to enforce SSL communication between the OHS and the WebLogic Domain.  If set to false then non-ssl communication will be used.  If secure mode is enabled then this should be set to true.|
|**OAM\_WLS\_ADMIN\_USER** | `weblogic` | The OAM WebLogic administration user name.|
|**OAM\_WLS\_PWD** | *`<password>`* | The password to be used for **OAM\_WLS\_ADMIN\_USER**.|
|**OAM\_ADMIN\_HOST** | `iadadminvhn.example.com` | The virtual host name assigned to the OAM Administration Server.|
|**OAM\_HOSTS** | `oamhost1.example.com,oamhost2.example.com` | Comma separated list of physical hosts which will host OAM.|
|**OAM\_DB\_SCAN** | `dbscan.example.com` | The database scan address used by the grid infrastructure.|
|**OAM\_DB\_LISTENER** | `1521` | The database listener port.|
|**OAM\_DB\_SERVICE** | `iadedg.example.com` | The database service that connects to the database you want to use for storing the OAM schemas.|
|**OAM\_DB\_SYS\_PWD** | `MySysPassword` | The SYS password of the OAM database.|
|**OAM\_RCU\_PREFIX** | `IADEDG` | The RCU prefix to use for the OAM schemas.|
|**OAM\_SCHEMA\_PWD** | `MySchemPassword` | The password to use for the OAM schemas that get created. If you are using special characters, you may need to escape them with a '`\`'. For example: '`Password\#`'.|
|**OAM\_LOGIN\_LBR\_HOST** | `login.example.com` | The load balancer name for logging OAM runtime operations.|
|**OAM\_LOGIN\_LBR\_PORT** | `443` | The load balancer port to use for OAM Runtime operations.|
|**OAM\_LOGIN\_LBR\_PROTOCOL** | `https` | The protocol of the load balancer port to use for OAM runtime operations.|
|**OAM\_ADMIN\_LBR\_HOST** | `iadadmin.example.com` | The load balancer name to use for accessing OAM administrative functions.|
|**OAM\_ADMIN\_LBR\_PORT** | `443 or 80` | The load balancer port to use for accessing OAM administrative functions.|
|**OAM\_ADMIN\_LBR\_PROTOCOL** | `https or http` | The protocol to use for accessing OAM administrative functions.|
|**OAM\_OIG\_INTEG** | `true` | Set to `true` if OAM is integrated with OIG.|
|**OAM\_ADMIN\_PORT** | `7001` | The port to assign to the OAM Administration server for non-ssl communication.|
|**OAM\_ADMIN\_SSL\_PORT** | `7002` | The port to assign to the OAM Administration server for ssl communication.|
|**OAM\_ADMIN\_ADMIN\_PORT** | `9002` | The port to assign to the OAM Administration server for administration communication.  This is used when **OAM\_MODE** is set to secure.|
|**OAM\_OAM\_PORT** | `14100` | The port to assign to the OAM managed server for non-ssl communication.|
|**OAM\_OAM\_SSL\_PORT** | `14101` | The port to assign to the OAM managed server for ssl communication.|
|**OAM\_OAM\_ADMIN\_PORT** | `9508` | The port to assign to the OAM managed server for administration communication.  This is used when **OAM\_MODE** is set to secure.|
|**OAM\_POLICY\_PORT** | `14150` | The port to assign to the OAM policy managed server for non-ssl communication.|
|**OAM\_POLICY\_SSL\_PORT** | `14151` | The port to assign to the OAM policy managed server for ssl communication.|
|**OAM\_POLICY\_ADMIN\_PORT** | `9509` | The port to assign to the OAM policy managed server for administration communication.  This is used when **OAM\_MODE** is set to secure.|

### OIG Parameters
These parameters determine how OIG is provisioned and configured.

| **Parameter** | **Sample Value** | **Comments** |
| --- | --- | --- |
|**OIG\_SHIPHOME\_DIR** | `$GEN_SHIPHOME_DIR`| The location of the OIG installation software, defaults to the Generic Location specified above.|
|**CONNECTOR\_DIR** | `/shiphomes/connectors/` | The location on the file system where you have downloaded and extracted the OIG connector bundle.|
|**CONNECTOR\_VER** | `OID-12.2.1.3.0` | The version of the connector to install.|
|**OIG\_KEYSTORE\_LOC** | `/u01/oracle/config/keystores` | The location of the certificates you wish OIG to use whilst running.|
|**OIG\_ORACLE\_HOME** |`/u01/oracle/products/idm`| The location where you wish OIG to be installed.|
|**OIG\_CERT\_STORE** | `/home/opc/certs/idmcerts/wlscerts.p12` | The location of the certificate keystore you wish OIG to use on the deployment host. The certificates will be copied from here to OIG\_KEYSTORE\_LOC|
|**OIG\_CERT\_TYPE** | `host or SAN` | The type of certificate you are using, either host or SAN.|
|**OIG\_TRUST\_STORE** | `/home/opc/certs/idmcerts/idmTrustStore.p12` | The location of the certificate trust store you wish OIG to use on the deployment host. The truststore will be copied from here to OIG\_KEYSTORE\_LOC this file must be in PKCS12 format.|
|**OIG\_CERT\_NAME** | `idmcerts` | The alias of the certificate you wish OIG to use as appears in the keystore.|
|**OIG\_DOMAIN\_NAME** | `oig` | The name of the OIG domain you want to create.|
|**OIG\_MSERVER\_HOME** | `/u02/oracle/config/domains/oig` | The location on local storage where OIG managed servers run from.|
|**OIG\_DOMAIN\_HOME** | `/u01/oracle/config/domains/oig` | The location on shared storage where the OIG Domain will be created.|
|**OIG\_NM\_HOME** | `/u02/oracle/config/nodemanager` | The location on local storage where the OIG nodemanager will be created.|
|**OIG\_OWNER** | `oracle` | The operating system account which will be used to install the OIG binaries.|
|**OIG\_GROUP** | `oinstall` | The operating system group which will own the OIG binaries.|
|**OIG\_MODE** | `secure or prod` | Set to secure if you wish to enable WebLogic Secure mode for the domain.|
|**OIG\_DOMAIN\_SSL\_ENABLED** | `true or false` | Set to true if you wish to enforce SSL communication between the OHS and the WebLogic Domain.  If set to false then non-ssl communication will be used.  If secure mode is enabled then this should be set to true.|
|**OIG\_WLS\_ADMIN\_USER** | `weblogic` | The OAM WebLogic administration user name.|
|**OIG\_WLS\_PWD** | *`<password>`* | The password to be used for **OIG\_WLS\_ADMIN\_USER**.|
|**OIG\_ADMIN\_HOST** | `igdadminvhn.example.com` | The virtual host name assigned to the OIG Administration Server.|
|**OIG\_HOSTS** | `oighost1.example.com,oighost2.example.com` | Comma separated list of physical hosts which will host OIG.|
|**OIG\_DB\_SCAN** | `dbscan.example.com` | The database scan address used by the grid infrastructure.|
|**OIG\_DB\_LISTENER** | `1521` | The database listener port.|
|**OIG\_DB\_SERVICE** | `igdedg.example.com` | The database service which connects to the database you want to use for storing the OIG schemas.|
|**OIG\_DB\_SYS\_PWD** | `MySysPassword` | The SYS password of the OIG database.|
|**OIG\_RCU\_PREFIX** | `IGDEDG` | The RCU prefix to use for OIG schemas.|
|**OIG\_SCHEMA\_PWD** | `MySchemPassword` | The password to use for the OIG schemas that get created. If you are using special characters, you may need to escape them with a '`\`'. For example: '`Password\#`'.|
|**OIG\_ADMIN\_LBR\_HOST** | `igdadmin.example.com` | The load balancer name to use for accessing OIG administrative functions.|
|**OIG\_ADMIN\_LBR\_PORT** | `443 or 80` | The load balancer port you use for accessing the OIG administrative functions.|
|**OIG\_ADMIN\_LBR\_PROTOCOL** | `https or http` | The load balancer protocol to use for accessing the OIG administrative functions.|
|**OIG\_LBR\_HOST** | `oim.example.com` | The load balancer name to use for accessing the OIG Identity Console.|
|**OIG\_LBR\_PORT** | `443` | The load balancer port to use for accessing the OIG Identity Console.|
|**OIG\_LBR\_PROTOCOL** | `https` | The load balancer protocol to use for accessing the OIG Identity Console.|
|**OIG\_LBR\_INT\_HOST** | `igdinternal.example.com` | The load balancer name you will use for accessing OIG internal callbacks.|
|**OIG\_LBR\_INT\_PORT** | `7777` | The load balancer port to use for accessing the OIG internal callbacks.|
|**OIG\_LBR\_INT\_PROTOCOL** | `http` | The load balancer protocol to use for accessing OIG Internal callbacks.|
|**OIG\_EMAIL\_CREATE** | `true` | If set to `true`, OIG will be configured for email notifications.|
|**OIG\_EMAIL\_SERVER** | `sendmail.example.com` | The name of your SMTP email server.|
|**OIG\_EMAIL\_PORT** | `25` | The port of your SMTP server. The valid values are `None` or `TLS`.|
|**OIG\_EMAIL\_SECURITY** | `None` | The security mode of your SMTP server.|
|**OIG\_EMAIL\_ADDRESS** | `myemail.example.com` | The user name that is used to connect to the SMTP server, if one is required.|
|**OIG\_EMAIL\_PWD** | *`<password>`* | The password of your SMTP server.|
|**OIG\_EMAIL\_FROM\_ADDRESS** | `from@example.com` | The '`From`' email address used when emails are sent.|
|**OIG\_EMAIL\_REPLY\_ADDRESS** | `noreplies@example.com` | The '`Reply`' to email address of the emails that are sent.|
|**OIG\_BI\_INTEG** | `true` | Set to `true` to configure BIP integration.|
|**OIG\_BI\_HOST** | `bi.example.com` | The load balancer name you will use for accessing BI Publisher.|
|**OIG\_BI\_PORT** | `443` | The load balancer port you will use for accessing BI Publisher.|
|**OIG\_BI\_PROTOCOL** | `https` | The load balancer protocol you will use for accessing BI Publisher.|
|**OIG\_BI\_USER** | `idm_report` | The BI user name you want to use for running reports in the BI Publisher deployment.|
|**OIG\_BI\_USER\_PWD** | `BIPassword` | The password of the **OIG_BI_USER**.|
|**OIG\_ADMIN\_PORT** | `7001` | The port to assign to the OIG Administration server for non-ssl communication.|
|**OIG\_ADMIN\_SSL\_PORT** | `7002` | The port to assign to the OIG Administration server for ssl communication.|
|**OIG\_ADMIN\_ADMIN\_PORT** | `9002` | The port to assign to the OIG Administration server for administration communication.  This is used when **OAM\_MODE** is set to secure.|
|**OIG\_SOA\_PORT** | `7003` | The port to assign to the SOA managed server for non-ssl communication.|
|**OIG\_SOA\_SSL\_PORT** | `7004` | The port to assign to the SOA managed server for ssl communication.|
|**OIG\_SOA\_ADMIN\_PORT** | `9004` | The port to assign to the SOA managed server for administration communication.  This is used when **OAM\_MODE** is set to secure.|
|**OIG\_OIM\_PORT** | `14000` | The port to assign to the OIM managed server for non-ssl communication.|
|**OIG\_OIM\_SSL\_PORT** | `14001` | The port to assign to the OIM managed server for ssl communication.|
|**OIG\_OIM\_ADMIN\_PORT** | `9010` | The port to assign to the OIM managed server for administration communication.  This is used when **OAM\_MODE** is set to secure.|


## Components of the Deployment Scripts

For reference purposes this section includes the name and function of the key objects making up the deployment scripts.

| **Name** | **Location** | **Function** |
| --- | --- | --- |
| **idm.rsp** | responsefile | Contains details of passwords used in the target environment. Needs to be updated for each deployment. |
| **.idmpwds** | responsefile | Contains details of the target environment. Needs to be updated for each deployment. |
| **prereqchecks.sh** | | Checks the environment prior to provisioning. |
| **provision.sh** | | Provisions everything. |
| **provision\_oud.sh** | | Installs/configures OUD. |
| **provision\_oudsm.sh** | | Installs/configures OUDSM. |
| **provision\_oam.sh** | | Installs/configures OAM. |
| **provision\_oig.sh** | | Installs/configures OIG. |
| **create\_idm\_certs.sh** | utils | Creates self-issued certificates and Certificate Authority for use in an Identity and Access Management Deployment. |
| **create\_lbr\_certs.sh** | utils | Creates self-issued certificates and Certificate Authority for use by a load balancer fronting an Identity and Access Management Deployment. |
| **delete\_all.sh** | utils | Deletes all deployments. |
| **delete\_oam.sh** | utils | Deletes the OAM deployment. |
| **delete\_oig.sh** | utils | Deletes the OIG deployment. |
| **delete\_oud.sh** | utils | Deletes the OUD deployment. |
| **delete\_oudsm.sh** | utils | Deletes the OUDSM deployment. |

