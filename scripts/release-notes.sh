#!/usr/bin/env bash
# Prints a release's notes for <tag>: the version's own "What's new"
# (docs/whatsnew/<version>.md, when it exists — the lines the app's update
# dialog shows, in the release's own words) and the README's download
# table, linking to this release's own files (their versioned names,
# Fali-VPN-1.2.3-...).
#
#   bash scripts/release-notes.sh v1.1.1
set -euo pipefail

tag="${1:?usage: release-notes.sh <tag>}"
version="${tag#v}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# The version's own words, when it has any: plain lines, no headings, no
# links — the dialog reads them as they are, and shows the app's own
# "Improvements and fixes" when this file is missing.
notes="$root/docs/whatsnew/$version.md"
if [ -f "$notes" ]; then
  cat "$notes"
  echo
  echo
fi

echo "## Download"
echo
# The table alone, from <table> to </table>.
awk '/^<table>/ { p = 1 } p { print } /^<\/table>/ && p { exit }' "$root/README.md" |
  sed -e "s|releases/latest/download/Fali-VPN-|releases/download/$tag/Fali-VPN-$version-|g" \
      -e "s|releases/latest/download/fali-vpn-core-|releases/download/$tag/fali-vpn-core-$version-|g" \
      -e "s|releases/latest/download/|releases/download/$tag/|g"
