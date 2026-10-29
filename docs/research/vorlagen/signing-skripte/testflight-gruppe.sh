#!/usr/bin/env bash
# Erst nach dem App-Eintrag in App Store Connect: interne Gruppe "Wir" (automatische Verteilung), Tester aus der Lovea-Gruppe "Wir".
# Reihenfolge ist wichtig (Erfahrung Bahnherz): 1. Sichtbarkeit der App fuer Nutzer mit eingeschraenkten Apps (sonst 409 "Tester(s) cannot be assigned"),
# 2. Gruppe anlegen (die Tester im Gruppen-POST werden still ignoriert), 3. je Person POST /v1/betaTesters mit der Gruppe.
# Gibt nur Statuscodes und Zaehler aus, nie Mail-Adressen.
set -euo pipefail
cd "$(dirname "$0")"
asc() { node asc.mjs "$@" | tail -n +2; }
st() { node asc.mjs "$@" | sed -n 1p; }
APP=$(asc GET '/v1/apps?filter[bundleId]=com.onlyus.lumen-fit' | jq -r '.data[0].id // empty')
[ -n "$APP" ] || { echo "FEHLER: App com.onlyus.lumen-fit fehlt in App Store Connect (App-Eintrag zuerst)" >&2; exit 1; }
LG=de1555e1-0004-46c6-bf85-2e6a157232ab   # Lovea, Gruppe "Wir": liefert Vornamen und Mail-Adressen der Tester
# 1. Sichtbarkeit: jeder Nutzer, der nicht alle Apps sieht (Partnerin, Rolle DEVELOPER)
for u in $(asc GET '/v1/users?limit=50' | jq -r '.data[]|select(.attributes.allAppsVisible==false)|.id'); do
  echo "Sichtbarkeit $u: $(st POST "/v1/users/$u/relationships/visibleApps" "{\"data\":[{\"type\":\"apps\",\"id\":\"$APP\"}]}")"
done
# 2. Gruppe
G=$(asc POST /v1/betaGroups "{\"data\":{\"type\":\"betaGroups\",\"attributes\":{\"name\":\"Wir\",\"isInternalGroup\":true,\"hasAccessToAllBuilds\":true,\"feedbackEnabled\":true},\"relationships\":{\"app\":{\"data\":{\"type\":\"apps\",\"id\":\"$APP\"}}}}}" | jq -r '.data.id // empty')
[ -n "$G" ] || { echo "FEHLER: Gruppe nicht angelegt" >&2; exit 1; }
echo "Gruppe $G"
# 3. Tester einzeln
n=0
while IFS=$'\t' read -r mail vorname nachname; do
  body=$(jq -n --arg m "$mail" --arg v "$vorname" --arg n "$nachname" --arg g "$G" '{data:{type:"betaTesters",attributes:{email:$m,firstName:$v,lastName:$n},relationships:{betaGroups:{data:[{type:"betaGroups",id:$g}]}}}}')
  echo "Tester $((++n)): $(st POST /v1/betaTesters "$body")"
done < <(asc GET "/v1/betaGroups/$LG/betaTesters" | jq -r '.data[]|[.attributes.email,(.attributes.firstName//""),(.attributes.lastName//"")]|@tsv')
echo "App-ID in ASC: $APP"
