#!/usr/bin/env bash
# TestFlight-Fenster: Privat-Check, Repo kurz öffentlich, testflight.yml auf main starten, abwarten, sofort wieder privat (trap).
# Vorher muss ios-ci auf demselben Stand grün sein (scripts/ci-fenster.sh). Aufruf nur im Hintergrund: bash scripts/testflight-fenster.sh
set -u
R="Tobito320/lumen-fit-ios"
cd "$(git rev-parse --show-toplevel)" || exit 2
PRIVAT_STRENG=1 bash scripts/pruefe-privat.sh >/dev/null 2>&1 || { echo "Privat-Check nicht sauber, Abbruch (Repo bleibt privat)"; exit 3; }
trap 'gh repo edit "$R" --visibility private --accept-visibility-change-consequences >/dev/null 2>&1; echo "Sichtbarkeit: $(gh repo view "$R" --json visibility -q .visibility)"' EXIT
gh repo edit "$R" --visibility public --accept-visibility-change-consequences >/dev/null || { echo "Öffentlich schalten fehlgeschlagen"; exit 4; }
sleep 5
gh workflow run testflight.yml --repo "$R" --ref main || exit 5
sleep 15
id=$(gh run list --repo "$R" --workflow testflight.yml -L1 --json databaseId -q '.[0].databaseId')
echo "Lauf $id"
# Blockierend warten, kein Abfragen per sleep.
if gh run watch "$id" --repo "$R" --exit-status --interval 30 >/dev/null 2>&1; then
  echo "ERGEBNIS: grün ($id)"
else
  echo "ERGEBNIS: rot ($id)"
  gh run view "$id" --repo "$R" --log-failed 2>/dev/null | tail -40
  exit 1
fi
