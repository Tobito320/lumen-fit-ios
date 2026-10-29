#!/usr/bin/env bash
# Setzt PRIVATE_DATEN_JSON aus der lokalen, gitignorierten LumenFit/Resources/PrivateDaten.json (kompakt, eine Zeile). Gibt nichts aus.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
jq -c . LumenFit/Resources/PrivateDaten.json | tr -d '\n' | gh secret set PRIVATE_DATEN_JSON --repo Tobito320/lumen-fit-ios
gh secret list --repo Tobito320/lumen-fit-ios | wc -l
