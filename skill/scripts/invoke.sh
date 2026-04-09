#!/bin/sh
# invoke.sh — hot-path wrapper around the deployed MODX CLI bridge.
#
# Usage:
#     invoke.sh                          # site auto-detected, JSON from stdin
#     invoke.sh <alias>                  # explicit site, JSON from stdin
#     invoke.sh <alias> '<json>'         # explicit site, JSON as argument
#     invoke.sh '<json>'                 # site auto-detected, JSON as argument
#
# Reads the matching ~/.config/modx-sites/<alias>.yaml file, builds the SSH
# command, pipes the JSON payload into the remote bridge, and returns the
# bridge's stdout (which is JSON) on this script's stdout.

set -eu

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REGISTRY_DIR="${HOME}/.config/modx-sites"

read_yaml_key() {
    # Extract a flat "key: value" line from a YAML file. Handles optional
    # double-quoted values and trims trailing whitespace and comments.
    sed -n "s/^${2}:[[:space:]]*\"\{0,1\}\([^\"#]*\)\"\{0,1\}[[:space:]]*\$/\\1/p" "$1" \
        | head -n 1 \
        | sed 's/[[:space:]]*$//'
}

ALIAS=""
PAYLOAD=""

# Parse positional args. A first argument starting with "{" is treated as JSON.
if [ "$#" -ge 1 ]; then
    first_char="$(printf '%s' "$1" | cut -c1)"
    if [ "$first_char" = "{" ]; then
        PAYLOAD="$1"
    else
        ALIAS="$1"
        if [ "$#" -ge 2 ]; then
            PAYLOAD="$2"
        fi
    fi
fi

# Resolve registry file
if [ -n "$ALIAS" ]; then
    REGISTRY="${REGISTRY_DIR}/${ALIAS}.yaml"
    if [ ! -f "$REGISTRY" ]; then
        printf 'invoke.sh: site "%s" not found (%s)\n' "$ALIAS" "$REGISTRY" >&2
        exit 1
    fi
else
    REGISTRY="$("${SKILL_DIR}/scripts/detect-site.sh")" || exit $?
fi

HOST="$(read_yaml_key "$REGISTRY" host)"
SSH_USER="$(read_yaml_key "$REGISTRY" ssh_user)"
SSH_KEY="$(read_yaml_key "$REGISTRY" ssh_key)"
SSH_PORT="$(read_yaml_key "$REGISTRY" ssh_port)"
PHP_USER="$(read_yaml_key "$REGISTRY" php_user)"
PHP_BINARY="$(read_yaml_key "$REGISTRY" php_binary)"
WEB_ROOT="$(read_yaml_key "$REGISTRY" web_root)"
BRIDGE_PATH="$(read_yaml_key "$REGISTRY" bridge_path)"

[ -n "$SSH_PORT" ] || SSH_PORT=22
[ -n "$PHP_BINARY" ] || PHP_BINARY=php
[ -n "$BRIDGE_PATH" ] || BRIDGE_PATH="cli/modx-cli.php"

for required in HOST SSH_USER PHP_USER WEB_ROOT; do
    eval "val=\${$required}"
    if [ -z "$val" ]; then
        lower="$(printf '%s' "$required" | tr '[:upper:]' '[:lower:]')"
        printf 'invoke.sh: required key "%s" is missing in %s\n' "$lower" "$REGISTRY" >&2
        exit 2
    fi
done

if [ -n "$SSH_KEY" ]; then
    case "$SSH_KEY" in
        "~"*) SSH_KEY="${HOME}${SSH_KEY#~}" ;;
    esac
fi

REMOTE_CMD="runuser -u ${PHP_USER} -- ${PHP_BINARY} ${WEB_ROOT}/${BRIDGE_PATH}"

set -- ssh -p "$SSH_PORT" -o BatchMode=yes -o StrictHostKeyChecking=accept-new
if [ -n "$SSH_KEY" ]; then
    set -- "$@" -i "$SSH_KEY"
fi
set -- "$@" "${SSH_USER}@${HOST}" "$REMOTE_CMD"

if [ -n "$PAYLOAD" ]; then
    printf '%s' "$PAYLOAD" | "$@"
else
    "$@"
fi
