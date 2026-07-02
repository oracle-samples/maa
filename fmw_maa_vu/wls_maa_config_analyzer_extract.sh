#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:\n  wls_maa_config_analyzer_extract.sh <WLS_DOMAIN_HOME> <WLS_CONFIG_ROOT> <NODEMANAGER_HOME>

Arguments:
  WLS_DOMAIN_HOME    Full path to the source WebLogic domain home.
  WLS_CONFIG_ROOT    Full path to the destination WLS_CONFIG root.
  NODEMANAGER_HOME   Full path to the Node Manager home on the Admin Server node.

Example:\n  ./wls_maa_config_analyzer_extract.sh \
    /u01/app/oracle/middleware/user_projects/domains/base_domain \
    /backup/WLS_CONFIG \
    /u01/app/oracle/middleware/oracle_common/common/nodemanager
EOF
}

if [[ $# -ne 3 ]]; then
  usage
  exit 1
fi

WLS_DOMAIN_HOME="$1"
WLS_CONFIG_ROOT="$2"
NODEMANAGER_HOME="$3"

if [[ ! -d "$WLS_DOMAIN_HOME" ]]; then
  echo "ERROR: WLS_DOMAIN_HOME does not exist or is not a directory: $WLS_DOMAIN_HOME" >&2
  exit 1
fi

if [[ ! -d "$NODEMANAGER_HOME" ]]; then
  echo "ERROR: NODEMANAGER_HOME does not exist or is not a directory: $NODEMANAGER_HOME" >&2
  exit 1
fi

DOMAIN_NAME="$(basename "$WLS_DOMAIN_HOME")"
DEST_DOMAIN_DIR="$WLS_CONFIG_ROOT/$DOMAIN_NAME"
DEST_CONFIG_DIR="$DEST_DOMAIN_DIR/config"
DEST_START_DIR="$DEST_DOMAIN_DIR/domain_startscripts"
DEST_NM_DIR="$DEST_DOMAIN_DIR/nodemanager"

mkdir -p "$DEST_CONFIG_DIR" "$DEST_START_DIR" "$DEST_NM_DIR"

# Copy main configuration files/directories.
if [[ -f "$WLS_DOMAIN_HOME/config/config.xml" ]]; then
  cp -p "$WLS_DOMAIN_HOME/config/config.xml" "$DEST_CONFIG_DIR/"
else
  echo "WARNING: config.xml not found at $WLS_DOMAIN_HOME/config/config.xml" >&2
fi

if [[ -d "$WLS_DOMAIN_HOME/config/jdbc" ]]; then
  cp -a "$WLS_DOMAIN_HOME/config/jdbc" "$DEST_CONFIG_DIR/"
else
  echo "WARNING: jdbc directory not found at $WLS_DOMAIN_HOME/config/jdbc" >&2
fi

if [[ -d "$WLS_DOMAIN_HOME/config/jms" ]]; then
  cp -a "$WLS_DOMAIN_HOME/config/jms" "$DEST_CONFIG_DIR/"
else
  echo "WARNING: jms directory not found at $WLS_DOMAIN_HOME/config/jms" >&2
fi

# Copy start scripts.
if compgen -G "$WLS_DOMAIN_HOME/bin/*" > /dev/null; then
  cp -a "$WLS_DOMAIN_HOME/bin/." "$DEST_START_DIR/"
else
  echo "WARNING: no files found in $WLS_DOMAIN_HOME/bin" >&2
fi

# Copy Node Manager home contents from the Admin Server node.
if compgen -G "$NODEMANAGER_HOME/*" > /dev/null; then
  cp -a "$NODEMANAGER_HOME/." "$DEST_NM_DIR/"
else
  echo "WARNING: no files found in $NODEMANAGER_HOME" >&2
fi

echo "WLS MAA configuration extraction completed successfully for domain: $DOMAIN_NAME"
echo "Destination: $DEST_DOMAIN_DIR"
