#!/bin/sh
# detect-site.sh — resolve which MODX site the current project is configured for.
#
# Walks up from $PWD looking for a .modx-site.yaml pointer file. If found,
# reads the "site:" key and returns the full path to the matching registry
# file at ~/.config/modx-sites/<site>.yaml. Falls back to
# ~/.config/modx-sites/default.yaml if no pointer is found.
#
# Exits 0 with the registry file path on stdout on success.
# Exits non-zero with a diagnostic on stderr if no configuration is reachable.

set -eu

REGISTRY_DIR="${HOME}/.config/modx-sites"

find_pointer() {
    d="$(pwd)"
    while [ "$d" != "/" ] && [ "$d" != "$HOME" ]; do
        if [ -f "${d}/.modx-site.yaml" ]; then
            printf '%s/.modx-site.yaml' "$d"
            return 0
        fi
        d="$(dirname "$d")"
    done
    if [ -f "${HOME}/.modx-site.yaml" ]; then
        printf '%s/.modx-site.yaml' "$HOME"
        return 0
    fi
    return 1
}

read_pointer_site() {
    sed -n 's/^site:[[:space:]]*\([^[:space:]#]*\).*$/\1/p' "$1" | head -n 1
}

if POINTER="$(find_pointer)"; then
    ALIAS="$(read_pointer_site "$POINTER")"
    if [ -z "$ALIAS" ]; then
        printf 'detect-site.sh: pointer file exists but has no "site:" key: %s\n' "$POINTER" >&2
        exit 2
    fi
    REGISTRY="${REGISTRY_DIR}/${ALIAS}.yaml"
    if [ ! -f "$REGISTRY" ]; then
        printf 'detect-site.sh: pointer references "%s" but %s does not exist\n' "$ALIAS" "$REGISTRY" >&2
        printf 'Initialize the site first: ~/.claude/skills/modx/scripts/init-site.sh\n' >&2
        exit 3
    fi
    printf '%s\n' "$REGISTRY"
    exit 0
fi

if [ -f "${REGISTRY_DIR}/default.yaml" ]; then
    printf '%s\n' "${REGISTRY_DIR}/default.yaml"
    exit 0
fi

printf 'detect-site.sh: no .modx-site.yaml in %s or any parent, and no default registry entry\n' "$(pwd)" >&2
printf 'Initialize the site first: ~/.claude/skills/modx/scripts/init-site.sh\n' >&2
exit 1
