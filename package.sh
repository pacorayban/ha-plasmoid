#!/bin/sh
# Builds dist/hadashboard-<version>.plasmoid, the file to upload to the KDE Store
# (a zip of package/ with metadata.json at its root).
set -e
cd "$(dirname "$0")"
version=$(python3 -c "import json;print(json.load(open('package/metadata.json'))['KPlugin']['Version'])")
out="dist/hadashboard-$version.plasmoid"
mkdir -p dist
rm -f "$out"
cp LICENSE package/LICENSE
(cd package && zip -qr -X "../$out" . -x '*.qmlc' -x '*/.*')
rm package/LICENSE
echo "$out"
