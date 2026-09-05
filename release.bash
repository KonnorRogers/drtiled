

#!/usr/bin/env bash
#
# release.sh - pack ./lib/tiled and publish a GitHub release for specified version
#
# Usage:
#   ./release.sh              # pack + publish
#   ./release.sh --draft      # publish as a draft
#   ./release.sh --dry-run    # validate + pack, but don't touch GitHub
#
set -euo pipefail

PACK_DIR="lib/tiled"
BUILDS_DIR="builds"

TAG=""
DRY_RUN=0

# logging
die()  { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }
info() { printf '\033[32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[33mwarn:\033[0m %s\n' "$*" >&2; }

while [ $# -gt 0 ]; do
  case "$1" in
    --draft)   DRAFT=(--draft) ;;
    --dry-run) DRY_RUN=1 ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    -*)        die "unknown flag: $1" ;;
    *)         [ -z "$TAG" ] || die "tag given twice: '$TAG' and '$1'"; TAG="$1" ;;
  esac
  shift
done

[ -n "$TAG" ] || die "no tag given. Usage: $(basename "$0") vX.Y.Z [--draft] [--dry-run]"

VERSION="${TAG}"
ASSET_PREFIX="dr-tiled"
ARCHIVE="$BUILDS_DIR/${ASSET_PREFIX}-${VERSION}.tar.gz"
CHECKSUM="$BUILDS_DIR/${ASSET_PREFIX}-${VERSION}.checksum"

mkdir -p "$BUILDS_DIR"
rm -f "$ARCHIVE"

info "packing $PACK_DIR -> $ARCHIVE"

# -C makes the archive contain 'tiled/...' rather than 'lib/tiled/...'
tar czf "$ARCHIVE" -C "$(dirname "$PACK_DIR")" "$(basename "$PACK_DIR")"

if command -v sha256sum >/dev/null; then
  SHA="$(sha256sum "$ARCHIVE" | cut -d' ' -f1)"
else
  SHA="$(shasum -a 256 "$ARCHIVE" | cut -d' ' -f1)"
fi
printf '%s  %s\n' "$SHA" "$(basename "$ARCHIVE")" > "$CHECKSUM"

info "$(du -h "$ARCHIVE" | cut -f1)  sha256:${SHA:0:16}…"

git rev-parse -q --verify "refs/tags/$TAG" >/dev/null || die "tag '$TAG' does not exist locally"

if [ "$DRY_RUN" -eq 1 ]; then
  info "dry run — validation passed for $TAG, nothing published"
  exit 0
fi

info "creating release $TAG"
gh release create "$TAG" \
  "$ARCHIVE" \
  "$CHECKSUM" \
  --title "$TAG" \
  --generate-notes \
  "${DRAFT[@]}"

info "done: $(gh release view "$TAG" --json url --jq .url)"

