FMW/WLS MAA Verificaooin Utility 
Copyright (c) 2026 Oracle and/or its affiliates  
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/  

# Fusion Middleware/WebLogic domain Maximum Availability Architecture Best Practices Verification framework
This framework provides a YAML-driven compliance/health checker for Oracle WebLogic / Fusion Middleware  domain configurations.
It generates a single HTML report per domain directory by inspecting: 

    config/config.xml (domain/cluster/server configuration)
    nodemanager/nodemanager.properties
    nodemanager/nodemanager.domains
    config/jdbc/*-jdbc.xml (JDBC datasources)
     

All checks and recommendations are defined in a YAML file (maa_checks.yml) so you can add/modify checks without changing Python code. 

| Script name  | Description |
| ------------- | ------------- |
| [wls_yaml_report.py](./wls_yaml_report.py) | This is the script generating the report per se.  |
| [maa_checks.yaml](./maa_checks.yaml) | This yamls file contains the MAA aspects being verified, the criteria for PASS/FAIL/WARN and a recommendation for the implementation (in many cases including link to documentation for reference. |

# What the script produces 

For each domain you run it against, the tool outputs an HTML report containing: 

    A header with:
        domain directory path
        config.xml path
        checks YAML path
        generation timestamp (UTC)
         
    One section per YAML sections[] entry (e.g., “config.xml”, “Node Manager”, “JDBC”)
    A table of results per section with:
        Check description
        Status (PASS, FAIL, WARN, NA)
        Evidence (what was observed)
        Recommendation (shown when status is FAIL/WARN)
         
     

Status meanings: 

    PASS: check condition satisfied
    FAIL: check condition not satisfied; recommendation included
    WARN: check flagged as warning; recommendation included
    NA: cannot evaluate (file missing, pattern matched nothing, unsupported condition, etc.)
     

# Requirements

    Python 3.9+ recommended
    PyYAML
     

Install PyYAML:
    python3 -m pip install pyyaml 

# Domain directory structure expected 

The script expects --domain-dir to point to a directory with the following structure: 
DOMAIN_DIR/
  config/
    config.xml
    jdbc/
      *-jdbc.xml
  nodemanager/
    nodemanager.properties
    nodemanager.domains

# How to run (single domain) 
python3 wls_yaml_report.py \
  --domain-dir /path/to/DOMAIN_DIR \
  --checks-yaml /path/to/maa_checks.yml \
  --out /path/to/report.html

Example:
    python3 wls_yaml_report.py 
      --domain-dir /stagingforMAAChecks/WLSConfig/SAMPLE_Domain 
      --checks-yaml /stagingforMAAChecks/maa_checks.yml 
      --out report_SAMPLE_Domain.html 

Open the report in a browser (copy it locally first if required). 

# Batch run (multiple domains under a base directory) 

If you have multiple domain directories under a base path such as: 

    /stagingforMAAChecks/WLSConfig/
     

Create a shell script like the following (example scripts/generate_all_reports.sh): 
#!/usr/bin/env bash
set -euo pipefail

BASE="/stagingforMAAChecks/WLSConfig"
CHECKS="/stagingforMAAChecks/maa_checks.yml"
PY="/stagingforMAAChecks/wls_yaml_report.py"
OUTDIR="/stagingforMAAChecks/reports"

mkdir -p "$OUTDIR"

for d in "$BASE"/*; do
  [[ -d "$d" ]] || continue
  [[ -f "$d/config/config.xml" ]] || { echo "SKIP (no config.xml): $d"; continue; }

  dn="$(basename "$d")"
  out="$OUTDIR/report_${dn}.html"

  echo "Generating $out"
  python3 "$PY" --domain-dir "$d" --checks-yaml "$CHECKS" --out "$out"
done

echo "Done. Reports in: $OUTDIR"

# Adding or modifying checks (YAML) 

All checks live in maa_checks.yml. 

High-level YAML structure: 
version: 1
sections:
  - name: "config.xml"
    checks:
      - id: prod_mode
        type: xml
        file: "config/config.xml"
        description: "Domain is in Production Mode"
        selector: "production-mode-enabled"
        operator: equals
        expected: "true"
        on_fail: FAIL
        recommendation: "Enable Production Mode ..."

Common fields: 

    id: unique identifier (for maintainability)
    type: check type (see supported types below)
    file: relative path or glob (e.g., config/jdbc/*-jdbc.xml)
    description: displayed in the report
    operator: comparison operator
    expected: expected value used by the operator (string or integer)
    on_fail: FAIL or WARN
    recommendation: shown only when status is FAIL/WARN
     

Supported check types 
1) type: xml 

Evaluates a single selector against the first matched file. 

Example:
    - id: prod_mode
      type: xml
      file: "config/config.xml"
      description: "Domain is in Production Mode"
      selector: "production-mode-enabled"
      operator: equals
      expected: "true"
      on_fail: FAIL
      recommendation: "Enable Production Mode ..." 
2) type: xml_each 

Evaluates per XML context element, producing one result row per element. 

Key fields: 

    context: element name (e.g., cluster, server)
    require_children: list of required child tags (e.g., ["name"] to avoid server membership refs)
    value: tag name or dotpath relative to the context element (e.g., cluster-messaging-mode or transaction-log-jdbc-store.enabled)
     

Example (cluster unicast):
    - id: cluster_unicast
      type: xml_each
      file: "config/config.xml"
      description: "Cluster uses unicast"
      context: "cluster"
      require_children: ["name"]
      value: "cluster-messaging-mode"
      operator: equals
      expected: "unicast"
      on_fail: FAIL
      recommendation: "Configure cluster messaging to unicast ..." 

Example (warn if migration-basis not database):
    - id: cluster_db_leasing_warn
      type: xml_each
      file: "config/config.xml"
      description: "WARN if cluster is not using database leasing"
      context: "cluster"
      require_children: ["name"]
      value: "migration-basis"
      operator: equals
      expected: "database"
      on_fail: WARN
      recommendation: "If leasing is required, set <migration-basis>database</migration-basis>." 
3) type: xml_each_file 

Evaluates the same selector once per matched XML file (commonly for JDBC). 

Example (test-table-name must be SQL ISVALID):
    - id: jdbc_test_table_isvalid
      type: xml_each_file
      file: "config/jdbc/*-jdbc.xml"
      description: "Test Table Name is SQL ISVALID"
      selector: "jdbc-connection-pool-params.test-table-name"
      operator: equals_ci_ws
      expected: "SQL ISVALID"
      on_fail: FAIL
      recommendation: "Set <test-table-name>SQL ISVALID</test-table-name> ..." 
4) type: properties 

Reads a .properties file and compares a key. 

Example:
    - id: nm_listen_any
      type: properties
      file: "nodemanager/nodemanager.properties"
      description: "Node Manager ListenAddress is blank (ANY interface)"
      key: "ListenAddress"
      operator: equals
      expected: ""
      on_fail: FAIL
      recommendation: "Set ListenAddress= (blank) if your standard requires NM listening on all interfaces." 
5) type: nodemanager_domains 

Evaluates nodemanager.domains entry for the current domain name (domain name is read from config/config.xml). 

Example (requires at least 2 paths separated by “;”):
    - id: nm_domains_two_paths
      type: nodemanager_domains
      file: "nodemanager/nodemanager.domains"
      description: "nodemanager.domains lists two paths for the domain"
      operator: min_paths
      expected: 2
      on_fail: FAIL
      recommendation: "List two domain paths separated by ';' if AdminServer and Managed Servers use separate domain directories." 

Supported operators 

    exists: selector/key exists and has at least one match
    not_empty: match exists and text is not empty
    equals: exact string match
    equals_ci_ws: case-insensitive, whitespace-normalized string match (useful for SQL strings)
    regex: Python regex match
    int_eq, int_gt, int_ge, int_lt, int_le: integer comparisons
     

# Examples of adding new checks 
Enforce seconds-to-trust-an-idle-pool-connection = 0 for all JDBC datasources 
- id: jdbc_trust_idle_zero
  type: xml_each_file
  file: "config/jdbc/*-jdbc.xml"
  description: "Seconds to trust idle connections is zero"
  selector: "jdbc-connection-pool-params.seconds-to-trust-an-idle-pool-connection"
  operator: equals
  expected: "0"
  on_fail: FAIL
  recommendation: "Set seconds-to-trust-an-idle-pool-connection to 0 to avoid trusting stale idle connections."

# Troubleshooting 
* Unnamed clusters or unexpected cluster counts 

For cluster checks, ensure you use: 

    context: cluster
    require_children: ["name"]
     

This avoids counting membership references like: 

    <server><cluster>ClusterName</cluster></server>
     

* Report PASS/FAIL mismatch vs file 

Confirm you opened the correct output file and verify the report header’s: 

    Domain dir
    config.xml path
    checks yaml path
     

Missing PyYAML 
python3 -m pip install pyyaml

# Security / handling notes 

Reports may include hostnames, service names, and configuration details. Treat outputs as internal operational artifacts and handle per your organization’s security and compliance policies. 