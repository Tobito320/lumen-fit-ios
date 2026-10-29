#!/usr/bin/env bash
# TestFlight-Fenster: Privat-Check und Namens-Gate, Stand prüfen, Repo kurz öffentlich, testflight.yml auf main starten, abwarten, sofort wieder privat (trap).
# Gleiche Tore wie ci-fenster.sh. Der Lauf baut origin/main: darum muss HEAD gepusht sein und ios-ci für genau diesen Commit grün.
# Aufruf nur im Hintergrund: bash scripts/testflight-fenster.sh
set -u
R="Tobito320/lumen-fit-ios"
cd "$(git rev-parse --show-toplevel)" || exit 2
PRIVAT_STRENG=1 bash scripts/pruefe-privat.sh >/dev/null 2>&1 || { echo "Privat-Check nicht sauber, Abbruch (Repo bleibt privat)"; exit 3; }
NAMEN_STRENG=1 bash scripts/namen-gate.sh >/dev/null 2>&1 || { echo "Namens-Gate nicht sauber, Abbruch (Repo bleibt privat)"; exit 3; }

git fetch origin main >/dev/null 2>&1 || { echo "git fetch fehlgeschlagen, Abbruch"; exit 2; }
sha=$(git rev-parse HEAD)
[ "$(git rev-parse origin/main)" = "$sha" ] || { echo "origin/main ist nicht HEAD ($sha): erst bash scripts/ci-fenster.sh (pusht), Abbruch"; exit 6; }
ci=$(gh run list --repo "$R" --workflow ios-ci.yml --commit "$sha" --json conclusion -q '.[0].conclusion' 2>/dev/null || true)
[ "$ci" = "success" ] || { echo "ios-ci für $sha ist nicht grün (Stand: ${ci:-kein Lauf}), Abbruch"; exit 7; }

trap 'gh repo edit "$R" --visibility private --accept-visibility-change-consequences >/dev/null 2>&1; echo "Sichtbarkeit: $(gh repo view "$R" --json visibility -q .visibility)"' EXIT
gh repo edit "$R" --visibility public --accept-visibility-change-consequences >/dev/null || { echo "Öffentlich schalten fehlgeschlagen"; exit 4; }
sleep 5
start=$(date -u -d '20 seconds ago' +%Y-%m-%dT%H:%M:%SZ)
gh workflow run testflight.yml --repo "$R" --ref main || exit 5
# Den eigenen Lauf finden (Commit und Startzeit), nicht den letzten irgendeinen: bis zu zwei Minuten.
id=""
for _ in $(seq 1 12); do
  id=$(gh run list --repo "$R" --workflow testflight.yml --json databaseId,headSha,createdAt \
    -q "[.[] | select(.headSha == \"$sha\" and .createdAt >= \"$start\")] | sort_by(.createdAt) | last | .databaseId // empty" 2>/dev/null || true)
  [ -n "$id" ] && break
  sleep 10
done
[ -n "$id" ] || { echo "Kein TestFlight-Lauf für $sha gefunden"; exit 5; }
echo "Lauf $id"
# Blockierend warten, kein Abfragen per sleep.
if gh run watch "$id" --repo "$R" --exit-status --interval 30 >/dev/null 2>&1; then
  echo "ERGEBNIS: grün ($id)"
else
  echo "ERGEBNIS: rot ($id)"
  gh run view "$id" --repo "$R" --log-failed 2>/dev/null | tail -40
  exit 1
fi
