#!/usr/bin/env bash
# Sammelt alle SF-Symbol-Namen aus den Swift-Quellen in LumenFit/Tests/Fixtures/System/symbole.txt.
# Läuft in CI auf demselben Runner VOR xcodegen generate (die Ordnerreferenz nimmt die Datei mit).
# Läuft auch auf macOS (bash 3.2, BSD sed/grep): keine Bash-4-Funktionen.
set -eu
cd "$(dirname "$0")/.."
ziel="LumenFit/Tests/Fixtures/System/symbole.txt"
mkdir -p "$(dirname "$ziel")"
{
  grep -rhoE '(systemName|systemImage|symbol|icon):[[:space:]]*"[A-Za-z0-9._]+"' \
    LumenFit/Sources LumenFitWidgets/Sources Gemeinsam 2>/dev/null || true
} | sed -E 's/^[A-Za-z]+:[[:space:]]*"//; s/"$//' | sort -u > "$ziel"
echo "symbole.txt: $(wc -l < "$ziel" | tr -d ' ') Namen"
