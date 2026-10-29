#!/usr/bin/env bash
# Setzt die sechs Signier-Secrets des Repos (Team, p12 samt Passwort, API-Schluessel). Gibt nie einen Wert aus.
# Die zwei Profil-Secrets setzt profile-und-secrets.sh, das neunte (PRIVATE_DATEN_JSON) privat-secret.sh. Zertifikat und Schluessel sind teamweit (Lovea-Ordner, nur lesen).
set -euo pipefail
cd "$(dirname "$0")"
R=Tobito320/lumen-fit-ios
S=/mnt/windows/Users/ahmed/code/lovea-app-ios/signing
KEY_ID=$(sed -n "s/^const KEY_ID = '\(.*\)';\$/\1/p" asc.mjs)
ISSUER=$(sed -n "s/^const ISSUER = '\(.*\)';\$/\1/p" asc.mjs)
# .p12 im macOS-lesbaren Format (F-13), Passwort zufaellig, nur in einer Variablen (kein persoenliches Passwort)
P=$(openssl rand -hex 16)
P=$P openssl pkcs12 -export -certpbe PBE-SHA1-3DES -keypbe PBE-SHA1-3DES -macalg sha1 \
  -inkey "$S/Lovea-Distribution.key" -in "$S/distribution.pem" -out lumenfit.p12 -passout env:P
printf '%s' "$P" | gh secret set APPLE_CERT_PASSWORD --repo "$R"
base64 -w0 lumenfit.p12 | gh secret set APPLE_CERT_P12_BASE64 --repo "$R"
unset P
openssl x509 -in "$S/distribution.pem" -noout -subject | sed -n 's/.*UID=\([^,]*\).*/\1/p' | tr -d '\n' | gh secret set DEVELOPMENT_TEAM --repo "$R"
printf '%s' "$KEY_ID" | gh secret set ASC_KEY_ID --repo "$R"
printf '%s' "$ISSUER" | gh secret set ASC_ISSUER_ID --repo "$R"
base64 -w0 "$S/AuthKey_$KEY_ID.p8" | gh secret set ASC_KEY_P8_BASE64 --repo "$R"
gh secret list --repo "$R"
