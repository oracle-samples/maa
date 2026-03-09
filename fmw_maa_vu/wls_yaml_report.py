#!/usr/bin/env python3
"""
wls_yaml_report.py script version 1.0.

Copyright (c) 2026 Oracle and/or its affiliates
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/


Generates an HTML report for MAA bets practices in a FMW/WebLogic "domain directory" using YAML-driven checks.

Expected domain directory layout:
  DOMAIN_DIR/
    config/config.xml
    config/jdbc/*.xml
    nodemanager/nodemanager.properties
    nodemanager/nodemanager.domains

Usage:
  python3 wls_yaml_report.py \
    --domain-dir /path/to/DOMAIN_DIR \
    --checks-yaml /path/to/maa_checks.yml \
    --out /path/to/report.html

Dependency:
  pip3 install pyyaml
"""

import argparse
import glob
import html
import os
import re
from datetime import datetime
import xml.etree.ElementTree as ET

try:
    import yaml
except ImportError:
    raise SystemExit("Missing dependency: PyYAML. Install with: pip3 install pyyaml")


# ----------------------------
# Common structures
# ----------------------------
class CheckResult:
    def __init__(self, check, status, evidence="", recommendation=""):
        self.check = check
        self.status = status  # PASS / FAIL / WARN / NA
        self.evidence = evidence
        self.recommendation = recommendation


# ----------------------------
# XML helpers (namespace-agnostic)
# ----------------------------
def localname(tag: str) -> str:
    return tag.split("}", 1)[-1] if "}" in tag else tag

def text_of(el, default=None):
    if el is None or el.text is None:
        return default
    return el.text.strip()

def children_by_localname(el, name):
    for c in list(el):
        if localname(c.tag) == name:
            yield c

def first_child(el, name):
    return next(children_by_localname(el, name), None)

def find_all_by_dotpath(root, dotpath: str):
    """
    Dotpath is local tag names separated by '.'.
    Example: "jdbc-connection-pool-params.test-table-name"
    """
    parts = dotpath.split(".")
    cur = [root]
    for p in parts:
        nxt = []
        for el in cur:
            nxt.extend(list(children_by_localname(el, p)))
        cur = nxt
    return cur


# ----------------------------
# Operators
# ----------------------------
def norm_ci_ws(s: str) -> str:
    return re.sub(r"\s+", " ", (s or "").strip()).upper()

def eval_operator(values, operator, expected):
    """
    values: list[str]
    expected: scalar
    """
    if operator == "exists":
        return len(values) > 0

    if operator == "not_empty":
        return len(values) > 0 and all((v or "").strip() != "" for v in values)

    if operator == "equals":
        exp = str(expected)
        return len(values) > 0 and all((v or "") == exp for v in values)

    if operator == "equals_ci_ws":
        exp = norm_ci_ws(str(expected))
        return len(values) > 0 and all(norm_ci_ws(v) == exp for v in values)

    if operator == "regex":
        rx = re.compile(str(expected))
        return len(values) > 0 and all(rx.search(v or "") for v in values)

    # numeric operators (optional)
    if operator in ("int_eq", "int_ge", "int_gt", "int_le", "int_lt"):
        exp = int(expected)
        if not values:
            return False
        for v in values:
            try:
                iv = int((v or "").strip())
            except ValueError:
                return False
            if operator == "int_eq" and not (iv == exp): return False
            if operator == "int_ge" and not (iv >= exp): return False
            if operator == "int_gt" and not (iv >  exp): return False
            if operator == "int_le" and not (iv <= exp): return False
            if operator == "int_lt" and not (iv <  exp): return False
        return True

    raise ValueError(f"Unsupported operator: {operator}")


# ----------------------------
# File expansion and parsing
# ----------------------------
def expand_files(domain_dir, pattern):
    return sorted(glob.glob(os.path.join(domain_dir, pattern)))

def parse_kv_properties(path):
    """
    Minimal .properties parser: key=value lines, ignores comments and blanks.
    """
    props = {}
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            s = line.strip()
            if not s or s.startswith("#"):
                continue
            if "=" in s:
                k, v = s.split("=", 1)
                props[k.strip()] = v.strip()
    return props

def parse_nodemanager_domains(path):
    """
    nodemanager.domains:
      domainName=/path1;/path2
    """
    mapping = {}
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            s = line.strip()
            if not s or s.startswith("#"):
                continue
            if "=" in s:
                k, v = s.split("=", 1)
                mapping[k.strip()] = v.strip()
    return mapping


# ----------------------------
# Domain name from config.xml
# ----------------------------
def parse_domain_name(domain_dir):
    config_xml = os.path.join(domain_dir, "config", "config.xml")
    root = ET.parse(config_xml).getroot()
    domain_name = text_of(first_child(root, "name"), "UNKNOWN_DOMAIN")
    return config_xml, root, domain_name


# ----------------------------
# YAML loading
# ----------------------------
def load_checks_yaml(path):
    with open(path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


# ----------------------------
# Check evaluation engine
# ----------------------------
def check_result(desc, status, evidence="", recommendation=""):
    return CheckResult(desc, status, evidence=evidence, recommendation=recommendation)

def eval_one_check(domain_dir, domain_name, check):
    """
    Returns list[CheckResult]. Some check types are "per item", producing multiple rows.
    """
    ctype = check["type"]
    desc = check.get("description", check.get("id", "unnamed-check"))
    recommendation = check.get("recommendation", "")
    on_fail = check.get("on_fail", "FAIL")  # FAIL or WARN, typically
    operator = check.get("operator", "exists")
    expected = check.get("expected", "")

    files = expand_files(domain_dir, check["file"])
    if not files:
        return [check_result(desc, "NA", evidence=f"No files matched: {check['file']}")]

    def pass_or_fail(ok, evidence):
        status = "PASS" if ok else on_fail
        rec = "" if status in ("PASS", "NA") else recommendation
        return check_result(desc, status, evidence=evidence, recommendation=rec)

    # ---- properties file checks ----
    if ctype == "properties":
        path = files[0]
        key = check["key"]
        try:
            props = parse_kv_properties(path)
        except Exception as e:
            return [check_result(desc, "FAIL", evidence=f"Failed reading properties: {e}", recommendation=recommendation)]
        actual = props.get(key, None)

        if operator != "equals":
            return [check_result(desc, "NA", evidence=f"Unsupported properties operator: {operator}")]
        ok = (actual == str(expected))
        evidence = f"{os.path.basename(path)}: {key}='{actual}' expected '{expected}'"
        return [pass_or_fail(ok, evidence)]

    # ---- nodemanager.domains check keyed by domain_name ----
    if ctype == "nodemanager_domains":
        path = files[0]
        try:
            mapping = parse_nodemanager_domains(path)
        except Exception as e:
            return [check_result(desc, "FAIL", evidence=f"Failed reading nodemanager.domains: {e}", recommendation=recommendation)]

        entry = mapping.get(domain_name)
        if not entry:
            return [check_result(desc, on_fail, evidence=f"No entry for domain '{domain_name}'", recommendation=recommendation)]

        paths = [p.strip() for p in entry.split(";") if p.strip()]

        if operator == "min_paths":
            needed = int(expected)
            ok = len(paths) >= needed
            evidence = f"{os.path.basename(path)}: domain='{domain_name}' paths={len(paths)} entry='{entry}'"
            return [pass_or_fail(ok, evidence)]

        return [check_result(desc, "NA", evidence=f"Unsupported nodemanager_domains operator: {operator}")]

    # ---- xml check against one XML file (single selector) ----
    if ctype == "xml":
        path = files[0]
        try:
            root = ET.parse(path).getroot()
        except Exception as e:
            return [check_result(desc, "FAIL", evidence=f"XML parse error: {e}", recommendation=recommendation)]

        selector = check["selector"]
        matches = find_all_by_dotpath(root, selector)
        values = [text_of(m, "") for m in matches]

        ok = eval_operator(values, operator, expected)
        ev = f"{os.path.basename(path)} selector='{selector}' matches={len(values)} value='{values[0] if values else ''}' expected='{expected}'"
        return [pass_or_fail(ok, ev)]

    # ---- xml_each_file: run selector once per matched file (e.g., config/jdbc/*-jdbc.xml) ----
    if ctype == "xml_each_file":
        selector = check["selector"]
        out = []
        for path in files:
            try:
                root = ET.parse(path).getroot()
            except Exception as e:
                out.append(check_result(f"{desc} ({os.path.basename(path)})", "FAIL", evidence=f"XML parse error: {e}", recommendation=recommendation))
                continue

            matches = find_all_by_dotpath(root, selector)
            values = [text_of(m, "") for m in matches]
            ok = eval_operator(values, operator, expected)
            status = "PASS" if ok else on_fail
            rec = "" if status in ("PASS", "NA") else recommendation
            ev = f"{os.path.basename(path)} selector='{selector}' matches={len(values)} value='{values[0] if values else ''}' expected='{expected}'"
            out.append(CheckResult(f"{desc} ({os.path.basename(path)})", status, evidence=ev, recommendation=rec))
        return out if out else [check_result(desc, "NA", evidence=f"No files matched: {check['file']}")]

    # ---- xml_each: iterate context elements inside one XML file (e.g., each cluster, each server) ----
    if ctype == "xml_each":
        path = files[0]
        try:
            root = ET.parse(path).getroot()
        except Exception as e:
            return [check_result(desc, "FAIL", evidence=f"XML parse error: {e}", recommendation=recommendation)]

        context = check["context"]  # e.g. "cluster", "server"
        require_children = check.get("require_children", [])  # e.g. ["name"] to avoid membership refs
        value = check["value"]  # tag or dotpath relative to context element

        out = []
        for ctx in root.iter():
            if localname(ctx.tag) != context:
                continue

            # require certain children exist (avoid <server><cluster>NAME</cluster> and other non-def blocks)
            ok_req = True
            for rc in require_children:
                if first_child(ctx, rc) is None:
                    ok_req = False
                    break
            if not ok_req:
                continue

            ctx_name = text_of(first_child(ctx, "name"), "<unnamed>")
            # allow dotpath relative to ctx (e.g. "dynamic-servers.maximum-dynamic-server-count")
            if "." in value:
                matches = find_all_by_dotpath(ctx, value)
                values = [text_of(m, "") for m in matches]
            else:
                v_el = first_child(ctx, value)
                values = [text_of(v_el, "")] if v_el is not None else []

            ok = eval_operator(values, operator, expected)
            status = "PASS" if ok else on_fail
            rec = "" if status in ("PASS", "NA") else recommendation
            ev = f"{context}='{ctx_name}' value-path='{value}' value='{values[0] if values else ''}' expected='{expected}'"
            out.append(CheckResult(f"{desc} ({ctx_name})", status, evidence=ev, recommendation=rec))

        return out if out else [check_result(desc, "NA", evidence=f"No applicable <{context}> elements found")]

    return [check_result(desc, "NA", evidence=f"Unsupported check type: {ctype}")]


def run_yaml_checks(domain_dir, domain_name, checks_yaml):
    """
    Returns list[(section_name, list[CheckResult])]
    """
    sections = []
    for sec in checks_yaml.get("sections", []):
        sec_name = sec.get("name", "Unnamed section")
        sec_results = []
        for chk in sec.get("checks", []):
            sec_results.extend(eval_one_check(domain_dir, domain_name, chk))
        sections.append((sec_name, sec_results))
    return sections


# ----------------------------
# HTML rendering
# ----------------------------
def html_table(check_results):
    def row(r: CheckResult):
        cls = {"PASS":"pass","FAIL":"fail","WARN":"warn","NA":"na"}.get(r.status, "na")
        return f"""
        <tr class="{cls}">
          <td>{html.escape(r.check)}</td>
          <td><b>{html.escape(r.status)}</b></td>
          <td>{html.escape(r.evidence or "")}</td>
          <td>{html.escape(r.recommendation or "")}</td>
        </tr>
        """

    return f"""
    <table>
      <tr>
        <th>Check</th>
        <th>Status</th>
        <th>Evidence</th>
        <th>Recommendation if failed/warn</th>
      </tr>
      {''.join(row(r) for r in check_results)}
    </table>
    """

def write_report(out_path, domain_dir, domain_name, config_xml_path, checks_yaml_path, sections):
    sections_html = []
    for sec_name, sec_results in sections:
        sections_html.append(f"<h2>{html.escape(sec_name)}</h2>")
        sections_html.append(html_table(sec_results))

    doc = f"""<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>WLS DOMAIN {html.escape(domain_name)} checks</title>
  <style>
    body {{ font-family: Arial, sans-serif; margin: 18px; }}
    h1 {{ margin: 0 0 10px 0; font-size: 18px; }}
    h2 {{ margin-top: 18px; border-top: 1px solid #ddd; padding-top: 10px; font-size: 15px; }}
    .meta {{ font-size: 12px; color: #444; margin-bottom: 12px; }}
    table {{ border-collapse: collapse; width: 100%; margin: 10px 0; }}
    th, td {{ border: 1px solid #ccc; padding: 6px 8px; font-size: 12px; vertical-align: top; }}
    th {{ background: #f3f3f3; }}
    .pass {{ background: #e9f7ef; }}
    .fail {{ background: #fdecea; }}
    .warn {{ background: #fff3cd; }}
    .na   {{ background: #f8f9fa; color: #555; }}
    code {{ font-family: Consolas, monospace; font-size: 11px; }}
  </style>
</head>
<body>
  <h1>WLS DOMAIN {html.escape(domain_name)} checks</h1>
  <div class="meta">
    Domain dir: <code>{html.escape(os.path.abspath(domain_dir))}</code><br/>
    config.xml: <code>{html.escape(config_xml_path)}</code><br/>
    checks yaml: <code>{html.escape(os.path.abspath(checks_yaml_path))}</code><br/>
    Generated: {datetime.utcnow().isoformat()}Z
  </div>

  {''.join(sections_html)}
</body>
</html>
"""
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(doc)


# ----------------------------
# Main
# ----------------------------
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--domain-dir", required=True, help="Domain directory containing config/config.xml, nodemanager/*, config/jdbc/*")
    ap.add_argument("--checks-yaml", required=True, help="Path to maa_checks.yml")
    ap.add_argument("--out", required=True, help="Output HTML report path")
    args = ap.parse_args()

    domain_dir = os.path.abspath(args.domain_dir)
    if not os.path.isdir(domain_dir):
        raise SystemExit(f"--domain-dir is not a directory: {domain_dir}")

    config_xml_path = os.path.join(domain_dir, "config", "config.xml")
    if not os.path.isfile(config_xml_path):
        raise SystemExit(f"Missing config.xml at: {config_xml_path}")

    # Parse domain name from config.xml
    config_xml_path, config_root, domain_name = parse_domain_name(domain_dir)

    # Load YAML checks
    checks_yaml = load_checks_yaml(args.checks_yaml)

    # Run checks
    sections = run_yaml_checks(domain_dir, domain_name, checks_yaml)

    # Write report
    write_report(args.out, domain_dir, domain_name, config_xml_path, args.checks_yaml, sections)
    print(f"Wrote report: {args.out}")

if __name__ == "__main__":
    main()
