#!/usr/bin/env bash
#
# Release macos_secure_bookmarks: verify, publish to pub.dev, then tag.
#
# Usage:
#   tool/release.sh <version>
#
# Example:
#   tool/release.sh 0.3.0
#
# Verifies the tree, publishes the current HEAD to pub.dev, then creates and
# pushes the corresponding git tag (v<version>). Fails unless the tree is
# clean, the current branch is master, pubspec.yaml carries <version>, and
# the tag does not exist yet.
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:?Usage: tool/release.sh <version> (e.g. tool/release.sh 0.3.0)}"

if [ -n "$(git status --porcelain)" ]; then
  echo "release: working tree is not clean" >&2
  exit 1
fi

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [ "$BRANCH" != "master" ]; then
  echo "release: must run on master, currently on $BRANCH" >&2
  exit 1
fi

PUBSPEC_VERSION="$(grep '^version: ' pubspec.yaml | awk '{print $2}')"
if [ "$PUBSPEC_VERSION" != "$VERSION" ]; then
  echo "release: pubspec.yaml says $PUBSPEC_VERSION, asked to release $VERSION" >&2
  exit 1
fi

if git rev-parse "v$VERSION" >/dev/null 2>&1; then
  echo "release: tag v$VERSION already exists" >&2
  exit 1
fi

echo "==> dart format --set-exit-if-changed lib test example/lib"
dart format --set-exit-if-changed lib test example/lib

echo "==> flutter analyze"
flutter analyze

echo "==> flutter analyze example"
(cd example && flutter analyze)

echo "==> flutter test"
flutter test

echo "==> flutter build macos (example)"
(cd example && flutter build macos)

echo "==> flutter pub publish --dry-run"
flutter pub publish --dry-run

echo "==> flutter pub publish --force"
flutter pub publish --force

echo "==> git tag v$VERSION"
git tag -a "v$VERSION" -m "macos_secure_bookmarks $VERSION"
git push origin "v$VERSION"

echo "release: published macos_secure_bookmarks $VERSION and pushed tag v$VERSION"
