import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fakeD1 } from "./fake-d1.js";
import { handleFetch } from "./index.js";
import { WERKZEUGE, werkzeugAufrufen } from "./mcp.mjs";

const SCHEMA = readFileSync(new URL("./schema.sql", import.meta.url), "utf8");
const APP = "app-key-test";
const ADMIN = "admin-key-test";
const ID = "a".repeat(32);
const GEHEIM = "g".repeat(48);
const env = () => ({ DB: fakeD1(SCHEMA), APP_KEY: APP, ADMIN_KEY: ADMIN, LOVEA_KEY: "lovea-geheim", LOVEA_URL: "https://lovea.test" });
const app = (extra = {}) => ({ "X-App-Key": APP, "X-Konto": ID, "X-Geheimnis": GEHEIM, ...extra });
const admin = { "X-Admin-Key": ADMIN, "content-type": "application/json" };
async function ruf(e, methode, pfad, { headers = {}, body } = {}) {
  const r = await handleFetch(new Request("https://x.test" + pfad, { method: methode, headers, body: body === undefined ? undefined : JSON.stringify(body) }), e);
  const text = await r.text();
  let json = null;
  try { json = JSON.parse(text); } catch {}
  return { status: r.status, json, text };
}
async function konto(e, person) {
  await ruf(e, "POST", "/konto", { headers: { "X-App-Key": APP }, body: { id: ID, geheimnis: GEHEIM, name: "Test", version: "1" } });
  if (person) await ruf(e, "PATCH", `/admin/konto/${ID}`, { headers: admin, body: { einstellungen: { loveaVerbinden: true }, lovea_person: person } });
}
const beleg = (extra = {}) => ({
  typ: "beleg", zeit: new Date().toISOString(), vollstaendig: true, seqMax: 11698, unlesbar: 0, neu: 10, schonDa: 0, uebersprungen: 0,
  arten: { "habit.setzen": { geholt: 10, uebernommen: 10, geplant: 10, wiedergefunden: 10 }, "nachricht.neu": { geholt: 5, ausgeschlossen: 5, grund: "Chat" } },
  ...extra,
});

test("Import-Beleg: nur freigegebene Konten, Eingabe geprüft, Größe begrenzt, letzter Beleg bleibt, Admin zeigt ihn", async () => {
  const e = env();
  await konto(e);
  const senden = (body, h = app()) => ruf(e, "POST", "/lovea/import-beleg", { headers: h, body });
  assert.equal((await senden(beleg())).status, 403, "ohne Freigabe nicht");
  await ruf(e, "PATCH", `/admin/konto/${ID}`, { headers: admin, body: { einstellungen: { loveaVerbinden: true }, lovea_person: "annika" } });
  assert.equal((await senden(beleg(), app({ "X-Geheimnis": "x".repeat(48) }))).status, 401);
  assert.equal((await senden(beleg())).status, 200);
  const z = JSON.parse(e.DB.roh.prepare("SELECT wert FROM konto_merker WHERE schluessel = 'lovea_import_beleg'").get().wert);
  assert.equal(z.arten["habit.setzen"].wiedergefunden, 10);
  assert.equal(z.arten["nachricht.neu"].grund, "Chat");
  assert.equal(z.arten["habit.setzen"].unbekannt, 0);
  for (const schlecht of [
    beleg({ vollstaendig: "ja" }), beleg({ seqMax: -1 }), beleg({ zeit: "gestern" }), beleg({ arten: [] }),
    beleg({ arten: { "Freitext mit Leerzeichen": { geholt: 1 } } }), beleg({ arten: { "habit.setzen": { geholt: 1.5 } } }),
    beleg({ arten: { "habit.setzen": { geholt: 1, grund: "x".repeat(200) } } }),
    { typ: "fehler", zeit: new Date().toISOString(), fehler: "frei erfunden" }, { typ: "sonst" }, [],
  ]) assert.equal((await senden(schlecht)).status, 400, JSON.stringify(schlecht).slice(0, 70));
  const gross = beleg({ ballast: "x".repeat(41000) });
  assert.equal((await senden(gross)).status, 413);
  assert.equal((await senden(beleg({ vollstaendig: false, neu: 3 }))).status, 200);
  assert.equal(e.DB.roh.prepare("SELECT COUNT(*) AS n FROM konto_merker WHERE schluessel = 'lovea_import_beleg'").get().n, 1, "ein Beleg je Konto, der letzte");
  assert.equal((await ruf(e, "GET", "/admin/import-beleg")).status, 401);
  const k = (await ruf(e, "GET", "/admin/import-beleg", { headers: admin })).json.konten[0];
  assert.equal(k.lovea_person, "annika");
  assert.equal(k.beleg.vollstaendig, false);
  assert.equal(k.beleg.neu, 3);
  assert.equal(k.fehler, null);
  assert.equal(k.lovea_import_erledigt, null);
  assert.ok(!JSON.stringify(k).includes(GEHEIM));
});

test("Import-Beleg: Übernahme-Gruppen (Abgabe aus Lovea) werden geprüft und gespeichert, alte Apps ohne Feld gehen weiter", async () => {
  const e = env();
  await konto(e, "annika");
  const senden = (body) => ruf(e, "POST", "/lovea/import-beleg", { headers: app(), body });
  const gruppe = { geholt: 3, aelter: 2, uebernommen: 1, vorhanden: 0, roh: 0, unlesbar: 0, eintraege: 4, geschrieben: 4 };
  assert.equal((await senden(beleg({ uebernahme: { "abgabe.lovea.gym.studioprofil": gruppe, "wecker.setzen": { geholt: 5, roh: 5, eintraege: 5 } } }))).status, 200);
  const z = JSON.parse(e.DB.roh.prepare("SELECT wert FROM konto_merker WHERE schluessel = 'lovea_import_beleg'").get().wert);
  assert.deepEqual(z.uebernahme["abgabe.lovea.gym.studioprofil"], gruppe);
  assert.equal(z.uebernahme["wecker.setzen"].roh, 5);
  assert.equal(z.uebernahme["wecker.setzen"].aelter, 0, "fehlende Zahl = 0");
  for (const schlecht of [
    beleg({ uebernahme: [] }), beleg({ uebernahme: { "Freitext mit Leerzeichen": gruppe } }), beleg({ uebernahme: { "abgabe.x": { geholt: 1.5 } } }),
    beleg({ uebernahme: { "abgabe.x": { geholt: -1 } } }), beleg({ uebernahme: { "abgabe.x": "text" } }),
    beleg({ uebernahme: Object.fromEntries(Array.from({ length: 61 }, (_, i) => [`abgabe.g${i}`, gruppe])) }),
  ]) assert.equal((await senden(schlecht)).status, 400, JSON.stringify(schlecht).slice(0, 70));
  assert.equal((await senden(beleg())).status, 200, "alte App ohne Feld");
  const k = (await ruf(e, "GET", "/admin/import-beleg", { headers: admin })).json.konten[0];
  assert.deepEqual(k.beleg.uebernahme, {});
});

test("Import-Fehler: Art aus fester Liste, zählt mit, Beleg bleibt daneben stehen", async () => {
  const e = env();
  await konto(e, "annika");
  const fehler = (f, extra = {}) => ruf(e, "POST", "/lovea/import-beleg", { headers: app(), body: { typ: "fehler", zeit: new Date().toISOString(), fehler: f, geladen: 4000, bisSeq: 4100, ...extra } });
  assert.equal((await fehler("keine_daten", { geladen: undefined, bisSeq: undefined })).status, 200);
  assert.equal((await fehler("netz")).status, 200);
  assert.equal((await fehler("netz", { geladen: -5 })).status, 400);
  const k = (await ruf(e, "GET", "/admin/import-beleg", { headers: admin })).json.konten[0];
  assert.equal(k.fehler.fehler, "netz");
  assert.equal(k.fehler.anzahl, 2);
  assert.equal(k.fehler.geladen, 4000);
  assert.equal(k.fehler.bisSeq, 4100);
  assert.equal(k.beleg, null);
});

test("MCP: lumenfit_import_beleg ruft GET /admin/import-beleg", async () => {
  assert.ok(WERKZEUGE.some((w) => w.name === "lumenfit_import_beleg"));
  const aufrufe = [];
  const holen = async (url, opt) => { aufrufe.push({ url, opt }); return Response.json({ konten: [] }); };
  await werkzeugAufrufen("lumenfit_import_beleg", {}, { holen, key: "K", basis: { live: "https://live.test", test: "https://test.test" } });
  assert.equal(aufrufe[0].url, "https://live.test/admin/import-beleg");
  assert.equal(aufrufe[0].opt.method, "GET");
});

test("Spuren des Servers: Freigabe-Abruf und Ops-Seiten werden mitgezählt, ohne dass die App einen Beleg schickt", async () => {
  const e = env();
  await konto(e, "annika");
  const holen = async () => Response.json({ ops: [], mehr: true });
  const abruf = (seit) => handleFetch(new Request(`https://x.test/lovea/agent/ops?seit=${seit}`, { headers: app() }), e, holen);
  assert.equal((await ruf(e, "GET", "/lovea/freigabe", { headers: app() })).status, 200);
  assert.equal((await abruf(0)).status, 200);
  assert.equal((await abruf(200)).status, 200);
  assert.equal((await abruf(400)).status, 200);
  const k = (await ruf(e, "GET", "/admin/import-beleg", { headers: admin })).json.konten[0];
  assert.ok(k.freigabe_zuletzt_geholt);
  assert.equal(k.ops_abruf.seiten, 3);
  assert.equal(k.ops_abruf.seit, 400);
  assert.equal(k.beleg, null);
  await abruf(0);
  assert.equal((await ruf(e, "GET", "/admin/import-beleg", { headers: admin })).json.konten[0].ops_abruf.seiten, 1, "seit 0 beginnt einen neuen Lauf");
});
