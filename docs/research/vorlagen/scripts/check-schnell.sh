#!/usr/bin/env bash
# Schnellcheck vor jedem Commit: Syntax geänderter Swift-Dateien, JSON, Shell, Privat-Check.
# Mit --alle werden alle Swift-Dateien geprüft. Kein Compiler: fängt Tippfehler, keine Typen.
set -u
cd "$(git rev-parse --show-toplevel)" || exit 2
fehler=0

if [ "${1:-}" = "--alle" ]; then
  dateien=$(git ls-files --cached --others --exclude-standard -- '*.swift')
else
  dateien=$( { git diff --name-only HEAD -- '*.swift'; git ls-files --others --exclude-standard -- '*.swift'; } | sort -u )
fi
if [ -n "$dateien" ]; then
  echo "$dateien" | tr '\n' '\0' | xargs -0 swift-syntax-check || fehler=1
else
  echo "Keine Swift-Dateien zu prüfen"
fi

jq -e . LumenFit/Resources/PrivateDaten.beispiel.json >/dev/null || { echo "JSON kaputt: PrivateDaten.beispiel.json"; fehler=1; }
for s in scripts/*.sh; do bash -n "$s" || { echo "Shell-Syntax: $s"; fehler=1; }; done
# Workflows wie in ios-ci (actionlint plus shellcheck). Der lokale actionlint kennt das Label macos-26 noch nicht, der in CI schon.
if command -v actionlint >/dev/null 2>&1; then
  actionlint -ignore 'label "macos-26" is unknown' || fehler=1
fi
bash scripts/pruefe-privat.sh || fehler=1
# Namens-Gate (Liste liegt außerhalb des Git, siehe scripts/namen-gate.sh), Typnamen eindeutig, Umfang-Gate (kein Wecker, keine Erinnerung)
bash scripts/namen-gate.sh || fehler=1
bash scripts/typnamen-doppelt.sh || fehler=1
if git grep -n -E --untracked -e 'AlarmKit|UNCalendarNotificationTrigger' -- LumenFit/Sources LumenFitWidgets/Sources Gemeinsam; then
  echo "Umfang: Wecker oder Erinnerung gefunden (Lumen Fit ist nur Health)"; fehler=1
fi
exit "$fehler"
