import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fakeD1 } from "./fake-d1.js";
import { handleFetch } from "./index.js";

const SCHEMA = readFileSync(new URL("./schema.sql", import.meta.url), "utf8");
const APP = "app-key-test";
const ADMIN = "admin-key-test";
const ID = "a".repeat(32);
const GEHEIM = "g".repeat(48);

function umgebung() {
  return { DB: fakeD1(SCHEMA), APP_KEY: APP, ADMIN_KEY: ADMIN, LOVEA_KEY: "lovea-geheim", LOVEA_URL: "https://lovea.test" };
}
const app = (extra = {}) => ({ "X-App-Key": APP, "X-Konto": ID, "X-Geheimnis": GEHEIM, ...extra });
const admin = { "X-Admin-Key": ADMIN, "content-type": "application/json" };
async function ruf(env, methode, pfad, { headers = {}, body, holen } = {}) {
  const r = await handleFetch(new Request("https://x.test" + pfad, { method: methode, headers, body: body === undefined ? undefined : JSON.stringify(body) }), env, holen);
  const text = await r.text();
  let json = null;
  try { json = JSON.parse(text); } catch {}
  return { status: r.status, json, text };
}
const registrieren = (env, id = ID, geheimnis = GEHEIM, name = "Ahmed iPhone") =>
  ruf(env, "POST", "/konto", { headers: { "X-App-Key": APP }, body: { id, geheimnis, name, version: "1.0 (1)" } });

test("Registrieren legt Konto an, nur Hash wird gespeichert", async () => {
  const env = umgebung();
  const r = await registrieren(env);
  assert.equal(r.status, 201);
  const zeile = env.DB.roh.prepare("SELECT * FROM konten").get();
  assert.equal(zeile.id, ID);
  assert.equal(zeile.name, "Ahmed iPhone");
  assert.notEqual(zeile.hash, GEHEIM);
  assert.match(zeile.hash, /^[0-9a-f]{64}$/);
  assert.ok(!JSON.stringify(zeile).includes(GEHEIM));
});

test("Registrieren: falscher App-Key 401, doppelte ID 409, schlechte Form 400", async () => {
  const env = umgebung();
  assert.equal((await ruf(env, "POST", "/konto", { headers: { "X-App-Key": "falsch" }, body: { id: ID, geheimnis: GEHEIM, name: "x" } })).status, 401);
  assert.equal((await registrieren(env, "kurz")).status, 400);
  assert.equal((await registrieren(env, ID, "zu-kurz")).status, 400);
  assert.equal((await registrieren(env, ID, GEHEIM, "")).status, 400);
  assert.equal((await registrieren(env)).status, 201);
  assert.equal((await registrieren(env, ID, "h".repeat(48))).status, 409);
  // Das Geheimnis des ersten Kontos bleibt gültig.
  assert.equal((await ruf(env, "GET", "/config", { headers: app() })).status, 200);
});

test("Registrieren ist bei zu vielen Konten gedeckelt", async () => {
  const env = umgebung();
  for (let i = 0; i < 200; i++) env.DB.roh.prepare("INSERT INTO konten (id, hash, name, erstellt, gesehen) VALUES (?, 'h', 'n', 't', 't')").run("k" + i);
  assert.equal((await registrieren(env)).status, 429);
});

test("Config: Standardwerte, Konto gewinnt vor global gewinnt vor Standard", async () => {
  const env = umgebung();
  await registrieren(env);
  let r = await ruf(env, "GET", "/config", { headers: app() });
  assert.deepEqual(r.json.config, { profilAnlegenErlaubt: false, loveaVerbinden: false, nameAendernTage: 7 });
  await ruf(env, "PATCH", "/admin/config", { headers: admin, body: { nameAendernTage: 3, neu: "x" } });
  await ruf(env, "PATCH", `/admin/konto/${ID}`, { headers: admin, body: { einstellungen: { nameAendernTage: 1 } } });
  r = await ruf(env, "GET", "/config", { headers: app() });
  assert.equal(r.json.config.nameAendernTage, 1);
  assert.equal(r.json.config.neu, "x");
  await ruf(env, "PATCH", `/admin/konto/${ID}`, { headers: admin, body: { einstellungen: { nameAendernTage: null } } });
  r = await ruf(env, "GET", "/config", { headers: app() });
  assert.equal(r.json.config.nameAendernTage, 3);
});

test("Config: Konto-Authentifizierung, unbekannte ID und falsches Geheimnis sehen gleich aus", async () => {
  const env = umgebung();
  await registrieren(env);
  const kein = await ruf(env, "GET", "/config", { headers: { "X-App-Key": APP } });
  const falsch = await ruf(env, "GET", "/config", { headers: app({ "X-Geheimnis": "x".repeat(48) }) });
  const unbekannt = await ruf(env, "GET", "/config", { headers: app({ "X-Konto": "b".repeat(32) }) });
  const ohneApp = await ruf(env, "GET", "/config", { headers: app({ "X-App-Key": "nein" }) });
  for (const r of [kein, falsch, unbekannt, ohneApp]) assert.equal(r.status, 401);
  assert.equal(falsch.text, unbekannt.text);
});

test("Config merkt zuletzt gesehen und Version", async () => {
  const env = umgebung();
  await registrieren(env);
  env.DB.roh.prepare("UPDATE konten SET gesehen = '2000-01-01T00:00:00.000Z'").run();
  await ruf(env, "GET", "/config", { headers: app({ "X-App-Version": "1.2 (9)" }) });
  const z = env.DB.roh.prepare("SELECT gesehen, version FROM konten").get();
  assert.equal(z.version, "1.2 (9)");
  assert.ok(z.gesehen > "2020");
});

test("Gesperrtes Konto bekommt 403 auf allem", async () => {
  const env = umgebung();
  await registrieren(env);
  await ruf(env, "PATCH", `/admin/konto/${ID}`, { headers: admin, body: { gesperrt: true } });
  assert.equal((await ruf(env, "GET", "/config", { headers: app() })).status, 403);
  assert.equal((await ruf(env, "GET", "/lovea/freigabe", { headers: app() })).status, 403);
  await ruf(env, "PATCH", `/admin/konto/${ID}`, { headers: admin, body: { gesperrt: false } });
  assert.equal((await ruf(env, "GET", "/config", { headers: app() })).status, 200);
});

test("Admin: ohne Admin-Key 401, App-Key reicht nicht", async () => {
  const env = umgebung();
  for (const h of [{}, { "X-Admin-Key": "falsch" }, { "X-App-Key": APP }]) {
    assert.equal((await ruf(env, "GET", "/admin/konten", { headers: h })).status, 401);
    assert.equal((await ruf(env, "PATCH", "/admin/config", { headers: h, body: { a: 1 } })).status, 401);
  }
  const ohneSecret = { ...env, ADMIN_KEY: undefined };
  assert.equal((await ruf(ohneSecret, "GET", "/admin/konten", { headers: {} })).status, 401);
});

test("Admin-Liste zeigt Konten ohne Hash und Geheimnis", async () => {
  const env = umgebung();
  await registrieren(env);
  await ruf(env, "PATCH", `/admin/konto/${ID}`, { headers: admin, body: { einstellungen: { loveaVerbinden: true }, lovea_person: "annika" } });
  const r = await ruf(env, "GET", "/admin/konten", { headers: admin });
  assert.equal(r.status, 200);
  assert.equal(r.json.konten.length, 1);
  const k = r.json.konten[0];
  assert.equal(k.id, ID);
  assert.equal(k.name, "Ahmed iPhone");
  assert.equal(k.lovea_person, "annika");
  assert.equal(k.einstellungen.loveaVerbinden, true);
  assert.ok(!r.text.includes(GEHEIM) && !("hash" in k));
});

test("Admin: ungültige Eingaben werden abgelehnt", async () => {
  const env = umgebung();
  await registrieren(env);
  const p = (body) => ruf(env, "PATCH", `/admin/konto/${ID}`, { headers: admin, body });
  assert.equal((await p({ lovea_person: "bernd" })).status, 400);
  assert.equal((await p({ einstellungen: { loveaVerbinden: "ja" } })).status, 400);
  assert.equal((await p({ einstellungen: { loveaVerbinden: true } })).status, 400, "ohne Person nicht freigeben");
  assert.equal((await p({ einstellungen: { "böse schlüssel": 1 } })).status, 400);
  assert.equal((await p({ gesperrt: "ja" })).status, 400);
  assert.equal((await ruf(env, "PATCH", `/admin/konto/${"c".repeat(32)}`, { headers: admin, body: { gesperrt: true } })).status, 404);
  assert.equal((await ruf(env, "PATCH", "/admin/config", { headers: admin, body: { loveaVerbinden: true } })).status, 400, "loveaVerbinden nie global");
  assert.equal((await ruf(env, "PATCH", "/admin/config", { headers: admin, body: [] })).status, 400);
});

test("loveaVerbinden zählt nie aus global, nur je Konto mit Person", async () => {
  const env = umgebung();
  await registrieren(env);
  // Falsche Daten direkt in der DB (an der Prüfung vorbei) dürfen nichts öffnen.
  env.DB.roh.prepare("UPDATE globale_config SET einstellungen = ?").run(JSON.stringify({ loveaVerbinden: true }));
  let r = await ruf(env, "GET", "/config", { headers: app() });
  assert.equal(r.json.config.loveaVerbinden, false);
  env.DB.roh.prepare("UPDATE konten SET einstellungen = ?").run(JSON.stringify({ loveaVerbinden: true }));
  r = await ruf(env, "GET", "/config", { headers: app() });
  assert.equal(r.json.config.loveaVerbinden, false, "ohne Person zu");
  env.DB.roh.prepare("UPDATE konten SET lovea_person = 'ahmed'").run();
  r = await ruf(env, "GET", "/config", { headers: app() });
  assert.equal(r.json.config.loveaVerbinden, true);
});

test("Lovea-Freigabe: nur für freigegebenes Konto, nennt Person, nie den Key", async () => {
  const env = umgebung();
  await registrieren(env);
  let r = await ruf(env, "GET", "/lovea/freigabe", { headers: app() });
  assert.deepEqual(r.json, { erlaubt: false });
  await ruf(env, "PATCH", `/admin/konto/${ID}`, { headers: admin, body: { einstellungen: { loveaVerbinden: true }, lovea_person: "annika" } });
  r = await ruf(env, "GET", "/lovea/freigabe", { headers: app() });
  assert.deepEqual(r.json, { erlaubt: true, person: "annika" });
  assert.ok(!r.text.includes("lovea-geheim"));
});

test("Lovea-Proxy: gesperrt ohne Freigabe, holt nichts", async () => {
  const env = umgebung();
  await registrieren(env);
  let gerufen = 0;
  const holen = async () => { gerufen++; return new Response("{}"); };
  const r = await ruf(env, "GET", "/lovea/agent/ops?seit=0", { headers: app(), holen });
  assert.equal(r.status, 403);
  assert.equal(gerufen, 0);
  assert.ok(!r.text.includes("lovea-geheim"));
  // Falsche Konto-Anmeldung: 401, auch ohne Freigabe-Prüfung.
  assert.equal((await ruf(env, "GET", "/lovea/agent/ops", { headers: app({ "X-Geheimnis": "x".repeat(48) }), holen })).status, 401);
  assert.equal(gerufen, 0);
});

test("Lovea-Proxy: freigegeben, Person und Key vom Server, Query gefiltert", async () => {
  const env = umgebung();
  await registrieren(env);
  await ruf(env, "PATCH", `/admin/konto/${ID}`, { headers: admin, body: { einstellungen: { loveaVerbinden: true }, lovea_person: "ahmed" } });
  let gesehen;
  const holen = async (url, opt) => { gesehen = { url: String(url), h: opt.headers }; return Response.json({ ops: [{ seq: 1 }], mehr: false }); };
  const r = await ruf(env, "GET", "/lovea/agent/ops?seit=5&limit=9999&aufsteigend=1&voll=1&von=annika&art=nachricht.neu&suche=x", { headers: app(), holen });
  assert.equal(r.status, 200);
  assert.deepEqual(r.json, { ops: [{ seq: 1 }], mehr: false });
  const u = new URL(gesehen.url);
  assert.equal(u.origin + u.pathname, "https://lovea.test/agent/ops");
  assert.equal(u.searchParams.get("von"), "ahmed", "von kommt vom Konto, nicht von der App");
  assert.equal(u.searchParams.get("seit"), "5");
  assert.equal(u.searchParams.get("limit"), "200");
  assert.equal(u.searchParams.get("aufsteigend"), "1");
  assert.equal(u.searchParams.get("voll"), "1");
  assert.equal(u.searchParams.has("art"), false);
  assert.equal(u.searchParams.has("suche"), false);
  assert.equal(gesehen.h["X-Lovea-Key"], "lovea-geheim");
  assert.equal(gesehen.h["X-Lovea-Person"], "ahmed");
  assert.ok(!r.text.includes("lovea-geheim"));
});

test("Lovea-Proxy: Fehler von Lovea werden zu 502 ohne Inhalt, andere Pfade gibt es nicht", async () => {
  const env = umgebung();
  await registrieren(env);
  await ruf(env, "PATCH", `/admin/konto/${ID}`, { headers: admin, body: { einstellungen: { loveaVerbinden: true }, lovea_person: "ahmed" } });
  const holen = async () => new Response("secret-fehler lovea-geheim", { status: 401 });
  const r = await ruf(env, "GET", "/lovea/agent/ops", { headers: app(), holen });
  assert.equal(r.status, 502);
  assert.ok(!r.text.includes("lovea-geheim"));
  for (const p of ["/lovea/agent/statistik", "/lovea/raum", "/lovea/agent/ops/x"]) assert.equal((await ruf(env, "GET", p, { headers: app(), holen })).status, 404);
  assert.equal((await ruf(env, "POST", "/lovea/agent/ops", { headers: app(), holen })).status, 404);
});

test("Unbekannte Pfade 404, Antworten sind JSON ohne Geheimnisse", async () => {
  const env = umgebung();
  assert.equal((await ruf(env, "GET", "/", { headers: app() })).status, 404);
  assert.equal((await ruf(env, "GET", "/gesundheit")).status, 200);
});
