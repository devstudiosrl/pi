#!/usr/bin/env bash
#
# Rebase the `printalo` branch onto an upstream release, check it, and tag it.
#
# Why this exists even though this fork has no patches
# ----------------------------------------------------
# `PATCHES.md` is empty on purpose: Printalo takes
# @earendil-works/pi-coding-agent from npm and has nothing to change in it. The
# fork is here for the day it does — a fix that cannot wait for upstream, a
# behaviour that has to differ — and a fork that has never been rebased once is
# a fork nobody knows how to rebase. So the command exists, it is run whenever
# upstream releases, and the day a patch lands it already works.
#
# Unlike pi-web-ui, upstream here tags every release, so the anchor is the tag.
#
#   ./scripts/sync-upstream.sh              sync to the newest upstream tag
#   ./scripts/sync-upstream.sh v0.84.4      sync to a specific tag
#   ./scripts/sync-upstream.sh --dry-run    say what it would do, touch nothing
#   ./scripts/sync-upstream.sh --no-build   rebase and tag, skip the checks
set -euo pipefail

UPSTREAM_REMOTE="${UPSTREAM_REMOTE:-upstream}"
BRANCH="${BRANCH:-printalo}"
PKG_JSON="${PKG_JSON:-packages/coding-agent/package.json}"
DRY=0
BUILD=1
TAG_MONTE=""
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY=1 ;;
    --no-build) BUILD=0 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) TAG_MONTE="$arg" ;;
  esac
done

say()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
stop() { printf '\033[1;31mKO \033[0m %s\n' "$*" >&2; exit 1; }

git rev-parse --git-dir >/dev/null 2>&1 || stop "not a git repository"
[ -n "$(git status --porcelain)" ] && stop "working tree not clean — commit or stash first"
git remote get-url "$UPSTREAM_REMOTE" >/dev/null 2>&1 \
  || stop "no '$UPSTREAM_REMOTE' remote. git remote add $UPSTREAM_REMOTE https://github.com/earendil-works/pi.git"

say "fetching $UPSTREAM_REMOTE"
git fetch --quiet --tags "$UPSTREAM_REMOTE"

if [ -z "$TAG_MONTE" ]; then
  TAG_MONTE="$(git tag --list 'v*' --sort=-v:refname | head -1)"
  [ -n "$TAG_MONTE" ] || stop "no v* tag found upstream"
fi
git rev-parse -q --verify "refs/tags/$TAG_MONTE" >/dev/null || stop "no such tag: $TAG_MONTE"
VERSION="$(git show "$TAG_MONTE:$PKG_JSON" | sed -n 's/^[[:space:]]*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
[ -n "$VERSION" ] || stop "cannot read the package version at $TAG_MONTE"
say "target: $TAG_MONTE (@earendil-works/pi-coding-agent $VERSION)"

if git merge-base --is-ancestor "$TAG_MONTE" "$BRANCH"; then
  say "$BRANCH already sits on $TAG_MONTE — nothing to rebase"
else
  if [ "$DRY" = 1 ]; then
    say "would rebase $BRANCH onto $TAG_MONTE; patches that would replay:"
    git log --oneline "$(git merge-base "$BRANCH" "$TAG_MONTE")..$BRANCH" | sed 's/^/    /'
    exit 0
  fi
  say "rebasing $BRANCH onto $TAG_MONTE"
  git checkout --quiet "$BRANCH"
  git rebase "$TAG_MONTE" || stop "rebase stopped on a conflict. Fix it, 'git rebase --continue', then run this again."
fi

[ "$DRY" = 1 ] && { say "dry run: stopping before the checks"; exit 0; }

if [ "$BUILD" = 1 ]; then
  # The order upstream's CI uses: install without lifecycle scripts, build the
  # workspaces, then test. The packages import each other through dist/, so
  # testing before the build fails by the hundred on "Failed to resolve entry
  # for package @earendil-works/pi-ai" — which says nothing about the rebase.
  say "npm ci";   npm ci --ignore-scripts
  say "build";    npm run build
  say "test";     npm test
else
  say "--no-build: skipping npm ci, build and test"
fi

n=1
while git rev-parse -q --verify "refs/tags/v${VERSION}-printalo.${n}" >/dev/null; do n=$((n+1)); done
TAG="v${VERSION}-printalo.${n}"
git tag -a "$TAG" -m "pi $VERSION for Printalo"
say "tagged $TAG"
echo
echo "  git push --force-with-lease origin $BRANCH && git push origin $TAG"
