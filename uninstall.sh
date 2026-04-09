#!/bin/sh
# uninstall.sh — remove ~/.claude/skills/modx/
#
# Intentionally leaves ~/.config/modx-sites/ alone. Your site credentials and
# pointer files survive an uninstall so a reinstall reconnects immediately.

set -eu

SKILL_NAME="modx"
TARGET="${HOME}/.claude/skills/${SKILL_NAME}"

if [ ! -e "$TARGET" ]; then
    printf 'uninstall.sh: nothing to remove at %s\n' "$TARGET"
    exit 0
fi

printf 'Removing %s ...\n' "$TARGET"
rm -rf "$TARGET"

cat <<EOF

Uninstalled claude-skill-modx.

Your site configs in ~/.config/modx-sites/ have been left alone. If you want to
remove them too, delete that directory manually:

    rm -rf ~/.config/modx-sites

The bridge files deployed to your MODX servers are also untouched. To remove
them, SSH to each server and delete <web_root>/cli/modx-cli.php and the
corresponding .htaccess file.
EOF
