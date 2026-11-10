#!/usr/bin/env node
// asc-store.mjs: App-Store-Seite von Lumen Fit über die App Store Connect API pflegen (ohne Web-Login).
//   node scripts/asc-store.mjs status                  Stand: Version, Sprachen, Kategorie, Preis, Länder, Build, Prüfung
//   node scripts/asc-store.mjs metadaten               Texte DE+EN aus docs/store/texte.md, Kategorie, Altersfreigabe,
//                                                      Preis kostenlos, Länder (alle außer China), Prüf-Kontakt, Copyright
//   node scripts/asc-store.mjs bilder <ordner>         Bildschirmfotos hochladen: <ordner>/<de-DE|en-US>/*.png (6,9 Zoll, 1320x2868)
//   node scripts/asc-store.mjs build <nummer>          Build an die Version 1.0 hängen
//   node scripts/asc-store.mjs einreichen              Version zur Prüfung einreichen (Freigabe danach von Hand: Veröffentlichung manuell)
// Schlüssel: ~/.config/lumen-fit/asc.json + .p8 (nur zum Signieren gelesen, nie ausgegeben). Prüf-Kontakt kommt aus der
// TestFlight-Prüfung (betaAppReviewDetail) und wird nur kopiert, nie ausgegeben. Copyright-Name aus
// ~/.config/lumen-fit/web-verantwortlich.txt (nie ausgeben, nie ins Git).
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import crypto from "node:crypto";
import { fileURLToPath } from "node:url";

const BASIS = "https://api.appstoreconnect.apple.com";
const BUNDLE = "com.onlyus.lumen-fit";
const VERSION = "1.0";
const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const cfg = JSON.parse(fs.readFileSync(path.join(os.homedir(), ".config/lumen-fit/asc.json"), "utf8"));
const schluessel = fs.readFileSync(String(cfg.keyPath).replace(/^~(?=\/)/, os.homedir()), "utf8");

let token = "", tokenZeit = 0;
function jwt() {
  const jetzt = Math.floor(Date.now() / 1000);
  if (token && jetzt - tokenZeit < 900) return token;
  const b = (o) => Buffer.from(JSON.stringify(o)).toString("base64url");
  const k = b({ alg: "ES256", kid: cfg.keyId, typ: "JWT" }), p = b({ iss: cfg.issuerId, iat: jetzt, exp: jetzt + 1200, aud: "appstoreconnect-v1" });
  token = `${k}.${p}.${crypto.createSign("SHA256").update(`${k}.${p}`).sign({ key: schluessel, dsaEncoding: "ieee-p1363" }).toString("base64url")}`;
  tokenZeit = jetzt;
  return token;
}

async function api(methode, pfad, koerper) {
  const r = await fetch(pfad.startsWith("http") ? pfad : BASIS + pfad, {
    method: methode,
    headers: { authorization: `Bearer ${jwt()}`, "content-type": "application/json" },
    body: koerper ? JSON.stringify(koerper) : undefined,
  });
  const text = await r.text();
  const j = text ? JSON.parse(text) : null;
  if (!r.ok) {
    const f = (j?.errors || []).map((e) => `${e.code}: ${e.detail || e.title}`).join(" | ");
    throw new Error(`${methode} ${pfad.split("?")[0]} -> ${r.status} ${f}`);
  }
  return j;
}
const holen = (p) => api("GET", p);
async function alle(p) {
  let j = await holen(p), d = j.data;
  while (j.links?.next) { j = await holen(j.links.next); d = d.concat(j.data); }
  return d;
}

// docs/store/texte.md: zwei Teile (Deutsch, dann nach "---" Englisch), Abschnitte "## Titel (Grenze)".
export function texte(md) {
  const [de, en] = md.split(/\n---\n/);
  const teil = (s) => {
    const o = {};
    for (const block of s.split(/\n## /).slice(1)) {
      const zeilen = block.split("\n");
      const titel = zeilen[0].replace(/\s*\(\d+.*\)\s*$/, "").trim();
      o[titel] = zeilen.slice(1).join("\n").trim();
    }
    return o;
  };
  const d = teil(de), e = teil(en);
  return {
    "de-DE": { name: d["Name"], subtitle: d["Untertitel"], promotionalText: d["Werbetext"], description: d["Beschreibung"], keywords: d["Stichwörter"], supportUrl: d["Support-URL"], privacyPolicyUrl: d["Datenschutz-URL"] },
    "en-US": { name: e["Name"], subtitle: e["Subtitle"], promotionalText: e["Promotional text"], description: e["Description"], keywords: e["Keywords"], supportUrl: e["Support URL"], privacyPolicyUrl: e["Privacy URL"] },
    pruefhinweis: d["Prüfhinweise für Apple (Englisch)"],
  };
}

function pruefeGrenzen(t) {
  const grenzen = { name: 30, subtitle: 30, promotionalText: 170, description: 4000, keywords: 100 };
  for (const loc of ["de-DE", "en-US"]) for (const [k, n] of Object.entries(grenzen)) {
    const v = t[loc][k];
    if (!v) throw new Error(`${loc} ${k} fehlt in texte.md`);
    if ([...v].length > n) throw new Error(`${loc} ${k} zu lang: ${[...v].length} > ${n}`);
  }
}

async function kontext() {
  const app = (await holen(`/v1/apps?filter[bundleId]=${BUNDLE}`)).data[0];
  const infos = await alle(`/v1/apps/${app.id}/appInfos`);
  const info = infos.find((i) => i.attributes.state !== "READY_FOR_DISTRIBUTION" && i.attributes.state !== "REPLACED_WITH_NEW_INFO") || infos[0];
  const versionen = await alle(`/v1/apps/${app.id}/appStoreVersions?filter[platform]=IOS`);
  const version = versionen.find((v) => v.attributes.versionString === VERSION);
  if (!version) throw new Error(`Version ${VERSION} fehlt in App Store Connect`);
  return { app, info, version };
}

async function lokalisierungen(t, { app, info, version }) {
  // Englisch als Hauptsprache: Länder ohne eigene Sprache sehen Englisch, Deutschland/Österreich/Schweiz Deutsch.
  if (app.attributes.primaryLocale !== "en-US") {
    const infoLocs0 = await alle(`/v1/appInfos/${info.id}/appInfoLocalizations`);
    if (!infoLocs0.some((l) => l.attributes.locale === "en-US"))
      await api("POST", "/v1/appInfoLocalizations", { data: { type: "appInfoLocalizations", attributes: { locale: "en-US", name: t["en-US"].name }, relationships: { appInfo: { data: { type: "appInfos", id: info.id } } } } });
    await api("PATCH", `/v1/apps/${app.id}`, { data: { type: "apps", id: app.id, attributes: { primaryLocale: "en-US" } } });
    console.log("Hauptsprache en-US");
  }
  const infoLocs = await alle(`/v1/appInfos/${info.id}/appInfoLocalizations`);
  const verLocs = await alle(`/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations`);
  for (const loc of ["en-US", "de-DE"]) {
    const x = t[loc];
    const ia = { name: x.name, subtitle: x.subtitle, privacyPolicyUrl: x.privacyPolicyUrl };
    const il = infoLocs.find((l) => l.attributes.locale === loc);
    if (il) await api("PATCH", `/v1/appInfoLocalizations/${il.id}`, { data: { type: "appInfoLocalizations", id: il.id, attributes: ia } });
    else await api("POST", "/v1/appInfoLocalizations", { data: { type: "appInfoLocalizations", attributes: { locale: loc, ...ia }, relationships: { appInfo: { data: { type: "appInfos", id: info.id } } } } });
    const va = { description: x.description, keywords: x.keywords, promotionalText: x.promotionalText, supportUrl: x.supportUrl, marketingUrl: x.supportUrl.replace(/(en\/)?support\.html$/, "$1").replace(/\/$/, "/") };
    const vl = verLocs.find((l) => l.attributes.locale === loc);
    if (vl) await api("PATCH", `/v1/appStoreVersionLocalizations/${vl.id}`, { data: { type: "appStoreVersionLocalizations", id: vl.id, attributes: va } });
    else await api("POST", "/v1/appStoreVersionLocalizations", { data: { type: "appStoreVersionLocalizations", attributes: { locale: loc, ...va }, relationships: { appStoreVersion: { data: { type: "appStoreVersions", id: version.id } } } } });
    console.log("Texte", loc, "ok");
  }
}

async function kategorieUndAlter({ info }) {
  await api("PATCH", `/v1/appInfos/${info.id}`, { data: { type: "appInfos", id: info.id, relationships: {
    primaryCategory: { data: { type: "appCategories", id: "HEALTH_AND_FITNESS" } },
    secondaryCategory: { data: { type: "appCategories", id: "SPORTS" } },
  } } });
  console.log("Kategorie Gesundheit und Fitness, Sport");
  const ar = (await holen(`/v1/appInfos/${info.id}/ageRatingDeclaration`)).data;
  const keine = "NONE";
  await api("PATCH", `/v1/ageRatingDeclarations/${ar.id}`, { data: { type: "ageRatingDeclarations", id: ar.id, attributes: {
    // Spitzname in der öffentlichen Liste (Stats "Alle") ist Nutzerinhalt, mit Melden/Blockieren. Kein Chat, keine Werbung.
    userGeneratedContent: true, messagingAndChat: false, advertising: false, gambling: false, lootBox: false,
    unrestrictedWebAccess: false, parentalControls: false, ageAssurance: false, healthOrWellnessTopics: true, socialMedia: false, contests: keine,
    alcoholTobaccoOrDrugUseOrReferences: keine, gamblingSimulated: keine, horrorOrFearThemes: keine, matureOrSuggestiveThemes: keine,
    medicalOrTreatmentInformation: keine, profanityOrCrudeHumor: keine, sexualContentGraphicAndNudity: keine, sexualContentOrNudity: keine,
    violenceCartoonOrFantasy: keine, violenceRealistic: keine, violenceRealisticProlongedGraphicOrSadistic: keine, gunsOrOtherWeapons: keine,
  } } });
  console.log("Altersfreigabe-Fragen gesetzt");
}

async function preisUndLaender({ app }) {
  let kostenlos = null;
  for (const p of await alle(`/v1/apps/${app.id}/appPricePoints?filter[territory]=USA&limit=200`)) if (Number(p.attributes.customerPrice) === 0) { kostenlos = p; break; }
  if (!kostenlos) throw new Error("kein Preis-Punkt 0,00 gefunden");
  await api("POST", "/v1/appPriceSchedules", {
    data: { type: "appPriceSchedules", relationships: {
      app: { data: { type: "apps", id: app.id } },
      baseTerritory: { data: { type: "territories", id: "USA" } },
      manualPrices: { data: [{ type: "appPrices", id: "${preis}" }] },
    } },
    included: [{ type: "appPrices", id: "${preis}", attributes: { startDate: null }, relationships: { appPricePoint: { data: { type: "appPricePoints", id: kostenlos.id } } } }],
  });
  console.log("Preis kostenlos");
  const gebiete = await alle("/v1/territories?limit=200");
  // China (Festland) braucht eine ICP-Lizenz: ausgenommen. Alle anderen Länder.
  const verfuegbar = gebiete.filter((g) => g.id !== "CHN");
  let vorhanden = null;
  try { vorhanden = (await holen(`/v1/apps/${app.id}/appAvailabilityV2`)).data; } catch { /* noch keine */ }
  if (vorhanden) { console.log("Länder schon gesetzt (Änderung in App Store Connect)"); return; }
  await api("POST", "/v2/appAvailabilities", {
    data: { type: "appAvailabilities", attributes: { availableInNewTerritories: true }, relationships: {
      app: { data: { type: "apps", id: app.id } },
      territoryAvailabilities: { data: gebiete.map((g) => ({ type: "territoryAvailabilities", id: `\${t-${g.id}}` })) },
    } },
    included: gebiete.map((g) => ({ type: "territoryAvailabilities", id: `\${t-${g.id}}`, attributes: { available: g.id !== "CHN" },
      relationships: { territory: { data: { type: "territories", id: g.id } } } })),
  });
  console.log("Länder:", verfuegbar.length, "von", gebiete.length, "(ohne China)");
}

async function pruefung(t, { app, version }) {
  const beta = (await holen(`/v1/apps/${app.id}/betaAppReviewDetail`)).data.attributes;
  const a = { contactFirstName: beta.contactFirstName, contactLastName: beta.contactLastName, contactPhone: beta.contactPhone, contactEmail: beta.contactEmail, demoAccountRequired: false, notes: t.pruefhinweis };
  let d = null;
  try { d = (await holen(`/v1/appStoreVersions/${version.id}/appStoreReviewDetail`)).data; } catch { /* noch keiner */ }
  if (d) await api("PATCH", `/v1/appStoreReviewDetails/${d.id}`, { data: { type: "appStoreReviewDetails", id: d.id, attributes: a } });
  else await api("POST", "/v1/appStoreReviewDetails", { data: { type: "appStoreReviewDetails", attributes: a, relationships: { appStoreVersion: { data: { type: "appStoreVersions", id: version.id } } } } });
  console.log("Prüf-Kontakt (aus TestFlight übernommen) und Hinweise gesetzt");
  const name = fs.readFileSync(path.join(os.homedir(), ".config/lumen-fit/web-verantwortlich.txt"), "utf8").trim().split("\n")[0];
  await api("PATCH", `/v1/appStoreVersions/${version.id}`, { data: { type: "appStoreVersions", id: version.id, attributes: { copyright: `2026 ${name}`, releaseType: "AFTER_APPROVAL" } } });
  await api("PATCH", `/v1/apps/${app.id}`, { data: { type: "apps", id: app.id, attributes: { contentRightsDeclaration: "DOES_NOT_USE_THIRD_PARTY_CONTENT" } } });
  console.log("Copyright, Freigabe manuell, Inhaltsrechte gesetzt");
}

async function status() {
  const k = await kontext();
  const { app, info, version } = k;
  console.log("App", app.id, "Hauptsprache", app.attributes.primaryLocale);
  console.log("Version", version.attributes.versionString, version.attributes.appStoreState || version.attributes.appVersionState);
  for (const l of await alle(`/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations`)) {
    const a = l.attributes;
    const sets = await alle(`/v1/appStoreVersionLocalizations/${l.id}/appScreenshotSets`);
    let bilder = 0;
    for (const s of sets) bilder += (await alle(`/v1/appScreenshotSets/${s.id}/appScreenshots`)).length;
    console.log(" ", a.locale, "Beschreibung", (a.description || "").length, "Stichwörter", (a.keywords || "").length, "Bilder", bilder);
  }
  const kat = (await holen(`/v1/appInfos/${info.id}/primaryCategory`)).data;
  console.log("Kategorie", kat?.id || "-");
  try { const b = (await holen(`/v1/appStoreVersions/${version.id}/build`)).data; console.log("Build", b ? b.attributes.version : "-"); } catch { console.log("Build -"); }
  try { const v = (await holen(`/v1/apps/${app.id}/appAvailabilityV2`)).data; console.log("Länder gesetzt", v.attributes.availableInNewTerritories ? "(auch neue)" : ""); } catch { console.log("Länder -"); }
}

async function bilder(ordner, { version }) {
  const verLocs = await alle(`/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations`);
  for (const loc of ["de-DE", "en-US"]) {
    const dir = path.join(ordner, loc);
    if (!fs.existsSync(dir)) continue;
    const dateien = fs.readdirSync(dir).filter((f) => f.endsWith(".png")).sort();
    const vl = verLocs.find((l) => l.attributes.locale === loc);
    if (!vl) throw new Error(`${loc} fehlt (erst metadaten)`);
    let set = (await alle(`/v1/appStoreVersionLocalizations/${vl.id}/appScreenshotSets`)).find((s) => s.attributes.screenshotDisplayType === "APP_IPHONE_67");
    if (set) for (const alt of await alle(`/v1/appScreenshotSets/${set.id}/appScreenshots`)) await api("DELETE", `/v1/appScreenshots/${alt.id}`);
    else set = (await api("POST", "/v1/appScreenshotSets", { data: { type: "appScreenshotSets", attributes: { screenshotDisplayType: "APP_IPHONE_67" }, relationships: { appStoreVersionLocalization: { data: { type: "appStoreVersionLocalizations", id: vl.id } } } } })).data;
    for (const f of dateien) {
      const daten = fs.readFileSync(path.join(dir, f));
      const s = (await api("POST", "/v1/appScreenshots", { data: { type: "appScreenshots", attributes: { fileName: f, fileSize: daten.length }, relationships: { appScreenshotSet: { data: { type: "appScreenshotSets", id: set.id } } } } })).data;
      for (const op of s.attributes.uploadOperations) {
        const r = await fetch(op.url, { method: op.method, headers: Object.fromEntries(op.requestHeaders.map((h) => [h.name, h.value])), body: daten.subarray(op.offset, op.offset + op.length) });
        if (!r.ok) throw new Error(`Hochladen ${f} ${r.status}`);
      }
      const md5 = crypto.createHash("md5").update(daten).digest("hex");
      await api("PATCH", `/v1/appScreenshots/${s.id}`, { data: { type: "appScreenshots", id: s.id, attributes: { uploaded: true, sourceFileChecksum: md5 } } });
      console.log(loc, f, "hochgeladen");
    }
  }
}

async function buildSetzen(nummer, { app, version }) {
  const b = (await holen(`/v1/builds?filter[app]=${app.id}&filter[version]=${nummer}&filter[preReleaseVersion.version]=${VERSION}`)).data[0];
  if (!b) throw new Error(`Build ${nummer} mit Version ${VERSION} nicht gefunden (noch in Verarbeitung?)`);
  if (b.attributes.processingState !== "VALID") throw new Error(`Build ${nummer}: ${b.attributes.processingState}`);
  await api("PATCH", `/v1/appStoreVersions/${version.id}/relationships/build`, { data: { type: "builds", id: b.id } });
  console.log("Build", nummer, "an Version", VERSION);
}

async function einreichen({ app, version }) {
  // Besitzer 10.11.2026: "We want the app public in app store": nach Apples Freigabe sofort öffentlich.
  await api("PATCH", `/v1/appStoreVersions/${version.id}`, { data: { type: "appStoreVersions", id: version.id, attributes: { releaseType: "AFTER_APPROVAL" } } });
  const offen = (await holen(`/v1/reviewSubmissions?filter[app]=${app.id}&filter[state]=READY_FOR_REVIEW,UNRESOLVED_ISSUES&filter[platform]=IOS`)).data[0];
  const sub = offen || (await api("POST", "/v1/reviewSubmissions", { data: { type: "reviewSubmissions", attributes: { platform: "IOS" }, relationships: { app: { data: { type: "apps", id: app.id } } } } })).data;
  const items = await alle(`/v1/reviewSubmissions/${sub.id}/items`);
  if (!items.length) await api("POST", "/v1/reviewSubmissionItems", { data: { type: "reviewSubmissionItems", relationships: { reviewSubmission: { data: { type: "reviewSubmissions", id: sub.id } }, appStoreVersion: { data: { type: "appStoreVersions", id: version.id } } } } });
  await api("PATCH", `/v1/reviewSubmissions/${sub.id}`, { data: { type: "reviewSubmissions", id: sub.id, attributes: { submitted: true } } });
  console.log("Eingereicht zur Prüfung");
}

const [befehl, arg] = process.argv.slice(2);
try {
  if (befehl === "selbsttest") {
    const t = texte(fs.readFileSync(path.join(repo, "docs/store/texte.md"), "utf8"));
    pruefeGrenzen(t);
    if (!t.pruefhinweis) throw new Error("Prüfhinweis fehlt");
    console.log("selbsttest ok", Object.fromEntries(["de-DE", "en-US"].map((l) => [l, [...t[l].description].length])));
  } else if (befehl === "status") await status();
  else {
    const k = await kontext();
    const t = texte(fs.readFileSync(path.join(repo, "docs/store/texte.md"), "utf8"));
    if (befehl === "metadaten") {
      pruefeGrenzen(t);
      await lokalisierungen(t, k);
      await kategorieUndAlter(k);
      await preisUndLaender(k);
      await pruefung(t, k);
    } else if (befehl === "bilder" && arg) await bilder(path.resolve(arg), k);
    else if (befehl === "build" && arg) await buildSetzen(arg, k);
    else if (befehl === "einreichen") await einreichen(k);
    else { console.error("Aufruf: status | metadaten | bilder <ordner> | build <nummer> | einreichen | selbsttest"); process.exit(2); }
  }
} catch (e) {
  console.error(String(e.message || e));
  process.exit(1);
}
