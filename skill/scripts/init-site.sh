#!/bin/sh
# init-site.sh — interactive helper that collects MODX site credentials and
# writes them to ~/.config/modx-sites/<alias>.yaml. Optionally drops a
# .modx-site.yaml pointer in the current directory and runs deploy-bridge.sh.
#
# Claude Code users typically do not run this script directly; Claude collects
# the same details via AskUserQuestion and writes the same files. This script
# exists for users who want to initialize a site from a regular shell, without
# going through Claude.
#
# Usage:
#     init-site.sh
#
# Prompts for every required field, confirms, writes config, and optionally
# deploys the bridge.

set -eu

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REGISTRY_DIR="${HOME}/.config/modx-sites"

prompt() {
    label="$1"
    default="$2"
    if [ -n "$default" ]; then
        printf '%s [%s]: ' "$label" "$default" >&2
    else
        printf '%s: ' "$label" >&2
    fi
    read -r value
    if [ -z "$value" ] && [ -n "$default" ]; then
        value="$default"
    fi
    printf '%s' "$value"
}

prompt_required() {
    label="$1"
    default="$2"
    while :; do
        value="$(prompt "$label" "$default")"
        if [ -n "$value" ]; then
            printf '%s' "$value"
            return 0
        fi
        printf '  (required)\n' >&2
    done
}

printf '\n=== claude-skill-modx site initialization ===\n\n'
printf 'This will collect SSH and MODX server details for one site and write them\n'
printf 'to %s/<alias>.yaml.\n\n' "$REGISTRY_DIR"

ALIAS="$(prompt_required "Site alias (short name, e.g. mysite)" "")"
HOST="$(prompt_required "SSH hostname" "")"
SSH_USER="$(prompt_required "SSH user" "root")"
SSH_PORT="$(prompt "SSH port" "22")"
SSH_KEY="$(prompt "SSH private key path (blank = use agent)" "")"
PHP_USER="$(prompt_required "PHP user (MODX runs as this POSIX user)" "")"
PHP_BINARY="$(prompt "PHP binary path on server" "/usr/bin/php")"
WEB_ROOT="$(prompt_required "MODX web root (absolute path)" "")"

REGISTRY="${REGISTRY_DIR}/${ALIAS}.yaml"

if [ -f "$REGISTRY" ]; then
    printf '\nWARNING: %s already exists.\n' "$REGISTRY" >&2
    printf 'Overwrite? [y/N] ' >&2
    read -r confirm
    case "$confirm" in
        y|Y|yes|YES) ;;
        *) printf 'Aborted.\n' >&2; exit 1 ;;
    esac
fi

mkdir -p "$REGISTRY_DIR"
chmod 0700 "$REGISTRY_DIR"

{
    printf 'host: "%s"\n' "$HOST"
    printf 'ssh_user: "%s"\n' "$SSH_USER"
    printf 'ssh_port: "%s"\n' "$SSH_PORT"
    if [ -n "$SSH_KEY" ]; then
        printf 'ssh_key: "%s"\n' "$SSH_KEY"
    fi
    printf 'php_user: "%s"\n' "$PHP_USER"
    printf 'php_binary: "%s"\n' "$PHP_BINARY"
    printf 'web_root: "%s"\n' "$WEB_ROOT"
    printf 'bridge_path: "cli/modx-cli.php"\n'
    printf 'modx_version: "3.x"\n'
} > "$REGISTRY"
chmod 0600 "$REGISTRY"

printf '\nWrote %s\n' "$REGISTRY"

printf '\nPlace a .modx-site.yaml pointer in the current directory (%s)? [Y/n] ' "$(pwd)"
read -r place_pointer
case "$place_pointer" in
    n|N|no|NO) ;;
    *)
        printf 'site: %s\n' "$ALIAS" > "./.modx-site.yaml"
        printf 'Wrote %s/.modx-site.yaml\n' "$(pwd)"
        ;;
esac

printf '\nDeploy the bridge to the server now? [Y/n] '
read -r deploy_now
case "$deploy_now" in
    n|N|no|NO)
        printf 'Skipped. Run deploy-bridge.sh %s when ready.\n' "$ALIAS"
        ;;
    *)
        "${SKILL_DIR}/scripts/deploy-bridge.sh" "$ALIAS"
        ;;
esac
