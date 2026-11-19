#!/usr/bin/env bash
# Prints a release's notes for <tag>: what the release brings first — the
# release commit's own words ("What's new"), which the app's update dialog
# reads (app/lib/app_info.dart, plainReleaseNotes) — and then README.md's
# download table, linking to this release's own files (their versioned
# names, Fali-VPN-1.2.3-...).
#
#   bash scripts/release-notes.sh v1.1.1
set -euo pipefail

tag="${1:?usage: release-notes.sh <tag>}"
version="${tag#v}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "## What's new"
echo
# The release commit's message, without its trailing "— v1.8.1" and its
# blank lines: it is the version's own words.
git log -1 --format=%B |
  sed -e 's/[[:space:]]*—[[:space:]]*v[0-9][0-9.]*[[:space:]]*$//' \
      -e '/^[[:space:]]*$/d'
echo
echo "## Download"
echo
# The table alone, from <table> to </table>.
awk '/^<table>/ { p = 1 } p { print } /^<\/table>/ && p { exit }' "$root/README.md" |
  sed -e "s|releases/latest/download/Fali-VPN-|releases/download/$tag/Fali-VPN-$version-|g" \
      -e "s|releases/latest/download/fali-vpn-core-|releases/download/$tag/fali-vpn-core-$version-|g" \
      -e "s|releases/latest/download/|releases/download/$tag/|g"
