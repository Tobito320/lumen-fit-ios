import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fakeD1 } from "./fake-d1.js";
import { handleFetch } from "./index.js";
import { aendern, kanon, verlauf } from "./coach.js";

const SCHEMA = readFileSync(new URL("./schema.sql", import.meta.url), "utf8");
const APP = "app-key-test";
const COACH = "c".repeat(40);
const ID = "p".repeat(32);
const GEHEIM = "q".repeat(48);
const kopf = { "X-App-Key": APP, "X-Konto": ID, "X-Geheimnis": GEHEIM, "content-type": "application/json" };
const admin = { "X-Admin-Key": "admin", "content-type": "application/json" };
const coachKopf = { "X-Coach-Key": COACH, "content-type": "application/json" };
// Katalog-ids: jHAnWmT Schrägbankdrücken an der Maschine, goJ6ezq Seitheben am Kabelzug, j9Q5crt Stepper.
const PLAN = {
  splitName: "PPL", ruhetage: [3],
  tage: [
    { id: "t1", name: "Push", wochentage: [1], uebungen: [
      { id: "u1", uebung: "jHAnWmT", saetze: [{ wdh: 10, kg: 40, failure: false }, { wdh: 10, kg: 40, failure: false }] },
      { id: "u2", uebung: "goJ6ezq", saetze: [{ wdh: 12, failure: false }] },
    ] },
    { id: "t2", name: "Push", wochentage: [5], uebungen: [{ id: "u3", uebung: "jHAnWmT", saetze: [{ wdh: 12, failure: false }] }] },
    { id: "t3", name: "Cardio", wochentage: [], uebungen: [{ id: "u4", uebung: "j9Q5crt", saetze: [], minuten: 20 }] },
  ],
};

const ruf = async (env, methode, pfad, headers, body) => {
  const r = await handleFetch(new Request(`https://x.test${pfad}`, { method: methode, headers, body: body === undefined ? undefined : JSON.stringify(body) }), env);
  return { status: r.status, json: await r.json() };
};

async function aufbau({ person = "ahmed", plan = PLAN } = {}) {
  const env = { DB: fakeD1(SCHEMA), APP_KEY: APP, ADMIN_KEY: "admin", COACH_KEY: COACH };
  assert.equal((await ruf(env, "POST", "/konto", { "X-App-Key": APP }, { id: ID, geheimnis: GEHEIM, name: "Test", version: "1" })).status, 201);
  assert.equal((await ruf(env, "PATCH", `/admin/konto/${ID}`, admin, { lovea_person: person, einstellungen: { planMelden: true } })).status, 200);
  if (plan) assert.equal((await ruf(env, "PUT", "/postfach/plan", kopf, { plan })).status, 200);
  return env;
}

test("Coach: ohne oder mit falschem Schlüssel 401, auch kein Admin-Key", async () => {
  const env = await aufbau();
  assert.equal((await ruf(env, "GET", "/coach/plan", {})).status, 401);
  assert.equal((await ruf(env, "GET", "/coach/plan", { "X-Coach-Key": "x".repeat(40) })).status, 401);
  assert.equal((await ruf(env, "GET", "/coach/plan", admin)).status, 401);
  assert.equal((await ruf(env, "GET", "/coach/plan", { "X-Coach-Key": COACH }, undefined)).status, 200);
  assert.equal((await ruf({ ...env, COACH_KEY: undefined }, "GET", "/coach/plan", coachKopf)).status, 401);
});

test("Coach: nur Ahmeds Konto, andere Person 404", async () => {
  const env = await aufbau({ person: "annika" });
  assert.equal((await ruf(env, "GET", "/coach/plan", coachKopf)).status, 404);
});

test("Coach: Plan lesbar mit Namen und Wochentagen", async () => {
  const env = await aufbau();
  const r = await ruf(env, "GET", "/coach/plan", coachKopf);
  assert.equal(r.status, 200);
  assert.equal(r.json.quelle, "App");
  assert.equal(r.json.plan.tage[0].uebungen[0].name, "Schrägbankdrücken an der Maschine");
  assert.deepEqual(r.json.plan.tage[1].wochentage, ["Fr"]);
  assert.equal(r.json.plan.tage[2].uebungen[0].minuten, 20);
});

test("Coach: Vorschlag ändert nichts, Anwenden legt genau ihn ins Postfach, Rückgängig stellt wieder her", async () => {
  const env = await aufbau();
  const v = await ruf(env, "POST", "/coach/vorschlag", coachKopf, { aenderungen: [{ tag: "Mo", uebung: "schrägbank", kg: 45, wdh: 8, saetze: 3 }] });
  assert.equal(v.status, 200, JSON.stringify(v.json));
  assert.deepEqual(v.json.aenderungen, ["Push (Mo) · Schrägbankdrücken an der Maschine: 2× 10×40 kg → 3× 8×45 kg"]);
  assert.equal((await ruf(env, "GET", "/postfach", kopf)).json.ops.length, 0);

  assert.equal((await ruf(env, "POST", "/coach/anwenden", coachKopf, { token: "falsch" })).status, 404);
  const a = await ruf(env, "POST", "/coach/anwenden", coachKopf, { token: v.json.token });
  assert.equal(a.status, 200);
  const ops = (await ruf(env, "GET", "/postfach", kopf)).json.ops;
  assert.equal(ops.length, 1);
  assert.deepEqual(ops[0].daten.tage[0].uebungen[0].saetze, Array(3).fill({ wdh: 8, kg: 45, failure: false }));
  assert.equal(ops[0].daten.splitName, "PPL");
  assert.deepEqual(ops[0].daten.tage[1], PLAN.tage[1]);
  assert.equal((await ruf(env, "POST", "/coach/anwenden", coachKopf, { token: v.json.token })).status, 404, "Token nur einmal");

  // Noch nicht abgeholt: Lesen zeigt schon den neuen Plan.
  const p = await ruf(env, "GET", "/coach/plan", coachKopf);
  assert.match(p.json.quelle, /noch nicht geholt/);
  assert.equal(p.json.plan.tage[0].uebungen[0].saetze[0].kg, 45);

  const z = await ruf(env, "POST", "/coach/rueckgaengig", coachKopf);
  assert.equal(z.status, 200);
  assert.equal((await ruf(env, "POST", "/coach/anwenden", coachKopf, { token: z.json.token })).status, 200);
  const ops2 = (await ruf(env, "GET", "/postfach", kopf)).json.ops;
  assert.equal(kanon(ops2.at(-1).daten), kanon(PLAN));
  assert.equal((await ruf(env, "POST", "/coach/rueckgaengig", coachKopf)).status, 404, "Stapel leer");
});

test("Coach: Plan in der App geändert seit dem Vorschlag -> 409, nichts im Postfach", async () => {
  const env = await aufbau();
  const v = await ruf(env, "POST", "/coach/vorschlag", coachKopf, { aenderungen: [{ tag: "t2", uebung: "u3", wdh: 8 }] });
  assert.equal(v.status, 200);
  const anders = structuredClone(PLAN);
  anders.tage[0].uebungen.pop();
  await ruf(env, "PUT", "/postfach/plan", kopf, { plan: anders });
  assert.equal((await ruf(env, "POST", "/coach/anwenden", coachKopf, { token: v.json.token })).status, 409);
  assert.equal((await ruf(env, "GET", "/postfach", kopf)).json.ops.length, 0);
});

test("Coach: App meldet denselben Plan neu kodiert (andere Reihenfolge der Schlüssel) -> Anwenden geht", async () => {
  const env = await aufbau();
  const v = await ruf(env, "POST", "/coach/vorschlag", coachKopf, { aenderungen: [{ tag: "t2", uebung: "u3", wdh: 8 }] });
  const umsortiert = JSON.parse(JSON.stringify(PLAN, Object.keys(PLAN).reverse().concat(["id", "name", "wochentage", "uebungen", "uebung", "saetze", "minuten", "failure", "kg", "wdh"])));
  await ruf(env, "PUT", "/postfach/plan", kopf, { plan: umsortiert });
  assert.equal((await ruf(env, "POST", "/coach/anwenden", coachKopf, { token: v.json.token })).status, 200);
});

test("Coach: mehrdeutige oder falsche Angaben werden abgelehnt", async () => {
  const env = await aufbau();
  const r = async (b) => (await ruf(env, "POST", "/coach/vorschlag", coachKopf, b));
  assert.match((await r({ aenderungen: [{ tag: "Push", uebung: "schrägbank", kg: 50 }] })).json.fehler, /mehrdeutig/);
  assert.match((await r({ aenderungen: [{ tag: "Mo", uebung: "kniebeuge", kg: 50 }] })).json.fehler, /nicht gefunden/);
  assert.match((await r({ aenderungen: [{ tag: "Mo", uebung: "u1", kg: 900 }] })).json.fehler, /kg/);
  assert.match((await r({ aenderungen: [{ tag: "Mo", uebung: "u1" }] })).json.fehler, /mindestens/);
  assert.match((await r({ aenderungen: [{ tag: "Mo", uebung: "u1", kg: 40, wdh: 10, saetze: 2 }] })).json.fehler, /ändert nichts/);
  assert.match((await r({ aenderungen: [{ tag: "Cardio", uebung: "u4", kg: 10 }] })).json.fehler, /Cardio/);
  assert.equal((await r({})).status, 400);
  assert.match((await r({ plan: { tage: [{ id: "x", name: "A", wochentage: [1], uebungen: [{ id: "y", uebung: "gibtsnicht", saetze: [{ wdh: 5, failure: false }] }] }] } })).json.fehler, /Katalog/);
});

test("Coach: ganzer Plan mit Tausch, neuer Übung und Liste; Splitname bleibt", async () => {
  const env = await aufbau();
  const neu = structuredClone(PLAN);
  delete neu.splitName;
  neu.tage[0].uebungen[1] = { id: "u9", uebung: "eigen", name: "Dips", saetze: [{ wdh: 6, kg: 10, failure: false }] };
  neu.tage[0].uebungen[0].name = "Schrägbankdrücken an der Maschine";
  const v = await ruf(env, "POST", "/coach/vorschlag", coachKopf, { plan: neu });
  assert.equal(v.status, 200, JSON.stringify(v.json));
  assert.deepEqual(v.json.aenderungen, ["Push (Mo) · neu: Dips 1× 6×10 kg", "Push (Mo) · raus: Seitheben am Kabelzug"]);
  await ruf(env, "POST", "/coach/anwenden", coachKopf, { token: v.json.token });
  const d = (await ruf(env, "GET", "/postfach", kopf)).json.ops[0].daten;
  assert.equal(d.splitName, "PPL");
  assert.equal(d.tage[0].uebungen[0].name, undefined, "Katalogname klebt nicht fest");
});

test("Coach: Liste setzt Pyramide, Aufwärmsatz bleibt bei kg", () => {
  const p = structuredClone(PLAN);
  p.tage[0].uebungen[0].saetze.unshift({ wdh: 12, kg: 20, failure: false, typ: "w" });
  const n = aendern(p, [{ tag: "t1", uebung: "u1", kg: 50 }]);
  assert.deepEqual(n.tage[0].uebungen[0].saetze.map((s) => s.kg), [20, 50, 50]);
  const l = aendern(p, [{ tag: "t1", uebung: "u1", liste: [{ wdh: 6, kg: 60 }, { wdh: 8, kg: 52.5, failure: true }] }]);
  assert.deepEqual(l.tage[0].uebungen[0].saetze, [{ wdh: 6, kg: 60, failure: false }, { wdh: 8, kg: 52.5, failure: true }]);
  assert.equal(p.tage[0].uebungen[0].saetze.length, 3, "Original unverändert");
});

test("Coach: Verlauf rechnet kg aus Zehnteln, e1RM und Bestsatz je Übung", async () => {
  const v = verlauf([
    { tag: "2026-11-04", name: "Push", uebungen: [{ name: "Bank", saetze: [{ wdh: 10, kg: 600 }, { wdh: 5, kg: 700 }] }] },
    { tag: "2026-11-09", name: "Push", uebungen: [{ name: "Bank", saetze: [{ wdh: 8, kg: 650 }] }] },
  ]);
  assert.equal(v.einheiten[0].tag, "2026-11-09");
  assert.equal(v.je_uebung[0].e1rm, 82.3);
  assert.equal(v.je_uebung[0].bester_satz, "8×65 kg (2026-11-09)");
  assert.equal(v.je_uebung[0].zuletzt.saetze, "1× 8×65 kg");

  const env = await aufbau();
  await env.DB.prepare("INSERT INTO partner_stand (konto, aktualisiert, daten) VALUES (?, ?, ?)").bind(ID, "2026-11-09T19:00:00Z", JSON.stringify({ heute: { verlauf: { trainings: 7, einheiten: [{ tag: "2026-11-09", name: "Push", uebungen: [{ name: "Bank", saetze: [{ wdh: 8, kg: 650 }] }] }] }, koerper: { gewicht: [{ tag: "2026-11-04", zehntel: 788 }] } } })).run();
  const r = await ruf(env, "GET", "/coach/verlauf", coachKopf);
  assert.equal(r.status, 200);
  assert.equal(r.json.koerpergewicht.kg, 78.8);
  assert.equal(r.json.je_uebung[0].uebung, "Bank");
});

test("Coach: Katalogsuche und kein Plan gemeldet", async () => {
  const env = await aufbau({ plan: null });
  const s = await ruf(env, "GET", "/coach/uebungen?suche=kniebeuge%20langhantel", coachKopf);
  assert.ok(s.json.treffer.length >= 1);
  assert.ok(s.json.treffer.every((t) => /kniebeuge/i.test(t.name)));
  assert.equal((await ruf(env, "GET", "/coach/plan", coachKopf)).json.plan, null);
  assert.equal((await ruf(env, "POST", "/coach/vorschlag", coachKopf, { aenderungen: [] })).status, 409);
});

// Ship-Review Build 17: Coach-Änderungen dürfen Felder, die er nicht kennt, nicht verlieren.
const REICH = {
  splitName: "PPL", ruhetage: [3], wochen: 4,
  tage: [{ id: "t1", name: "Push", wochentage: [1], farbe: "blau", uebungen: [
    { id: "u1", uebung: "jHAnWmT", notiz: "Sitz 4", pause: 150, supersatz: "s1", saetze: [{ wdh: 12, kg: 20, failure: false, typ: "w" }, { wdh: 8, kg: 40, failure: false, rpe: 8 }] },
    { id: "u2", uebung: "goJ6ezq", supersatz: "s1", saetze: [{ wdh: 12, failure: false }] },
  ] }],
};

test("Coach: liste gleicher Länge behält typ und rpe; andere Länge nur, was kommt; typ im Eintrag gewinnt", () => {
  const gleich = aendern(REICH, [{ tag: "Push", uebung: "schrägbank", liste: [{ wdh: 10, kg: 25 }, { wdh: 6, kg: 45, failure: true }] }]);
  assert.deepEqual(gleich.tage[0].uebungen[0].saetze, [{ wdh: 10, kg: 25, failure: false, typ: "w" }, { wdh: 6, kg: 45, failure: true, rpe: 8 }]);
  assert.equal(gleich.tage[0].uebungen[0].notiz, "Sitz 4");
  const anders = aendern(REICH, [{ tag: "Push", uebung: "schrägbank", liste: [{ wdh: 10, kg: 20, typ: "w" }, { wdh: 6, kg: 45 }, { wdh: 8, kg: 40 }] }]);
  assert.deepEqual(anders.tage[0].uebungen[0].saetze.map((s) => s.typ ?? "-"), ["w", "-", "-"]);
  const aus = aendern(REICH, [{ tag: "Push", uebung: "schrägbank", liste: [{ wdh: 10, kg: 30, typ: null }, { wdh: 6, kg: 45 }] }]);
  assert.equal(aus.tage[0].uebungen[0].saetze[0].typ, undefined);
});

test("Coach: ganzer Plan behält Notiz, Pause, Supersatz, Satz-Typ, RPE und Tag-Felder; Tausch übernimmt sie nicht", async () => {
  const env = await aufbau({ plan: REICH });
  const plan = { tage: [{ id: "t1", name: "Push", wochentage: [1], uebungen: [
    { id: "u1", uebung: "jHAnWmT", saetze: [{ wdh: 12, kg: 20, failure: false }, { wdh: 6, kg: 45, failure: false }] },
    { id: "u2", uebung: "j9Q5crt", saetze: [{ wdh: 12, failure: false }] },
  ] }] };
  const v = await ruf(env, "POST", "/coach/vorschlag", coachKopf, { plan });
  assert.equal(v.status, 200, JSON.stringify(v.json));
  assert.equal(v.json.token.length, 36);
  const a = await ruf(env, "POST", "/coach/anwenden", coachKopf, { token: v.json.token });
  assert.equal(a.status, 200);
  const neu = JSON.parse((await env.DB.prepare("SELECT daten FROM agent_postfach ORDER BY id DESC LIMIT 1").first()).daten);
  assert.equal(neu.wochen, 4);
  assert.equal(neu.tage[0].farbe, "blau");
  const [u1, u2] = neu.tage[0].uebungen;
  assert.deepEqual([u1.notiz, u1.pause, u1.supersatz], ["Sitz 4", 150, "s1"]);
  assert.deepEqual(u1.saetze, [{ wdh: 12, kg: 20, failure: false, typ: "w" }, { wdh: 6, kg: 45, failure: false, rpe: 8 }]);
  assert.equal(u2.supersatz, undefined);
});

test("Coach: dasselbe Token zweimal gibt nur einen Postfach-Eintrag; 10 Fehlversuche sperren eine Minute", async () => {
  const env = await aufbau();
  const v = await ruf(env, "POST", "/coach/vorschlag", coachKopf, { aenderungen: [{ tag: "Mo", uebung: "schrägbank", kg: 45 }] });
  const [x, y] = await Promise.all([ruf(env, "POST", "/coach/anwenden", coachKopf, { token: v.json.token }), ruf(env, "POST", "/coach/anwenden", coachKopf, { token: v.json.token })]);
  assert.equal([x.status, y.status].filter((s) => s === 200).length, 1);
  assert.ok([x.status, y.status].some((s) => s === 404 || s === 409));
  assert.equal((await env.DB.prepare("SELECT COUNT(*) AS n FROM agent_postfach").first()).n, 1);
  for (let i = 0; i < 10; i++) assert.equal((await ruf(env, "GET", "/coach/plan", { "X-Coach-Key": "x".repeat(40) })).status, 401);
  assert.equal((await ruf(env, "GET", "/coach/plan", coachKopf)).status, 429);
});
