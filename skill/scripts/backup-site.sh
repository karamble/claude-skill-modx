#!/bin/sh
# backup-site.sh — create a full site backup (files + database) on the server.
#
# Usage:
#     backup-site.sh                    # site auto-detected
#     backup-site.sh <alias>            # explicit site
#     backup-site.sh <alias> <dest>     # explicit site, download to local <dest> dir
#
# What it does:
#   1. SSH into the server
#   2. Parse MODX core/config/config.inc.php for database credentials
#   3. Run mysqldump to export the full database
#   4. Create a tar.gz archive containing the web root + SQL dump
#   5. Report the backup path (and optionally download it)
#
# The backup archive is stored on the server at /tmp/modx-backup-<alias>-<date>.tar.gz
# and contains:
#   - All files from the web root
#   - database.sql at the archive root
#
# Requires: ssh, tar, gzip, mysqldump on the server.

set -eu

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REGISTRY_DIR="${HOME}/.config/modx-sites"

read_yaml_key() {
    sed -n "s/^${2}:[[:space:]]*\"\{0,1\}\([^\"#]*\)\"\{0,1\}[[:space:]]*\$/\\1/p" "$1" \
        | head -n 1 \
        | sed 's/[[:space:]]*$//'
}

ALIAS=""
LOCAL_DEST=""

if [ "$#" -ge 1 ]; then
    ALIAS="$1"
fi
if [ "$#" -ge 2 ]; then
    LOCAL_DEST="$2"
fi

# Resolve registry file
if [ -n "$ALIAS" ]; then
    REGISTRY="${REGISTRY_DIR}/${ALIAS}.yaml"
    if [ ! -f "$REGISTRY" ]; then
        printf 'backup-site.sh: site "%s" not found (%s)\n' "$ALIAS" "$REGISTRY" >&2
        exit 1
    fi
else
    REGISTRY="$("${SKILL_DIR}/scripts/detect-site.sh")" || exit $?
    ALIAS="$(basename "$REGISTRY" .yaml)"
fi

HOST="$(read_yaml_key "$REGISTRY" host)"
SSH_USER="$(read_yaml_key "$REGISTRY" ssh_user)"
SSH_KEY="$(read_yaml_key "$REGISTRY" ssh_key)"
SSH_PORT="$(read_yaml_key "$REGISTRY" ssh_port)"
PHP_USER="$(read_yaml_key "$REGISTRY" php_user)"
WEB_ROOT="$(read_yaml_key "$REGISTRY" web_root)"

[ -n "$SSH_PORT" ] || SSH_PORT=22

for required in HOST SSH_USER PHP_USER WEB_ROOT; do
    eval "val=\${$required}"
    if [ -z "$val" ]; then
        lower="$(printf '%s' "$required" | tr '[:upper:]' '[:lower:]')"
        printf 'backup-site.sh: required key "%s" is missing in %s\n' "$lower" "$REGISTRY" >&2
        exit 2
    fi
done

if [ -n "$SSH_KEY" ]; then
    case "$SSH_KEY" in
        "~"*) SSH_KEY="${HOME}${SSH_KEY#~}" ;;
    esac
fi

DATE="$(date +%Y%m%d-%H%M%S)"
BACKUP_NAME="modx-backup-${ALIAS}-${DATE}"
BACKUP_PATH="/tmp/${BACKUP_NAME}.tar.gz"
CONFIG_PATH="${WEB_ROOT}/core/config/config.inc.php"
WEB_ROOT_PARENT="$(dirname "$WEB_ROOT")"
WEB_ROOT_BASE="$(basename "$WEB_ROOT")"

printf 'Creating backup for site "%s" on %s...\n' "$ALIAS" "$HOST" >&2

# Build SSH args
set -- ssh -p "$SSH_PORT" -o BatchMode=yes -o StrictHostKeyChecking=accept-new
if [ -n "$SSH_KEY" ]; then
    set -- "$@" -i "$SSH_KEY"
fi
set -- "$@" "${SSH_USER}@${HOST}"

# Run backup on remote server. The quoted heredoc ('REMOTESCRIPT') prevents
# local shell expansion — all $ references are interpreted by the remote shell.
# Local variables are passed as positional arguments to the remote bash.
"$@" /bin/bash -s "$CONFIG_PATH" "$BACKUP_PATH" "$BACKUP_NAME" "$WEB_ROOT_PARENT" "$WEB_ROOT_BASE" << 'REMOTESCRIPT'
set -eu

CONFIG="$1"
BACKUP_PATH="$2"
BACKUP_NAME="$3"
WEB_ROOT_PARENT="$4"
WEB_ROOT_BASE="$5"

if [ ! -f "$CONFIG" ]; then
    echo "ERROR: config not found at $CONFIG" >&2
    exit 1
fi

# Parse PHP config variables
DB_HOST=$(grep -oP '\$database_server\s*=\s*'"'"'\K[^'"'"']+' "$CONFIG")
DB_NAME=$(grep -oP '\$dbase\s*=\s*'"'"'\K[^'"'"']+' "$CONFIG")
DB_USER=$(grep -oP '\$database_user\s*=\s*'"'"'\K[^'"'"']+' "$CONFIG")
DB_PASS=$(grep -oP '\$database_password\s*=\s*'"'"'\K[^'"'"']+' "$CONFIG")
DB_CHARSET=$(grep -oP '\$database_connection_charset\s*=\s*'"'"'\K[^'"'"']+' "$CONFIG" || echo "utf8mb4")

if [ -z "$DB_NAME" ] || [ -z "$DB_USER" ]; then
    echo "ERROR: could not parse database credentials from $CONFIG" >&2
    exit 1
fi

echo "Database: $DB_NAME @ $DB_HOST" >&2
echo "Web root: $WEB_ROOT_PARENT/$WEB_ROOT_BASE" >&2

# mysqldump
SQLDUMP="/tmp/${BACKUP_NAME}-database.sql"
echo "Running mysqldump..." >&2
mysqldump \
    --host="$DB_HOST" \
    --user="$DB_USER" \
    --password="$DB_PASS" \
    --default-character-set="$DB_CHARSET" \
    --single-transaction \
    --routines \
    --triggers \
    --add-drop-table \
    "$DB_NAME" > "$SQLDUMP" 2>/dev/null

SQLSIZE=$(du -h "$SQLDUMP" | cut -f1)
echo "SQL dump: $SQLSIZE" >&2

# Create tar.gz archive
echo "Creating archive..." >&2
tar czf "$BACKUP_PATH" \
    -C "$WEB_ROOT_PARENT" "$WEB_ROOT_BASE" \
    -C "/tmp" "${BACKUP_NAME}-database.sql"

# Clean up SQL dump
rm -f "$SQLDUMP"

ARCHSIZE=$(du -h "$BACKUP_PATH" | cut -f1)
echo "Archive: $BACKUP_PATH ($ARCHSIZE)" >&2

# Output the path on stdout for script consumption
echo "$BACKUP_PATH"
REMOTESCRIPT

RESULT=$?
if [ $RESULT -ne 0 ]; then
    printf 'backup-site.sh: backup failed (exit %d)\n' "$RESULT" >&2
    exit $RESULT
fi

# Optionally download the archive
if [ -n "$LOCAL_DEST" ]; then
    printf 'Downloading backup to %s...\n' "$LOCAL_DEST" >&2
    set -- scp -P "$SSH_PORT" -o BatchMode=yes -o StrictHostKeyChecking=accept-new
    if [ -n "$SSH_KEY" ]; then
        set -- "$@" -i "$SSH_KEY"
    fi
    "$@" "${SSH_USER}@${HOST}:${BACKUP_PATH}" "${LOCAL_DEST}/"
    printf 'Downloaded: %s/%s\n' "$LOCAL_DEST" "$(basename "$BACKUP_PATH")" >&2
fi

printf 'Backup complete: %s\n' "$BACKUP_PATH"
