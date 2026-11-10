import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fakeD1 } from "./fake-d1.js";
import { handleFetch } from "./index.js";
import { KONTO_LOESCHER } from "./konto-loeschen.js";

const SCHEMA = readFileSync(new URL("./schema.sql", import.meta.url), "utf8");
const APP = "app-key-test";
// Mit _ und -: der Drossel-Vergleich darf nicht wie LIKE raten.
const ICH = "ich_" + "a".repeat(28);
const DU = "du-" + "b".repeat(29);
const ANDERS = "ichXaaaa" + "a".repeat(24);
const GEHEIM = "g".repeat(48);

const env = () => ({ DB: fakeD1(SCHEMA), APP_KEY: APP, ADMIN_KEY: "admin" });
const kopf = (id) => ({ "X-App-Key": APP, "X-Konto": id, "X-Geheimnis": GEHEIM });
const ruf = (e, methode, pfad, headers = {}, body) =>
  handleFetch(new Request("https://x.test" + pfad, { method: methode, headers, body: body === undefined ? undefined : JSON.stringify(body) }), e);
const anlegen = (e, id) => ruf(e, "POST", "/konto", { "X-App-Key": APP }, { id, geheimnis: GEHEIM, name: "Test", version: "1" });

// Jede Tabelle mit Konto-Bezug bekommt Zeilen für mich, für dich und eine Verbindung zwischen uns.
function fuellen(e) {
  const sql = (s, ...w) => e.DB.roh.prepare(s).run(...w);
  for (const k of [ICH, DU, ANDERS]) {
    sql("INSERT INTO konto_merker VALUES (?, 'lovea_import', 'x')", k);
    sql("INSERT INTO nutzung (konto, tag) VALUES (?, '2026-11-01')", k);
    sql("INSERT INTO nutzung_mehr (konto, tag) VALUES (?, '2026-11-01')", k);
    sql("INSERT INTO partner_stand VALUES (?, 't', '{}')", k);
    sql("INSERT INTO ki_nutzung VALUES (?, '2026-11-01', 2)", k);
    sql("INSERT INTO einladungen VALUES (?, ?, 0, 0)", "h" + k, k);
    sql("INSERT INTO drossel VALUES (?, 1, 1)", "scan:" + k);
    sql("INSERT INTO drossel VALUES (?, 1, 1)", "einladung:" + k);
    sql("INSERT INTO schlaf_belege (konto, zeit, daten) VALUES (?, 't', '{}')", k);
    sql("INSERT INTO agent_postfach (konto, art, daten, erstellt) VALUES (?, 'gym.plan', '{}', 't')", k);
  }
  sql("INSERT INTO drossel VALUES ('coach:fehl', 1, 1)");
  sql("INSERT INTO verbindungen (id, a, b, status, erstellt, geaendert) VALUES ('v1', ?, ?, 'aktiv', 't', 't')", DU, ICH);
  sql("INSERT INTO verbindungen (id, a, b, status, erstellt, geaendert) VALUES ('v2', ?, ?, 'aktiv', 't', 't')", DU, ANDERS);
  sql("INSERT INTO reaktionen VALUES ('r1', ?, ?, 'respekt', 'einheit:2026-11-01', '', 't')", DU, ICH);
  sql("INSERT INTO reaktionen VALUES ('r2', ?, ?, 'respekt', 'einheit:2026-11-01', '', 't')", ICH, DU);
  sql("INSERT INTO reaktionen VALUES ('r3', ?, ?, 'respekt', 'einheit:2026-11-01', '', 't')", DU, ANDERS);
  // h1: meine (du bist dabei, ANDERS eingeladen); h2: deine (ich bin dabei); h3: nur meine.
  sql("INSERT INTO herausforderungen (id, ersteller, art, modus, start, ende, erstellt) VALUES ('h1', ?, 'tage', 'gegen', 's', 'z', 't')", ICH);
  sql("INSERT INTO herausforderungen (id, ersteller, art, modus, start, ende, erstellt) VALUES ('h2', ?, 'tage', 'gegen', 's', 'z', 't')", DU);
  sql("INSERT INTO herausforderungen (id, ersteller, art, modus, start, ende, erstellt) VALUES ('h3', ?, 'tage', 'gegen', 's', 'z', 't')", ICH);
  for (const [h, k, s] of [["h1", ICH, "dabei"], ["h1", DU, "dabei"], ["h1", ANDERS, "eingeladen"], ["h2", DU, "dabei"], ["h2", ICH, "dabei"], ["h3", ICH, "dabei"]]) {
    sql("INSERT INTO herausforderung_teilnehmer (herausforderung, konto, status) VALUES (?, ?, ?)", h, k, s);
  }
}

function alles(e) {
  const tabellen = e.DB.roh.prepare("SELECT name FROM sqlite_master WHERE type = 'table'").all().map((t) => t.name);
  return Object.fromEntries(tabellen.map((t) => [t, e.DB.roh.prepare(`SELECT * FROM ${t}`).all()]));
}

test("DELETE /konto: keine Zeile irgendeiner Tabelle nennt das Konto mehr, andere Konten bleiben", async () => {
  const e = env();
  for (const k of [ICH, DU, ANDERS]) assert.equal((await anlegen(e, k)).status, 201);
  fuellen(e);
  const vorher = alles(e);
  const r = await ruf(e, "DELETE", "/konto", kopf(ICH));
  assert.equal(r.status, 200);
  const nachher = alles(e);
  for (const [tabelle, zeilen] of Object.entries(nachher)) {
    assert.ok(!JSON.stringify(zeilen).includes(ICH), `${tabelle} nennt das gelöschte Konto noch`);
  }
  // Andere Konten: alle Zeilen ohne Bezug zu mir sind unverändert da.
  for (const [tabelle, zeilen] of Object.entries(vorher)) {
    if (tabelle.startsWith("herausforderung")) continue;
    const ohneMich = zeilen.filter((z) => !JSON.stringify(z).includes(ICH));
    assert.deepEqual(nachher[tabelle], ohneMich, tabelle);
  }
  assert.ok(nachher.drossel.some((z) => z.schluessel === "coach:fehl"), "globale Drossel bleibt");
  assert.equal(nachher.drossel.filter((z) => z.schluessel.endsWith(ANDERS)).length, 2, "ähnliche Kennung bleibt");
  // Verbindung des Partners zu mir ist weg, seine andere bleibt.
  assert.deepEqual(nachher.verbindungen.map((v) => v.id), ["v2"]);
  // Meine Herausforderung mit dir: abgebrochen, ohne meine Kennung, offene Einladung weg. Deine: ich bin raus. Nur meine: ganz weg.
  const h = Object.fromEntries(nachher.herausforderungen.map((x) => [x.id, x]));
  assert.equal(h.h1.abgebrochen, 1);
  assert.equal(h.h1.ersteller, "geloescht");
  assert.equal(h.h2.abgebrochen, 0);
  assert.equal(h.h2.ersteller, DU);
  assert.equal(h.h3, undefined);
  assert.deepEqual(nachher.herausforderung_teilnehmer.map((t) => `${t.herausforderung}:${t.konto}`).sort(), [`h1:${DU}`, `h2:${DU}`]);
});

test("DELETE /konto: danach unbekannt (401), dieselbe Kennung lässt sich wie ein neues Gerät anlegen", async () => {
  const e = env();
  await anlegen(e, ICH);
  assert.equal((await ruf(e, "DELETE", "/konto", kopf(ICH))).status, 200);
  assert.equal((await ruf(e, "GET", "/config", kopf(ICH))).status, 401);
  assert.equal((await ruf(e, "DELETE", "/konto", kopf(ICH))).status, 401, "zweites Löschen: schon weg");
  assert.equal((await anlegen(e, ICH)).status, 201);
  assert.equal((await ruf(e, "GET", "/config", kopf(ICH))).status, 200);
});

test("DELETE /konto: ohne oder mit falschen Kopfzeilen 401, gesperrt 403, nichts gelöscht", async () => {
  const e = env();
  await anlegen(e, ICH);
  assert.equal((await ruf(e, "DELETE", "/konto")).status, 401);
  assert.equal((await ruf(e, "DELETE", "/konto", { "X-App-Key": APP })).status, 401);
  assert.equal((await ruf(e, "DELETE", "/konto", { ...kopf(ICH), "X-Geheimnis": "x".repeat(48) })).status, 401);
  assert.equal((await ruf(e, "DELETE", "/konto", { ...kopf(ICH), "X-App-Key": "falsch" })).status, 401);
  e.DB.roh.prepare("UPDATE konten SET gesperrt = 1").run();
  assert.equal((await ruf(e, "DELETE", "/konto", kopf(ICH))).status, 403);
  assert.equal(e.DB.roh.prepare("SELECT COUNT(*) AS n FROM konten").get().n, 1);
});

test("DELETE /konto: eingetragene Löscher (stats.js) laufen mit dem Konto, vor der Konto-Zeile", async () => {
  const e = env();
  await anlegen(e, ICH);
  const gesehen = [];
  const loescher = async (env2, konto) => {
    gesehen.push(konto, (await env2.DB.prepare("SELECT COUNT(*) AS n FROM konten WHERE id = ?").bind(konto).first()).n);
  };
  KONTO_LOESCHER.push(loescher);
  try {
    assert.equal((await ruf(e, "DELETE", "/konto", kopf(ICH))).status, 200);
  } finally {
    KONTO_LOESCHER.splice(KONTO_LOESCHER.indexOf(loescher), 1);
  }
  assert.deepEqual(gesehen, [ICH, 1]);
});
