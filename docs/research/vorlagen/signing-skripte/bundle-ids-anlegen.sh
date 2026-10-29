#!/usr/bin/env bash
# Schritt 1 (vor dem Portal): legt die zwei Bundle IDs an und schaltet die Faehigkeiten ein. Mehrfach startbar (legt nichts doppelt an).
# Danach Handarbeit im Portal: App Group anlegen und zuweisen (Abschnitt 5 von konfiguration.md), App-Eintrag in App Store Connect.
set -euo pipefail
cd "$(dirname "$0")"
asc() { node asc.mjs "$@" | tail -n +2; }
bundle() { # IDENT NAME -> gibt die Ressourcen-ID aus
  local ident="$1" name="$2" id
  id=$(asc GET "/v1/bundleIds?filter[identifier]=$ident" | jq -r --arg i "$ident" '[.data[]|select(.attributes.identifier==$i)][0].id // empty')
  if [ -z "$id" ]; then
    id=$(asc POST /v1/bundleIds "{\"data\":{\"type\":\"bundleIds\",\"attributes\":{\"identifier\":\"$ident\",\"name\":\"$name\",\"platform\":\"IOS\"}}}" | jq -r '.data.id // empty')
  fi
  [ -n "$id" ] || { echo "FEHLER: Bundle ID $ident nicht angelegt" >&2; exit 1; }
  echo "$id"
}
faehigkeit() { # RESSOURCEN-ID TYP
  local vorhanden
  vorhanden=$(asc GET "/v1/bundleIds/$1/bundleIdCapabilities" | jq -r --arg t "$2" '[.data[]|select(.attributes.capabilityType==$t)]|length')
  if [ "$vorhanden" = "0" ]; then
    # HEALTHKIT per API ist hier noch nicht erprobt (APP_GROUPS ist es): bei 4xx die Meldung lesen, sonst im Portal einschalten.
    asc POST /v1/bundleIdCapabilities "{\"data\":{\"type\":\"bundleIdCapabilities\",\"attributes\":{\"capabilityType\":\"$2\"},\"relationships\":{\"bundleId\":{\"data\":{\"type\":\"bundleIds\",\"id\":\"$1\"}}}}}" \
      | jq -r '(.errors[0].detail // "ok")' | sed "s/^/$2: /"
  else
    echo "$2: schon da"
  fi
}
APP=$(bundle com.onlyus.lumen-fit "Lumen Fit")
WID=$(bundle com.onlyus.lumen-fit.widgets "Lumen Fit Widgets")
echo "Bundle IDs: App $APP, Widgets $WID"
faehigkeit "$APP" APP_GROUPS
faehigkeit "$APP" HEALTHKIT
faehigkeit "$WID" APP_GROUPS
