#!/bin/bash
set -euo pipefail

usage() {
    echo "Uso: scripts/release.sh [--dry-run] <versão X.Y.Z>" >&2
    exit 64
}

fail() {
    echo "Erro: $*" >&2
    exit 1
}

dry_run=false
version=""
for arg in "$@"; do
    case "$arg" in
        --dry-run) dry_run=true ;;
        -h|--help) usage ;;
        -*) usage ;;
        *) [[ -z "$version" ]] || usage; version="$arg" ;;
    esac
done
[[ -n "$version" ]] || usage

cd "$(dirname "$0")/.."

semver='^([0-9]+)\.([0-9]+)\.([0-9]+)$'
[[ "$version" =~ $semver ]] || fail "versão \"$version\" não está no formato X.Y.Z"

current=$(sed -n 's/^ *MARKETING_VERSION: *//p' project.yml | head -n 1)
[[ "$current" =~ $semver ]] || fail "MARKETING_VERSION do project.yml (\"$current\") não está no formato X.Y.Z"
build_number=$(sed -n 's/^ *CURRENT_PROJECT_VERSION: *//p' project.yml | head -n 1)
[[ "$build_number" =~ ^[0-9]+$ ]] || fail "CURRENT_PROJECT_VERSION do project.yml (\"$build_number\") não é um número"

version_key() {
    local IFS=.
    read -r major minor patch <<< "$1"
    printf '%05d%05d%05d' "$major" "$minor" "$patch"
}

[[ "$(version_key "$version")" > "$(version_key "$current")" || "$version" == "$current" ]] \
    || fail "versão $version é menor que a atual ($current)"

[[ -z "$(git status --porcelain)" ]] || fail "há mudanças não commitadas"
[[ "$(git branch --show-current)" == "main" ]] || fail "o release sai da branch main"

tag="v$version"
git rev-parse -q --verify "refs/tags/$tag" > /dev/null && fail "a tag $tag já existe"
gh auth status > /dev/null 2>&1 || fail "gh não está logado (rode gh auth login)"

previous_tag=$(git describe --tags --abbrev=0 --match 'v*' HEAD 2> /dev/null || true)

run() {
    if $dry_run; then
        echo "[dry-run] $*"
    else
        "$@"
    fi
}

project_changed=false
if [[ "$version" != "$current" ]]; then
    project_changed=true
    next_build=$((build_number + 1))
    echo "project.yml: $current ($build_number) -> $version ($next_build)"
    if ! $dry_run; then
        sed -i '' \
            -e "s/^\( *MARKETING_VERSION: *\).*/\1$version/" \
            -e "s/^\( *CURRENT_PROJECT_VERSION: *\).*/\1$next_build/" \
            project.yml
    fi
else
    echo "project.yml já está na versão $version ($build_number)"
fi

(cd PRumoKit && swift test)
scripts/make-dmg.sh

[[ -s build/PRumo.dmg && -s build/PRumo.dmg.sha256 ]] || fail "build/PRumo.dmg ou build/PRumo.dmg.sha256 não foi gerado"

if $project_changed; then
    run git add project.yml
    run git commit -m "chore: versão $version"
fi
run git tag -a "$tag" -m "PRumo $version"
run git push origin main --follow-tags

notes_file=$(mktemp -t prumo-release-notes)
trap 'rm -f "$notes_file"' EXIT
range="HEAD"
[[ -n "$previous_tag" ]] && range="$previous_tag..HEAD"
git log --pretty='- %s' "$range" | grep -E '^- (feat|fix)(\(|!|:)' > "$notes_file" || true
[[ -s "$notes_file" ]] || echo "- Ajustes internos." > "$notes_file"

echo "Notas do release ($range):"
cat "$notes_file"

run gh release create "$tag" build/PRumo.dmg build/PRumo.dmg.sha256 \
    --title "PRumo $version" --notes-file "$notes_file"

if $dry_run; then
    echo "[dry-run] nada foi publicado"
else
    echo "Release $tag publicado"
fi
