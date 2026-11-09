import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { createHash } from "node:crypto";
import { fakeD1 } from "./fake-d1.js";
import { handleFetch } from "./index.js";

const SCHEMA = readFileSync(new URL("./schema.sql", import.meta.url), "utf8");
const APP = "app-key-test";
const KONTEN = {
  ich: { id: "a".repeat(32), geheimnis: "g".repeat(48), name: "Beispiel Ich" },
  du: { id: "b".repeat(32), geheimnis: "h".repeat(48), name: "Beispiel Du" },
  fremd: { id: "c".repeat(32), geheimnis: "i".repeat(48), name: "Beispiel Fremd" },
  vier: { id: "d".repeat(32), geheimnis: "j".repeat(48), name: "Beispiel Vier" },
};
const kopf = (k) => ({ "X-App-Key": APP, "X-Konto": KONTEN[k].id, "X-Geheimnis": KONTEN[k].geheimnis });
const heute = () => new Date().toISOString().slice(0, 10);

// Jede Antwort wird auf die Konto-Ids der anderen Personen durchsucht: keine darf je hinausgehen.
async function ruf(env, k, methode, pfad, body) {
  const r = await handleFetch(new Request("https://x.test" + pfad, { method: methode, headers: k === null ? {} : kopf(k), body: body === undefined ? undefined : JSON.stringify(body) }), env);
  const text = await r.text();
  let json = null;
  try { json = JSON.parse(text); } catch {}
  if (k !== null) {
    for (const [n, x] of Object.entries(KONTEN)) if (n !== k) assert.ok(!text.includes(x.id), `${methode} ${pfad}: Konto-Id von ${n} in der Antwort`);
  }
  return { status: r.status, json, text, headers: r.headers };
}
async function welt(...namen) {
  const env = { DB: fakeD1(SCHEMA), APP_KEY: APP, ADMIN_KEY: "admin-key-test", LOVEA_KEY: "x", LOVEA_URL: "https://lovea.test" };
  for (const n of namen) {
    const k = KONTEN[n];
    const r = await handleFetch(new Request("https://x.test/konto", { method: "POST", headers: { "X-App-Key": APP }, body: JSON.stringify({ id: k.id, geheimnis: k.geheimnis, name: k.name, version: "1" }) }), env);
    assert.equal(r.status, 201);
  }
  return env;
}
// Besitzer zeigt Code, Scanner fragt an, Besitzer nimmt an. Liefert die Verbindungs-Id.
async function verbinden(env, besitzer, scanner) {
  const { json: e } = await ruf(env, besitzer, "POST", "/verbindungen/einladung");
  const a = await ruf(env, scanner, "POST", "/verbindungen/anfrage", { token: e.token });
  assert.equal(a.status, 201);
  assert.equal((await ruf(env, besitzer, "POST", `/verbindungen/${a.json.id}/annehmen`)).status, 200);
  return a.json.id;
}
const duell = (einladen, extra = {}) => ({ art: "saetze", modus: "gegen", tage: 7, einladen, ...extra });
const erstellen = (env, k, body) => ruf(env, k, "POST", "/freunde/herausforderungen", body);
const uebersicht = async (env, k) => (await ruf(env, k, "GET", "/freunde")).json;
const hole = async (env, k, id) => (await uebersicht(env, k)).herausforderungen.find((x) => x.id === id);
const sql = (env, text, ...w) => env.DB.roh.prepare(text).run(...w);
const einst = (env, vid, seite, e) => sql(env, `UPDATE verbindungen SET ${seite}_einst = ? WHERE id = ?`, JSON.stringify(e), vid);
const sha16 = (s) => createHash("sha256").update(s).digest("hex").slice(0, 16);

test("Alles braucht ein Konto, Landeseite nicht", async () => {
  const env = await welt("ich");
  for (const [m, p] of [["GET", "/freunde"], ["POST", "/freunde/herausforderungen"], ["PUT", "/freunde/werte"], ["POST", "/freunde/reaktionen"], ["DELETE", "/freunde/reaktionen"], ["POST", "/freunde/einladung"]]) {
    assert.equal((await ruf(env, null, m, p, m === "GET" ? undefined : {})).status, 401, `${m} ${p}`);
  }
  assert.equal((await ruf(env, "ich", "GET", "/freunde/unbekannt")).status, 404);
  assert.deepEqual(await uebersicht(env, "ich"), { herausforderungen: [], reaktionen: [], gesendet: [] });
});

test("Erstellen: nur mit eigenen aktiven Verbindungen, Pause blockiert, fremde Id geht nicht", async () => {
  const env = await welt("ich", "du", "fremd");
  const vd = await verbinden(env, "ich", "du");
  const vf = await verbinden(env, "fremd", "du"); // du <-> fremd, nicht meine
  assert.equal((await erstellen(env, "ich", duell([vf]))).status, 400, "Verbindung anderer Leute");
  assert.equal((await erstellen(env, "ich", duell(["e".repeat(32)]))).status, 400, "unbekannte Id");
  await einst(env, vd, "b", { pause: true });
  assert.equal((await erstellen(env, "ich", duell([vd]))).status, 400, "Pause auf der anderen Seite");
  await einst(env, vd, "b", {});
  await einst(env, vd, "a", { pause: true });
  assert.equal((await erstellen(env, "ich", duell([vd]))).status, 400, "Pause auf meiner Seite");
  await einst(env, vd, "a", {});
  const ok = await erstellen(env, "ich", duell([vd]));
  assert.equal(ok.status, 201);
  assert.match(ok.json.id, /^[a-f0-9]{32}$/);
  const x = await hole(env, "ich", ok.json.id);
  assert.equal(x.status, "laeuft");
  assert.equal(x.ersteller, true);
  assert.equal(x.ich, "dabei");
  assert.deepEqual(x.teilnehmer.map((t) => [t.status, t.ich, t.verbunden, t.wert]), [["dabei", true, false, 0], ["eingeladen", false, true, 0]]);
  assert.equal(x.teilnehmer[1].id, vd, "Verbundene erscheinen mit der Verbindungs-Id");
  const seine = await hole(env, "du", ok.json.id);
  assert.equal(seine.ich, "eingeladen");
  assert.equal(seine.ersteller, false);
  // Ende rund 7 Tage nach dem Start.
  assert.ok(Math.abs(Date.parse(x.ende) - Date.parse(x.start) - 7 * 86400_000) < 5000);
});

test("Erstellen prüft jede Eingabe an der Grenze", async () => {
  const env = await welt("ich", "du");
  const v = await verbinden(env, "ich", "du");
  const bad = async (body, was) => { sql(env, "DELETE FROM drossel"); assert.equal((await erstellen(env, "ich", body)).status, 400, was); };
  await bad(null, "kein Objekt");
  await bad(duell([v], { art: "kilometer" }), "art");
  await bad(duell([v], { modus: "alle" }), "modus");
  await bad(duell([v], { tage: 0 }), "tage 0");
  await bad(duell([v], { tage: 29 }), "tage 29");
  await bad(duell([v], { tage: 1.5 }), "tage Kommazahl");
  await bad(duell([v], { tage: "7" }), "tage Text");
  await bad({ art: "saetze", modus: "gegen", einladen: [v] }, "weder tage noch ende");
  await bad(duell([v], { ende: new Date(Date.now() + 86400_000).toISOString() }), "tage und ende");
  await bad({ art: "saetze", modus: "gegen", einladen: [v], ende: new Date(Date.now() + 60_000).toISOString() }, "ende unter 1 h");
  await bad({ art: "saetze", modus: "gegen", einladen: [v], ende: new Date(Date.now() + 30 * 86400_000).toISOString() }, "ende über 28 Tage");
  await bad({ art: "saetze", modus: "gegen", einladen: [v], ende: "morgen" }, "ende kein ISO");
  await bad(duell([v], { modus: "gemeinsam" }), "gemeinsam ohne ziel");
  await bad(duell([v], { modus: "gemeinsam", ziel: 0 }), "ziel 0");
  await bad(duell([v], { modus: "gemeinsam", ziel: 10_000_001 }), "ziel zu groß");
  await bad(duell([v], { ziel: 5 }), "ziel bei gegen");
  await bad(duell([v], { art: "uebung" }), "übung ohne Namen");
  await bad(duell([v], { art: "uebung", uebung: "x".repeat(41) }), "übungsname zu lang");
  await bad(duell([v], { art: "uebung", uebung: "Bank\ndrücken" }), "Steuerzeichen");
  await bad(duell([v], { uebung: "Bank" }), "übung bei anderer art");
  await bad(duell([]), "niemand eingeladen");
  await bad(duell([v, v]), "doppelt eingeladen");
  await bad(duell("x"), "einladen kein Array");
  await bad(duell(["nicht-hex"]), "Id-Form");
  await bad(duell(Array.from({ length: 10 }, (_, i) => String(i).repeat(32))), "mehr als 9");
  sql(env, "DELETE FROM drossel");
  assert.equal((await erstellen(env, "ich", duell([v], { modus: "gemeinsam", ziel: 500, art: "uebung", uebung: " Bankdrücken " }))).status, 201);
  const x = (await uebersicht(env, "ich")).herausforderungen[0];
  assert.deepEqual([x.modus, x.ziel, x.uebung, x.art], ["gemeinsam", 500, "Bankdrücken", "uebung"]);
  sql(env, "DELETE FROM drossel");
  const mitEnde = await erstellen(env, "ich", { art: "tage", modus: "gegen", einladen: [v], ende: new Date(Date.now() + 5 * 3600_000).toISOString() });
  assert.equal(mitEnde.status, 201);
});

test("Erstellen: Drossel 10 je Minute, höchstens 10 laufende, Aufräumen nach 30 Tagen", async () => {
  const env = await welt("ich", "du");
  const v = await verbinden(env, "ich", "du");
  for (let i = 0; i < 10; i++) assert.equal((await erstellen(env, "ich", null)).status, 400);
  assert.equal((await erstellen(env, "ich", null)).status, 429, "die elfte Anfrage in der Minute");
  sql(env, "DELETE FROM drossel");
  for (let i = 0; i < 10; i++) { assert.equal((await erstellen(env, "ich", duell([v]))).status, 201); }
  sql(env, "DELETE FROM drossel");
  const elf = await erstellen(env, "ich", duell([v]));
  assert.equal(elf.status, 429, "zehn laufende, in denen ich dabei bin");
  // Was seit mehr als 30 Tagen vorbei ist, geht beim nächsten Erstellen samt Teilnehmern.
  const alt = new Date(Date.now() - 31 * 86400_000).toISOString();
  sql(env, "UPDATE herausforderungen SET ende = ? WHERE rowid IN (SELECT rowid FROM herausforderungen LIMIT 2)", alt);
  sql(env, "DELETE FROM drossel");
  assert.equal((await erstellen(env, "ich", duell([v]))).status, 201);
  assert.equal(env.DB.roh.prepare("SELECT COUNT(*) AS n FROM herausforderungen").get().n, 9);
  assert.equal(env.DB.roh.prepare("SELECT COUNT(*) AS n FROM herausforderung_teilnehmer").get().n, 18, "keine Teilnehmer ohne Herausforderung");
});

test("Annehmen, Ablehnen, Verlassen; Fremde und Unbekannte sind nicht zu unterscheiden", async () => {
  const env = await welt("ich", "du", "fremd");
  const vd = await verbinden(env, "ich", "du");
  const x = (await erstellen(env, "ich", duell([vd]))).json.id;
  const weg = (k, id, a) => ruf(env, k, "POST", `/freunde/herausforderungen/${id}/${a}`);
  for (const a of ["annehmen", "ablehnen", "verlassen"]) {
    assert.equal((await weg("fremd", x, a)).status, 404, `fremd ${a}`);
    assert.equal((await weg("du", "f".repeat(32), a)).status, 404, `unbekannt ${a}`);
    assert.equal((await weg("du", "kaputt", a)).status, 404, `Form ${a}`);
  }
  assert.equal((await ruf(env, "fremd", "GET", "/freunde")).json.herausforderungen.length, 0);
  assert.equal((await weg("ich", x, "annehmen")).status, 409, "der Ersteller ist schon dabei");
  assert.equal((await weg("du", x, "verlassen")).status, 409, "eingeladen ist nicht dabei");
  assert.equal((await weg("du", x, "annehmen")).status, 200);
  assert.equal((await hole(env, "ich", x)).teilnehmer.find((t) => !t.ich).status, "dabei");
  assert.equal((await weg("du", x, "annehmen")).status, 409);
  assert.equal((await weg("du", x, "ablehnen")).status, 409, "ablehnen nur wenn eingeladen");
  assert.equal((await weg("du", x, "verlassen")).status, 200);
  assert.equal(await hole(env, "du", x), undefined, "ausgetreten: nicht mehr in der Liste");
  assert.equal((await hole(env, "ich", x)).teilnehmer.length, 1, "und nicht bei den anderen");
  assert.equal((await hole(env, "ich", x)).status, "laeuft", "ein Teilnehmer geht, die Herausforderung bleibt");
  // Ablehnen.
  const y = (await erstellen(env, "ich", duell([vd]))).json.id;
  assert.equal((await weg("du", y, "ablehnen")).status, 200);
  assert.equal(await hole(env, "du", y), undefined);
  assert.equal((await weg("du", y, "annehmen")).status, 409, "abgelehnt bleibt abgelehnt");
  // Vorbei oder abgebrochen: Annehmen geht nicht mehr.
  const z = (await erstellen(env, "ich", duell([vd]))).json.id;
  sql(env, "UPDATE herausforderungen SET ende = ? WHERE id = ?", new Date(Date.now() - 1000).toISOString(), z);
  assert.equal((await weg("du", z, "annehmen")).status, 409);
  assert.equal((await hole(env, "du", z)).status, "beendet");
});

test("Der Ersteller bricht ab, indem er verlässt", async () => {
  const env = await welt("ich", "du");
  const vd = await verbinden(env, "ich", "du");
  const x = (await erstellen(env, "ich", duell([vd]))).json.id;
  assert.equal((await ruf(env, "du", "POST", `/freunde/herausforderungen/${x}/annehmen`)).status, 200);
  assert.equal((await ruf(env, "ich", "POST", `/freunde/herausforderungen/${x}/verlassen`)).status, 200);
  assert.equal((await hole(env, "du", x)).status, "abgebrochen");
  assert.equal(await hole(env, "ich", x), undefined);
  // Werte werden dort nicht mehr angenommen, Annehmen auch nicht.
  const w = await ruf(env, "du", "PUT", "/freunde/werte", { werte: [{ id: x, wert: 5 }] });
  assert.deepEqual(w.json, { ok: true, gesetzt: 0 });
  const y = (await erstellen(env, "ich", duell([vd]))).json.id;
  await ruf(env, "ich", "POST", `/freunde/herausforderungen/${y}/verlassen`);
  assert.equal((await ruf(env, "du", "POST", `/freunde/herausforderungen/${y}/annehmen`)).status, 409);
});

test("Werte: nur wo ich dabei bin, nicht abgebrochen, bis Ende plus 24 Stunden", async () => {
  const env = await welt("ich", "du");
  const vd = await verbinden(env, "ich", "du");
  const x = (await erstellen(env, "ich", duell([vd]))).json.id;
  const melden = (k, werte) => ruf(env, k, "PUT", "/freunde/werte", { werte });
  assert.deepEqual((await melden("du", [{ id: x, wert: 7 }])).json, { ok: true, gesetzt: 0 }, "nur eingeladen: still übergangen");
  assert.deepEqual((await melden("ich", [{ id: x, wert: 12 }, { id: "f".repeat(32), wert: 3 }])).json, { ok: true, gesetzt: 1 }, "Unbekanntes still übergangen");
  await ruf(env, "du", "POST", `/freunde/herausforderungen/${x}/annehmen`);
  assert.equal((await melden("du", [{ id: x, wert: 9 }])).json.gesetzt, 1);
  const t = (await hole(env, "ich", x)).teilnehmer;
  assert.deepEqual(t.map((e) => e.wert), [12, 9]);
  assert.ok(t.every((e) => Math.abs(Date.parse(e.aktualisiert) - Date.now()) < 5000));
  // Ende vor 23 Stunden: noch ja; vor 25 Stunden: nein.
  sql(env, "UPDATE herausforderungen SET ende = ? WHERE id = ?", new Date(Date.now() - 23 * 3600_000).toISOString(), x);
  assert.equal((await melden("ich", [{ id: x, wert: 20 }])).json.gesetzt, 1);
  sql(env, "UPDATE herausforderungen SET ende = ? WHERE id = ?", new Date(Date.now() - 25 * 3600_000).toISOString(), x);
  assert.equal((await melden("ich", [{ id: x, wert: 30 }])).json.gesetzt, 0);
  assert.equal((await hole(env, "ich", x)).teilnehmer[0].wert, 20);
  // Form der Anfrage.
  for (const werte of [[{ id: x, wert: -1 }], [{ id: x, wert: 1_000_000_001 }], [{ id: x, wert: 1.5 }], [{ id: x, wert: "5" }], [{ id: "kaputt", wert: 1 }], [{ wert: 1 }], Array.from({ length: 21 }, () => ({ id: x, wert: 1 })), "x"]) {
    assert.equal((await melden("ich", werte)).status, 400, JSON.stringify(werte).slice(0, 60));
  }
  assert.equal((await ruf(env, "ich", "PUT", "/freunde/werte", {})).status, 400);
  assert.equal((await melden("ich", [])).status, 200);
});

test("Reaktion: nur an aktive Verbindungen mit Gym-Freigabe, ohne Pause", async () => {
  const env = await welt("ich", "du", "fremd");
  const vd = await verbinden(env, "ich", "du");
  const vf = await verbinden(env, "fremd", "du");
  const r = (k, body) => ruf(env, k, "POST", "/freunde/reaktionen", body);
  const gut = { an: vd, art: "respekt", ziel: "rekord:2026-11-09:kniebeuge", text: "Kniebeuge 120 kg × 5" };
  assert.equal((await r("ich", gut)).status, 201, "Standard zeigt Gym");
  assert.equal((await r("ich", { ...gut, an: vf })).status, 404, "Verbindung anderer Leute");
  assert.equal((await r("ich", { ...gut, an: "e".repeat(32) })).status, 404, "unbekannt");
  // Das Gegenüber zeigt kein Gym.
  await einst(env, vd, "a", { zeigt: ["schritte"] });
  assert.equal((await r("ich", { ...gut, ziel: "einheit:2026-11-09" })).status, 403);
  await einst(env, vd, "a", {});
  // Ich (Seite b, Besitzer des Codes) blende Gym bei ihr aus.
  await einst(env, vd, "b", { ausblenden: ["gym"] });
  assert.equal((await r("ich", { ...gut, ziel: "einheit:2026-11-09" })).status, 403);
  await einst(env, vd, "b", {});
  await einst(env, vd, "a", { pause: true });
  assert.equal((await r("ich", { ...gut, ziel: "einheit:2026-11-09" })).status, 403, "Pause der anderen Seite");
  await einst(env, vd, "a", {});
  await einst(env, vd, "b", { pause: true });
  assert.equal((await r("ich", { ...gut, ziel: "einheit:2026-11-09" })).status, 403, "Pause auf meiner Seite");
  await einst(env, vd, "b", {});
  for (const [was, body] of [["art", { ...gut, art: "herz" }], ["ziel leer", { ...gut, ziel: "" }], ["ziel zu lang", { ...gut, ziel: "x".repeat(81) }], ["text zu lang", { ...gut, text: "x".repeat(81) }],
    ["Steuerzeichen im Ziel", { ...gut, ziel: "a\u0000b" }], ["Zeilenumbruch im Text", { ...gut, text: "a\nb" }], ["Umkehr der Leserichtung", { ...gut, text: "a‮b" }], ["text Zahl", { ...gut, text: 5 }],
    ["an fehlt", { art: "respekt", ziel: "x" }], ["an keine Id", { ...gut, an: "x" }]]) {
    assert.equal((await r("ich", body)).status, 400, was);
  }
  const eigen = (await uebersicht(env, "ich")).gesendet;
  assert.deepEqual(eigen, [{ an: vd, art: "respekt", ziel: "rekord:2026-11-09:kniebeuge" }]);
  const dort = (await uebersicht(env, "du")).reaktionen;
  assert.equal(dort.length, 1);
  assert.deepEqual([dort[0].von, dort[0].name, dort[0].art, dort[0].ziel, dort[0].text], [vd, "Beispiel Ich", "respekt", "rekord:2026-11-09:kniebeuge", "Kniebeuge 120 kg × 5"]);
  assert.match(dort[0].id, /^[a-f0-9]{32}$/);
});

test("Stups: nur mit stups:<heute>, einmal am Tag je Person", async () => {
  const env = await welt("ich", "du");
  const vd = await verbinden(env, "ich", "du");
  const stups = (ziel) => ruf(env, "ich", "POST", "/freunde/reaktionen", { an: vd, art: "stups", ziel });
  assert.equal((await stups("stups:2020-01-01")).status, 400, "altes Datum");
  assert.equal((await stups("einheit:" + heute())).status, 400, "falsches Ziel für einen Stups");
  assert.equal((await stups("stups:" + heute())).status, 201);
  assert.equal((await stups("stups:" + heute())).status, 201, "doppelt: still ok");
  assert.equal(env.DB.roh.prepare("SELECT COUNT(*) AS n FROM reaktionen WHERE art = 'stups'").get().n, 1, "aber nur eine Zeile");
  // Dasselbe gilt für jede Reaktion: gleiche Art und gleiches Ziel gibt es nur einmal.
  const re = { an: vd, art: "stark", ziel: "einheit:" + heute(), text: "erst" };
  await ruf(env, "ich", "POST", "/freunde/reaktionen", re);
  await ruf(env, "ich", "POST", "/freunde/reaktionen", { ...re, text: "zweit" });
  assert.deepEqual(env.DB.roh.prepare("SELECT text FROM reaktionen WHERE art = 'stark'").all().map((x) => x.text), ["erst"]);
});

test("Reaktion zurücknehmen: nur eigene", async () => {
  const env = await welt("ich", "du", "fremd");
  const vd = await verbinden(env, "ich", "du");
  const vf = await verbinden(env, "fremd", "du");
  const re = { an: vd, art: "anfeuern", ziel: "live:" + heute() };
  await ruf(env, "ich", "POST", "/freunde/reaktionen", re);
  await ruf(env, "du", "POST", "/freunde/reaktionen", { ...re, an: vd }); // die Gegenrichtung, gleiches Ziel
  assert.equal((await ruf(env, "fremd", "DELETE", "/freunde/reaktionen", re)).status, 404, "fremde Verbindung");
  assert.equal((await ruf(env, "ich", "DELETE", "/freunde/reaktionen", { ...re, an: vf })).status, 404);
  assert.equal((await ruf(env, "ich", "DELETE", "/freunde/reaktionen", { ...re, art: "kaputt" })).status, 400);
  assert.equal(env.DB.roh.prepare("SELECT COUNT(*) AS n FROM reaktionen").get().n, 2);
  assert.equal((await ruf(env, "ich", "DELETE", "/freunde/reaktionen", re)).status, 200);
  assert.deepEqual(env.DB.roh.prepare("SELECT von FROM reaktionen").all().map((x) => x.von), [KONTEN.du.id], "nur meine ist weg");
  assert.equal((await uebersicht(env, "du")).reaktionen.length, 0);
  assert.equal((await uebersicht(env, "ich")).gesendet.length, 0);
});

test("Reaktion einer entfernten oder pausierten Verbindung ist nicht mehr sichtbar; Alte nach 30 Tagen weg", async () => {
  const env = await welt("ich", "du");
  const vd = await verbinden(env, "ich", "du");
  await ruf(env, "ich", "POST", "/freunde/reaktionen", { an: vd, art: "respekt", ziel: "einheit:" + heute(), text: "Einheit" });
  assert.equal((await uebersicht(env, "du")).reaktionen.length, 1);
  await einst(env, vd, "a", { pause: true });
  assert.equal((await uebersicht(env, "du")).reaktionen.length, 0, "Pause auf der Seite des Senders");
  await einst(env, vd, "a", {});
  await einst(env, vd, "b", { pause: true });
  assert.equal((await uebersicht(env, "du")).reaktionen.length, 0, "Pause auf der Seite des Empfängers");
  await einst(env, vd, "b", {});
  assert.equal((await uebersicht(env, "du")).reaktionen.length, 1);
  assert.equal((await ruf(env, "du", "DELETE", `/verbindungen/${vd}`)).status, 200);
  assert.deepEqual(await uebersicht(env, "du"), { herausforderungen: [], reaktionen: [], gesendet: [] });
  assert.deepEqual((await uebersicht(env, "ich")).reaktionen, []);
  assert.deepEqual((await uebersicht(env, "ich")).gesendet, []);
  assert.equal((await ruf(env, "ich", "POST", "/freunde/reaktionen", { an: vd, art: "respekt", ziel: "x" })).status, 404, "an eine entfernte Verbindung geht nichts");
  // Wieder verbunden: nur Reaktionen der letzten 30 Tage.
  sql(env, "UPDATE reaktionen SET zeit = ?", new Date(Date.now() - 31 * 86400_000).toISOString());
  const v2 = await verbinden(env, "ich", "du");
  assert.equal((await uebersicht(env, "du")).reaktionen.length, 0, "älter als 30 Tage");
  await ruf(env, "ich", "POST", "/freunde/reaktionen", { an: v2, art: "stark", ziel: "x" });
  assert.equal(env.DB.roh.prepare("SELECT COUNT(*) AS n FROM reaktionen").get().n, 1, "die alte wird beim nächsten Senden gelöscht");
});

test("Reaktion: Drossel 30 je Minute", async () => {
  const env = await welt("ich", "du");
  const vd = await verbinden(env, "ich", "du");
  for (let i = 0; i < 30; i++) assert.equal((await ruf(env, "ich", "POST", "/freunde/reaktionen", { an: vd, art: "respekt", ziel: `einheit:${i}` })).status, 201);
  assert.equal((await ruf(env, "ich", "POST", "/freunde/reaktionen", { an: vd, art: "respekt", ziel: "einheit:x" })).status, 429);
});

test("Gruppe: Namen, Teilnehmer-Ids für Unverbundene, keine Konto-Id in irgendeiner Antwort", async () => {
  const env = await welt("ich", "du", "fremd", "vier");
  const vd = await verbinden(env, "ich", "du");
  const vf = await verbinden(env, "ich", "fremd");
  // "du" hat ein Profil mit Namen in der Zusammenfassung, "fremd" nicht (dann gilt der Kontoname).
  assert.equal((await ruf(env, "du", "PUT", "/partner", { version: 1, geschrieben: new Date().toISOString(), profilName: "Beispiel Profil Du", freigaben: ["gym"], heute: { tag: heute() }, ereignisse: [] })).status, 200);
  const id = (await erstellen(env, "ich", duell([vd, vf], { modus: "gemeinsam", ziel: 100 }))).json.id;
  for (const k of ["du", "fremd"]) await ruf(env, k, "POST", `/freunde/herausforderungen/${id}/annehmen`);
  await ruf(env, "du", "PUT", "/freunde/werte", { werte: [{ id, wert: 40 }] });
  await ruf(env, "fremd", "PUT", "/freunde/werte", { werte: [{ id, wert: 25 }] });
  const ichSicht = (await hole(env, "ich", id)).teilnehmer;
  assert.deepEqual(ichSicht.map((t) => [t.name, t.verbunden, t.ich, t.wert]), [["Beispiel Ich", false, true, 0], ["Beispiel Profil Du", true, false, 40], ["Beispiel Fremd", true, false, 25]]);
  assert.deepEqual([ichSicht[1].id, ichSicht[2].id], [vd, vf]);
  await einst(env, vd, "a", { pause: true });
  assert.equal((await hole(env, "ich", id)).teilnehmer[1].id, vd, "Pause ändert die Id nicht");
  await einst(env, vd, "a", {});
  // "du" kennt "fremd" nicht: Teilnehmer-Id aus Herausforderung und Konto, 16 Hex-Zeichen, nie die Konto-Id.
  const duSicht = (await hole(env, "du", id)).teilnehmer;
  const f = duSicht.find((t) => t.name === "Beispiel Fremd");
  assert.deepEqual([f.verbunden, f.ich, f.id], [false, false, sha16(`${id}:${KONTEN.fremd.id}`)]);
  assert.match(f.id, /^[a-f0-9]{16}$/);
  assert.equal(duSicht.find((t) => t.ich).id, sha16(`${id}:${KONTEN.du.id}`));
  assert.equal(duSicht.find((t) => t.id === vd).name, "Beispiel Ich");
  // Name auf 40 Zeichen gekürzt.
  sql(env, "UPDATE konten SET name = ? WHERE id = ?", "N".repeat(60), KONTEN.fremd.id);
  assert.equal((await hole(env, "du", id)).teilnehmer.find((t) => !t.ich && !t.verbunden).name, "N".repeat(40));
  // Reaktionen und Einladungen laufen auch noch einmal durch `ruf`, das jede Antwort auf die Konto-Ids der anderen prüft.
  await ruf(env, "ich", "POST", "/freunde/reaktionen", { an: vd, art: "respekt", ziel: "x" });
  await ruf(env, "du", "POST", "/freunde/einladung");
  for (const k of ["ich", "du", "fremd", "vier"]) await ruf(env, k, "GET", "/freunde");
  await ruf(env, "ich", "GET", "/verbindungen");
  assert.equal((await hole(env, "vier", id)), undefined, "Unbeteiligte sehen nichts");
});

test("Gruppe: wer noch nicht angenommen hat, bleibt für Unverbundene ohne Namen", async () => {
  const env = await welt("ich", "du", "fremd");
  const vd = await verbinden(env, "ich", "du");
  const vf = await verbinden(env, "ich", "fremd");
  const id = (await erstellen(env, "ich", duell([vd, vf]))).json.id;
  await ruf(env, "du", "POST", `/freunde/herausforderungen/${id}/annehmen`);
  const vorher = (await hole(env, "du", id)).teilnehmer.find((t) => !t.ich && !t.verbunden);
  assert.deepEqual([vorher.name, vorher.status], ["Eingeladen", "eingeladen"]);
  assert.equal((await hole(env, "ich", id)).teilnehmer.find((t) => t.id === vf).name, "Beispiel Fremd", "der Ersteller ist verbunden und sieht den Namen");
  await ruf(env, "fremd", "POST", `/freunde/herausforderungen/${id}/annehmen`);
  assert.equal((await hole(env, "du", id)).teilnehmer.find((t) => !t.ich && !t.verbunden).name, "Beispiel Fremd");
});

test("Die Liste zeigt nur eingeladen oder dabei, Ende höchstens 14 Tage her", async () => {
  const env = await welt("ich", "du");
  const vd = await verbinden(env, "ich", "du");
  const alt = (await erstellen(env, "ich", duell([vd]))).json.id;
  const neu = (await erstellen(env, "ich", duell([vd]))).json.id;
  sql(env, "UPDATE herausforderungen SET ende = ? WHERE id = ?", new Date(Date.now() - 13 * 86400_000).toISOString(), alt);
  assert.deepEqual((await uebersicht(env, "ich")).herausforderungen.map((x) => [x.id, x.status]).sort(), [[alt, "beendet"], [neu, "laeuft"]].sort());
  sql(env, "UPDATE herausforderungen SET ende = ? WHERE id = ?", new Date(Date.now() - 15 * 86400_000).toISOString(), alt);
  assert.deepEqual((await uebersicht(env, "ich")).herausforderungen.map((x) => x.id), [neu]);
});

test("Link-Einladung: 24 Stunden, höchstens drei offene, ein QR-Code löscht sie nicht, der bestehende Ablauf nimmt sie an", async () => {
  const env = await welt("ich", "du");
  const r = await ruf(env, "ich", "POST", "/freunde/einladung");
  assert.equal(r.status, 201);
  assert.match(r.json.token, /^[A-Za-z0-9_-]{43}$/);
  assert.equal(r.json.sekunden, 86400);
  const zeile = env.DB.roh.prepare("SELECT * FROM einladungen").get();
  assert.equal(zeile.hash, createHash("sha256").update(r.json.token).digest("hex"), "nur der Hash liegt in der Datenbank");
  assert.ok(Math.abs(zeile.laeuft_ab - (Date.now() + 86400_000)) < 5000);
  assert.ok(Math.abs(Date.parse(r.json.laeuftAb) - zeile.laeuft_ab) < 1);
  // Ein neuer QR-Code (10 Minuten) und noch einer: der Link lebt.
  const qr1 = (await ruf(env, "ich", "POST", "/verbindungen/einladung")).json.token;
  const qr2 = (await ruf(env, "ich", "POST", "/verbindungen/einladung")).json.token;
  const rest = env.DB.roh.prepare("SELECT hash FROM einladungen").all().map((x) => x.hash);
  assert.equal(rest.length, 2, "Link und der neueste QR-Code");
  assert.ok(rest.includes(createHash("sha256").update(r.json.token).digest("hex")));
  assert.ok(!rest.includes(createHash("sha256").update(qr1).digest("hex")), "der alte QR-Code ist weg");
  assert.ok(rest.includes(createHash("sha256").update(qr2).digest("hex")));
  // Anschauen und Anfragen mit dem Link-Token, wie bisher.
  assert.equal((await ruf(env, "du", "POST", "/verbindungen/ansehen", { token: r.json.token })).json.name, "Beispiel Ich");
  const a = await ruf(env, "du", "POST", "/verbindungen/anfrage", { token: r.json.token });
  assert.equal(a.status, 201);
  assert.equal((await ruf(env, "ich", "POST", `/verbindungen/${a.json.id}/annehmen`)).status, 200);
  assert.equal((await ruf(env, "du", "POST", "/verbindungen/anfrage", { token: r.json.token })).status, 404, "einmal nutzbar");
  // Höchstens drei offene Links, der älteste fliegt. Ein QR-Code und fremde Konten zählen nicht.
  const t = [];
  for (let i = 0; i < 4; i++) { t.push((await ruf(env, "ich", "POST", "/freunde/einladung")).json.token); sql(env, "UPDATE einladungen SET laeuft_ab = laeuft_ab + ? WHERE hash = ?", i, createHash("sha256").update(t[i]).digest("hex")); }
  await ruf(env, "du", "POST", "/freunde/einladung");
  const lang = env.DB.roh.prepare("SELECT hash FROM einladungen WHERE konto = ? AND benutzt = 0 AND laeuft_ab > ?").all(KONTEN.ich.id, Date.now() + 700_000).map((x) => x.hash);
  assert.equal(lang.length, 3);
  assert.ok(!lang.includes(createHash("sha256").update(t[0]).digest("hex")), "der älteste Link ist weg");
  // Abgelaufene Link-Einladungen werden mit weggeräumt.
  sql(env, "UPDATE einladungen SET laeuft_ab = ? WHERE konto = ?", Date.now() - 2 * 3600_000, KONTEN.du.id);
  await ruf(env, "ich", "POST", "/freunde/einladung");
  assert.equal(env.DB.roh.prepare("SELECT COUNT(*) AS n FROM einladungen WHERE konto = ?").get(KONTEN.du.id).n, 0);
});

test("Link-Einladung: Drossel 10 je Minute", async () => {
  const env = await welt("ich");
  for (let i = 0; i < 10; i++) assert.equal((await ruf(env, "ich", "POST", "/freunde/einladung")).status, 201);
  assert.equal((await ruf(env, "ich", "POST", "/freunde/einladung")).status, 429);
});

test("Landeseite /f/<token>: ohne Konto, mit Kopfzeilen, Knopf und Weiterleitung auf lumenfit://", async () => {
  const env = await welt();
  const token = "A1_-".repeat(10) + "xyz"; // 43 Zeichen
  assert.equal(token.length, 43);
  const r = await ruf(env, null, "GET", `/f/${token}`);
  assert.equal(r.status, 200);
  assert.match(r.headers.get("content-type"), /^text\/html/);
  assert.equal(r.headers.get("cache-control"), "no-store");
  assert.equal(r.headers.get("x-robots-tag"), "noindex");
  assert.equal(r.headers.get("referrer-policy"), "no-referrer");
  assert.equal(r.headers.get("content-security-policy"), "default-src 'none'; style-src 'unsafe-inline'");
  assert.ok(r.text.includes(`<a href="lumenfit://freund?d=${token}">In Lumen Fit öffnen</a>`));
  assert.ok(r.text.includes(`<meta http-equiv="refresh" content="0;url=lumenfit://freund?d=${token}">`));
  assert.ok(!/<script/i.test(r.text));
  // Läuft ohne Datenbank: ein kaputtes DB-Objekt stört nicht.
  const ohneDb = await handleFetch(new Request(`https://x.test/f/${token}`), { APP_KEY: APP });
  assert.equal(ohneDb.status, 200);
});

test("Landeseite nimmt nur die Token-Form: nichts Gefährliches kommt je in die Seite", async () => {
  const env = await welt();
  const gut = "a".repeat(43);
  for (const pfad of [
    `/f/${"a".repeat(42)}`, `/f/${"a".repeat(44)}`, "/f/", "/f", `/f/${gut}/`, `/f/${gut}/x`, `/f/${gut.slice(1)}%22`, `/f/${gut.slice(2)}"%3E`,
    `/f/${gut.slice(1)}%2F`, `/f/%3Cscript%3Ealert(1)%3C%2Fscript%3E${"a".repeat(20)}`, `/f/${gut.slice(2)}%00x`, `/f/${gut.slice(0, 40)}%0d%0a`,
    `/f/${gut.slice(1)}.`, `/f/${gut.slice(1)}=`, `/f/${gut.slice(2)}äö`,
  ]) {
    const r = await ruf(env, null, "GET", pfad);
    assert.equal(r.status, 404, pfad);
    assert.ok(!r.text.includes("lumenfit://"), "keine Weiterleitung bei kaputtem Token");
    assert.ok(!r.text.includes("alert"), pfad);
    if (pfad.startsWith("/f/")) assert.equal(r.headers.get("cache-control"), "no-store");
    if (pfad.startsWith("/f/")) assert.equal(r.headers.get("referrer-policy"), "no-referrer");
  }
  assert.equal((await ruf(env, null, "POST", `/f/${gut}`)).status, 404, "nur GET");
});
