# maa samples

<!-- Describe your project's features, functionality and target audience -->

Oracle’s Maximum Availability Architecture (Oracle MAA) is the best practices blueprint for data protection and availability of Oracle products (Database, Fusion Middleware, Applications) deployed on on-premises, private, public or hybrid clouds. Implementing Oracle Maximum Availability Architecture best practices is one of the key requirements for any Oracle deployment. Oracle Fusion Middleware and Oracle Databases include an extensive set of high availability features which can protect application deployments from unplanned downtime and minimize planned downtime. These features include: process death detection and restart, clustering, server migration, clusterware integration, GridLink datasources, load balancing, failover, backup and recovery, rolling upgrades, and rolling configuration changes.

The maa samples repository contains a set of downloadable and installable demonstrations for creating different High Availability and Disaster Protection solutions for Oracle products. Each sample can be installed independently of any of the other demonstrations and may address different tiers and components of the Oracle stack. Most examples are intended to be used in Oracle Cloud Infrastructure (OCI) but may apply also to on-prem systems. Each demonstration has it's own folder within the maa repository. 

## Installation

<!-- Provide detailed step-by-step installation instructions -->
Refer to each demonstration for the detailed steps to set up the MAA/DR topologies

## Documentation

<!-- Developer-oriented documentation can be published on GitHub, but all product
     documentation must be published on <https://docs.oracle.com>. -->
For details on MAA Best practices, pelase refer to https://www.oracle.com/database/technologies/maximum-availability-architecture/

## Examples

<!-- Describe any included examples or provide a link to a demo/tutorial -->
This repository stores a variety of examples demonstrating how to configure MAA/DR for different Oracle products. 

| Repo/Folder name  | Description |
| ------------- | ------------- |
| [Oracle Data Guard](./dg_setup_scripts) | Scripts that can be used to set up Oracle Data Guard for an existing Oracle Database (on-prem to on-prem, OCI to OCI and on-prem to OCI). |
| [FMW Hybrid Disaster Recovery ](./hybrid_dr) | Scripts that can be used to set up and maintain a Disaster Protection system involving an on-prem topology as primary and a standby system running on Oracle's CLoud (OCI).|
| [Weblogic for OCI DR](./wls_mp_dr) |  Scripts that can be used to set up and maintain a Disaster Protection system for an Oracle Weblogic for OCI deployment. |
| [Oracle SOA Marketplace DR](./drs_mp_soa) | scripts that can be used to set up and maintain a Disaster Protection system for an Oracle SOA Marketplace Deployemnt. |
| [Private DNS views for DR](./private_dns_views_for_dr) | Terraform scripts to create private DNS views in primary and standby OCI VCNs. This is used in Disaster Recovery environments. These private DNS views contain the other site's host names, but resolved with local IPs.  |
| [dns_and_frontend_utilities](./dns_and_frontend_utilities) | Examples scripts for actions related with the frontend name and DNS in Disaster Recovery environments  |


## Contributing

<!-- If your project has specific contribution requirements, update the
    CONTRIBUTING.md file to ensure those requirements are clearly explained. -->

This project welcomes contributions from the community. Before submitting a pull
request, please [review our contribution guide](./CONTRIBUTING.md).

## Security

Please consult the [security guide](./SECURITY.md) for our responsible security
vulnerability disclosure process.

## License

<!-- The correct copyright notice format for both documentation and software
    is "Copyright (c) [year,] year Oracle and/or its affiliates."
    You must include the year the content was first released (on any platform) and
    the most recent year in which it was revised. -->

Copyright (c) 2022 Oracle and/or its affiliates.

<!-- Replace this statement if your project is not licensed under the UPL -->

Released under the Universal Permissive License v1.0 as shown at
<https://oss.oracle.com/licenses/upl/>.

Refer to each precise example licensing implications.
