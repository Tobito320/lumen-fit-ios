// Lumen-Fit-Server (Cloudflare Worker + D1): Konten, Einstellungen ohne Build, Lovea-Freigabe als Proxy.
// App-Wege: X-App-Key + X-Konto + X-Geheimnis. Verwaltung (/admin/*): nur X-Admin-Key.
// Reine fetch(request, env, holen)-Funktion ohne cloudflare:workers-Import -> unter Node testbar.
import { kiFoto } from "./ki-foto.js";

const STANDARD = { profilAnlegenErlaubt: false, loveaVerbinden: false, nameAendernTage: 7 };
const PERSONEN = ["ahmed", "annika"];
// shortcut: harte Obergrenze statt Ratenbegrenzung gegen Massen-Registrierung; bei mehr Geräten Grenze anheben oder Cloudflare-Regel davor.
const MAX_KONTEN = 200;
const ID_FORM = /^[A-Za-z0-9_-]{16,64}$/;
const GEHEIM_FORM = /^[A-Za-z0-9_-]{32,128}$/;
const SCHLUESSEL_FORM = /^[A-Za-z][A-Za-z0-9_]{0,40}$/;
const MAX_EINSTELLUNGEN_BYTES = 4000;
const MAX_LIMIT = 200;
const TAG_FORM = /^\d{4}-\d{2}-\d{2}$/;
const NAME_FORM = /^[a-z][A-Za-z0-9_.]{0,39}$/;
const MAX_NAMEN = 60;
const NUTZUNG_TAGE = 90;
const FREIGABEN = ["schritte", "gym", "schlaf", "essen", "plan", "verlauf", "tagebuch", "koerper"];
// Partner-Daten: rohe Obergrenze, bevor etwas geparst wird. Gesäubert bleibt es weit darunter (Plan, Tagebuch, Messreihen sind einzeln begrenzt).
const MAX_PARTNER_BYTES = 262144;
const KOERPER_ARTEN = ["gewicht", "taille", "brust", "schulter", "bizeps", "oberschenkel", "koerperfett"];
const MAHLZEITEN = ["fruehstueck", "mittag", "abend", "snack"];
const EREIGNIS_ARTEN = ["gymStart", "gymEnde", "ziel", "rekord", "schlafGut"];
// Namen, die die App meldet (Tabs, Seiten, Funktionen). "Nie genutzt" in der Auswertung = in dieser Liste, aber nie gemeldet.
// Nur Namen, die die App wirklich senden kann: Tabs, die Seiten, die als eigene Route auf einem Tab liegen, und die zwei Blätter. Die Unterseiten im Profil
// (Aussehen, Ziele ...) sind Links innerhalb des Blatts und werden nicht einzeln gemessen: das Profil zählt als "blatt.profil".
export const BEKANNTE_BEREICHE = [
  "tab.heute", "tab.gym", "tab.essen", "tab.schlaf", "tab.coach", "blatt.profil", "blatt.freund",
  "seite.gym.plaene", "seite.gym.fortschritt", "seite.essen.scan", "seite.essen.favoriten", "seite.schlaf.verlauf", "seite.schlaf.werte",
  "seite.verlauf", "seite.gewichtEintragen", "seite.uebung",
];
export const BEKANNTE_FUNKTIONEN = ["training", "satz", "mahlzeit", "gewicht", "habit", "meilenstein"];

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
  return cfg;
}
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
  return json({ erlaubt: true, person: konto.lovea_person, importErledigt: !!(await merker(env, konto.id, "lovea_import")) });
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

// Zähler { name: Anzahl } prüfen; null bei ungültiger Form. Nur Namen aus Kleinbuchstaben-Anfang, nie Freitext.
function zaehler(x) {
  if (x === undefined) return {};
  if (!istObjekt(x) || Object.keys(x).length > MAX_NAMEN) return null;
  const aus = {};
  for (const [k, v] of Object.entries(x)) {
    if (!NAME_FORM.test(k) || !Number.isInteger(v) || v < 0 || v > 9999) return null;
    aus[k] = v;
  }
  return aus;
}
const summe = (a, b) => { const o = { ...a }; for (const [k, v] of Object.entries(b)) o[k] = Math.min(9999, (o[k] ?? 0) + v); return o; };

// Nutzung: ein Bündel je Start (Tag, Zähler für Bereiche und Funktionen). Keine Inhalte, keine Gesundheitswerte. Mehrere Bündel am Tag werden addiert.
async function nutzungMelden(request, env) {
  const { konto, antwort } = await kontoPruefen(request, env);
  if (antwort) return antwort;
  const b = await koerper(request);
  if (!istObjekt(b) || !TAG_FORM.test(b.tag ?? "")) return nein(400, "ungültig");
  const t = Date.parse(`${b.tag}T00:00:00Z`);
  if (!(t > Date.now() - 3 * 864e5 && t < Date.now() + 2 * 864e5)) return nein(400, "tag");
  const bereiche = zaehler(b.bereiche), funktionen = zaehler(b.funktionen);
  if (!bereiche || !funktionen) return nein(400, "ungültig");
  const alt = await env.DB.prepare("SELECT bereiche, funktionen FROM nutzung WHERE konto = ? AND tag = ?").bind(konto.id, b.tag).first();
  const neuB = summe(lesen(alt?.bereiche), bereiche), neuF = summe(lesen(alt?.funktionen), funktionen);
  if (Object.keys(neuB).length > MAX_NAMEN || Object.keys(neuF).length > MAX_NAMEN) return nein(400, "zu viele Namen");
  const version = (request.headers.get("X-App-Version") ?? konto.version).slice(0, 20);
  await env.DB.prepare("INSERT OR REPLACE INTO nutzung (konto, tag, version, bereiche, funktionen) VALUES (?, ?, ?, ?, ?)")
    .bind(konto.id, b.tag, version, JSON.stringify(neuB), JSON.stringify(neuF)).run();
  const grenze = new Date(Date.now() - NUTZUNG_TAGE * 864e5).toISOString().slice(0, 10);
  await env.DB.prepare("DELETE FROM nutzung WHERE konto = ? AND tag < ?").bind(konto.id, grenze).run();
  return json({ ok: true });
}

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

// Freigabe verlauf: "im Gym" und die letzten Trainings als Zusammenfassung, nie Sätze oder Gewichte.
function verlaufSauber(v) {
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
  const neu = {
    plan: freigaben.includes("plan") ? planSauber(h.plan) : undefined,
    verlauf: freigaben.includes("verlauf") ? verlaufSauber(h.verlauf) : undefined,
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

// Der andere der zwei freigegebenen Konten (ahmed <-> annika), das zuletzt aktive ungesperrte.
const andere = (person) => PERSONEN.find((p) => p !== person);

async function partnerLegen(request, env) {
  const { konto, antwort } = await kontoPruefen(request, env);
  if (antwort) return antwort;
  if (!freigegeben(konto)) return nein(403, "nicht freigegeben");
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

async function partnerLesen(request, env) {
  const { konto, antwort } = await kontoPruefen(request, env);
  if (antwort) return antwort;
  if (!freigegeben(konto)) return nein(403, "nicht freigegeben");
  const zeile = await env.DB.prepare(
    "SELECT p.daten, p.aktualisiert FROM partner_stand p JOIN konten k ON k.id = p.konto WHERE k.lovea_person = ? AND k.gesperrt = 0 ORDER BY p.aktualisiert DESC")
    .bind(andere(konto.lovea_person)).first();
  return json({ partner: zeile ? lesen(zeile.daten) : null, aktualisiert: zeile?.aktualisiert ?? null });
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
  if (url.pathname === "/admin/config" && m === "PATCH") {
    const r = flicken(await globaleConfig(env), await koerper(request), ["loveaVerbinden"]);
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
  if (url.pathname === "/lovea/import-erledigt" && m === "POST") return importErledigt(request, env);
  if (url.pathname === "/nutzung" && m === "POST") return nutzungMelden(request, env);
  if (url.pathname === "/partner" && m === "PUT") return partnerLegen(request, env);
  if (url.pathname === "/partner" && m === "GET") return partnerLesen(request, env);
  if (url.pathname === "/ki/foto" && m === "POST") return kiFoto(request, env, { kontoPruefen, zusammen, globaleConfig }, kiHolen);
  if (url.pathname.startsWith("/admin/")) return verwalten(request, url, env);
  return nein(404, "not found");
}

export default { fetch: (request, env) => handleFetch(request, env) };
