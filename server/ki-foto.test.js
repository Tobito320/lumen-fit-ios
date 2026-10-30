import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fakeD1 } from "./fake-d1.js";
import { handleFetch } from "./index.js";
import { TAGESLIMIT, itemBerechnen } from "./ki-foto.js";

const SCHEMA = readFileSync(new URL("./schema.sql", import.meta.url), "utf8");
const APP = "app-key-test";
const ADMIN = "admin-key-test";
const ID = "a".repeat(32);
const GEHEIM = "g".repeat(48);
const SCHLUESSEL = "sk-test-geheim-nie-loggen";
const BILD = Buffer.from("jpeg-bytes-fuer-den-test").toString("base64");
const kopf = { "X-App-Key": APP, "X-Konto": ID, "X-Geheimnis": GEHEIM, "content-type": "application/json" };

const REIS = { name: "Reis, gekocht", gramm: 200, kcal_pro_100g: 130, protein_pro_100g: 2.7, kohlenhydrate_pro_100g: 28, fett_pro_100g: 0.3, sicherheit: "mittel" };
const OEL = { name: "Bratöl", gramm: 10, kcal_pro_100g: 880 };
const antwortMit = (o) => new Response(JSON.stringify({ output_text: JSON.stringify(o) }), { status: 200 });
const ESSEN = { ist_essen: true, items: [REIS], versteckt: [OEL], frage: null, bemerkung: "Reis mit etwas Öl." };

/** Umgebung mit Konto; `an`: Schalter kiFotoErlaubt am Konto; `schluessel`: Secret gesetzt. */
async function aufbau({ an = true, schluessel = true } = {}) {
  const env = { DB: fakeD1(SCHEMA), APP_KEY: APP, ADMIN_KEY: ADMIN, LOVEA_KEY: "lovea-geheim" };
  if (schluessel) env.OPENAI_API_KEY = SCHLUESSEL;
  const reg = await handleFetch(new Request("https://x.test/konto", {
    method: "POST", headers: { "X-App-Key": APP }, body: JSON.stringify({ id: ID, geheimnis: GEHEIM, name: "Test", version: "1" }),
  }), env);
  assert.equal(reg.status, 201);
  if (an) {
    const r = await handleFetch(new Request(`https://x.test/admin/konto/${ID}`, {
      method: "PATCH", headers: { "X-Admin-Key": ADMIN, "content-type": "application/json" }, body: JSON.stringify({ einstellungen: { kiFotoErlaubt: true } }),
    }), env);
    assert.equal(r.status, 200);
  }
  return env;
}

/** holen mit Zähler; `antwort` ist eine Funktion, die eine Response liefert. */
function fakeOpenAI(antwort = () => antwortMit(ESSEN)) {
  const f = async (url, opt) => { f.aufrufe.push({ url, opt }); return antwort(url, opt); };
  f.aufrufe = [];
  return f;
}

async function foto(env, { holen = fakeOpenAI(), body = { bild: BILD, mahlzeit: "mittag" }, headers = kopf, roh } = {}) {
  const r = await handleFetch(new Request("https://x.test/ki/foto", { method: "POST", headers, body: roh ?? JSON.stringify(body) }), env, undefined, holen);
  const text = await r.text();
  let json = null;
  try { json = JSON.parse(text); } catch {}
  return { status: r.status, json, text };
}

const zaehler = (env) => env.DB.roh.prepare("SELECT n FROM ki_nutzung").get()?.n ?? 0;

test("ohne Konto-Login 401, auch bei ausgeschaltetem Schalter", async () => {
  const env = await aufbau({ an: false });
  assert.equal((await foto(env, { headers: { "X-App-Key": APP } })).status, 401);
  assert.equal((await foto(env, { headers: { ...kopf, "X-Geheimnis": "x".repeat(48) } })).status, 401);
});

test("Schalter aus: 403 und OpenAI wird nie gefragt, auch nicht ohne Secret", async () => {
  const holen = fakeOpenAI();
  const env = await aufbau({ an: false });
  const r = await foto(env, { holen });
  assert.equal(r.status, 403);
  assert.equal(r.json.fehler, "nichtErlaubt");
  assert.equal(holen.aufrufe.length, 0);
  assert.equal(zaehler(await aufbau({ an: false, schluessel: false })), 0);
  assert.equal((await foto(await aufbau({ an: false, schluessel: false }))).status, 403);
});

test("Schalter global an gilt für das Konto, Konto kann ihn abschalten", async () => {
  const env = await aufbau({ an: false });
  await handleFetch(new Request("https://x.test/admin/config", { method: "PATCH", headers: { "X-Admin-Key": ADMIN, "content-type": "application/json" }, body: JSON.stringify({ kiFotoErlaubt: true }) }), env);
  assert.equal((await foto(env)).status, 200);
  await handleFetch(new Request(`https://x.test/admin/konto/${ID}`, { method: "PATCH", headers: { "X-Admin-Key": ADMIN, "content-type": "application/json" }, body: JSON.stringify({ einstellungen: { kiFotoErlaubt: false } }) }), env);
  assert.equal((await foto(env)).status, 403);
});

test("ohne Secret 503 nichtEingerichtet, nichts gezählt, OpenAI nicht gefragt", async () => {
  const holen = fakeOpenAI();
  const env = await aufbau({ schluessel: false });
  const r = await foto(env, { holen });
  assert.equal(r.status, 503);
  assert.equal(r.json.fehler, "nichtEingerichtet");
  assert.equal(holen.aufrufe.length, 0);
  assert.equal(zaehler(env), 0);
});

test("Erfolg: Format der Vorlage, Schlüssel und Bild gehen nur an OpenAI, store:false, Schema strikt", async () => {
  const holen = fakeOpenAI();
  const env = await aufbau();
  const r = await foto(env, { holen, body: { bild: BILD, mahlzeit: "abend", hinweis: "  mit   Olivenöl " } });
  assert.equal(r.status, 200);
  assert.equal(r.json.ok, true);
  assert.equal(r.json.ist_essen, true);
  assert.equal(r.json.items[0].name, "Reis, gekocht");
  assert.equal(r.json.items[0].kcal, 260);
  assert.deepEqual(r.json.versteckt, [{ name: "Bratöl", gramm: 10, kcal: 88 }]);
  assert.equal(r.json.gesamt.kcal, 260);
  assert.equal(r.json.gesamt.kcal_mit_versteckt, 348);
  assert.ok(r.json.gesamt.kcal_min < 260 && r.json.gesamt.kcal_max > 348);
  assert.equal(r.json.rest, TAGESLIMIT - 1);
  assert.equal(zaehler(env), 1);

  assert.equal(holen.aufrufe.length, 1);
  const { url, opt } = holen.aufrufe[0];
  assert.equal(url, "https://api.openai.com/v1/responses");
  assert.equal(opt.headers.Authorization, `Bearer ${SCHLUESSEL}`);
  const k = JSON.parse(opt.body);
  assert.equal(k.store, false);
  assert.equal(k.text.format.strict, true);
  assert.match(k.input[0].content[0].text, /Abendessen/);
  assert.match(k.input[0].content[0].text, /mit Olivenöl/);
  assert.equal(k.input[0].content[1].image_url, `data:image/jpeg;base64,${BILD}`);
  // Nichts davon darf in der Antwort an die App stehen.
  assert.ok(!r.text.includes(SCHLUESSEL) && !r.text.includes(BILD));
});

test("OpenAI wird mit dem globalen fetch gefragt, nie über die Dienstbindung LOVEA", async () => {
  const env = await aufbau();
  env.LOVEA = { fetch: async () => { throw new Error("LOVEA darf für OpenAI nie benutzt werden"); } };
  const echtes = globalThis.fetch;
  const aufrufe = [];
  globalThis.fetch = async (url, opt) => { aufrufe.push({ url, auth: opt.headers.Authorization }); return antwortMit(ESSEN); };
  try {
    const r = await handleFetch(new Request("https://x.test/ki/foto", { method: "POST", headers: kopf, body: JSON.stringify({ bild: BILD }) }), env);
    assert.equal(r.status, 200);
  } finally {
    globalThis.fetch = echtes;
  }
  assert.deepEqual(aufrufe, [{ url: "https://api.openai.com/v1/responses", auth: `Bearer ${SCHLUESSEL}` }]);
});

test("kein Essen auf dem Foto: ist_essen false, leere Listen, Foto zählt trotzdem", async () => {
  const env = await aufbau();
  const r = await foto(env, { holen: fakeOpenAI(() => antwortMit({ ist_essen: false, items: [], versteckt: [], frage: null, bemerkung: "Das ist ein Hund." })) });
  assert.equal(r.status, 200);
  assert.equal(r.json.ist_essen, false);
  assert.deepEqual(r.json.items, []);
  assert.equal(r.json.bemerkung, "Das ist ein Hund.");
  assert.equal(zaehler(env), 1);
});

test("Bild: zu groß 413 bildZuGross, kaputt oder falscher Typ 400 ungueltig, ohne Zählen und ohne OpenAI", async () => {
  const holen = fakeOpenAI();
  const env = await aufbau();
  const gross = await foto(env, { holen, body: { bild: "A".repeat(1_400_001) } });
  assert.equal(gross.status, 413);
  assert.equal(gross.json.fehler, "bildZuGross");
  const riesig = await foto(env, { holen, roh: JSON.stringify({ bild: "A".repeat(1_700_000) }) });
  assert.equal(riesig.status, 413);
  const meldet = await foto(env, { holen, headers: { ...kopf, "content-length": "9999999" }, body: { bild: BILD } });
  assert.equal(meldet.status, 413);
  for (const body of [{}, { bild: "kein base64!" }, { bild: BILD, mime: "application/pdf" }, { bild: 5 }, []]) {
    const r = await foto(env, { holen, body });
    assert.equal(r.status, 400, JSON.stringify(body).slice(0, 40));
    assert.equal(r.json.fehler, "ungueltig");
  }
  assert.equal((await foto(env, { holen, roh: "{kaputt" })).status, 400);
  assert.equal(holen.aufrufe.length, 0);
  assert.equal(zaehler(env), 0);
});

test("Tageslimit: das 41. Foto bekommt 429 tageslimit, ohne OpenAI; anderer Tag und anderes Konto zählen extra", async () => {
  const holen = fakeOpenAI();
  const env = await aufbau();
  const heute = new Intl.DateTimeFormat("sv-SE", { timeZone: "Europe/Berlin" }).format(new Date());
  env.DB.roh.prepare("INSERT INTO ki_nutzung (konto, tag, n) VALUES (?, ?, ?)").run(ID, heute, TAGESLIMIT - 1);
  const letztes = await foto(env, { holen });
  assert.equal(letztes.status, 200);
  assert.equal(letztes.json.rest, 0);
  const zuviel = await foto(env, { holen });
  assert.equal(zuviel.status, 429);
  assert.equal(zuviel.json.fehler, "tageslimit");
  assert.equal(holen.aufrufe.length, 1);
  assert.equal(zaehler(env), TAGESLIMIT);
  // Gestern ist verbraucht, heute zählt neu; ein fremdes Konto hat seinen eigenen Zähler.
  env.DB.roh.prepare("DELETE FROM ki_nutzung").run();
  env.DB.roh.prepare("INSERT INTO ki_nutzung (konto, tag, n) VALUES (?, '2000-01-01', ?), ('fremd', ?, ?)").run(ID, TAGESLIMIT, heute, TAGESLIMIT);
  assert.equal((await foto(env, { holen })).status, 200);
});

test("zwei Fotos gleichzeitig beim vorletzten Platz: genau eines geht durch", async () => {
  const env = await aufbau();
  const heute = new Intl.DateTimeFormat("sv-SE", { timeZone: "Europe/Berlin" }).format(new Date());
  env.DB.roh.prepare("INSERT INTO ki_nutzung (konto, tag, n) VALUES (?, ?, ?)").run(ID, heute, TAGESLIMIT - 1);
  const holen = fakeOpenAI();
  const [a, b] = await Promise.all([foto(env, { holen }), foto(env, { holen })]);
  assert.deepEqual([a.status, b.status].sort(), [200, 429]);
  assert.equal(holen.aufrufe.length, 1);
  assert.equal(zaehler(env), TAGESLIMIT);
});

test("Fehlerzuordnung und Rückgabe des Fotos bei jedem Fehler nach dem Zählen", async () => {
  const faelle = [
    ["Netz weg", () => { throw new Error("offline"); }, 502, "netz"],
    ["429 ohne Quota", () => new Response(JSON.stringify({ error: { code: "rate_limit_exceeded" } }), { status: 429 }), 429, "zuVieleAnfragen"],
    ["Guthaben leer", () => new Response(JSON.stringify({ error: { code: "insufficient_quota" } }), { status: 429 }), 503, "guthaben"],
    ["Limit der Rechnung", () => new Response(JSON.stringify({ error: { code: "billing_hard_limit_reached" } }), { status: 429 }), 503, "guthaben"],
    ["Schlüssel falsch", () => new Response("{}", { status: 401 }), 503, "nichtEingerichtet"],
    ["Schlüssel gesperrt", () => new Response("nicht json", { status: 403 }), 503, "nichtEingerichtet"],
    ["Serverfehler", () => new Response("{}", { status: 500 }), 502, "kiFehler"],
    ["Antwort kein JSON", () => new Response(JSON.stringify({ output_text: "das ist kein json" }), { status: 200 }), 502, "kiFehler"],
    ["Antwort leer", () => new Response(JSON.stringify({ output: [] }), { status: 200 }), 502, "kiFehler"],
    ["unvollständig", () => new Response(JSON.stringify({ status: "incomplete", output_text: "{}" }), { status: 200 }), 502, "kiFehler"],
  ];
  for (const [name, antwort, status, fehler] of faelle) {
    const env = await aufbau();
    const r = await foto(env, { holen: fakeOpenAI(antwort) });
    assert.equal(r.status, status, name);
    assert.equal(r.json.fehler, fehler, name);
    assert.equal(zaehler(env), 0, `${name}: das Foto wird zurückgegeben`);
    assert.ok(!r.text.includes(SCHLUESSEL), name);
  }
});

test("Antwort in output-Liste statt output_text wird gelesen", async () => {
  const env = await aufbau();
  const r = await foto(env, { holen: fakeOpenAI(() => new Response(JSON.stringify({ output: [{ type: "message", content: [{ type: "output_text", text: JSON.stringify(ESSEN) }] }] }))) });
  assert.equal(r.status, 200);
  assert.equal(r.json.items.length, 1);
});

test("Berechnung: Makros gewinnen bei Abweichung über 30 Prozent, Alkohol nicht; Grenzen greifen", () => {
  assert.equal(itemBerechnen({ name: "Brot", gramm: 100, kcal_pro_100g: 900, protein_pro_100g: 10, kohlenhydrate_pro_100g: 50, fett_pro_100g: 2 }).kcal_pro_100g, 258);
  assert.equal(itemBerechnen({ name: "Bier", gramm: 500, kcal_pro_100g: 43, protein_pro_100g: 0.5, kohlenhydrate_pro_100g: 3, fett_pro_100g: 0 }).kcal, 215);
  const wild = itemBerechnen({ name: "  ", gramm: 99999, kcal_pro_100g: -5, sicherheit: "egal" });
  assert.equal(wild.name, "Unbekannt");
  assert.equal(wild.gramm, 2000);
  assert.equal(wild.kcal, 0);
  assert.equal(wild.sicherheit, "mittel");
});

test("nichts wird geloggt: weder Schlüssel noch Bild noch Antwort", async () => {
  const gesehen = [];
  const alt = {};
  for (const m of ["log", "info", "warn", "error", "debug"]) { alt[m] = console[m]; console[m] = (...a) => gesehen.push(a.join(" ")); }
  try {
    const env = await aufbau();
    await foto(env);
    await foto(env, { holen: fakeOpenAI(() => { throw new Error(`Schlüssel ${SCHLUESSEL}`); }) });
    await foto(env, { holen: fakeOpenAI(() => new Response("{}", { status: 401 })) });
  } finally {
    for (const m of Object.keys(alt)) console[m] = alt[m];
  }
  assert.deepEqual(gesehen, []);
});
