# MAA samples

Oracle’s Maximum Availability Architecture (Oracle MAA) is the best practices blueprint for data protection and availability of Oracle products (Database, Fusion Middleware, Applications) deployed on on-premises, private, public or hybrid clouds. Implementing Oracle Maximum Availability Architecture best practices is one of the key requirements for any Oracle deployment. Oracle Fusion Middleware and Oracle Databases include an extensive set of high availability features which can protect application deployments from unplanned downtime and minimize planned downtime. These features include: process death detection and restart, clustering, server migration, clusterware integration, GridLink datasources, load balancing, failover, backup and recovery, rolling upgrades, and rolling configuration changes.

The maa samples repository contains a set of downloadable and installable demonstrations for creating different High Availability and Disaster Protection solutions for Oracle products. Each sample can be installed independently of any of the other demonstrations and may address different tiers and components of the Oracle stack. Most examples are intended to be used in Oracle Cloud Infrastructure (OCI) but may apply also to on-prem systems. Each demonstration has it's own folder within the maa repository. 

## Installation

Refer to each demonstration for the detailed steps to set up the MAA/DR topologies

## Documentation

For details on MAA Best practices, pelase refer to https://www.oracle.com/database/technologies/maximum-availability-architecture/

## Examples

This repository stores a variety of examples demonstrating how to configure MAA/DR for different Oracle products. 

| Repo/Folder name  | Description |
| ------------- | ------------- |
| [1412EDG](./1412EDG) | **(New)** Scripts referenced from the 14.1.2 Enterprise Deployment Guide. 
| [WLS HYDR Framework](./wls-hydr) | **(New)** Hybrid Disaster Recovery framework for WLS/FMW domains. 
| [FMW Schemas Export Import Scripts](./fmw_schemas_exp_imp) | **(New)** Scripts to export and import the FMW database schemas using Data Pump.
| [App DR common scripts](./app_dr_common) | Common scripts referenced by different Disaster Recovery documents. 
| [Oracle Data Guard](./dg_setup_scripts) | Scripts to set up Oracle Data Guard for an existing Oracle Database (on-prem to on-prem, OCI to OCI and on-prem to OCI). |
| [FMW Manual Hybrid Disaster Recovery ](./manual_hybrid_dr) | *(Legacy)* Scripts for the manual setup and maintenance of a Hybrid Disaster Protection system (primary on-prem and standby on Oracle's Cloud OCI).|
| [Weblogic for OCI DR](./wls_mp_dr) |  Scripts to set up and maintain a Disaster Protection system for an Oracle Weblogic for OCI deployment. |
| [Oracle SOA Marketplace DR](./drs_mp_soa) | scripts to set up and maintain a Disaster Protection system for an Oracle SOA Marketplace Deployemnt. |
| [Private DNS views for DR](./private_dns_views_for_dr) | Terraform scripts to create private DNS views in primary and standby OCI VCNs. This is used in Disaster Recovery environments. These private DNS views contain the other site's host names, but resolved with local IPs.  |
| [DNS and Frontend Utilities](./dns_and_frontend_utilities) | Scripts for actions related with the frontend name and DNS in Disaster Recovery environments  |
| [FMW-WLS Autonomous Database Shared DR](./fmw-wls-with-adb-dr) | Scripts and utilities to manage/obtain information from ADB systems and set up FMW DR with ADBS. |
| [Kubernetes DR and MAA](./kubernetes-maa) | Scripts and utilities for High Availbility and Disaster Protection of Kubernetes clusters. |


## Contributing

This project welcomes contributions from the community. Before submitting a pull
request, please [review our contribution guide](./CONTRIBUTING.md).

## Security

Please consult the [security guide](./SECURITY.md) for our responsible security
vulnerability disclosure process.

## License

Copyright (c) 2022, 2023 Oracle and/or its affiliates.

Released under the Universal Permissive License v1.0 as shown at
<https://oss.oracle.com/licenses/upl/>.

Refer to each precise example licensing implications.
