#!/usr/bin/env bash
# Packs Webling.Tailwind under a throwaway version, builds tests/Webling.Tailwind.Sample against it from a local feed
# into a private packages folder, and checks the compiled stylesheet. Runs in CI on Linux, Windows and macOS.
set -euo pipefail
cd "$(dirname "$0")/.."

version="0.0.0-sample.$(date +%s)"
work="$(mktemp -d "${TMPDIR:-/tmp}/webling-tailwind.XXXXXX")"
trap 'rm -rf "${work:?}"' EXIT
# Git Bash on Windows: hand dotnet a Windows path.
if command -v cygpath >/dev/null 2>&1; then work="$(cygpath -m "$work")"; fi
sample=tests/Webling.Tailwind.Sample
output="$sample/wwwroot/css/app.css"

dotnet pack src/Webling.Tailwind/Webling.Tailwind.csproj -c Release -o "$work/feed" -p:WeblingVersion="$version" --nologo -v q
rm -rf "${sample:?}/bin" "${sample:?}/obj" "${sample:?}/wwwroot"
dotnet build "$sample" --nologo -v q \
  --source "$work/feed" --source https://api.nuget.org/v3/index.json \
  -p:WeblingTailwindVersion="$version" -p:RestorePackagesPath="$work/packages"

[ -s "$output" ] || { echo "Tailwind wrote no $output"; exit 1; }
for class in text-brand text-4xl font-semibold; do
  grep -q "$class" "$output" || { echo "$output has no .$class"; exit 1; }
done
grep -qi "#5a3fc0" "$output" || { echo "$output lost the theme color"; exit 1; }
echo "ok    $output ($(wc -c < "$output" | tr -d ' ') bytes) with the sample's classes"
