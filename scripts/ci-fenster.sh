#!/usr/bin/env bash
# CI-Fenster: Historien-Check, Repo kurz öffentlich, Push, ios-ci abwarten, Repo sofort wieder privat.
# GitHub rechnet private Actions nicht ab; Läufe starten nur bei öffentlichem Repo. Nie GitHub-Billing vorschlagen.
# Aufruf (im Hintergrund, nie im Vordergrund warten): bash scripts/ci-fenster.sh [--tag NAME]
# Das Repo wird auch bei Abbruch oder Fehler wieder privat (trap).
set -u
REPO="Tobito320/lumen-fit-ios"
cd "$(git rev-parse --show-toplevel)" || exit 2
tag=""
[ "${1:-}" = "--tag" ] && tag="${2:-}"

privat_aus=$(PRIVAT_STRENG=1 bash scripts/pruefe-privat.sh) || { echo "$privat_aus"; echo "Privat-Check nicht sauber, Abbruch (Repo bleibt privat)"; exit 3; }
# Ohne Adressen in der lokalen Datei sagt der Check "EINGESCHRÄNKT": dann gilt er nicht als Beweis für "keine Adressen im Git".
echo "Privat-Check: $(printf '%s\n' "$privat_aus" | head -n 1)"
NAMEN_STRENG=1 bash scripts/namen-gate.sh || { echo "Namens-Gate nicht sauber, Abbruch (Repo bleibt privat)"; exit 3; }

zurueck() {
  # Nach dem Lauf antwortet GitHub manchmal mit einem Fehler (wie beim Push): wiederholen, bis "PRIVATE" bestätigt ist.
  local sicht=""
  for _ in 1 2 3 4 5 6; do
    gh repo edit "$REPO" --visibility private --accept-visibility-change-consequences >/dev/null 2>&1
    sicht=$(gh repo view "$REPO" --json visibility -q .visibility 2>/dev/null)
    [ "$sicht" = "PRIVATE" ] && break
    sleep 10
  done
  echo "Sichtbarkeit jetzt: $sicht"
}
trap zurueck EXIT

gh repo edit "$REPO" --visibility public --accept-visibility-change-consequences >/dev/null || { echo "Öffentlich schalten fehlgeschlagen"; exit 4; }
echo "Sichtbarkeit: $(gh repo view "$REPO" --json visibility -q .visibility)"

# Direkt nach dem Öffentlich-Schalten antwortet GitHub beim Push manchmal kurz mit 403: bis zu fünfmal wiederholen.
for versuch in 1 2 3 4 5; do
  if git push origin main >/dev/null 2>&1; then echo "Push ok (Versuch $versuch)"; break; fi
  echo "Push Versuch $versuch fehlgeschlagen"
  sleep 15
done
sha=$(git rev-parse HEAD)
id=""
# Kurz auf den vom Push ausgelösten Lauf warten (höchstens vier Minuten)
for _ in $(seq 1 24); do
  id=$(gh run list --repo "$REPO" --workflow ios-ci.yml --commit "$sha" --json databaseId -q '.[0].databaseId' 2>/dev/null || true)
  [ -n "$id" ] && break
  sleep 10
done
[ -z "$id" ] && { echo "Kein CI-Lauf für $sha gefunden"; exit 5; }
echo "Lauf: https://github.com/$REPO/actions/runs/$id"
# `gh run watch` bricht bei einem Netzfehler ab, der Lauf läuft weiter: erst als rot werten, wenn GitHub "completed" meldet.
# Würde das Repo bei einem laufenden Lauf wieder privat, bräche GitHub den Lauf ab (Ergebnis wertlos).
rc=1
for _ in $(seq 1 12); do
  if gh run watch "$id" --repo "$REPO" --exit-status --interval 30 >/dev/null 2>&1; then rc=0; break; fi
  [ "$(gh run view "$id" --repo "$REPO" --json status -q .status 2>/dev/null)" = "completed" ] && break
  sleep 20
done
if [ "$rc" = 0 ]; then
  echo "ERGEBNIS: grün ($id)"
  if [ -n "$tag" ]; then git tag -f "$tag" "$sha" && git push -f origin "$tag" 2>&1 | tail -1; fi
else
  echo "ERGEBNIS: rot ($id)"
fi
gh run view "$id" --repo "$REPO" --json jobs -q '.jobs[] | "\(.name): \(.conclusion)"'
exit "$rc"
