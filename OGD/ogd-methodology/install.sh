#!/usr/bin/env bash
#
# OGD Methodology Skill — installer / updater
#
# Platforms: macOS and Linux only. Requires bash, git, and a filesystem
# that supports symlinks. On Windows: use WSL, or follow the manual
# install instructions in README.md.
#
# Installs the ogd-methodology skill via symlink so that `git pull` in the
# source repo updates the skill instantly. Supports multiple agentic coding
# tools (Claude Code, Cursor, Cline, OpenCode, GitHub Copilot).
#
# Two source modes:
#   1. Local — run from inside a cloned repo (next to SKILL.md).
#   2. Remote — run via `curl ... | bash`; clones the repo first.
#
# Usage:
#   ./install.sh                    Auto: update existing installs, or pick
#                                   a smart default if nothing is installed.
#   ./install.sh --target <name>    Install to a specific target.
#   ./install.sh --check            List all known installations with versions.
#   ./install.sh --help             Show all options.
#
# Environment overrides:
#   CLONE_DIR   Where to clone the source repo in remote mode.
#               Default: ~/.local/share/indie-gamedev-knowledge-base

set -euo pipefail

REPO_URL="https://github.com/dim-s/indie-gamedev-knowledge-base.git"
REPO_BRANCH="v0.9.5-beta"
SKILL_NAME="ogd-methodology"
SKILL_PATH_IN_REPO="OGD/${SKILL_NAME}"
DEFAULT_CLONE="${HOME}/.local/share/indie-gamedev-knowledge-base"
CLONE_DIR="${CLONE_DIR:-${DEFAULT_CLONE}}"

ALL_TARGETS="claude claude-project cursor cursor-project cline cline-project opencode opencode-project copilot copilot-project"

# ─────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────

log()  { printf "  %s\n" "$1"; }
ok()   { printf "  ✓ %s\n" "$1"; }
warn() { printf "  ! %s\n" "$1" >&2; }
err()  { printf "  ✗ %s\n" "$1" >&2; }

# Resolve a target name → install path. Unknown names are treated as custom paths.
target_path() {
    case "$1" in
        claude)            echo "${HOME}/.claude/skills/${SKILL_NAME}" ;;
        claude-project)    echo "${PWD}/.claude/skills/${SKILL_NAME}" ;;
        cursor)            echo "${HOME}/.cursor/skills/${SKILL_NAME}" ;;
        cursor-project)    echo "${PWD}/.cursor/skills/${SKILL_NAME}" ;;
        cline)             echo "${HOME}/.cline/skills/${SKILL_NAME}" ;;
        cline-project)     echo "${PWD}/.cline/skills/${SKILL_NAME}" ;;
        opencode)          echo "${HOME}/.config/opencode/skills/${SKILL_NAME}" ;;
        opencode-project)  echo "${PWD}/.opencode/skills/${SKILL_NAME}" ;;
        copilot)           echo "${HOME}/.copilot/skills/${SKILL_NAME}" ;;
        copilot-project)   echo "${PWD}/.github/skills/${SKILL_NAME}" ;;
        *)                 echo "$1" ;;  # treat as a custom absolute path
    esac
}

# Read version field from a SKILL.md file's frontmatter.
# Returns empty string if file is missing or has no version field.
# Always returns 0 — never aborts the caller under set -e.
read_version() {
    local file="$1"
    [ -f "$file" ] || { echo ""; return 0; }
    local line
    line=$(grep -E '^[[:space:]]*version:' "$file" 2>/dev/null | head -1 || true)
    if [ -z "$line" ]; then
        echo ""
        return 0
    fi
    printf '%s' "$line" | sed -E 's/^[[:space:]]*version:[[:space:]]*"?([^"]+)"?[[:space:]]*$/\1/'
}

# Canonicalize a path (resolve symlinks, relative segments) without GNU readlink -f.
# Returns the input unchanged if it can't be resolved.
canonicalize() {
    local p="$1"
    if [ -d "$p" ]; then
        ( cd "$p" 2>/dev/null && pwd ) || echo "$p"
    elif [ -L "$p" ] || [ -e "$p" ]; then
        local dir base
        dir=$(dirname "$p")
        base=$(basename "$p")
        ( cd "$dir" 2>/dev/null && printf '%s/%s\n' "$(pwd)" "$base" ) || echo "$p"
    else
        echo "$p"
    fi
}

# Read version of an existing install (symlink or directory)
installed_version() {
    local path="$1"
    if [ -e "$path" ] || [ -L "$path" ]; then
        read_version "$path/SKILL.md"
    fi
}

# Find all known existing installations
find_existing() {
    local found=""
    for name in $ALL_TARGETS; do
        local p
        p=$(target_path "$name")
        if [ -e "$p" ] || [ -L "$p" ]; then
            found="${found}${name} "
        fi
    done
    echo "$found"
}

# Pick a smart default target when nothing is installed
smart_default() {
    if [ -d "${HOME}/.claude" ]; then echo "claude"; return; fi
    if [ -d "${HOME}/.cursor" ]; then echo "cursor"; return; fi
    if [ -d "${HOME}/.config/opencode" ]; then echo "opencode"; return; fi
    if [ -d "${HOME}/.cline" ]; then echo "cline"; return; fi
    if [ -d "${HOME}/.copilot" ]; then echo "copilot"; return; fi
    echo "claude"  # fallback
}

# ─────────────────────────────────────────────────────────
# Modes
# ─────────────────────────────────────────────────────────

mode_check() {
    echo "OGD Methodology Skill — installation status"
    echo
    local any=0
    for name in $ALL_TARGETS; do
        local p
        p=$(target_path "$name")
        if [ -e "$p" ] || [ -L "$p" ]; then
            local v
            local kind="dir"
            [ -L "$p" ] && kind="link"
            v=$(installed_version "$p")
            printf "  ✓ %-18s  v%-8s  [%s]\n" "$name" "${v:-unknown}" "$kind"
            printf "      %s\n" "$p"
            any=1
        fi
    done
    if [ $any -eq 0 ]; then
        echo "  (no installations found)"
    fi
}

show_help() {
    cat <<'EOF'
OGD Methodology Skill — installer / updater

Usage:
  ./install.sh                    Auto-mode: update all existing installs,
                                  or install to a smart default if none exist.
  ./install.sh --target <name>    Install/update only the specified target.
  ./install.sh --check            List all known installations with versions.
  ./install.sh --help             Show this help.

Targets (--target name):
  claude              ~/.claude/skills/ogd-methodology
  claude-project      ./.claude/skills/ogd-methodology
  cursor              ~/.cursor/skills/ogd-methodology
  cursor-project      ./.cursor/skills/ogd-methodology
  cline               ~/.cline/skills/ogd-methodology
  cline-project       ./.cline/skills/ogd-methodology
  opencode            ~/.config/opencode/skills/ogd-methodology
  opencode-project    ./.opencode/skills/ogd-methodology
  copilot             ~/.copilot/skills/ogd-methodology
  copilot-project     ./.github/skills/ogd-methodology
  /any/absolute/path  A custom path (anything starting with / is accepted)

Environment:
  CLONE_DIR    Where to clone the source repo in remote mode.
               Default: ~/.local/share/indie-gamedev-knowledge-base
EOF
}

# Install the skill into a single target. Always recreates the symlink, even
# if the version hasn't changed — so the user always gets a clear "I did
# something" confirmation.
install_one() {
    local name="$1"
    local source_dir="$2"
    local new_version="$3"

    local target
    target=$(target_path "$name")

    # Canonicalize source for a stable comparison against existing symlinks
    local source_canon
    source_canon=$(canonicalize "$source_dir")

    local prev_version=""
    local prev_kind=""        # "" | "matching-link" | "wrong-link" | "directory"
    if [ -L "$target" ]; then
        prev_version=$(installed_version "$target")
        # Resolve the symlink target through the parent dir to get an absolute path,
        # then canonicalize for a like-for-like comparison.
        local raw_link link_abs link_canon
        raw_link=$(readlink "$target")
        case "$raw_link" in
            /*) link_abs="$raw_link" ;;
            *)  link_abs="$(dirname "$target")/$raw_link" ;;
        esac
        link_canon=$(canonicalize "$link_abs")
        if [ "$link_canon" = "$source_canon" ]; then
            prev_kind="matching-link"
        else
            prev_kind="wrong-link"
        fi
    elif [ -e "$target" ]; then
        prev_version=$(installed_version "$target")
        prev_kind="directory"
    fi

    # Always remove the existing entry, even a correct symlink — we recreate
    # so the user sees an explicit confirmation.
    if [ "$prev_kind" = "matching-link" ] || [ "$prev_kind" = "wrong-link" ]; then
        rm "$target"
    elif [ "$prev_kind" = "directory" ]; then
        local backup
        backup="${target}.backup-$(date +%Y%m%d-%H%M%S)"
        mv "$target" "$backup"
        warn "$name: backed up previous install → ${backup##*/}"
    fi

    mkdir -p "$(dirname "$target")"
    ln -s "$source_dir" "$target"

    # Report what happened
    if [ -z "$prev_kind" ]; then
        printf "  ✓ %-18s installed v%s\n" "$name" "$new_version"
    elif [ "$prev_version" = "$new_version" ] && [ -n "$new_version" ]; then
        case "$prev_kind" in
            matching-link)
                printf "  ✓ %-18s reinstalled v%s (no change)\n" "$name" "$new_version"
                ;;
            wrong-link)
                printf "  ✓ %-18s relinked to current source (v%s)\n" "$name" "$new_version"
                ;;
            directory)
                printf "  ✓ %-18s replaced copy with symlink (v%s)\n" "$name" "$new_version"
                ;;
        esac
    else
        printf "  ✓ %-18s updated v%s → v%s\n" "$name" "${prev_version:-?}" "${new_version:-?}"
    fi
}

# ─────────────────────────────────────────────────────────
# Argument parsing
# ─────────────────────────────────────────────────────────

TARGET_ARG=""
ACTION="install"

while [ $# -gt 0 ]; do
    case "$1" in
        --target)
            [ $# -ge 2 ] || { err "--target requires a value"; exit 1; }
            TARGET_ARG="$2"
            shift 2
            ;;
        --target=*)
            TARGET_ARG="${1#--target=}"
            shift
            ;;
        --check)
            ACTION="check"
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            err "Unknown argument: $1"
            echo
            show_help
            exit 1
            ;;
    esac
done

# Check mode is independent — runs without preparing source
if [ "$ACTION" = "check" ]; then
    mode_check
    exit 0
fi

# ─────────────────────────────────────────────────────────
# Prepare source (local or remote)
# ─────────────────────────────────────────────────────────

echo "OGD Methodology Skill — installer"
echo

# Detect local mode only when BASH_SOURCE points to a real file. When the
# script is piped via `curl ... | bash`, BASH_SOURCE[0] is empty (or "bash")
# and we MUST go remote — otherwise an unrelated SKILL.md in cwd could be
# picked up as the source by accident.
SCRIPT_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
    SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
fi

if [ -n "$SCRIPT_DIR" ] && [ -f "${SCRIPT_DIR}/SKILL.md" ]; then
    MODE="local"
    SOURCE_DIR="$SCRIPT_DIR"
    if ! REPO_ROOT=$(cd "${SOURCE_DIR}/../.." 2>/dev/null && pwd); then
        REPO_ROOT="${SOURCE_DIR}/../.."
        warn "Could not resolve repo root — git pull hint may be inaccurate"
    fi
    log "Mode: local (running from cloned skill)"
    log "Source: $SOURCE_DIR"
else
    MODE="remote"
    SOURCE_DIR="${CLONE_DIR}/${SKILL_PATH_IN_REPO}"
    REPO_ROOT="$CLONE_DIR"
    log "Mode: remote (will clone or pull repo)"
    log "Repo: $CLONE_DIR"
fi
echo

if [ "$MODE" = "remote" ]; then
    if ! command -v git >/dev/null 2>&1; then
        err "git is not installed. Install git and retry."
        exit 1
    fi

    PRE_PULL_VERSION=""
    if [ -d "${CLONE_DIR}/.git" ]; then
        PRE_PULL_VERSION=$(read_version "${SOURCE_DIR}/SKILL.md")
        log "Repo already cloned, pulling latest..."
        if ! git -C "$CLONE_DIR" pull --ff-only --quiet; then
            err "git pull failed (the local clone may have diverged from upstream)."
            err "To recover, remove the clone and re-run the installer:"
            err "  rm -rf '$CLONE_DIR'"
            exit 1
        fi
        ok "Repo updated"
    else
        log "Cloning ${REPO_URL}..."
        mkdir -p "$(dirname "$CLONE_DIR")"
        if ! git clone --depth 1 --branch "$REPO_BRANCH" --quiet "$REPO_URL" "$CLONE_DIR"; then
            err "git clone failed. Check your network and that the repo URL is reachable:"
            err "  $REPO_URL"
            exit 1
        fi
        ok "Repo cloned"
    fi

    if [ ! -f "${SOURCE_DIR}/SKILL.md" ]; then
        err "Repo does not contain ${SKILL_PATH_IN_REPO}/SKILL.md"
        exit 1
    fi

    POST_PULL_VERSION=$(read_version "${SOURCE_DIR}/SKILL.md")
    if [ -n "$PRE_PULL_VERSION" ] && [ "$PRE_PULL_VERSION" != "$POST_PULL_VERSION" ]; then
        log "Source version: ${PRE_PULL_VERSION} → ${POST_PULL_VERSION}"
    else
        log "Source version: ${POST_PULL_VERSION:-unknown}"
    fi
    echo
fi

NEW_VERSION=$(read_version "${SOURCE_DIR}/SKILL.md")

# ─────────────────────────────────────────────────────────
# Decide which targets to install / update
# ─────────────────────────────────────────────────────────

# Use an indexed array so custom paths with spaces survive intact.
TARGETS_TO_INSTALL=()

if [ -n "$TARGET_ARG" ]; then
    TARGETS_TO_INSTALL+=("$TARGET_ARG")
    log "Target: $TARGET_ARG (explicit)"
else
    EXISTING=$(find_existing)
    if [ -n "$EXISTING" ]; then
        # find_existing returns only known target names (no spaces),
        # so word-splitting here is safe.
        for n in $EXISTING; do
            TARGETS_TO_INSTALL+=("$n")
        done
        log "Found existing installations — updating all:"
        for n in "${TARGETS_TO_INSTALL[@]}"; do
            log "  • $n"
        done
    else
        DEFAULT=$(smart_default)
        TARGETS_TO_INSTALL+=("$DEFAULT")
        log "No existing installations found."
        log "Installing to smart default: $DEFAULT"
        log "(use --target <name> to override; --help for the full list)"
    fi
fi
echo

# ─────────────────────────────────────────────────────────
# Install / update each target
# ─────────────────────────────────────────────────────────

for name in "${TARGETS_TO_INSTALL[@]}"; do
    install_one "$name" "$SOURCE_DIR" "$NEW_VERSION"
done

echo
echo "Done. Skill version: v${NEW_VERSION:-unknown}"
echo
if [ "$MODE" = "local" ]; then
    echo "  Update later:  cd $REPO_ROOT && git pull"
    echo "  Or re-run:     ${BASH_SOURCE[0]}"
else
    echo "  Update later:  cd $REPO_ROOT && git pull"
    echo "  Or re-run:     curl -sSL https://raw.githubusercontent.com/dim-s/indie-gamedev-knowledge-base/${REPO_BRANCH}/OGD/ogd-methodology/install.sh | bash"
fi
echo "  Check status:  $0 --check    (or re-run installer)"
echo "  Uninstall:     rm <path-shown-by---check>"
