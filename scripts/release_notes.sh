#!/usr/bin/env bash
#
# Release-notes helpers used by the release workflows. Works on any machine
# with git and bash; run from inside the repository.
#
#   release_notes.sh previous-tag <tag>          Tag to diff the release against
#   release_notes.sh commits <from> [to]         Markdown commit list with authors
#   release_notes.sh summary <from> [to]         Fallback summary from commit prefixes
#   release_notes.sh ai-input <from> [to]        Commits + diffstat fed to the AI model
#   release_notes.sh body <tag> <version> <from> <summary-file> [sha256-file]
#                                                Full release body (markdown)
#
# <from> may be empty ("") for the very first release; the whole history is used.
#
set -euo pipefail

REPO="${GITHUB_REPOSITORY:-antonioaren/vimotion}"
REPO_URL="https://github.com/$REPO"
STABLE_RE='^v[0-9]+\.[0-9]+\.[0-9]+$'

range() {
    local from="$1" to="${2:-HEAD}"
    if [[ -n "$from" ]]; then echo "$from..$to"; else echo "$to"; fi
}

# Only meaningful for tags of the same shape (two stables, or two betas of the
# same X.Y.Z line), which is all previous_tag compares.
version_lt() {
    [[ "$1" != "$2" && "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1)" == "$1" ]]
}

# Highest stable tag below <tag>, or — for a beta — the previous beta of the
# same X.Y.Z line, falling back to the latest stable below X.Y.Z.
previous_tag() {
    local tag="$1" base="${1%%-*}" t
    local sorted
    sorted="$(git tag --list 'v[0-9]*' | sort -rV)"

    if [[ "$tag" != "$base" ]]; then
        while IFS= read -r t; do
            if [[ "$t" == "$base-"* ]] && version_lt "$t" "$tag"; then echo "$t"; return; fi
        done <<< "$sorted"
    fi
    while IFS= read -r t; do
        if [[ "$t" =~ $STABLE_RE ]] && version_lt "$t" "$base"; then echo "$t"; return; fi
    done <<< "$sorted"
}

commits() {
    git log --no-merges --pretty="- %s ([%h]($REPO_URL/commit/%H)) — %an" "$(range "$@")"
}

summary() {
    local feats fixes others
    local log
    log="$(git log --no-merges --pretty='%s' "$(range "$@")")"
    strip() { sed -E 's/^[a-zA-Z]+(\([^)]*\))?!?:[[:space:]]*//; s/^/- /'; }
    feats="$(grep -E '^feat(\(|!|:)' <<< "$log" | strip || true)"
    fixes="$(grep -E '^fix(\(|!|:)' <<< "$log" | strip || true)"
    others="$(grep -vE '^(feat|fix)(\(|!|:)' <<< "$log" | strip || true)"

    [[ -n "$feats" ]] && printf '### New\n%s\n\n' "$feats"
    [[ -n "$fixes" ]] && printf '### Fixes\n%s\n\n' "$fixes"
    [[ -n "$others" ]] && printf '### Internal\n%s\n\n' "$others"
    [[ -z "$log" ]] && echo "- No changes since the previous release."
    return 0
}

ai_input() {
    echo "Commits (subject — author):"
    git log --no-merges --pretty='- %s — %an' "$(range "$@")"
    echo
    echo "Diffstat:"
    if [[ -n "$1" ]]; then
        git diff --stat "$1" "${2:-HEAD}"
    else
        git show --stat --format= "${2:-HEAD}"
    fi
}

body() {
    local tag="$1" version="$2" from="$3" summary_file="$4" sha_file="${5:-}"
    local dmg="vimotion-$version.dmg"
    local dl="$REPO_URL/releases/download/$tag"

    echo "## What's changed"
    echo
    sed -e '$a\' "$summary_file"
    echo
    echo "## Commits"
    echo
    commits "$from"
    echo
    if [[ -n "$from" ]]; then
        echo "**Full diff:** $REPO_URL/compare/$from...$tag"
        echo
    fi
    echo "## Download"
    echo
    echo "| File | Use |"
    echo "|------|-----|"
    echo "| [$dmg]($dl/$dmg) | Fresh install: open it and drag **vimotion** to **Applications** |"
    echo "| [vimotion.zip]($dl/vimotion.zip) | Used by the in-app updater |"
    echo
    if [[ -n "$sha_file" && -f "$sha_file" ]]; then
        echo "SHA-256 (\`vimotion.zip\`): \`$(tr -d '[:space:]' < "$sha_file")\`"
        echo
    fi
    echo "> **First launch:** vimotion isn't notarized yet, so right-click the app and choose **Open** the first time."
    echo "> After installing or updating, macOS may ask you to grant **Accessibility** access again."
    echo ">"
    echo "> **Coming from 1.0.0?** That version has no built-in updater — install this \`.dmg\` manually once; later updates arrive from the menu bar."
}

cmd="${1:-}"; shift || true
case "$cmd" in
    previous-tag) previous_tag "$@" ;;
    commits)      commits "${1:-}" "${2:-HEAD}" ;;
    summary)      summary "${1:-}" "${2:-HEAD}" ;;
    ai-input)     ai_input "${1:-}" "${2:-HEAD}" ;;
    body)         body "$@" ;;
    *)
        sed -n '3,13p' "$0" >&2
        exit 1
        ;;
esac
