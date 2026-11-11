import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fakeD1 } from "./fake-d1.js";
import { handleFetch } from "./index.js";
import { berlinMontag, berlinTag, statsKontoLoeschen } from "./stats.js";

const SCHEMA = readFileSync(new URL("./schema.sql", import.meta.url), "utf8");
const APP = "app-key-test";
const ADMIN = "admin-key-test";
const KONTEN = Object.fromEntries(["ich", "du", "fremd", "vier", "fuenf", "sechs"].map((n, i) => [n, { id: "abcdef"[i].repeat(32), geheimnis: "ghijkl"[i].repeat(48), name: `Beispiel ${n}` }]));
const kopf = (k) => ({ "X-App-Key": APP, "X-Konto": KONTEN[k].id, "X-Geheimnis": KONTEN[k].geheimnis });

// Jede Antwort an ein Konto wird auf die Konto-Ids der anderen durchsucht: keine darf hinausgehen.
async function ruf(env, k, methode, pfad, body) {
  const r = await handleFetch(new Request("https://x.test" + pfad, { method: methode, headers: k === null ? {} : kopf(k), body: body === undefined ? undefined : JSON.stringify(body) }), env);
  const text = await r.text();
  let json = null;
  try { json = JSON.parse(text); } catch {}
  if (k !== null) for (const [n, x] of Object.entries(KONTEN)) if (n !== k) assert.ok(!text.includes(x.id), `${methode} ${pfad}: Konto-Id von ${n} in der Antwort`);
  return { status: r.status, json };
}
const admin = async (env, methode, pfad, body) => {
  const r = await handleFetch(new Request("https://x.test" + pfad, { method: methode, headers: { "X-Admin-Key": ADMIN }, body: body === undefined ? undefined : JSON.stringify(body) }), env);
  return { status: r.status, json: await r.json() };
};
async function welt(...namen) {
  const env = { DB: fakeD1(SCHEMA), APP_KEY: APP, ADMIN_KEY: ADMIN };
  for (const n of namen) {
    const k = KONTEN[n];
    const r = await handleFetch(new Request("https://x.test/konto", { method: "POST", headers: { "X-App-Key": APP }, body: JSON.stringify({ id: k.id, geheimnis: k.geheimnis, name: k.name, version: "1" }) }), env);
    assert.equal(r.status, 201);
  }
  return env;
}
// Besitzer zeigt den QR-Code, der andere scannt: gleich verbunden. Liefert die Verbindungs-Id.
async function verbinden(env, besitzer, scanner) {
  const { json: e } = await ruf(env, besitzer, "POST", "/verbindungen/einladung");
  const a = await ruf(env, scanner, "POST", "/verbindungen/anfrage", { token: e.token });
  assert.equal(a.json.status, "aktiv");
  return a.json.id;
}
const sql = (env, text, ...w) => env.DB.roh.prepare(text).run(...w);
const zahl = (env, text, ...w) => env.DB.roh.prepare(text).get(...w).n;
const seite = (env, v, n) => (env.DB.roh.prepare("SELECT a FROM verbindungen WHERE id = ?").get(v).a === KONTEN[n].id ? "a" : "b");
const einst = (env, v, n, e) => sql(env, `UPDATE verbindungen SET ${seite(env, v, n)}_einst = ? WHERE id = ?`, JSON.stringify(e), v);
const plus = (tag, n) => { const d = new Date(`${tag}T12:00:00Z`); d.setUTCDate(d.getUTCDate() + n); return d.toISOString().slice(0, 10); };
const M = () => berlinMontag(Date.now());
const T = () => berlinTag(Date.now());

const REKORDE = { "2gPfomN": 150, "lv-ma-brustpresse-sitzend-schraeg": 32.5 };
const werte = (extra = {}) => ({ freunde: true, oeffentlich: false, montag: M(), trainings: 3, sets: 40, rekordeNeu: 1, serie: 4, rekorde: REKORDE, ...extra });
const oeffentlich = (spitzname, jahr = 1, extra = {}) => werte({ freunde: false, oeffentlich: true, spitzname, jahr, ...extra });
const setzen = (env, k, body) => ruf(env, k, "PUT", "/stats", body);
const lesen = async (env, k) => (await ruf(env, k, "GET", "/stats")).json;
const schritte = (heute, monat, tag = T()) => ({ schritteTag: tag, schritteHeute: heute, schritteMonat: monat });
const schritteZeile = (env, n) => ({ ...env.DB.roh.prepare("SELECT tag, heute, monat FROM stats_schritte WHERE konto = ?").get(KONTEN[n].id) });
const PRIVAT = { freunde: false, oeffentlich: false, spitzname: null, ausgeblendet: false };

test("Stats: Woche nach Berliner Zeit, auch bei Zeitumstellung", () => {
  assert.equal(berlinMontag(Date.parse("2026-11-10T12:00:00Z")), "2026-11-09");
  assert.equal(berlinMontag(Date.parse("2026-11-15T22:30:00Z")), "2026-11-09"); // Sonntag 23:30 in Berlin
  assert.equal(berlinMontag(Date.parse("2026-11-15T23:30:00Z")), "2026-11-16"); // Montag 00:30 in Berlin
  assert.equal(berlinMontag(Date.parse("2026-03-29T21:30:00Z")), "2026-03-23"); // Sommerzeit: Sonntag 23:30
  assert.equal(berlinMontag(Date.parse("2026-03-29T22:30:00Z")), "2026-03-30"); // Montag 00:30
  assert.equal(berlinMontag(Date.parse("2026-12-31T23:30:00Z")), "2026-12-28"); // Jahreswechsel
});

test("Stats: braucht ein Konto, Standard ist privat", async () => {
  const env = await welt("ich");
  for (const [m, p] of [["GET", "/stats"], ["PUT", "/stats"], ["POST", "/stats/melden"], ["POST", "/stats/blockieren"]]) {
    assert.equal((await ruf(env, null, m, p, m === "GET" ? undefined : {})).status, 401, `${m} ${p}`);
  }
  assert.equal((await ruf(env, "ich", "GET", "/stats/unbekannt")).status, 404);
  assert.deepEqual(await lesen(env, "ich"), { montag: M(), ich: PRIVAT, freunde: [], alle: [], rekorde: {} });
});

test("Stats: PUT prüft Werte, Woche und Übungen", async () => {
  const env = await welt("ich");
  const schlecht = [
    {}, { freunde: "ja", oeffentlich: false }, werte({ montag: undefined }), werte({ montag: "2020-01-06" }), werte({ montag: plus(M(), 1) }),
    werte({ trainings: 15 }), werte({ trainings: -1 }), werte({ sets: 501 }), werte({ sets: 2.5 }), werte({ rekordeNeu: 101 }), werte({ serie: 521 }), werte({ serie: undefined }),
    werte({ rekorde: [] }), werte({ rekorde: { "": 10 } }), werte({ rekorde: JSON.parse('{"__proto__": 10}') }), werte({ rekorde: { abc: 0 } }),
    werte({ rekorde: { abc: 1001 } }), werte({ rekorde: { abc: "100" } }), werte({ rekorde: Object.fromEntries(Array.from({ length: 31 }, (_, i) => [`u${i}`, 10])) }),
    oeffentlich("Eisenfaust", 0), oeffentlich("Eisenfaust", 11), oeffentlich("Eisenfaust", 1.5), oeffentlich("Eisenfaust", 1, { jahr: undefined }),
  ];
  for (const b of schlecht) {
    sql(env, "DELETE FROM drossel");
    assert.equal((await setzen(env, "ich", b)).status, 400, JSON.stringify(b));
  }
  assert.equal(zahl(env, "SELECT COUNT(*) AS n FROM stats"), 0);
  const r = await setzen(env, "ich", werte({ rekorde: { abc: 61.256 } }));
  assert.equal(r.status, 200);
  assert.deepEqual(r.json, { ok: true, ich: { ...PRIVAT, freunde: true } });
  assert.equal(env.DB.roh.prepare("SELECT rekorde FROM stats").get().rekorde, '{"abc":61.26}');
});

test("Stats: Spitzname nötig, gefiltert, eindeutig, Fehler als Code", async () => {
  const env = await welt("ich", "du");
  let r = await setzen(env, "ich", oeffentlich(undefined));
  assert.deepEqual([r.status, r.json.fehler], [422, "spitzname_laenge"]);
  r = await setzen(env, "ich", oeffentlich("Hur3nsohn"));
  assert.deepEqual([r.status, r.json.fehler], [422, "spitzname_unpassend"]);
  assert.equal((await setzen(env, "ich", oeffentlich("Eisenfaust"))).status, 200);
  r = await setzen(env, "du", oeffentlich("eisen faust"));
  assert.deepEqual([r.status, r.json.fehler], [409, "spitzname_vergeben"]);
  // Der eigene Name bleibt meiner, auch anders geschrieben.
  r = await setzen(env, "ich", oeffentlich("Eisen Faust"));
  assert.deepEqual(r.json.ich, { freunde: false, oeffentlich: true, spitzname: "Eisen Faust", ausgeblendet: false });
  // Wer nicht mehr öffentlich ist, gibt den Namen frei.
  assert.equal((await setzen(env, "ich", werte())).status, 200);
  assert.equal((await setzen(env, "du", oeffentlich("eisen faust"))).status, 200);
});

test("Stats: beide Schalter aus löscht sofort alles auf dem Server", async () => {
  const env = await welt("ich");
  await setzen(env, "ich", oeffentlich("Eisenfaust"));
  assert.equal(zahl(env, "SELECT COUNT(*) AS n FROM stats"), 1);
  const r = await setzen(env, "ich", { freunde: false, oeffentlich: false });
  assert.deepEqual([r.status, r.json], [200, { ok: true, ich: PRIVAT }]);
  assert.equal(zahl(env, "SELECT COUNT(*) AS n FROM stats"), 0);
  assert.deepEqual((await lesen(env, "ich")).ich, PRIVAT);
});

test("Stats Freunde: nur aktive, nicht pausierte Verbindungen, die mir Gym zeigen und Freunde sehen mich an haben", async () => {
  const env = await welt("ich", "du", "fremd");
  const v = await verbinden(env, "ich", "du");
  await setzen(env, "du", werte());
  await setzen(env, "fremd", werte());
  const eintrag = { id: v, name: "Beispiel du", punkte: 75, trainings: 3, sets: 40, serie: 4, rekorde: REKORDE };
  assert.deepEqual((await lesen(env, "ich")).freunde, [eintrag]);
  assert.deepEqual((await lesen(env, "du")).freunde, [], "ich bin privat");
  // Name aus dem Profil der Person, wie bei den Freunden.
  sql(env, "INSERT INTO partner_stand (konto, aktualisiert, daten) VALUES (?, ?, ?)", KONTEN.du.id, new Date().toISOString(), JSON.stringify({ profilName: "Profil du" }));
  assert.equal((await lesen(env, "ich")).freunde[0].name, "Profil du");
  for (const [n, e] of [["ich", { pause: true }], ["du", { pause: true }], ["du", { zeigt: ["schritte"] }], ["ich", { ausblenden: ["gym"] }]]) {
    await einst(env, v, n, e);
    assert.deepEqual((await lesen(env, "ich")).freunde, [], `${n} ${JSON.stringify(e)}`);
    await einst(env, v, n, {});
  }
  sql(env, "UPDATE konten SET gesperrt = 1 WHERE id = ?", KONTEN.du.id);
  assert.deepEqual((await lesen(env, "ich")).freunde, [], "gesperrt");
  sql(env, "UPDATE konten SET gesperrt = 0 WHERE id = ?", KONTEN.du.id);
  await setzen(env, "du", oeffentlich("Eisenfaust"));
  assert.deepEqual((await lesen(env, "ich")).freunde, [], "nur öffentlich, Freunde sehen mich aus");
  await setzen(env, "du", werte());
  sql(env, "UPDATE verbindungen SET status = 'entfernt' WHERE id = ?", v);
  assert.deepEqual((await lesen(env, "ich")).freunde, [], "entfernt");
});

test("Stats Freunde: Vorwoche zählt 0, Serie bleibt nur mit Training in der Vorwoche", async () => {
  const env = await welt("ich", "du");
  const v = await verbinden(env, "ich", "du");
  await setzen(env, "du", werte({ trainings: 2 }));
  const vorwoche = plus(M(), -7);
  const freund = async () => { const f = (await lesen(env, "ich")).freunde[0]; return [f.punkte, f.trainings, f.sets, f.serie]; };
  sql(env, "UPDATE stats SET montag = ?", vorwoche);
  assert.deepEqual(await freund(), [0, 0, 0, 4]);
  sql(env, "UPDATE stats SET trainings = 0");
  assert.deepEqual(await freund(), [0, 0, 0, 0]);
  sql(env, "UPDATE stats SET montag = ?, trainings = 2", plus(M(), -14));
  assert.deepEqual(await freund(), [0, 0, 0, 0]);
  assert.equal((await lesen(env, "ich")).freunde[0].id, v);
});

test("Stats: ein älteres Paket überschreibt keine neueren Zahlen", async () => {
  const env = await welt("ich");
  await setzen(env, "ich", werte({ trainings: 3 }));
  sql(env, "UPDATE stats SET montag = ?", plus(M(), 7));
  assert.equal((await setzen(env, "ich", oeffentlich("Eisenfaust", 1, { trainings: 1 }))).status, 200);
  const z = env.DB.roh.prepare("SELECT trainings, oeffentlich, spitzname FROM stats").get();
  assert.deepEqual({ ...z }, { trainings: 3, oeffentlich: 1, spitzname: "Eisenfaust" });
});

test("Stats Alle: nur Öffentliche mit öffentlicher Id, Trainingsjahr, ohne kg, sortiert; Private lesen mit", async () => {
  const env = await welt("ich", "du", "fremd", "vier");
  await setzen(env, "du", oeffentlich("Eisenfaust", 1, { trainings: 2, sets: 10, rekordeNeu: 0 }));
  await setzen(env, "fremd", oeffentlich("Stahlbiene", 2, { trainings: 4, sets: 50, rekordeNeu: 2 }));
  await setzen(env, "vier", werte());
  const alle = (await lesen(env, "ich")).alle;
  assert.deepEqual(alle.map((e) => [e.name, e.jahr, e.punkte, e.trainings, e.sets, e.serie, e.ich]), [["Stahlbiene", 2, 100, 4, 50, 4, false], ["Eisenfaust", 1, 30, 2, 10, 4, false]]);
  assert.ok(alle.every((e) => /^[a-f0-9]{32}$/.test(e.id) && !("rekorde" in e)));
  const eigen = (await lesen(env, "du")).alle.find((e) => e.ich);
  assert.equal(eigen.name, "Eisenfaust");
  assert.equal(eigen.id, alle[1].id, "die öffentliche Id bleibt gleich");
  // Vorwoche: Wochenzahlen 0; älter: nicht mehr in der Liste.
  sql(env, "UPDATE stats SET montag = ? WHERE konto = ?", plus(M(), -7), KONTEN.fremd.id);
  assert.deepEqual((await lesen(env, "ich")).alle.map((e) => [e.name, e.punkte]), [["Eisenfaust", 30], ["Stahlbiene", 0]]);
  sql(env, "UPDATE stats SET montag = ? WHERE konto = ?", plus(M(), -14), KONTEN.fremd.id);
  assert.deepEqual((await lesen(env, "ich")).alle.map((e) => e.name), ["Eisenfaust"]);
  sql(env, "UPDATE konten SET gesperrt = 1 WHERE id = ?", KONTEN.du.id);
  assert.deepEqual((await lesen(env, "ich")).alle, []);
});

test("Stats Melden: sofort weg für mich, ab 3 Meldungen für alle, Freigabe über die Verwaltung", async () => {
  const env = await welt("ich", "du", "fremd", "vier", "fuenf");
  await setzen(env, "du", oeffentlich("Eisenfaust"));
  const id = (await lesen(env, "fuenf")).alle[0].id;
  assert.deepEqual((await ruf(env, "ich", "POST", "/stats/melden", { id })).json, { ok: true });
  assert.deepEqual((await lesen(env, "ich")).alle, []);
  assert.equal((await lesen(env, "fuenf")).alle.length, 1);
  await ruf(env, "ich", "POST", "/stats/melden", { id }); // doppelt zählt nicht
  await ruf(env, "fremd", "POST", "/stats/melden", { id });
  assert.equal((await lesen(env, "fuenf")).alle.length, 1);
  await ruf(env, "vier", "POST", "/stats/melden", { id });
  assert.deepEqual((await lesen(env, "fuenf")).alle, []);
  const du = await lesen(env, "du");
  assert.equal(du.ich.ausgeblendet, true);
  assert.deepEqual(du.alle.map((e) => e.ich), [true], "die Person sieht sich selbst");
  assert.equal((await admin(env, "PATCH", `/admin/stats/${KONTEN.du.id}`, { freigeben: true })).status, 200);
  assert.equal((await lesen(env, "fuenf")).alle.length, 1);
  assert.deepEqual((await lesen(env, "ich")).alle, [], "für mich bleibt sie ausgeblendet");
  assert.equal((await lesen(env, "du")).ich.ausgeblendet, false);
});

test("Stats Blockieren: beide sehen sich in Alle nicht mehr", async () => {
  const env = await welt("ich", "du", "fremd");
  await setzen(env, "du", oeffentlich("Eisenfaust"));
  await setzen(env, "ich", oeffentlich("Stahlbiene"));
  const id = (await lesen(env, "ich")).alle.find((e) => !e.ich).id;
  assert.deepEqual((await ruf(env, "ich", "POST", "/stats/blockieren", { id })).json, { ok: true });
  assert.deepEqual((await lesen(env, "ich")).alle.map((e) => e.name), ["Stahlbiene"]);
  assert.deepEqual((await lesen(env, "du")).alle.map((e) => e.name), ["Eisenfaust"]);
  assert.equal((await lesen(env, "fremd")).alle.length, 2);
});

test("Stats Melden und Blockieren: nur Einträge in Alle, nicht sich selbst, Grenzen je Tag", async () => {
  const env = await welt("ich", "du", "fremd");
  await setzen(env, "ich", oeffentlich("Stahlbiene"));
  await setzen(env, "fremd", werte());
  const ich = (await lesen(env, "ich")).alle[0].id;
  const privat = env.DB.roh.prepare("SELECT id FROM stats WHERE konto = ?").get(KONTEN.fremd.id).id;
  for (const weg of ["melden", "blockieren"]) {
    assert.equal((await ruf(env, "ich", "POST", `/stats/${weg}`, { id: ich })).status, 400, weg);
    assert.equal((await ruf(env, "du", "POST", `/stats/${weg}`, { id: privat })).status, 404, weg);
    assert.equal((await ruf(env, "du", "POST", `/stats/${weg}`, { id: "e".repeat(32) })).status, 404, weg);
    assert.equal((await ruf(env, "du", "POST", `/stats/${weg}`, { id: 7 })).status, 400, weg);
  }
  const jetzt = new Date().toISOString();
  for (let i = 0; i < 10; i++) sql(env, "INSERT INTO stats_meldungen (von, an, zeit) VALUES (?, ?, ?)", KONTEN.du.id, `x${String(i).padStart(31, "0")}`, jetzt);
  let r = await ruf(env, "du", "POST", "/stats/melden", { id: ich });
  assert.deepEqual([r.status, r.json.fehler], [429, "tageslimit"]);
  for (let i = 0; i < 30; i++) sql(env, "INSERT INTO stats_blockiert (von, an, zeit) VALUES (?, ?, ?)", KONTEN.du.id, `y${String(i).padStart(31, "0")}`, jetzt);
  r = await ruf(env, "du", "POST", "/stats/blockieren", { id: ich });
  assert.deepEqual([r.status, r.json.fehler], [429, "tageslimit"]);
});

test("Stats Rekorde: kg nur als Verteilung je Übung, ab 5 Leuten, ohne mich und ohne Gesperrte", async () => {
  const env = await welt("ich", "du", "fremd", "vier", "fuenf", "sechs");
  const kg = { du: 100, fremd: 120, vier: 120, fuenf: 140, sechs: 160 };
  const namen = { du: "Eisenfaust", fremd: "Stahlbiene", vier: "Kraftpaket", fuenf: "Hantelheld", sechs: "Muskelmaus" };
  for (const [n, w] of Object.entries(kg)) await setzen(env, n, oeffentlich(namen[n], n === "sechs" ? 2 : 1, { rekorde: { "2gPfomN": w } }));
  await setzen(env, "ich", werte({ rekorde: { "2gPfomN": 90 } })); // nur Freunde: zählt nicht mit
  assert.deepEqual((await lesen(env, "ich")).rekorde, { "2gPfomN": { alle: [[100, 1], [120, 2], [140, 1], [160, 1]] } });
  await setzen(env, "ich", oeffentlich("Ohnename", 1, { rekorde: { "2gPfomN": 90 } }));
  assert.deepEqual((await lesen(env, "du")).rekorde, { "2gPfomN": { alle: [[90, 1], [120, 2], [140, 1], [160, 1]] } }, "Jahr 1 ohne du: nur 4");
  assert.deepEqual((await lesen(env, "sechs")).rekorde, { "2gPfomN": { alle: [[90, 1], [100, 1], [120, 2], [140, 1]], 1: [[90, 1], [100, 1], [120, 2], [140, 1]] } });
  sql(env, "UPDATE konten SET gesperrt = 1 WHERE id = ?", KONTEN.fuenf.id);
  assert.deepEqual((await lesen(env, "sechs")).rekorde, {});
});

test("Stats Rekorde: Übungs-Ids wie constructor sind nur Daten", async () => {
  const env = await welt("ich", "du", "fremd", "vier", "fuenf", "sechs");
  for (const [i, n] of ["du", "fremd", "vier", "fuenf", "sechs"].entries()) await setzen(env, n, oeffentlich(["Eisenfaust", "Stahlbiene", "Kraftpaket", "Hantelheld", "Muskelmaus"][i], 1, { rekorde: { constructor: 50, toString: 60 } }));
  const r = (await lesen(env, "ich")).rekorde;
  assert.deepEqual(r.constructor, { alle: [[50, 5]], 1: [[50, 5]] });
  assert.deepEqual(r.toString, { alle: [[60, 5]], 1: [[60, 5]] });
  assert.equal(Object.prototype.alle, undefined);
});

test("Stats Verwaltung: Teilnehmer und Meldungen nur mit Admin-Schlüssel", async () => {
  const env = await welt("ich", "du");
  await setzen(env, "du", oeffentlich("Eisenfaust"));
  const id = (await lesen(env, "ich")).alle[0].id;
  await ruf(env, "ich", "POST", "/stats/melden", { id });
  assert.equal((await ruf(env, null, "GET", "/admin/stats")).status, 401);
  const r = await admin(env, "GET", "/admin/stats");
  assert.equal(r.status, 200);
  assert.deepEqual(r.json.teilnehmer.map((t) => [t.konto, t.spitzname, t.oeffentlich, t.meldungen]), [[KONTEN.du.id, "Eisenfaust", true, 1]]);
  assert.deepEqual(r.json.meldungen.map((m) => [m.von, m.an, m.geprueft]), [[KONTEN.ich.id, KONTEN.du.id, false]]);
  assert.equal((await admin(env, "PATCH", `/admin/stats/${KONTEN.ich.id}`, { freigeben: true })).status, 404);
  assert.equal((await admin(env, "PATCH", `/admin/stats/${KONTEN.du.id}`, { freigeben: false })).status, 400);
  assert.deepEqual((await admin(env, "PATCH", `/admin/stats/${KONTEN.du.id}`, { freigeben: true })).json, { ok: true, geprueft: 1 });
});

test("Stats: statsKontoLoeschen räumt Zeile, Meldungen und Blockaden in beide Richtungen", async () => {
  const env = await welt("ich", "du", "fremd");
  await setzen(env, "du", oeffentlich("Eisenfaust"));
  await setzen(env, "fremd", oeffentlich("Stahlbiene"));
  const [du, fremd] = ["du", "fremd"].map((n) => env.DB.roh.prepare("SELECT id FROM stats WHERE konto = ?").get(KONTEN[n].id).id);
  await ruf(env, "ich", "POST", "/stats/melden", { id: du });
  await ruf(env, "du", "POST", "/stats/blockieren", { id: fremd });
  await ruf(env, "fremd", "POST", "/stats/melden", { id: du });
  await statsKontoLoeschen(env, KONTEN.du.id);
  assert.equal(zahl(env, "SELECT COUNT(*) AS n FROM stats WHERE konto = ?", KONTEN.du.id), 0);
  assert.equal(zahl(env, "SELECT COUNT(*) AS n FROM stats_meldungen"), 0);
  assert.equal(zahl(env, "SELECT COUNT(*) AS n FROM stats_blockiert"), 0);
  assert.equal(zahl(env, "SELECT COUNT(*) AS n FROM drossel WHERE schluessel LIKE ?", `%${KONTEN.du.id}`), 0);
  assert.equal(zahl(env, "SELECT COUNT(*) AS n FROM stats"), 1);
});

test("Stats: Drossel je Konto", async () => {
  const env = await welt("ich");
  for (let i = 0; i < 10; i++) assert.equal((await setzen(env, "ich", werte())).status, 200);
  assert.deepEqual((await setzen(env, "ich", werte())).json, { fehler: "zu_schnell" });
  for (let i = 0; i < 30; i++) assert.equal((await ruf(env, "ich", "GET", "/stats")).status, 200);
  assert.equal((await ruf(env, "ich", "GET", "/stats")).status, 429);
});

test("Stats Schritte: PUT prüft Tag und Grenzen; ohne Schritte (alte App, keine Zustimmung, Zustimmung zurück) keine Zeile, privat löscht sie", async () => {
  const env = await welt("ich");
  const tagImMonat = Number(T().slice(8));
  const schlecht = [
    schritte(100, 100, "2020-01-01"), schritte(100, 100, plus(T(), 2)), schritte(100, 100, plus(T(), -2)), schritte(100, 100, 20261111), { schritteTag: T() },
    schritte(-1, 0), schritte(100001, 100001), schritte(1.5, 2), schritte(100, 99), schritte(100, tagImMonat * 100000 + 1), schritte("100", "100"),
  ];
  for (const b of schlecht) {
    sql(env, "DELETE FROM drossel");
    assert.equal((await setzen(env, "ich", werte(b))).status, 400, JSON.stringify(b));
  }
  assert.equal(zahl(env, "SELECT COUNT(*) AS n FROM stats"), 0);
  assert.equal((await setzen(env, "ich", werte())).status, 200, "alte App ohne Schritte");
  assert.equal(zahl(env, "SELECT COUNT(*) AS n FROM stats_schritte"), 0);
  assert.equal((await setzen(env, "ich", werte(schritte(6240, 70000)))).status, 200);
  assert.deepEqual(schritteZeile(env, "ich"), { tag: T(), heute: 6240, monat: 70000 });
  assert.equal((await setzen(env, "ich", werte())).status, 200, "Schritte teilen zurückgenommen (oder Mitzählen aus): Upload ohne Felder");
  assert.equal(zahl(env, "SELECT COUNT(*) AS n FROM stats_schritte"), 0);
  await setzen(env, "ich", werte(schritte(10, 10)));
  await setzen(env, "ich", { freunde: false, oeffentlich: false });
  assert.equal(zahl(env, "SELECT COUNT(*) AS n FROM stats_schritte"), 0);
});

test("Stats Schritte: ein älterer Tag überschreibt keinen neueren", async () => {
  const env = await welt("ich");
  await setzen(env, "ich", werte(schritte(5000, 60000)));
  await setzen(env, "ich", werte(schritte(9000, 9000, plus(T(), -1))));
  assert.deepEqual(schritteZeile(env, "ich"), { tag: T(), heute: 5000, monat: 60000 });
  await setzen(env, "ich", werte(schritte(5100, 60100)));
  assert.deepEqual(schritteZeile(env, "ich"), { tag: T(), heute: 5100, monat: 60100 });
});

test("Stats Schritte: Freunde und Alle sehen heute und Monat, nur wer Schritte schickt und Freunden Schritte zeigt", async () => {
  const env = await welt("ich", "du", "fremd", "vier");
  const v = await verbinden(env, "ich", "du");
  await setzen(env, "du", werte(schritte(6240, 70000)));
  const freund = async () => (await lesen(env, "ich")).freunde[0];
  assert.deepEqual(await freund(), { id: v, name: "Beispiel du", punkte: 75, trainings: 3, sets: 40, serie: 4, rekorde: REKORDE, schritteHeute: 6240, schritteMonat: 70000 });
  await einst(env, v, "du", { zeigt: ["gym"] });
  let f = await freund();
  assert.ok(f && !("schritteHeute" in f) && !("schritteMonat" in f), "Gym ja, Schritte nein");
  await einst(env, v, "ich", { ausblenden: ["schritte"] });
  await einst(env, v, "du", {});
  f = await freund();
  assert.ok(f && !("schritteHeute" in f), "ich blende Schritte aus");
  await einst(env, v, "ich", {});

  await setzen(env, "fremd", oeffentlich("Stahlbiene", 1, schritte(12000, 150000)));
  await setzen(env, "vier", oeffentlich("Eisenfaust", 1));
  const alle = async () => Object.fromEntries((await lesen(env, "ich")).alle.map((e) => [e.name, [e.schritteHeute, e.schritteMonat]]));
  assert.deepEqual(await alle(), { Stahlbiene: [12000, 150000], Eisenfaust: [undefined, undefined] });
  // Letzter Stand von gestern: heute 0, der Monat nur im selben Monat; älter als der Monat: beides 0.
  sql(env, "UPDATE stats_schritte SET tag = ? WHERE konto = ?", plus(T(), -1), KONTEN.fremd.id);
  assert.deepEqual((await alle()).Stahlbiene, [0, plus(T(), -1).slice(0, 7) === T().slice(0, 7) ? 150000 : 0]);
  sql(env, "UPDATE stats_schritte SET tag = ? WHERE konto = ?", plus(T(), -40), KONTEN.fremd.id);
  assert.deepEqual((await alle()).Stahlbiene, [0, 0]);
});
