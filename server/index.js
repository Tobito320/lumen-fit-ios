// Lumen-Fit-Server (Cloudflare Worker + D1): Konten, Einstellungen ohne Build, Lovea-Freigabe als Proxy.
// App-Wege: X-App-Key + X-Konto + X-Geheimnis. Verwaltung (/admin/*): nur X-Admin-Key.
// Reine fetch(request, env, holen)-Funktion ohne cloudflare:workers-Import -> unter Node testbar.
import { kiFoto } from "./ki-foto.js";
import { handleEssen } from "./essen.js";
import { postfachApp, postfachAdmin } from "./postfach.js";
import { coach } from "./coach.js";
import { verbindungen, autoVerbinden, partnerFuerLovea } from "./verbindungen.js";
import { NAMEN } from "./nutzung-namen.js";
import { zaehlerPruefen, gruppenPruefen, zusammenfuehren, fehlerAuswerten, auswertungBauen, IOS_FORM, GERAET_FORM } from "./nutzung.js";

const STANDARD = { profilAnlegenErlaubt: false, loveaVerbinden: false, nameAendernTage: 7, bandStandard: false, schlafBeleg: false, schlafSichtbar: false, kiFotoErlaubt: true, kiFotoLimit: 5 };
const PERSONEN = ["ahmed", "annika"];
// shortcut: harte Obergrenze statt Ratenbegrenzung gegen Massen-Registrierung; bei mehr Geräten Grenze anheben oder Cloudflare-Regel davor.
const MAX_KONTEN = 200;
const ID_FORM = /^[A-Za-z0-9_-]{16,64}$/;
const GEHEIM_FORM = /^[A-Za-z0-9_-]{32,128}$/;
const SCHLUESSEL_FORM = /^[A-Za-z][A-Za-z0-9_]{0,40}$/;
const MAX_EINSTELLUNGEN_BYTES = 4000;
const MAX_LIMIT = 200;
const TAG_FORM = /^\d{4}-\d{2}-\d{2}$/;
// 90 Tage: genug für "mindestens 30 Tage ohne Nutzung" bei den Streichkandidaten, alles darüber wird bei jeder Meldung gelöscht.
const NUTZUNG_TAGE = 90;
const MAX_NUTZUNG_BYTES = 16384;
const FREIGABEN = ["schritte", "gym", "schlaf", "essen", "plan", "verlauf", "tagebuch", "koerper", "stimmung", "gewohnheiten"];
// Bereiche je Verbindung: die zehn Freigaben.
export const BEREICHE = FREIGABEN;
// Partner-Daten: rohe Obergrenze, bevor etwas geparst wird. Gesäubert bleibt es weit darunter (Plan, Tagebuch, Messreihen sind einzeln begrenzt).
const MAX_PARTNER_BYTES = 262144;
const KOERPER_ARTEN = ["gewicht", "taille", "brust", "schulter", "bizeps", "oberschenkel", "koerperfett"];
const MAHLZEITEN = ["fruehstueck", "mittag", "abend", "snack"];
const EREIGNIS_ARTEN = ["gymStart", "gymEnde", "ziel", "rekord", "schlafGut"];
// "Nie genutzt" in der Auswertung = in der Liste der App (nutzung-namen.js), aber nie gemeldet.
export const BEKANNTE_BEREICHE = NAMEN.bereiche;
export const BEKANNTE_FUNKTIONEN = NAMEN.funktionen;

const json = (o, status = 200) => Response.json(o, { status });
const nein = (status, fehler) => json({ fehler }, status);
const unauthorized = () => nein(401, "unauthorized");

// Konstante Zeit über die maximale Länge, auch bei unterschiedlicher Länge.
function gleich(a, b) {
  const enc = new TextEncoder();
  const x = enc.encode(a ?? "");
  const y = enc.encode(b ?? "");
  let diff = x.length ^ y.length;
  for (let i = 0; i < Math.max(x.length, y.length, 1); i++) diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  return diff === 0;
}
async function sha256(text) {
  const b = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return [...new Uint8Array(b)].map((x) => x.toString(16).padStart(2, "0")).join("");
}
const appOk = (request, env) => !!env.APP_KEY && gleich(request.headers.get("X-App-Key"), env.APP_KEY);
const adminOk = (request, env) => !!env.ADMIN_KEY && gleich(request.headers.get("X-Admin-Key"), env.ADMIN_KEY);
const lesen = (text) => { try { return JSON.parse(text); } catch { return {}; } };
async function koerper(request) {
  try { return await request.json(); } catch { return null; }
}
const istObjekt = (x) => x !== null && typeof x === "object" && !Array.isArray(x);

// Merge-Patch: null löscht den Schlüssel. Liefert { wert } oder { fehler }.
function flicken(alt, patch, verboten = []) {
  if (!istObjekt(patch)) return { fehler: "Objekt erwartet" };
  const neu = { ...alt };
  for (const [k, v] of Object.entries(patch)) {
    if (!SCHLUESSEL_FORM.test(k)) return { fehler: `Schlüssel ungültig: ${k}` };
    if (verboten.includes(k) && v !== null && v !== false) return { fehler: `${k} gibt es nicht global, nur je Konto` };
    if (v === null) delete neu[k];
    else neu[k] = v;
  }
  if (JSON.stringify(neu).length > MAX_EINSTELLUNGEN_BYTES) return { fehler: "zu groß" };
  return { wert: neu };
}

// Standard < global < Konto. loveaVerbinden zählt nur, wenn das KONTO es gesetzt hat und eine Person hinterlegt ist.
function zusammen(konto, global) {
  const eigen = lesen(konto.einstellungen);
  const cfg = { ...STANDARD, ...global, ...eigen };
  cfg.loveaVerbinden = eigen.loveaVerbinden === true && PERSONEN.includes(konto.lovea_person);
  const person = PERSONEN.includes(konto.lovea_person);
  // Schlaf, Armband, AirPods: Standard nur für die zwei Lovea-Konten; ein Wert am Konto gewinnt (ohne Build änderbar).
  cfg.schlafSichtbar = typeof eigen.schlafSichtbar === "boolean" ? eigen.schlafSichtbar : person;
  // Foto-Scan: die zwei Lovea-Konten ohne Limit (null), alle anderen höchstens kiFotoLimit Fotos am Tag (Standard 5).
  cfg.kiFotoLimit = person ? null : Number.isInteger(cfg.kiFotoLimit) && cfg.kiFotoLimit >= 0 ? cfg.kiFotoLimit : STANDARD.kiFotoLimit;
  // Band in Lumen Fit: Standard an für ahmed (ein bewusstes Aus in der App gewinnt dort), für alle anderen aus; ein Wert am Konto gewinnt.
  cfg.bandStandard = typeof eigen.bandStandard === "boolean" ? eigen.bandStandard : konto.lovea_person === "ahmed" || global.bandStandard === true;
  // Schlaf-Beleg (Diagnose): nur Ahmeds Konto und nur, wenn das KONTO den Schalter selbst gesetzt hat; nie aus global.
  cfg.schlafBeleg = schlafBelegAn(konto);
  return cfg;
}
const schlafBelegAn = (konto) => lesen(konto.einstellungen).schlafBeleg === true && konto.lovea_person === "ahmed";
const globaleConfig = async (env) => lesen((await env.DB.prepare("SELECT einstellungen FROM globale_config WHERE id = 1").first())?.einstellungen);

// Meldet das Konto an: Antwort { konto } oder { antwort } (Fehler). Unbekannte ID und falsches Geheimnis sind nicht zu unterscheiden.
async function kontoPruefen(request, env) {
  if (!appOk(request, env)) return { antwort: unauthorized() };
  const id = request.headers.get("X-Konto") ?? "";
  const geheimnis = request.headers.get("X-Geheimnis") ?? "";
  const zeile = ID_FORM.test(id) ? await env.DB.prepare("SELECT * FROM konten WHERE id = ?").bind(id).first() : null;
  const hash = await sha256(geheimnis);
  if (!gleich(hash, zeile?.hash ?? "0".repeat(64)) || !zeile) return { antwort: unauthorized() };
  if (zeile.gesperrt) return { antwort: nein(403, "gesperrt") };
  return { konto: zeile };
}

async function registrieren(request, env) {
  if (!appOk(request, env)) return unauthorized();
  const b = await koerper(request);
  const name = typeof b?.name === "string" ? b.name.trim().slice(0, 40) : "";
  if (!istObjekt(b) || !ID_FORM.test(b.id ?? "") || !GEHEIM_FORM.test(b.geheimnis ?? "") || !name) return nein(400, "ungültig");
  const version = typeof b.version === "string" ? b.version.slice(0, 20) : "";
  const n = await env.DB.prepare("SELECT COUNT(*) AS n FROM konten").first();
  if (n.n >= MAX_KONTEN) return nein(429, "zu viele Konten");
  if (await env.DB.prepare("SELECT 1 AS x FROM konten WHERE id = ?").bind(b.id).first()) return nein(409, "vergeben");
  const jetzt = new Date().toISOString();
  await env.DB.prepare("INSERT INTO konten (id, hash, name, version, erstellt, gesehen) VALUES (?, ?, ?, ?, ?, ?)")
    .bind(b.id, await sha256(b.geheimnis), name, version, jetzt, jetzt).run();
  return json({ ok: true }, 201);
}

async function config(request, env) {
  const { konto, antwort } = await kontoPruefen(request, env);
  if (antwort) return antwort;
  const version = (request.headers.get("X-App-Version") ?? konto.version).slice(0, 20);
  await env.DB.prepare("UPDATE konten SET gesehen = ?, version = ? WHERE id = ?").bind(new Date().toISOString(), version, konto.id).run();
  return json({ config: zusammen(konto, await globaleConfig(env)) });
}

function freigegeben(konto) {
  return lesen(konto.einstellungen).loveaVerbinden === true && PERSONEN.includes(konto.lovea_person);
}

async function loveaFreigabe(request, env) {
  const { konto, antwort } = await kontoPruefen(request, env);
  if (antwort) return antwort;
  if (!freigegeben(konto)) return json({ erlaubt: false });
  await spur(env, konto.id, "lovea_freigabe_gesehen", new Date().toISOString());
  // essenExportAn: globaler Schalter `essenExport` (lumenfit_config_setzen), erst an, wenn Lovea die Essen-Daten wieder zeigt (09.11.2026).
  return json({ erlaubt: true, person: konto.lovea_person, importErledigt: !!(await merker(env, konto.id, "lovea_import")),
    essenExportErledigt: !!(await merker(env, konto.id, "essen_export")), essenExportAn: (await globaleConfig(env)).essenExport === true });
}

// Spur des Servers selbst (unabhängig davon, ob die App je einen Beleg schickt): wann die App Freigabe und Ops zuletzt geholt hat. Ein Fehler hier stört den Weg nicht.
async function spur(env, konto, schluessel, wert) {
  try { await env.DB.prepare("INSERT OR REPLACE INTO konto_merker (konto, schluessel, wert) VALUES (?, ?, ?)").bind(konto, schluessel, wert).run(); } catch {}
}

const merker = (env, konto, schluessel) => env.DB.prepare("SELECT wert FROM konto_merker WHERE konto = ? AND schluessel = ?").bind(konto, schluessel).first();

// Der einmalige Lovea-Import ist fertig: je Konto auf dem Server gemerkt, damit er nach einer Neuinstallation nicht nochmal läuft. Der erste Zeitpunkt bleibt.
async function importErledigt(request, env) {
  const { konto, antwort } = await kontoPruefen(request, env);
  if (antwort) return antwort;
  if (!PERSONEN.includes(konto.lovea_person)) return nein(403, "nicht freigegeben");
  await env.DB.prepare("INSERT OR IGNORE INTO konto_merker (konto, schluessel, wert) VALUES (?, 'lovea_import', ?)").bind(konto.id, new Date().toISOString()).run();
  return json({ ok: true });
}

// Import-Beleg der App nach jedem Lauf: nur Zahlen je Op-Art, nie Inhalte oder Gesundheitswerte. Gespeichert wird je Konto der letzte Beleg und der letzte Fehler.
const MAX_BELEG_BYTES = 40000;
const BELEG_ART = /^[a-z][A-Za-z0-9_.]{0,59}$/;
const BELEG_FEHLER = ["nicht_erlaubt", "profil_nicht_leer", "netz", "abgelehnt", "server", "antwort_kaputt", "speichern", "unvollstaendig", "keine_daten", "kein_zugang"];
const BELEG_ZAHLEN = ["geholt", "uebernommen", "roh", "ausgeschlossen", "unbekannt", "geplant", "wiedergefunden", "uebersprungen", "zeitKaputt"];
// Gruppen ohne eigene Op-Art (Abgabe aus Lovea, Coach, Wecker, Vorräte): Einheiten und Einträge, siehe ProfilLoveaUebernahmeBeleg.
const BELEG_UEBERNAHME_ZAHLEN = ["geholt", "aelter", "uebernommen", "vorhanden", "roh", "unlesbar", "eintraege", "geschrieben"];
const MAX_UEBERNAHME = 60;
const zahl = (x) => Number.isInteger(x) && x >= 0 && x <= 1e7;

// Gibt die gesäuberte Form zurück (nur bekannte Felder) oder null bei ungültiger Eingabe.
function belegPruefen(b) {
  if (!istObjekt(b) || !zeitOk(b.zeit)) return null;
  if (b.typ === "fehler") {
    if (!BELEG_FEHLER.includes(b.fehler) || !zahl(b.geladen ?? 0) || !zahl(b.bisSeq ?? 0)) return null;
    return { typ: "fehler", zeit: b.zeit, fehler: b.fehler, geladen: b.geladen ?? 0, bisSeq: b.bisSeq ?? 0 };
  }
  if (b.typ !== "beleg" || typeof b.vollstaendig !== "boolean" || !istObjekt(b.arten) || Object.keys(b.arten).length > 150) return null;
  const kopf = {};
  for (const k of ["seqMax", "unlesbar", "neu", "schonDa", "uebersprungen"]) {
    if (!zahl(b[k])) return null;
    kopf[k] = b[k];
  }
  const arten = {};
  for (const [name, a] of Object.entries(b.arten)) {
    if (!BELEG_ART.test(name) || !istObjekt(a)) return null;
    const z = {};
    for (const k of BELEG_ZAHLEN) {
      if (!zahl(a[k] ?? 0)) return null;
      z[k] = a[k] ?? 0;
    }
    if (a.grund !== undefined) {
      if (typeof a.grund !== "string" || a.grund.length > 80) return null;
      z.grund = a.grund;
    }
    arten[name] = z;
  }
  const uebernahme = {};
  if (b.uebernahme !== undefined) {
    if (!istObjekt(b.uebernahme) || Object.keys(b.uebernahme).length > MAX_UEBERNAHME) return null;
    for (const [name, u] of Object.entries(b.uebernahme)) {
      if (!BELEG_ART.test(name) || !istObjekt(u)) return null;
      const z = {};
      for (const k of BELEG_UEBERNAHME_ZAHLEN) {
        if (!zahl(u[k] ?? 0)) return null;
        z[k] = u[k] ?? 0;
      }
      uebernahme[name] = z;
    }
  }
  return { typ: "beleg", zeit: b.zeit, vollstaendig: b.vollstaendig, ...kopf, arten, uebernahme };
}

async function importBeleg(request, env) {
  const { konto, antwort } = await kontoPruefen(request, env);
  if (antwort) return antwort;
  if (!freigegeben(konto)) return nein(403, "nicht freigegeben");
  const text = await request.text();
  if (text.length > MAX_BELEG_BYTES) return nein(413, "zu groß");
  let roh;
  try { roh = JSON.parse(text); } catch { return nein(400, "ungültig"); }
  const b = belegPruefen(roh);
  if (!b) return nein(400, "ungültig");
  const schluessel = b.typ === "beleg" ? "lovea_import_beleg" : "lovea_import_fehler";
  if (b.typ === "fehler") b.anzahl = Math.min(9999, (lesen((await merker(env, konto.id, schluessel))?.wert).anzahl ?? 0) + 1);
  await env.DB.prepare("INSERT OR REPLACE INTO konto_merker (konto, schluessel, wert) VALUES (?, ?, ?)").bind(konto.id, schluessel, JSON.stringify(b)).run();
  return json({ ok: true });
}

// Schlaf-Beleg (Diagnose, nur auf Freigabe): Rohwerte von Schlaf und Schritten, damit ein Agent falsches Tracking untersuchen kann. Standard aus, nur je Konto.
const MAX_SCHLAF_BYTES = 524288;
const SCHLAF_BELEGE = 30;
async function schlafBelegAnnehmen(request, env) {
  const { konto, antwort } = await kontoPruefen(request, env);
  if (antwort) return antwort;
  if (!schlafBelegAn(konto)) return nein(403, "nicht freigegeben");
  const text = await request.text();
  if (text.length > MAX_SCHLAF_BYTES) return nein(413, "zu groß");
  let b;
  try { b = JSON.parse(text); } catch { b = null; }
  if (!istObjekt(b)) return nein(400, "ungültig");
  await env.DB.prepare("INSERT INTO schlaf_belege (konto, zeit, daten) VALUES (?, ?, ?)").bind(konto.id, new Date().toISOString(), text).run();
  await env.DB.prepare("DELETE FROM schlaf_belege WHERE konto = ? AND id NOT IN (SELECT id FROM schlaf_belege WHERE konto = ? ORDER BY id DESC LIMIT ?)")
    .bind(konto.id, konto.id, SCHLAF_BELEGE).run();
  return json({ ok: true });
}

// Nutzung: ein Bündel je Start (Tag, Zähler für Bereiche und Funktionen, dazu Gruppen mit festen Namen). Mehrere Bündel am Tag werden addiert.
// Es zählt nur, was in nutzung-namen.js steht; alles andere (auch zusätzliche Felder) wird verworfen. Keine Inhalte, keine Gesundheitswerte.
async function nutzungMelden(request, env) {
  const { konto, antwort } = await kontoPruefen(request, env);
  if (antwort) return antwort;
  const text = await request.text();
  if (text.length > MAX_NUTZUNG_BYTES) return nein(413, "zu groß");
  let b;
  try { b = JSON.parse(text); } catch { b = null; }
  if (!istObjekt(b) || !TAG_FORM.test(b.tag ?? "")) return nein(400, "ungültig");
  const t = Date.parse(`${b.tag}T00:00:00Z`);
  if (!(t > Date.now() - 3 * 864e5 && t < Date.now() + 2 * 864e5)) return nein(400, "tag");
  const bereiche = zaehlerPruefen("bereiche", b.bereiche), funktionen = zaehlerPruefen("funktionen", b.funktionen), gruppen = gruppenPruefen(b.gruppen);
  if (!bereiche || !funktionen || !gruppen) return nein(400, "ungültig");
  const alt = await env.DB.prepare("SELECT bereiche, funktionen FROM nutzung WHERE konto = ? AND tag = ?").bind(konto.id, b.tag).first();
  const neuB = summe(lesen(alt?.bereiche), bereiche), neuF = summe(lesen(alt?.funktionen), funktionen);
  const version = (request.headers.get("X-App-Version") ?? konto.version).slice(0, 20);
  await env.DB.prepare("INSERT OR REPLACE INTO nutzung (konto, tag, version, bereiche, funktionen) VALUES (?, ?, ?, ?, ?)")
    .bind(konto.id, b.tag, version, JSON.stringify(neuB), JSON.stringify(neuF)).run();
  if (Object.keys(gruppen).length) {
    // iOS und Gerätetyp nur in fester Form (sonst leer): kein Freitext, kein genaues Gerät.
    const ios = typeof b.ios === "string" && IOS_FORM.test(b.ios) ? b.ios : "";
    const geraet = typeof b.geraet === "string" && GERAET_FORM.test(b.geraet) ? b.geraet : "";
    const vorhanden = await env.DB.prepare("SELECT daten FROM nutzung_mehr WHERE konto = ? AND tag = ? AND version = ? AND ios = ? AND geraet = ?")
      .bind(konto.id, b.tag, version, ios, geraet).first();
    await env.DB.prepare("INSERT OR REPLACE INTO nutzung_mehr (konto, tag, version, ios, geraet, daten) VALUES (?, ?, ?, ?, ?, ?)")
      .bind(konto.id, b.tag, version, ios, geraet, JSON.stringify(zusammenfuehren(lesen(vorhanden?.daten), gruppen))).run();
  }
  // Aufräumen für alle Konten, nicht nur für das meldende: wer auf "Nein" geht, meldet nie wieder, seine alten Tage sollen trotzdem verschwinden.
  const grenze = new Date(Date.now() - NUTZUNG_TAGE * 864e5).toISOString().slice(0, 10);
  await env.DB.prepare("DELETE FROM nutzung WHERE tag < ?").bind(grenze).run();
  await env.DB.prepare("DELETE FROM nutzung_mehr WHERE tag < ?").bind(grenze).run();
  return json({ ok: true });
}
const summe = (a, b) => { const o = { ...a }; for (const [k, v] of Object.entries(b)) o[k] = Math.min(9999, (o[k] ?? 0) + v); return o; };

// Auswertung je Konto für den MCP: zuletzt aktiv, aktive Tage 7/30, meistgenutzt, nie genutzt (laut Liste der App).
function auswerten(konto, zeilen, jetzt = Date.now()) {
  const tag = (n) => new Date(jetzt - n * 864e5).toISOString().slice(0, 10);
  const ab7 = tag(6), ab30 = tag(29);
  const bereiche = {}, funktionen = {};
  const tage = zeilen.map((z) => z.tag).sort();
  for (const z of zeilen) {
    for (const [k, v] of Object.entries(lesen(z.bereiche))) bereiche[k] = (bereiche[k] ?? 0) + v;
    for (const [k, v] of Object.entries(lesen(z.funktionen))) funktionen[k] = (funktionen[k] ?? 0) + v;
  }
  const oben = (o) => Object.entries(o).sort((a, b) => b[1] - a[1]).slice(0, 5).map(([name, anzahl]) => ({ name, anzahl }));
  return {
    id: konto.id, name: konto.name, lovea_person: konto.lovea_person, version: konto.version, zuletzt_gesehen: konto.gesehen,
    zuletzt_aktiv: tage.at(-1) ?? null,
    aktive_tage_7: tage.filter((t) => t >= ab7).length,
    aktive_tage_30: tage.filter((t) => t >= ab30).length,
    meistgenutzt: { bereiche: oben(bereiche), funktionen: oben(funktionen) },
    nie_genutzt: { bereiche: BEKANNTE_BEREICHE.filter((n) => !bereiche[n]), funktionen: BEKANNTE_FUNKTIONEN.filter((n) => !funktionen[n]) },
  };
}

// Zusammenfassung für den Partner: Form von SPEC 5.5 (zusammenfassung.json), nur freigegebene Felder, alles andere fliegt raus.
const ganz = (x) => (Number.isInteger(x) && x >= 0 && x < 1e6 ? x : undefined);
const kurz = (x, n) => (typeof x === "string" ? x.trim().slice(0, n) : "");
const reihe = (x, n) => (Array.isArray(x) ? x.slice(0, n).filter(istObjekt) : []);
const zeitOk = (x) => typeof x === "string" && Number.isFinite(Date.parse(x));

// Freigabe plan: Name, Wochentage (1 = Mo ... 7 = So) und Übungsnamen. Kein Plan ohne Tage.
function planSauber(p) {
  if (!istObjekt(p)) return undefined;
  const wochentage = (liste) => [...new Set((Array.isArray(liste) ? liste : []).filter((w) => Number.isInteger(w) && w >= 1 && w <= 7))].sort();
  const tage = reihe(p.tage, 14).map((t) => ({
    name: kurz(t.name, 40), wochentage: wochentage(t.wochentage),
    uebungen: reihe(t.uebungen, 20).map((u) => ({ name: kurz(u.name, 40), saetze: ganz(u.saetze) ?? 0 })),
  }));
  if (!tage.length) return undefined;
  const aus = { tage };
  if (kurz(p.name, 40)) aus.name = kurz(p.name, 40);
  const ruhe = wochentage(p.ruhetage);
  if (ruhe.length) aus.ruhetage = ruhe;
  return aus;
}

// Gym-Verlauf mit Sätzen (Erweiterung, nur additiv): alle Trainingstage für das Monatsraster und die letzten Einheiten mit Übungen, Gewicht (Zehntel kg)
// und Wiederholungen zum Nachlesen. Kommt nur an, wenn BEIDE Freigaben (verlauf und gym) offen sind; alte Apps lesen die Felder nicht.
const MAX_TAGE = 400, MAX_EINHEITEN = 30, MAX_UEBUNGEN = 15, MAX_SAETZE = 12;
function einheitenSauber(v) {
  const aus = {};
  const tage = [...new Set((Array.isArray(v.tage) ? v.tage : []).filter((t) => typeof t === "string" && TAG_FORM.test(t)))].sort().reverse().slice(0, MAX_TAGE);
  if (tage.length) aus.tage = tage;
  const einheiten = reihe(v.einheiten, MAX_EINHEITEN).filter((e) => typeof e.tag === "string" && TAG_FORM.test(e.tag)).map((e) => {
    const x = { tag: e.tag, uebungen: reihe(e.uebungen, MAX_UEBUNGEN).filter((u) => kurz(u.name, 40)).map((u) => ({
      name: kurz(u.name, 40),
      saetze: reihe(u.saetze, MAX_SAETZE).filter((z) => ganz(z.wdh) !== undefined && z.wdh < 10000).map((z) => {
        const y = { wdh: z.wdh };
        if (ganz(z.kg) !== undefined && z.kg < 100000) y.kg = z.kg; // Zehntel kg
        if (z.typ === "w" || z.typ === "d" || z.typ === "f") y.typ = z.typ;
        return y;
      }),
    })) };
    if (kurz(e.name, 40)) x.name = kurz(e.name, 40);
    for (const f of ["minuten", "kcal"]) if (ganz(e[f]) !== undefined) x[f] = e[f];
    return x;
  });
  if (einheiten.length) aus.einheiten = einheiten;
  return aus;
}

// Freigabe verlauf: "im Gym" und die letzten Trainings als Zusammenfassung. Sätze und Gewichte nur mit zusätzlicher Freigabe gym (`einheitenSauber`).
function verlaufSauber(v, mitSaetzen = false) {
  if (!istObjekt(v)) return undefined;
  const aus = {
    trainings: reihe(v.trainings, 10).filter((t) => typeof t.tag === "string" && TAG_FORM.test(t.tag)).map((t) => {
      const e = { tag: t.tag, saetze: ganz(t.saetze) ?? 0, uebungen: ganz(t.uebungen) ?? 0 };
      if (kurz(t.name, 40)) e.name = kurz(t.name, 40);
      for (const f of ["minuten", "kcal"]) if (ganz(t[f]) !== undefined) e[f] = t[f];
      return e;
    }),
  };
  if (v.imGym === true && zeitOk(v.imGymSeit)) {
    aus.imGym = true;
    aus.imGymSeit = v.imGymSeit;
    if (kurz(v.imGymName, 40)) aus.imGymName = kurz(v.imGymName, 40);
  }
  for (const f of ["woche", "serieWochen", "gesamt"]) if (ganz(v[f]) !== undefined) aus[f] = v[f];
  if (mitSaetzen) Object.assign(aus, einheitenSauber(v));
  return aus;
}

// Freigabe tagebuch: Tageswerte, Makros und Namen der Einträge der letzten sieben Tage. Keine Fotos, keine Mengen.
function tagebuchSauber(t) {
  return (Array.isArray(t) ? t : []).slice(0, 7).filter((d) => istObjekt(d) && typeof d.tag === "string" && TAG_FORM.test(d.tag)).map((d) => ({
    tag: d.tag, kcal: ganz(d.kcal) ?? 0, protein: ganz(d.protein) ?? 0, kohlenhydrate: ganz(d.kohlenhydrate) ?? 0, fett: ganz(d.fett) ?? 0,
    mahlzeiten: reihe(d.mahlzeiten, 30).map((m) => ({ mahlzeit: MAHLZEITEN.includes(m.mahlzeit) ? m.mahlzeit : "snack", name: kurz(m.name, 60), kcal: ganz(m.kcal) ?? 0 })),
  }));
}

function zieleSauber(z) {
  if (!istObjekt(z)) return undefined;
  const felder = ["kcal", "protein", "kohlenhydrate", "fett"];
  return felder.every((f) => ganz(z[f]) !== undefined) ? Object.fromEntries(felder.map((f) => [f, z[f]])) : undefined;
}

// Freigabe koerper: Messreihen in Zehnteln (784 = 78,4 kg), je Art höchstens 90 Punkte.
function koerperSauber(k) {
  if (!istObjekt(k)) return undefined;
  const aus = {};
  for (const art of KOERPER_ARTEN) {
    const punkte = reihe(k[art], 90).filter((p) => typeof p.tag === "string" && TAG_FORM.test(p.tag) && Number.isInteger(p.zehntel) && p.zehntel > 0 && p.zehntel < 10000)
      .map((p) => ({ tag: p.tag, zehntel: p.zehntel }));
    if (punkte.length) aus[art] = punkte;
  }
  return Object.keys(aus).length ? aus : undefined;
}

// Felder aus dem Health-Gleichstand (Wochenwerte, Ziele, Energie, Gewohnheiten): jedes nur mit seiner Freigabe, mit Grenzen.
const ENERGIE = ["hoch", "mittel", "niedrig"];
const zahlenTage = (x, max) => {
  if (!istObjekt(x)) return undefined;
  const aus = Object.fromEntries(Object.entries(x).slice(0, 14).filter(([t, v]) => TAG_FORM.test(t) && ganz(v) !== undefined && v <= max));
  return Object.keys(aus).length ? aus : undefined;
};
function erweiterungSauber(h, freigaben, heute) {
  const setze = (feld, wert) => { if (wert !== undefined) heute[feld] = wert; };
  if (freigaben.includes("schritte")) { setze("schritteZiel", ganz(h.schritteZiel)); setze("schritteWoche", zahlenTage(h.schritteWoche, 1e5)); }
  if (freigaben.includes("gym")) {
    setze("gymZiel", ganz(h.gymZiel));
    const tage = Array.isArray(h.gymTage) ? h.gymTage.slice(0, 7).filter((t) => typeof t === "string" && TAG_FORM.test(t)) : [];
    if (tage.length) heute.gymTage = tage;
  }
  if (freigaben.includes("schlaf")) {
    setze("schlafZiel", ganz(h.schlafZiel));
    setze("schlafWoche", zahlenTage(h.schlafWoche, 1500));
    if (ENERGIE.includes(h.energieStufe)) heute.energieStufe = h.energieStufe;
    if (freigaben.includes("gym") && ENERGIE.includes(h.energieGym)) heute.energieGym = h.energieGym;
  }
  if (freigaben.includes("essen") && ganz(h.wasserGlaeser) !== undefined && h.wasserGlaeser <= 99) heute.wasserGlaeser = h.wasserGlaeser;
  if (Array.isArray(h.habitsFertig)) {
    const erlaubt = [freigaben.includes("gym") ? "gym" : null, freigaben.includes("essen") ? "wasser" : null];
    const fertig = [...new Set(h.habitsFertig.filter((k) => typeof k === "string" && erlaubt.includes(k)))];
    if (fertig.length) heute.habitsFertig = fertig;
  }
  // Stimmung (Morgen-Check, 1 bis 5): heute und die letzten Tage der Woche.
  if (freigaben.includes("stimmung")) {
    if (Number.isInteger(h.stimmung) && h.stimmung >= 1 && h.stimmung <= 5) heute.stimmung = h.stimmung;
    const woche = zahlenTage(h.stimmungWoche, 5);
    if (woche) { for (const t of Object.keys(woche)) if (woche[t] < 1) delete woche[t]; if (Object.keys(woche).length) heute.stimmungWoche = woche; }
  }
  // Alle Gewohnheiten mit Serie (Tage oder Wochen in Folge) und Quote der letzten 30 Tage in Prozent; höchstens 30.
  if (freigaben.includes("gewohnheiten")) {
    const liste = reihe(h.gewohnheiten, 30).filter((g) => typeof g.id === "string" && g.id && g.id.length <= 60 && kurz(g.name, 40)).map((g) => ({
      id: g.id, name: kurz(g.name, 40), symbol: kurz(g.symbol, 40), serie: Math.min(ganz(g.serie) ?? 0, 9999), quote: Math.min(ganz(g.quote) ?? 0, 100), heute: g.heute === true,
    }));
    if (liste.length) heute.gewohnheiten = liste;
  }
}

function zusammenfassungSauber(b) {
  if (!istObjekt(b) || b.version !== 1 || typeof b.profilName !== "string" || !b.profilName.trim() || !istObjekt(b.heute)) return null;
  const geschrieben = Date.parse(b.geschrieben);
  if (!Number.isFinite(geschrieben) || typeof b.heute.tag !== "string" || !TAG_FORM.test(b.heute.tag)) return null;
  const freigaben = Array.isArray(b.freigaben) ? [...new Set(b.freigaben.filter((f) => FREIGABEN.includes(f)))] : [];
  const h = b.heute;
  const heute = { tag: h.tag };
  if (freigaben.includes("schritte") && ganz(h.schritte) !== undefined) heute.schritte = h.schritte;
  if (freigaben.includes("gym") && ganz(h.gymTageWoche) !== undefined) heute.gymTageWoche = h.gymTageWoche;
  if (freigaben.includes("schlaf") && ganz(h.schlafMinuten) !== undefined) heute.schlafMinuten = h.schlafMinuten;
  if (freigaben.includes("essen") && ganz(h.kcal) !== undefined) heute.kcal = h.kcal;
  erweiterungSauber(h, freigaben, heute);
  const neu = {
    plan: freigaben.includes("plan") ? planSauber(h.plan) : undefined,
    verlauf: freigaben.includes("verlauf") ? verlaufSauber(h.verlauf, freigaben.includes("gym")) : undefined,
    tagebuch: freigaben.includes("tagebuch") ? tagebuchSauber(h.tagebuch) : undefined,
    tagebuchZiele: freigaben.includes("tagebuch") ? zieleSauber(h.tagebuchZiele) : undefined,
    koerper: freigaben.includes("koerper") ? koerperSauber(h.koerper) : undefined,
  };
  for (const [feld, wert] of Object.entries(neu)) if (wert !== undefined && !(Array.isArray(wert) && !wert.length)) heute[feld] = wert;
  const ereignisse = (Array.isArray(b.ereignisse) ? b.ereignisse : []).slice(0, 20).filter((e) => istObjekt(e)
    && typeof e.id === "string" && e.id.length <= 80 && EREIGNIS_ARTEN.includes(e.art) && Number.isFinite(Date.parse(e.zeit)) && typeof e.text === "string")
    .map((e) => ({ id: e.id, art: e.art, zeit: e.zeit, text: e.text.slice(0, 120) }));
  return { version: 1, geschrieben: b.geschrieben, profilName: b.profilName.trim().slice(0, 40), freigaben, heute, ereignisse };
}

// Der andere der zwei Lovea-Personen (ahmed <-> annika).
const andere = (person) => PERSONEN.find((p) => p !== person);

// Welcher Bereich gehört zu welchem Ereignis (Mitteilungen laufen nur über Bereiche, die die Verbindung freigibt).
const EREIGNIS_BEREICH = { gymStart: "gym", gymEnde: "gym", rekord: "gym", ziel: "schritte", schlafGut: "schlaf" };

// Die gespeicherte (gesäuberte) Zusammenfassung des Besitzers, auf die Bereiche begrenzt, die DIESE Verbindung für DIESEN Leser erlaubt.
// Läuft immer auf dem Server, bevor etwas ausgeliefert wird; die App filtert nur zusätzlich.
export function filtern(stand, erlaubt, mitteilungen = true) {
  const frei = erlaubt.filter((b) => FREIGABEN.includes(b));
  const s = zusammenfassungSauber({ ...stand, freigaben: (stand.freigaben ?? []).filter((f) => frei.includes(f)) });
  if (!s) return null;
  // Auch nur, was die App für diese Art hochgeladen hat (Gym in der App aus: kein Gym-Ereignis, selbst wenn die Verbindung Gym erlaubt).
  s.ereignisse = mitteilungen ? s.ereignisse.filter((e) => s.freigaben.includes(EREIGNIS_BEREICH[e.art])) : [];
  return s;
}

async function partnerLegen(request, env) {
  const { konto, antwort } = await kontoPruefen(request, env);
  if (antwort) return antwort;
  const roh = await request.text();
  if (roh.length > MAX_PARTNER_BYTES) return nein(413, "zu groß");
  let eingang = null;
  try { eingang = JSON.parse(roh); } catch { /* bleibt null -> 400 */ }
  const sauber = zusammenfassungSauber(eingang);
  if (!sauber) return nein(400, "ungültig");
  await env.DB.prepare("INSERT OR REPLACE INTO partner_stand (konto, aktualisiert, daten) VALUES (?, ?, ?)")
    .bind(konto.id, new Date().toISOString(), JSON.stringify(sauber)).run();
  return json({ ok: true });
}

// Alter Weg (App-Stände vor den Verbindungen): nur für die zwei Lovea-Konten, liefert deren Verbindung, gefiltert wie der neue Weg.
async function partnerLesen(request, env) {
  const { konto, antwort } = await kontoPruefen(request, env);
  if (antwort) return antwort;
  if (!freigegeben(konto)) return nein(403, "nicht freigegeben");
  await autoVerbinden(env, konto, { freigegeben, PERSONEN, andere });
  const r = await partnerFuerLovea(env, konto, { andere, filtern, lesen });
  return json({ partner: r?.partner ?? null, aktualisiert: r?.aktualisiert ?? null });
}

// Essen zurück zu Lovea (09.11.2026): die App schickt ihre Essen-Ops, der Server reicht sie mit Key und Person an Lovea `POST /ops` durch.
// Nur die Essen-Arten und Einstellungen (Ziele), `von` setzt der Server; doppelte Ids überspringt Lovea selbst (INSERT OR IGNORE).
const EXPORT_ARTEN = new Set(["essen.setzen", "lebensmittel.setzen", "lebensmittel.favorit", "rezept.setzen", "fasten.setzen", "fasten.eintrag", "fasten.plan",
  "food.anpassung", "koerper.setzen", "einstellung.setzen"]);
// Grenzen je Anfrage, damit ein kaputtes oder falsches Gerät Loveas Raum nicht füllt: 256 KB gesamt, je Op id 80 Zeichen, d 4 KB, Zeit höchstens einen Tag voraus.
// Die App sendet deshalb Pakete zu 50 Ops (50 mal 4 KB passen in 256 KB).
const OPS_BYTES = 256 * 1024;
const OP_ID_MAX = 80;
const OP_D_MAX = 4096;
const OP_ZUKUNFT_MS = 24 * 3600 * 1000;
async function loveaOpsSenden(request, env, holen) {
  const { konto, antwort } = await kontoPruefen(request, env);
  if (antwort) return antwort;
  if (!freigegeben(konto)) return nein(403, "nicht freigegeben");
  if (!env.LOVEA_KEY) return nein(503, "nicht eingerichtet");
  const text = await request.text().catch(() => "");
  if (new TextEncoder().encode(text).length > OPS_BYTES) return nein(400, "zu groß (höchstens 256 KB)");
  let k = null;
  try { k = JSON.parse(text); } catch {}
  if (!istObjekt(k) || !Array.isArray(k.ops) || k.ops.length === 0 || k.ops.length > MAX_LIMIT) return nein(400, "ops");
  const ops = [];
  for (const op of k.ops) {
    if (!istObjekt(op) || typeof op.id !== "string" || !op.id || typeof op.art !== "string" || typeof op.zeit !== "string" || !istObjekt(op.d)) return nein(400, "op");
    if (!EXPORT_ARTEN.has(op.art)) return nein(400, "art");
    if (op.id.length > OP_ID_MAX) return nein(400, "id zu lang (höchstens 80 Zeichen)");
    if (new TextEncoder().encode(JSON.stringify(op.d)).length > OP_D_MAX) return nein(400, "d zu groß (höchstens 4 KB)");
    const zeit = Date.parse(op.zeit);
    if (!Number.isFinite(zeit) || zeit > Date.now() + OP_ZUKUNFT_MS) return nein(400, "zeit ungültig oder mehr als einen Tag in der Zukunft");
    // Von Einstellungen darf nur ein Ernährungsziel (Zahl) mit.
    if (op.art === "einstellung.setzen" && !(typeof op.d.schluessel === "string" && op.d.schluessel.startsWith("ziel.") && typeof op.d.wert === "number" && Number.isFinite(op.d.wert))) return nein(400, "einstellung: nur ziel.* mit Zahl");
    ops.push({ id: op.id, art: op.art, von: konto.lovea_person, zeit: op.zeit, d: op.d });
  }
  let r;
  try {
    r = await holen(`${env.LOVEA_URL ?? "https://lovea.intern"}/ops`, {
      method: "POST", headers: { "X-Lovea-Key": env.LOVEA_KEY, "X-Lovea-Person": konto.lovea_person, "content-type": "application/json" }, body: JSON.stringify({ ops }),
    });
  } catch {
    return nein(502, "lovea");
  }
  if (!r.ok) return nein(502, "lovea");
  const a = await r.json().catch(() => ({}));
  return json({ ok: true, seq: typeof a.seq === "number" ? a.seq : null, uebersprungen: typeof a.uebersprungen === "number" ? a.uebersprungen : 0 });
}

// Der einmalige Essen-Export nach Lovea ist fertig: je Konto gemerkt (wie der Import), der erste Zeitpunkt bleibt.
async function exportErledigt(request, env) {
  const { konto, antwort } = await kontoPruefen(request, env);
  if (antwort) return antwort;
  if (!PERSONEN.includes(konto.lovea_person)) return nein(403, "nicht freigegeben");
  await env.DB.prepare("INSERT OR IGNORE INTO konto_merker (konto, schluessel, wert) VALUES (?, 'essen_export', ?)").bind(konto.id, new Date().toISOString()).run();
  return json({ ok: true });
}

// Proxy statt Schlüssel: nur GET /agent/ops, Person und Key setzt der Server, die App bekommt den Key nie.
async function loveaOps(request, url, env, holen) {
  const { konto, antwort } = await kontoPruefen(request, env);
  if (antwort) return antwort;
  if (!freigegeben(konto)) return nein(403, "nicht freigegeben");
  if (!env.LOVEA_KEY) return nein(503, "nicht eingerichtet");
  const q = new URLSearchParams({ von: konto.lovea_person });
  for (const k of ["seit", "aufsteigend", "voll"]) if (url.searchParams.has(k)) q.set(k, url.searchParams.get(k));
  if (url.searchParams.has("limit")) q.set("limit", String(Math.min(MAX_LIMIT, Math.max(1, Number(url.searchParams.get("limit")) || 1))));
  let r;
  try {
    r = await holen(`${env.LOVEA_URL ?? "https://lovea.intern"}/agent/ops?${q}`, { headers: { "X-Lovea-Key": env.LOVEA_KEY, "X-Lovea-Person": konto.lovea_person } });
  } catch {
    return nein(502, "lovea");
  }
  if (!r.ok) return nein(502, "lovea");
  const seit = Number(url.searchParams.get("seit")) || 0;
  const alt = seit > 0 ? lesen((await merker(env, konto.id, "lovea_ops_abruf"))?.wert) : {};
  await spur(env, konto.id, "lovea_ops_abruf", JSON.stringify({ zeit: new Date().toISOString(), seit, seiten: (seit > 0 ? alt.seiten ?? 0 : 0) + 1 }));
  return new Response(r.body, { status: 200, headers: { "content-type": "application/json" } });
}

const oeffentlich = (z) => ({
  id: z.id, name: z.name, version: z.version, erstellt: z.erstellt, zuletzt_gesehen: z.gesehen,
  gesperrt: !!z.gesperrt, lovea_person: z.lovea_person, einstellungen: lesen(z.einstellungen),
});

async function verwalten(request, url, env) {
  if (!adminOk(request, env)) return unauthorized();
  const m = request.method;
  if (url.pathname === "/admin/konten" && m === "GET") {
    const { results } = await env.DB.prepare("SELECT * FROM konten ORDER BY gesehen DESC").all();
    return json({ konten: results.map(oeffentlich), global: { ...STANDARD, ...(await globaleConfig(env)) } });
  }
  if (url.pathname === "/admin/nutzung" && m === "GET") {
    const { results: konten } = await env.DB.prepare("SELECT * FROM konten ORDER BY gesehen DESC").all();
    const { results: zeilen } = await env.DB.prepare("SELECT konto, tag, bereiche, funktionen FROM nutzung").all();
    const { results: importe } = await env.DB.prepare("SELECT konto, wert FROM konto_merker WHERE schluessel = 'lovea_import'").all();
    return json({
      konten: konten.map((k) => ({
        ...auswerten(k, zeilen.filter((z) => z.konto === k.id)),
        lovea_import_erledigt: importe.find((i) => i.konto === k.id)?.wert ?? null,
      })),
    });
  }
  if ((url.pathname === "/admin/fehler" || url.pathname === "/admin/auswertung") && m === "GET") {
    const tage = url.searchParams.get("tage") ?? 30;
    const { results: mehr } = await env.DB.prepare("SELECT konto, tag, version, ios, geraet, daten FROM nutzung_mehr").all();
    if (url.pathname === "/admin/fehler") return json(fehlerAuswerten(mehr, { tage }));
    const { results: alt } = await env.DB.prepare("SELECT konto, tag, bereiche, funktionen FROM nutzung").all();
    return json(auswertungBauen(alt, mehr, { tage }));
  }
  if (url.pathname === "/admin/import-beleg" && m === "GET") {
    const { results: konten } = await env.DB.prepare("SELECT * FROM konten WHERE lovea_person IS NOT NULL ORDER BY gesehen DESC").all();
    const { results: ms } = await env.DB.prepare("SELECT konto, schluessel, wert FROM konto_merker WHERE schluessel IN ('lovea_import', 'lovea_import_beleg', 'lovea_import_fehler', 'lovea_freigabe_gesehen', 'lovea_ops_abruf')").all();
    const hol = (k, s) => ms.find((x) => x.konto === k && x.schluessel === s)?.wert;
    return json({
      konten: konten.map((k) => ({
        id: k.id, name: k.name, lovea_person: k.lovea_person, version: k.version, zuletzt_gesehen: k.gesehen,
        lovea_import_erledigt: hol(k.id, "lovea_import") ?? null,
        freigabe_zuletzt_geholt: hol(k.id, "lovea_freigabe_gesehen") ?? null,
        ops_abruf: hol(k.id, "lovea_ops_abruf") ? lesen(hol(k.id, "lovea_ops_abruf")) : null,
        beleg: hol(k.id, "lovea_import_beleg") ? lesen(hol(k.id, "lovea_import_beleg")) : null,
        fehler: hol(k.id, "lovea_import_fehler") ? lesen(hol(k.id, "lovea_import_fehler")) : null,
      })),
    });
  }
  if (url.pathname === "/admin/schlaf-beleg" && m === "GET") {
    const id = url.searchParams.get("konto") ?? "";
    if (!ID_FORM.test(id)) return nein(400, "konto ungültig");
    const n = Number(url.searchParams.get("limit") ?? 1);
    const limit = Number.isInteger(n) && n >= 1 ? Math.min(n, SCHLAF_BELEGE) : 1;
    const { results } = await env.DB.prepare("SELECT zeit, daten FROM schlaf_belege WHERE konto = ? ORDER BY id DESC LIMIT ?").bind(id, limit).all();
    return json({ konto: id, belege: results.map((z) => ({ zeit: z.zeit, daten: lesen(z.daten) })) });
  }
  if (url.pathname.startsWith("/admin/postfach")) {
    const r = await postfachAdmin(request, url, env, { json, nein, koerper, lesen, ID_FORM });
    if (r) return r;
  }
  if (url.pathname === "/admin/config" && m === "PATCH") {
    const r = flicken(await globaleConfig(env), await koerper(request), ["loveaVerbinden", "schlafBeleg"]);
    if (r.fehler) return nein(400, r.fehler);
    await env.DB.prepare("UPDATE globale_config SET einstellungen = ? WHERE id = 1").bind(JSON.stringify(r.wert)).run();
    return json({ global: { ...STANDARD, ...r.wert } });
  }
  const t = url.pathname.match(/^\/admin\/konto\/([A-Za-z0-9_-]+)$/);
  if (t && m === "PATCH") {
    const zeile = await env.DB.prepare("SELECT * FROM konten WHERE id = ?").bind(t[1]).first();
    if (!zeile) return nein(404, "unbekannt");
    const b = await koerper(request);
    if (!istObjekt(b)) return nein(400, "Objekt erwartet");
    let person = zeile.lovea_person;
    if ("lovea_person" in b) {
      if (b.lovea_person !== null && !PERSONEN.includes(b.lovea_person)) return nein(400, "lovea_person: ahmed, annika oder null");
      person = b.lovea_person;
    }
    let gesperrt = zeile.gesperrt;
    if ("gesperrt" in b) {
      if (typeof b.gesperrt !== "boolean") return nein(400, "gesperrt: true oder false");
      gesperrt = b.gesperrt ? 1 : 0;
    }
    if ("lovea_import" in b) {
      if (b.lovea_import !== null) return nein(400, "lovea_import: nur null (setzt den Merker zurück)");
      await env.DB.prepare("DELETE FROM konto_merker WHERE konto = ? AND schluessel = 'lovea_import'").bind(zeile.id).run();
    }
    let einstellungen = lesen(zeile.einstellungen);
    if ("einstellungen" in b) {
      const r = flicken(einstellungen, b.einstellungen);
      if (r.fehler) return nein(400, r.fehler);
      einstellungen = r.wert;
    }
    if ("loveaVerbinden" in einstellungen && typeof einstellungen.loveaVerbinden !== "boolean") return nein(400, "loveaVerbinden: true oder false");
    if ("schlafBeleg" in einstellungen && typeof einstellungen.schlafBeleg !== "boolean") return nein(400, "schlafBeleg: true oder false");
    for (const k of ["schlafSichtbar", "kiFotoErlaubt"]) if (k in einstellungen && typeof einstellungen[k] !== "boolean") return nein(400, `${k}: true oder false`);
    if ("kiFotoLimit" in einstellungen && !(Number.isInteger(einstellungen.kiFotoLimit) && einstellungen.kiFotoLimit >= 0)) return nein(400, "kiFotoLimit: ganze Zahl ab 0");
    if (einstellungen.schlafBeleg === true && person !== "ahmed") return nein(400, "schlafBeleg nur mit lovea_person ahmed");
    if (einstellungen.loveaVerbinden === true && !person) return nein(400, "loveaVerbinden braucht lovea_person");
    await env.DB.prepare("UPDATE konten SET lovea_person = ?, gesperrt = ?, einstellungen = ? WHERE id = ?")
      .bind(person, gesperrt, JSON.stringify(einstellungen), zeile.id).run();
    return json({ konto: oeffentlich(await env.DB.prepare("SELECT * FROM konten WHERE id = ?").bind(zeile.id).first()) });
  }
  return nein(404, "not found");
}

// kiHolen: Abruf zu OpenAI (Standard: globales fetch), getrennt von `holen`, das über die Dienstbindung zu Lovea geht.
export async function handleFetch(request, env, holen = (u, o) => (env.LOVEA ?? { fetch }).fetch(u, o), kiHolen = undefined) {
  // Worker-zu-Worker über workers.dev ist im selben Konto gesperrt (1042): Lovea kommt über die Dienstbindung LOVEA.
  const url = new URL(request.url);
  const m = request.method;
  if (url.pathname === "/gesundheit" && m === "GET") return json({ ok: true });
  if (url.pathname === "/konto" && m === "POST") return registrieren(request, env);
  if (url.pathname === "/config" && m === "GET") return config(request, env);
  if (url.pathname === "/lovea/freigabe" && m === "GET") return loveaFreigabe(request, env);
  if (url.pathname === "/lovea/agent/ops" && m === "GET") return loveaOps(request, url, env, holen);
  if (url.pathname === "/lovea/ops" && m === "POST") return loveaOpsSenden(request, env, holen);
  if (url.pathname === "/lovea/export-erledigt" && m === "POST") return exportErledigt(request, env);
  if (url.pathname === "/lovea/import-erledigt" && m === "POST") return importErledigt(request, env);
  if (url.pathname === "/lovea/import-beleg" && m === "POST") return importBeleg(request, env);
  if (url.pathname === "/diagnose/schlaf" && m === "POST") return schlafBelegAnnehmen(request, env);
  if (url.pathname === "/nutzung" && m === "POST") return nutzungMelden(request, env);
  if (url.pathname === "/partner" && m === "PUT") return partnerLegen(request, env);
  if (url.pathname === "/partner" && m === "GET") return partnerLesen(request, env);
  if (url.pathname === "/verbindungen" || url.pathname.startsWith("/verbindungen/")) {
    return verbindungen(request, url, env, { kontoPruefen, json, nein, koerper, lesen, istObjekt, sha256, freigegeben, PERSONEN, andere, filtern, BEREICHE });
  }
  if (url.pathname === "/ki/foto" && m === "POST") return kiFoto(request, env, { kontoPruefen, zusammen, globaleConfig }, kiHolen);
  if (url.pathname === "/postfach" || url.pathname.startsWith("/postfach/")) return postfachApp(request, url, env, { kontoPruefen, json, nein, koerper, lesen });
  if (url.pathname.startsWith("/essen/") && m === "GET") return handleEssen(request, url, env, { kontoPruefen });
  if (url.pathname.startsWith("/admin/")) return verwalten(request, url, env);
  if (url.pathname.startsWith("/coach/")) return coach(request, url, env, { json, nein, koerper, lesen, gleich });
  return nein(404, "not found");
}

export default { fetch: (request, env) => handleFetch(request, env) };
