#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: criomos-deploy <node> [--boot] [--commit <hash>]"
  echo ""
  echo "Build fullOs on <node>, set system profile, and activate."
  echo ""
  echo "  --boot     Set boot entry only, don't activate (for kernel changes)"
  echo "  --commit   Build specific commit (default: current main)"
  echo ""
  echo "Examples:"
  echo "  criomos-deploy zeus"
  echo "  criomos-deploy zeus --boot"
  echo "  criomos-deploy prometheus --commit abc123"
  exit 1
}

[ $# -lt 1 ] && usage

NODE="$1"; shift
MODE="switch"
COMMIT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --boot)   MODE="boot"; shift ;;
    --commit) COMMIT="$2"; shift 2 ;;
    *)        usage ;;
  esac
done

CLUSTER="maisiliym"
REPO="github:criome/CriomOS"

if [ -z "$COMMIT" ]; then
  COMMIT=$(jj log -r main -T 'commit_id' --no-graph 2>/dev/null)
fi

REF="${REPO}/${COMMIT}"
ATTR="${REF}#crioZones.${CLUSTER}.${NODE}.fullOs"

echo "Building ${NODE} from ${COMMIT:0:12}..."
ssh root@"${NODE}.${CLUSTER}.criome" \
  "nix build ${ATTR} --no-write-lock-file -o /tmp/criomos-deploy \
   && nix-env -p /nix/var/nix/profiles/system --set \$(readlink /tmp/criomos-deploy) \
   && \$(readlink /tmp/criomos-deploy)/bin/switch-to-configuration ${MODE}"

echo "Done: ${NODE} ${MODE}"
