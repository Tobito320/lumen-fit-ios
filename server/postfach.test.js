import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fakeD1 } from "./fake-d1.js";
import { handleFetch } from "./index.js";

const SCHEMA = readFileSync(new URL("./schema.sql", import.meta.url), "utf8");
const APP = "app-key-test";
const ID = "p".repeat(32);
const GEHEIM = "q".repeat(48);
const kopf = { "X-App-Key": APP, "X-Konto": ID, "X-Geheimnis": GEHEIM, "content-type": "application/json" };
const admin = { "X-Admin-Key": "admin", "content-type": "application/json" };
const PLAN = { tage: [{ id: "t", name: "Push", wochentage: [1], uebungen: [{ id: "u", uebung: "eigen", name: "Bank", saetze: [{ wdh: 8, failure: false }] }] }] };

async function aufbau() {
  const env = { DB: fakeD1(SCHEMA), APP_KEY: APP, ADMIN_KEY: "admin" };
  const reg = await handleFetch(new Request("https://x.test/konto", { method: "POST", headers: { "X-App-Key": APP }, body: JSON.stringify({ id: ID, geheimnis: GEHEIM, name: "Test", version: "1" }) }), env);
  assert.equal(reg.status, 201);
  return env;
}
const ruf = async (env, methode, pfad, headers, body) => {
  const r = await handleFetch(new Request(`https://x.test${pfad}`, { method: methode, headers, body: body === undefined ? undefined : JSON.stringify(body) }), env);
  return { status: r.status, json: await r.json() };
};

test("Postfach: Agent legt gym.plan ab, App holt, quittiert, danach leer", async () => {
  const env = await aufbau();
  assert.equal((await ruf(env, "POST", "/admin/postfach", admin, { konto: ID, art: "gym.plan", daten: PLAN })).status, 201);
  const a = await ruf(env, "GET", "/postfach", kopf);
  assert.equal(a.status, 200);
  assert.equal(a.json.ops.length, 1);
  assert.equal(a.json.ops[0].art, "gym.plan");
  assert.deepEqual(a.json.ops[0].daten, PLAN);
  assert.equal((await ruf(env, "POST", "/postfach/quittung", kopf, { ids: [a.json.ops[0].id] })).status, 200);
  assert.equal((await ruf(env, "GET", "/postfach", kopf)).json.ops.length, 0);
});

test("Postfach: Admin nur mit Admin-Key, App nur mit Konto-Login, andere Arten und kaputte Pläne abgewiesen", async () => {
  const env = await aufbau();
  const op = { konto: ID, art: "gym.plan", daten: PLAN };
  assert.equal((await ruf(env, "POST", "/admin/postfach", { "X-App-Key": APP, ...kopf, "X-Admin-Key": "falsch" }, op)).status, 401);
  assert.equal((await ruf(env, "POST", "/admin/postfach", { "content-type": "application/json" }, op)).status, 401);
  assert.equal((await ruf(env, "GET", "/postfach", { "X-App-Key": APP })).status, 401);
  assert.equal((await ruf(env, "GET", "/postfach", { ...kopf, "X-Geheimnis": "z".repeat(48) })).status, 401);
  assert.equal((await ruf(env, "POST", "/admin/postfach", admin, { ...op, art: "einstellung.setzen" })).status, 400);
  assert.equal((await ruf(env, "POST", "/admin/postfach", admin, { ...op, art: "toString" })).status, 400);
  assert.equal((await ruf(env, "POST", "/admin/postfach", admin, { ...op, daten: { tage: [] } })).status, 400);
  assert.equal((await ruf(env, "POST", "/admin/postfach", admin, { ...op, konto: "u".repeat(32) })).status, 404);
  assert.equal((await ruf(env, "GET", "/postfach", kopf)).json.ops.length, 0);
});

test("Postfach: ein Konto quittiert nur eigene Einträge", async () => {
  const env = await aufbau();
  await ruf(env, "POST", "/admin/postfach", admin, { konto: ID, art: "gym.plan", daten: PLAN });
  env.DB.roh.exec("INSERT INTO konten (id, hash, name, erstellt, gesehen) VALUES ('" + "o".repeat(32) + "', 'x', 'Anderes', '', '')");
  const fremd = await ruf(env, "POST", "/admin/postfach", admin, { konto: "o".repeat(32), art: "gym.plan", daten: PLAN });
  assert.equal(fremd.status, 201);
  const id = env.DB.roh.prepare("SELECT id FROM agent_postfach WHERE konto = ?").get("o".repeat(32)).id;
  await ruf(env, "POST", "/postfach/quittung", kopf, { ids: [id] });
  assert.equal(env.DB.roh.prepare("SELECT abgeholt FROM agent_postfach WHERE id = ?").get(id).abgeholt, null);
});

test("Plan melden: nur mit planMelden am Konto, Admin liest den Stand", async () => {
  const env = await aufbau();
  assert.equal((await ruf(env, "PUT", "/postfach/plan", kopf, { plan: PLAN })).status, 403);
  await ruf(env, "PATCH", `/admin/konto/${ID}`, admin, { einstellungen: { planMelden: true } });
  assert.equal((await ruf(env, "GET", "/postfach", kopf)).json.planMelden, true);
  assert.equal((await ruf(env, "PUT", "/postfach/plan", kopf, { plan: { tage: "x" } })).status, 400);
  assert.equal((await ruf(env, "PUT", "/postfach/plan", kopf, { plan: PLAN })).status, 200);
  const g = await ruf(env, "GET", `/admin/postfach/plan?konto=${ID}`, admin);
  assert.deepEqual(g.json.stand.plan, PLAN);
});

test("Plan mit doppelter Übungs-id in einem Tag -> 400, gleiche id an verschiedenen Tagen bleibt erlaubt", async () => {
  const env = await aufbau();
  await ruf(env, "PATCH", `/admin/konto/${ID}`, admin, { einstellungen: { planMelden: true } });
  const u = (id) => ({ id, uebung: "eigen", name: "Bank", saetze: [{ wdh: 8, failure: false }] });
  const tag = (id, uebungen) => ({ id, name: "Tag", wochentage: [1], uebungen });
  const doppelt = { tage: [tag("t", [u("a"), u("b"), u("a")])] };
  assert.equal((await ruf(env, "PUT", "/postfach/plan", kopf, { plan: doppelt })).status, 400);
  const abgelegt = await ruf(env, "POST", "/admin/postfach", admin, { konto: ID, art: "gym.plan", daten: doppelt });
  assert.equal(abgelegt.status, 400);
  assert.match(abgelegt.json.fehler, /id doppelt/);
  const verteilt = { tage: [tag("t1", [u("a"), u("b")]), tag("t2", [u("a")])] };
  assert.equal((await ruf(env, "PUT", "/postfach/plan", kopf, { plan: verteilt })).status, 200);
  assert.equal((await ruf(env, "POST", "/admin/postfach", admin, { konto: ID, art: "gym.plan", daten: verteilt })).status, 201);
});
