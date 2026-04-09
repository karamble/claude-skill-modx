#!/bin/sh
# install.sh — copy the skill tree into ~/.claude/skills/modx/
#
# This script is intentionally hands-off outside ~/.claude/skills/. It does not
# create ~/.config/modx-sites/ or touch any server. The first-run init flow
# (triggered when you ask Claude to work on a MODX site) handles everything else.

set -eu

SKILL_NAME="modx"
TARGET="${HOME}/.claude/skills/${SKILL_NAME}"
SOURCE="$(cd "$(dirname "$0")" && pwd)/skill"
FORCE=0

for arg in "$@"; do
    case "$arg" in
        -f|--force)
            FORCE=1
            ;;
        -h|--help)
            cat <<EOF
Usage: $0 [--force]

Copies the skill tree from ./skill/ into ~/.claude/skills/${SKILL_NAME}/.

Options:
  -f, --force   Overwrite an existing installation.
  -h, --help    Show this help and exit.
EOF
            exit 0
            ;;
        *)
            printf 'install.sh: unknown argument: %s\n' "$arg" >&2
            exit 1
            ;;
    esac
done

if [ ! -d "$SOURCE" ]; then
    printf 'install.sh: source directory not found: %s\n' "$SOURCE" >&2
    printf 'Run this script from the root of the claude-skill-modx repo.\n' >&2
    exit 1
fi

if [ -e "$TARGET" ] && [ "$FORCE" -eq 0 ]; then
    printf 'install.sh: target already exists: %s\n' "$TARGET" >&2
    printf 'Pass --force to overwrite, or remove it first with ./uninstall.sh\n' >&2
    exit 1
fi

if [ "$FORCE" -eq 1 ] && [ -e "$TARGET" ]; then
    printf 'Removing existing installation at %s\n' "$TARGET"
    rm -rf "$TARGET"
fi

mkdir -p "${HOME}/.claude/skills"
cp -R "$SOURCE" "$TARGET"

# Make helper scripts executable
chmod +x "${TARGET}/scripts/"*.sh 2>/dev/null || true

cat <<EOF

Installed claude-skill-modx into:
  ${TARGET}

Next steps:
  1. Open Claude Code in the directory of your MODX project.
  2. Ask Claude: "I want to work on my MODX site."
  3. Claude will ask for your SSH and MODX server details, write them to
     ~/.config/modx-sites/<alias>.yaml, deploy the bridge, and verify it works.

To uninstall later:
  ./uninstall.sh

Docs:
  ${TARGET}/SKILL.md
  ${TARGET}/reference/actions.md
EOF
