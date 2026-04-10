#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: criomos-reload-shell <user> [<node>]"
  echo ""
  echo "Restart noctalia-shell in a user's Wayland session."
  echo "If <node> is omitted, runs locally."
  echo ""
  echo "Examples:"
  echo "  criomos-reload-shell bird zeus"
  echo "  criomos-reload-shell li"
  exit 1
}

[ $# -lt 1 ] && usage

USER="$1"
NODE="${2:-}"
CLUSTER="maisiliym"

run() {
  if [ -n "$NODE" ]; then
    ssh root@"${NODE}.${CLUSTER}.criome" "$@"
  else
    eval "$@"
  fi
}

# Find the user's Wayland socket and runtime dir
UID_NUM=$(run "id -u ${USER}")
RUNTIME="/run/user/${UID_NUM}"

# Kill old quickshell
run "kill \$(pgrep -u ${USER} quickshell) 2>/dev/null" || true
sleep 1

# Relaunch noctalia-shell in the user's session
run "su - ${USER} -c 'WAYLAND_DISPLAY=wayland-1 XDG_RUNTIME_DIR=${RUNTIME} noctalia-shell &'"

echo "Reloaded ${USER}'s shell${NODE:+ on ${NODE}}"
