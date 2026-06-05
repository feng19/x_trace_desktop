#!/usr/bin/env bash
#
# Bump the app version everywhere it appears. The version must match an
# existing x_trace release tag, since the sidecar binary is downloaded
# from that release.
#
# Usage:
#   ./scripts/bump-version.sh            # use the latest x_trace release version
#   ./scripts/bump-version.sh 0.3.2      # use an explicit version
#   ./scripts/bump-version.sh 0.3.2 -f   # skip the x_trace release existence check

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
XTRACE_REPO="feng19/x_trace"

VERSION=""
FORCE=false
for arg in "$@"; do
  case "$arg" in
    -f|--force) FORCE=true ;;
    -*) echo "unknown option: $arg" >&2; exit 1 ;;
    *) VERSION="$arg" ;;
  esac
done

# No version given -> use the latest x_trace release
if [[ -z "$VERSION" ]]; then
  echo "No version given, fetching latest $XTRACE_REPO release..."
  VERSION=$(curl -fsSL "https://api.github.com/repos/$XTRACE_REPO/releases/latest" \
    | grep -m1 '"tag_name"' | sed -E 's/.*"tag_name": *"v?([^"]+)".*/\1/')
  [[ -n "$VERSION" ]] || { echo "error: could not determine latest release" >&2; exit 1; }
fi

if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "error: '$VERSION' is not a valid version (expected X.Y.Z)" >&2
  exit 1
fi

# The sidecar is downloaded from the x_trace release with this tag,
# so refuse versions that don't have one.
if [[ "$FORCE" != true ]]; then
  if ! curl -fsI -o /dev/null "https://github.com/$XTRACE_REPO/releases/tag/v$VERSION"; then
    echo "error: $XTRACE_REPO has no release tagged v$VERSION (use -f to skip this check)" >&2
    exit 1
  fi
fi

cd "$REPO_ROOT"
CURRENT=$(sed -n 's/^APP_VERSION=//p' Makefile)
echo "Bumping version: $CURRENT -> $VERSION"

export V="$VERSION"
perl -pi -e 's/^APP_VERSION=.*/APP_VERSION=$ENV{V}/' Makefile
perl -pi -e 's/^(\s*"version": ")[^"]+/$1$ENV{V}/' src-tauri/tauri.conf.json
perl -pi -e 's/^version = "[^"]+"/version = "$ENV{V}"/' src-tauri/Cargo.toml
perl -0777 -pi -e 's/(name = "x_trace"\nversion = ")[^"]+/$1$ENV{V}/' src-tauri/Cargo.lock
npm version "$VERSION" --no-git-tag-version --allow-same-version >/dev/null

# Verify every file actually carries the new version
fail=0
check() { # file, pattern
  if grep -q "$2" "$1"; then
    printf '  %-30s ok\n' "$1"
  else
    printf '  %-30s MISSING\n' "$1"; fail=1
  fi
}
check Makefile                  "^APP_VERSION=$V\$"
check package.json              "\"version\": \"$V\""
check package-lock.json         "\"version\": \"$V\""
check src-tauri/tauri.conf.json "\"version\": \"$V\""
check src-tauri/Cargo.toml      "^version = \"$V\"\$"
check src-tauri/Cargo.lock      "^version = \"$V\"\$"
[[ "$fail" == 0 ]] || { echo "error: some files were not updated" >&2; exit 1; }

echo
echo "Done. Next steps:"
echo "  make download-macos    # re-download sidecar binaries for v$VERSION"
echo "  git commit -am 'release v$VERSION' && git tag v$VERSION && git push origin master v$VERSION"
