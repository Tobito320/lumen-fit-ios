#!/usr/bin/env bash
# Webseite (web/) nach Cloudflare Pages, Projekt lumen-fit. Die Platzhalter werden nur in einer Kopie im Temp-Ordner ersetzt, nie im Repo:
#   {{VERANTWORTLICH}}  aus ~/.config/lumen-fit/web-verantwortlich.txt (Inhalt wird nie ausgegeben; Zeilen werden zu <br>, HTML maskiert)
#   {{APPSTORE_LINK}}   aus $APPSTORE_LINK oder ~/.config/lumen-fit/appstore-link.txt (nur https://apps.apple.com/...)
# Trockenlauf: WEB_TROCKEN=1 (kein Deploy, Kopie bleibt liegen, Pfad wird genannt). Andere Dateien zum Testen: WEB_VERANTWORTLICH_DATEI, WEB_APPSTORE_DATEI.
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
verantwortlich="${WEB_VERANTWORTLICH_DATEI:-$HOME/.config/lumen-fit/web-verantwortlich.txt}"
appstore_datei="${WEB_APPSTORE_DATEI:-$HOME/.config/lumen-fit/appstore-link.txt}"

[[ -s "$verantwortlich" ]] || { echo "Fehlt oder leer: $verantwortlich" >&2; exit 1; }
link="${APPSTORE_LINK:-}"
if [[ -z "$link" && -s "$appstore_datei" ]]; then link="$(tr -d '[:space:]' < "$appstore_datei")"; fi
[[ -n "$link" ]] || { echo "Kein App-Store-Link: APPSTORE_LINK setzen oder $appstore_datei anlegen" >&2; exit 1; }

basis="$(mktemp -d "${TMPDIR:-/tmp}/lumen-fit-web.XXXXXX")"
if [[ "${WEB_TROCKEN:-0}" != "1" ]]; then trap 'rm -rf "$basis"' EXIT; fi
tmp="$basis/seite"; mkdir -p "$tmp"
cp -r "$repo/web/." "$tmp/"
# Pages Functions (Weiterleitung /kontakt und /f/<Token> an den Server) liegen neben der Seite, nie in ihr (sonst wären sie abrufbar).
cp -r "$repo/web-functions" "$basis/functions"

# Ersetzen in Python (kein sed: der Inhalt kann /, &, Umlaute und mehrere Zeilen haben). Gibt nichts vom Inhalt aus.
APPSTORE_LINK="$link" python3 -I - "$tmp" "$verantwortlich" <<'PY'
import html, os, pathlib, re, sys
ziel, datei = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
link = os.environ["APPSTORE_LINK"]
if not re.fullmatch(r"https://apps\.apple\.com/(?:[a-z]{2}/)?app/(?:[a-z0-9-]{1,80}/)?id\d{6,12}", link):
    sys.exit("App-Store-Link hat nicht die Form https://apps.apple.com/.../id123456789")
zeilen = [z.strip() for z in datei.read_text(encoding="utf-8").splitlines() if z.strip()]
if not zeilen:
    sys.exit("Verantwortlich-Datei ist leer")
wer = "<br>".join(html.escape(z) for z in zeilen)
seiten = sorted(ziel.rglob("*.html"))
for seite in seiten:
    text = seite.read_text(encoding="utf-8").replace("{{VERANTWORTLICH}}", wer).replace("{{APPSTORE_LINK}}", html.escape(link))
    if "{{" in text:
        sys.exit(f"Platzhalter übrig in {seite.relative_to(ziel)}")
    seite.write_text(text, encoding="utf-8")
print(f"{len(seiten)} Seiten vorbereitet")
PY

if [[ "${WEB_TROCKEN:-0}" == "1" ]]; then
  echo "Trockenlauf: kein Deploy. Kopie: $basis"
  exit 0
fi
cd "$basis"
"$repo/server/node_modules/.bin/wrangler" pages deploy seite --project-name lumen-fit --commit-dirty=true
