import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fakeD1 } from "./fake-d1.js";
import { handleFetch } from "./index.js";
import { ftsAnfrage, normalisiere } from "./essen.js";

const SCHEMA = readFileSync(new URL("./schema.sql", import.meta.url), "utf8");
const ESSEN_SCHEMA = readFileSync(new URL("./essen-schema.sql", import.meta.url), "utf8");
const APP = "app-key-test";
const ID = "e".repeat(32);
const GEHEIM = "h".repeat(48);
const kopf = { "X-App-Key": APP, "X-Konto": ID, "X-Geheimnis": GEHEIM };

async function aufbau({ essen = true } = {}) {
  const env = { DB: fakeD1(SCHEMA), APP_KEY: APP, ADMIN_KEY: "admin" };
  if (essen) {
    env.ESSEN = fakeD1(ESSEN_SCHEMA);
    const rein = env.ESSEN.roh.prepare("INSERT INTO produkt (code, name, marke, menge, portion_g, portion_name, pro100, beliebtheit) VALUES (?, ?, ?, ?, ?, ?, ?, ?)");
    rein.run("4000000000001", "High Protein Pudding", "Ehrmann", "200 g", 200, "Becher", JSON.stringify({ kcal: 75, protein: 10, kohlenhydrate: 6, fett: 1.5 }), 50);
    rein.run("4000000000002", "Dönerfleisch", "Royal Döner", null, null, null, JSON.stringify({ kcal: 220, protein: 18, kohlenhydrate: 2, fett: 15 }), 3);
    rein.run("4000000000003", "Döner Pizza", null, null, null, null, JSON.stringify({ kcal: 250, protein: 11, kohlenhydrate: 28, fett: 10 }), 0);
    rein.run("0012345678905", "Erdnussbutter", "Kaputt", null, null, null, "{kein json", 0);
  }
  const reg = await handleFetch(new Request("https://x.test/konto", { method: "POST", headers: { "X-App-Key": APP }, body: JSON.stringify({ id: ID, geheimnis: GEHEIM, name: "Test", version: "1" }) }), env);
  assert.equal(reg.status, 201);
  return env;
}
const hol = async (env, pfad, headers = kopf) => {
  const r = await handleFetch(new Request(`https://x.test${pfad}`, { headers }), env);
  return { status: r.status, json: await r.json() };
};

test("ohne Login 401, nie Daten", async () => {
  const env = await aufbau();
  assert.equal((await hol(env, "/essen/suche?q=döner", { "X-App-Key": APP })).status, 401);
  assert.equal((await hol(env, "/essen/barcode/4000000000001", {})).status, 401);
});

test("Suche: Präfix je Wort, Marke zählt, Beliebtheit vorn, n begrenzt", async () => {
  const env = await aufbau();
  let r = await hol(env, "/essen/suche?q=ehrmann%20high%20prot");
  assert.equal(r.status, 200);
  assert.equal(r.json.treffer[0].name, "High Protein Pudding");
  assert.deepEqual(r.json.treffer[0].pro100, { kcal: 75, protein: 10, kohlenhydrate: 6, fett: 1.5 });
  r = await hol(env, "/essen/suche?q=d%C3%B6ner&n=1");
  assert.equal(r.json.treffer.length, 1);
  r = await hol(env, "/essen/suche?q=d%C3%B6ner");
  assert.deepEqual(r.json.treffer.map((t) => t.name).sort(), ["Döner Pizza", "Dönerfleisch"]);
  assert.deepEqual((await hol(env, "/essen/suche?q=%22%29%20OR%20*")).json.treffer, []);
  assert.deepEqual((await hol(env, "/essen/suche?q=")).json.treffer, []);
});

test("Barcode: 12 Stellen werden 13, unbekannt 404, kaputte Werte leer statt Absturz", async () => {
  const env = await aufbau();
  let r = await hol(env, "/essen/barcode/4000000000002");
  assert.equal(r.status, 200);
  assert.equal(r.json.produkt.marke, "Royal Döner");
  r = await hol(env, "/essen/barcode/012345678905");
  assert.equal(r.status, 200);
  assert.deepEqual(r.json.produkt.pro100, {});
  r = await hol(env, "/essen/barcode/4000000000999");
  assert.equal(r.status, 404);
  assert.equal(r.json.produkt, null);
});

test("ohne Bindung ESSEN 503 nichtEingerichtet", async () => {
  const env = await aufbau({ essen: false });
  assert.equal((await hol(env, "/essen/suche?q=skyr")).status, 503);
});

test("Hilfen: Anfrage nur aus Wörtern, Barcode nur Ziffern", () => {
  assert.equal(ftsAnfrage('Skyr "natur" OR'), '"skyr"* "natur"* "or"*');
  assert.equal(normalisiere("401-234 5678901"), "4012345678901");
});
