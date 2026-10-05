#!/usr/bin/env bash
# Zabalí widget do .plasmoid (zip s metadata.json v kořeni) pro KDE Store / ruční instalaci.
set -euo pipefail
cd "$(dirname "$0")"

id=$(python3 -c 'import json; print(json.load(open("package/metadata.json"))["KPlugin"]["Id"])')
version=$(python3 -c 'import json; print(json.load(open("package/metadata.json"))["KPlugin"]["Version"])')
out="$PWD/$id-$version.plasmoid"

rm -f "$out"
(cd package && zip -qr "$out" . -x '*.swp' '*~')
echo "Vytvořeno: $out"
