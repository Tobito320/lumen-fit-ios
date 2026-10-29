#!/usr/bin/env bash
# Legt beide App-Store-Profile neu an (loescht gleichnamige alte), speichert sie in signing/ und setzt die zwei Profil-Secrets.
# Nach jeder Aenderung der Faehigkeiten oder App Group neu laufen lassen. Gibt keine Schluessel aus.
set -euo pipefail
cd "$(dirname "$0")"
REPO=Tobito320/lumen-fit-ios
CERT=7Y36JLKMH5   # Apple Distribution, gueltig bis 2027-09-22
asc() { node asc.mjs "$@" | tail -n +2; }
profil() { # NAME BUNDLEID-IDENT DATEI SECRET PFLICHT-EINTRAEGE...
  local name="$1" ident="$2" datei="$3" secret="$4" bid alt pflicht
  shift 4
  bid=$(asc GET "/v1/bundleIds?filter[identifier]=$ident" | python3 -c "import sys,json;print([d['id'] for d in json.load(sys.stdin)['data'] if d['attributes']['identifier']=='$ident'][0])")
  for alt in $(asc GET "/v1/profiles?filter[name]=$name&limit=50" | python3 -c "import sys,json;print(' '.join(d['id'] for d in json.load(sys.stdin)['data'] if d['attributes']['name']=='$name'))"); do
    node asc.mjs DELETE "/v1/profiles/$alt" >/dev/null
  done
  asc POST /v1/profiles "{\"data\":{\"type\":\"profiles\",\"attributes\":{\"name\":\"$name\",\"profileType\":\"IOS_APP_STORE\"},\"relationships\":{\"bundleId\":{\"data\":{\"type\":\"bundleIds\",\"id\":\"$bid\"}},\"certificates\":{\"data\":[{\"type\":\"certificates\",\"id\":\"$CERT\"}]}}}}" \
    | python3 -c "import sys,json,base64;a=json.load(sys.stdin)['data']['attributes'];assert a['profileState']=='ACTIVE',a['profileState'];open('$datei','wb').write(base64.b64decode(a['profileContent']))"
  # Fail-fast: fehlt ein Pflicht-Eintrag (App Group, HealthKit) im Profil, bricht `xcodebuild archive` erst im TestFlight-Lauf ab.
  # Dann das Secret nicht anfassen. Ein Profil ist nach jeder Aenderung der Faehigkeiten oder Gruppen neu zu erzeugen.
  for pflicht in "$@"; do
    if ! openssl smime -inform der -verify -noverify -in "$datei" 2>/dev/null | grep -aq "$pflicht"; then
      echo "FEHLER: $name enthaelt '$pflicht' nicht. Im Apple-Portal bei der App-ID anlegen/zuweisen (Gruppe: Identifiers > App Groups; App-ID > App Groups > Configure; HealthKit: Faehigkeit), dann dieses Skript erneut starten. Secret $secret bleibt unveraendert." >&2
      exit 1
    fi
  done
  base64 -w0 "$datei" | gh secret set "$secret" --repo "$REPO"
  openssl smime -inform der -verify -noverify -in "$datei" 2>/dev/null | python3 -c "
import sys,plistlib;p=plistlib.loads(sys.stdin.buffer.read());e=p['Entitlements']
print('$name', 'Team', p['TeamIdentifier'], 'Gruppen', e.get('com.apple.security.application-groups'), 'HealthKit', 'com.apple.developer.healthkit' in e, 'bis', p['ExpirationDate'].date())"
}
# App: eigene Gruppe, Lovea-Gruppe (geteiltes Band, Kopplung) und HealthKit. Widgets: nur die eigene Gruppe.
profil "Lumen Fit App Store" com.onlyus.lumen-fit LumenFit_App_Store.mobileprovision APPSTORE_PROFILE_BASE64 \
  group.com.onlyus.lumen-fit group.com.onlyus.lovea com.apple.developer.healthkit
profil "Lumen Fit Widgets App Store" com.onlyus.lumen-fit.widgets LumenFit_Widgets_App_Store.mobileprovision APPSTORE_WIDGETS_PROFILE_BASE64 \
  group.com.onlyus.lumen-fit
