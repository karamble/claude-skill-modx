#!/bin/sh
# deploy-bridge.sh — upload the MODX CLI bridge to a configured site.
#
# Usage:
#     deploy-bridge.sh <alias> [--force]
#
# Reads ~/.config/modx-sites/<alias>.yaml for SSH and server details, then:
#   1. mkdir -p <web_root>/cli on the remote
#   2. scp the bridge PHP file to <web_root>/cli/modx-cli.php
#   3. scp the .htaccess deny rule alongside it
#   4. chown the files to <php_user> and chmod them to the safe modes
#   5. Run a "ping" smoke test via invoke.sh and print the response
#
# Refuses to overwrite an existing modx-cli.php on the remote unless --force
# is passed. On success, exits 0. On failure, exits non-zero with a diagnostic.

set -eu

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REGISTRY_DIR="${HOME}/.config/modx-sites"
BRIDGE_SOURCE="${SKILL_DIR}/bridge/modx-cli.php"
HTACCESS_SOURCE="${SKILL_DIR}/bridge/modx-cli.htaccess"

read_yaml_key() {
    sed -n "s/^${2}:[[:space:]]*\"\{0,1\}\([^\"#]*\)\"\{0,1\}[[:space:]]*\$/\\1/p" "$1" \
        | head -n 1 \
        | sed 's/[[:space:]]*$//'
}

usage() {
    cat <<EOF
Usage: $0 <alias> [--force]

Arguments:
  <alias>       Name of a site registered in ${REGISTRY_DIR}
  --force       Overwrite the bridge if it already exists on the remote
EOF
}

if [ "$#" -lt 1 ]; then
    usage >&2
    exit 1
fi

ALIAS="$1"
FORCE=0
shift
for arg in "$@"; do
    case "$arg" in
        --force) FORCE=1 ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'deploy-bridge.sh: unknown argument: %s\n' "$arg" >&2; exit 1 ;;
    esac
done

REGISTRY="${REGISTRY_DIR}/${ALIAS}.yaml"
if [ ! -f "$REGISTRY" ]; then
    printf 'deploy-bridge.sh: site "%s" not registered at %s\n' "$ALIAS" "$REGISTRY" >&2
    exit 1
fi

if [ ! -f "$BRIDGE_SOURCE" ]; then
    printf 'deploy-bridge.sh: bridge source not found at %s\n' "$BRIDGE_SOURCE" >&2
    exit 2
fi

HOST="$(read_yaml_key "$REGISTRY" host)"
SSH_USER="$(read_yaml_key "$REGISTRY" ssh_user)"
SSH_KEY="$(read_yaml_key "$REGISTRY" ssh_key)"
SSH_PORT="$(read_yaml_key "$REGISTRY" ssh_port)"
PHP_USER="$(read_yaml_key "$REGISTRY" php_user)"
WEB_ROOT="$(read_yaml_key "$REGISTRY" web_root)"
BRIDGE_PATH="$(read_yaml_key "$REGISTRY" bridge_path)"

[ -n "$SSH_PORT" ] || SSH_PORT=22
[ -n "$BRIDGE_PATH" ] || BRIDGE_PATH="cli/modx-cli.php"

for required in HOST SSH_USER PHP_USER WEB_ROOT; do
    eval "val=\${$required}"
    if [ -z "$val" ]; then
        lower="$(printf '%s' "$required" | tr '[:upper:]' '[:lower:]')"
        printf 'deploy-bridge.sh: required key "%s" is missing in %s\n' "$lower" "$REGISTRY" >&2
        exit 2
    fi
done

if [ -n "$SSH_KEY" ]; then
    case "$SSH_KEY" in
        "~"*) SSH_KEY="${HOME}${SSH_KEY#~}" ;;
    esac
fi

REMOTE_DIR="$(dirname "${WEB_ROOT}/${BRIDGE_PATH}")"
REMOTE_BRIDGE="${WEB_ROOT}/${BRIDGE_PATH}"
REMOTE_HTACCESS="${REMOTE_DIR}/.htaccess"

ssh_run() {
    set -- ssh -p "$SSH_PORT" -o BatchMode=yes -o StrictHostKeyChecking=accept-new
    if [ -n "$SSH_KEY" ]; then
        set -- "$@" -i "$SSH_KEY"
    fi
    set -- "$@" "${SSH_USER}@${HOST}" "$1"
    "$@"
}

scp_to() {
    set -- scp -P "$SSH_PORT" -o BatchMode=yes -o StrictHostKeyChecking=accept-new
    if [ -n "$SSH_KEY" ]; then
        set -- "$@" -i "$SSH_KEY"
    fi
    set -- "$@" "$1" "${SSH_USER}@${HOST}:$2"
    "$@"
}

printf 'Deploying bridge to %s@%s:%s\n' "$SSH_USER" "$HOST" "$REMOTE_BRIDGE"

# Sanity check: can we SSH at all?
if ! ssh_run "echo ok" >/dev/null 2>&1; then
    printf 'deploy-bridge.sh: SSH connection to %s@%s failed\n' "$SSH_USER" "$HOST" >&2
    printf 'See: %s/reference/troubleshooting.md\n' "$SKILL_DIR" >&2
    exit 3
fi

# Check for existing bridge
if ssh_run "test -f ${REMOTE_BRIDGE}" 2>/dev/null; then
    if [ "$FORCE" -eq 0 ]; then
        printf 'deploy-bridge.sh: bridge already exists at %s\n' "$REMOTE_BRIDGE" >&2
        printf 'Pass --force to overwrite.\n' >&2
        exit 4
    fi
    printf 'Existing bridge will be overwritten (--force set)\n'
fi

ssh_run "mkdir -p ${REMOTE_DIR}"
scp_to "$BRIDGE_SOURCE" "$REMOTE_BRIDGE"
scp_to "$HTACCESS_SOURCE" "$REMOTE_HTACCESS"
ssh_run "chown ${PHP_USER}: ${REMOTE_BRIDGE} ${REMOTE_HTACCESS} && chmod 0640 ${REMOTE_BRIDGE} && chmod 0644 ${REMOTE_HTACCESS}"

printf 'Uploaded. Running ping smoke test ...\n'
PING_RESPONSE="$("${SKILL_DIR}/scripts/invoke.sh" "$ALIAS" '{"action":"ping"}')"
printf '%s\n' "$PING_RESPONSE"

# Extract the "user" field from the ping response and compare to php_user
PING_USER="$(printf '%s' "$PING_RESPONSE" | sed -n 's/.*"user":[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)"
if [ -n "$PING_USER" ] && [ "$PING_USER" != "$PHP_USER" ]; then
    printf '\nWARNING: bridge is running as "%s" but config expects "%s".\n' "$PING_USER" "$PHP_USER" >&2
    printf 'This usually means runuser is not taking effect. Fix before running mutating actions.\n' >&2
    exit 5
fi

printf '\nBridge deployed successfully. You can now use invoke.sh to run actions.\n'
