import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fakeD1 } from "./fake-d1.js";
import { handleFetch } from "./index.js";

const SCHEMA = readFileSync(new URL("./schema.sql", import.meta.url), "utf8");
const ORIGIN = "https://lumen-fit.pages.dev";
const env = () => ({ DB: fakeD1(SCHEMA), APP_KEY: "app", ADMIN_KEY: "admin-key" });
const senden = (e, body, { origin = ORIGIN, ip = "203.0.113.1", roh } = {}) => handleFetch(new Request("https://x.test/kontakt", {
  method: "POST", headers: { "content-type": "application/json", ...(origin ? { Origin: origin } : {}), "CF-Connecting-IP": ip },
  body: roh ?? JSON.stringify(body),
}), e);
const admin = (e, key = "admin-key") => handleFetch(new Request("https://x.test/admin/kontakt", { headers: { "X-Admin-Key": key } }), e);
const zeilen = (e) => e.DB.roh.prepare("SELECT * FROM kontakt").all();

test("Kontakt: gültige Nachricht wird gespeichert, ohne IP, mit CORS nur für die Webseite", async () => {
  const e = env();
  const r = await senden(e, { text: "  Die App stürzt beim Start ab.  ", antwort: "x@example.org" });
  assert.equal(r.status, 201);
  assert.equal(r.headers.get("access-control-allow-origin"), ORIGIN);
  const z = zeilen(e);
  assert.equal(z.length, 1);
  assert.equal(z[0].text, "Die App stürzt beim Start ab.");
  assert.equal(z[0].antwort, "x@example.org");
  const alles = JSON.stringify(e.DB.roh.prepare("SELECT * FROM drossel").all()) + JSON.stringify(z);
  assert.ok(!alles.includes("203.0.113.1"), "IP nie im Klartext");
  assert.equal((await senden(e, { text: "Ohne Adresse geht auch." })).status, 201);
  assert.equal(zeilen(e)[1].antwort, null);
});

test("Kontakt: Preflight nur für die Webseite, fremde oder fehlende Herkunft 403", async () => {
  const e = env();
  const ok = await handleFetch(new Request("https://x.test/kontakt", { method: "OPTIONS", headers: { Origin: ORIGIN, "Access-Control-Request-Method": "POST" } }), e);
  assert.equal(ok.status, 204);
  assert.equal(ok.headers.get("access-control-allow-origin"), ORIGIN);
  assert.match(ok.headers.get("access-control-allow-headers"), /content-type/);
  const fremd = await handleFetch(new Request("https://x.test/kontakt", { method: "OPTIONS", headers: { Origin: "https://boese.example" } }), e);
  assert.equal(fremd.status, 403);
  assert.equal(fremd.headers.get("access-control-allow-origin"), null);
  assert.equal((await senden(e, { text: "Hallo, eine Frage." }, { origin: "https://boese.example" })).status, 403);
  assert.equal((await senden(e, { text: "Hallo, eine Frage." }, { origin: null })).status, 403);
  assert.equal(zeilen(e).length, 0);
  // Andere Herkunft per Umgebung (Vorschau-Deploy).
  const e2 = { ...env(), KONTAKT_ORIGIN: "https://vorschau.lumen-fit.pages.dev" };
  assert.equal((await senden(e2, { text: "Hallo, eine Frage." }, { origin: "https://vorschau.lumen-fit.pages.dev" })).status, 201);
});

test("Kontakt: Text 10 bis 2000 Zeichen, Adresse nur in Mail-Form, Körper begrenzt", async () => {
  const e = env();
  for (const [body, was] of [[{ text: "zu kurz" }, "kurz"], [{ text: "x".repeat(2001) }, "lang"], [{}, "ohne"], [{ text: 12345678901 }, "zahl"],
    [{ text: "Genug Text hier.", antwort: "keine adresse" }, "adresse"], [{ text: "Genug Text hier.", antwort: "<a@b.de>" }, "spitz"]]) {
    assert.equal((await senden(e, body)).status, 400, was);
  }
  assert.equal((await senden(e, null, { roh: "kein json" })).status, 400);
  assert.equal((await senden(e, null, { roh: JSON.stringify({ text: "x".repeat(9000) }) })).status, 413);
  assert.equal((await senden(e, { text: "x".repeat(10) })).status, 201);
  assert.equal((await senden(e, { text: "x".repeat(2000) })).status, 201);
});

test("Kontakt: höchstens 5 je IP und Stunde, andere IP frei", async () => {
  const e = env();
  for (let i = 0; i < 5; i++) assert.equal((await senden(e, { text: `Nachricht Nummer ${i}` })).status, 201);
  assert.equal((await senden(e, { text: "Nachricht Nummer 6" })).status, 429);
  assert.equal((await senden(e, { text: "Andere Leitung hier" }, { ip: "203.0.113.2" })).status, 201);
  assert.equal(zeilen(e).length, 6);
});

test("Kontakt: Admin liest nur mit Schlüssel, alte Nachrichten (über 180 Tage) werden gelöscht", async () => {
  const e = env();
  e.DB.roh.prepare("INSERT INTO kontakt (zeit, text) VALUES (?, 'uralt')").run(new Date(Date.now() - 181 * 864e5).toISOString());
  e.DB.roh.prepare("INSERT INTO kontakt (zeit, text) VALUES (?, 'neu genug')").run(new Date(Date.now() - 179 * 864e5).toISOString());
  assert.equal((await admin(e, "falsch")).status, 401);
  assert.equal((await handleFetch(new Request("https://x.test/admin/kontakt"), e)).status, 401);
  const r = await admin(e);
  assert.equal(r.status, 200);
  assert.deepEqual((await r.json()).nachrichten.map((n) => n.text), ["neu genug"]);
  assert.equal(zeilen(e).length, 1);
});

test("kontakt: über die Webseite zählt die weitergereichte IP nur mit dem Schlüssel", async () => {
  const e = env();
  e.PROXY_SCHLUESSEL = "s".repeat(40);
  const ueber = (ip, schluessel) => handleFetch(new Request("https://x.test/kontakt", {
    method: "POST",
    headers: { "content-type": "application/json", Origin: ORIGIN, "CF-Connecting-IP": "198.51.100.9", "x-lumen-proxy": schluessel, "x-lumen-ip": ip },
    body: JSON.stringify({ text: "Hallo, eine Frage zur App" }),
  }), e);
  for (let i = 0; i < 5; i++) assert.equal((await ueber("203.0.113.50", e.PROXY_SCHLUESSEL)).status, 201);
  assert.equal((await ueber("203.0.113.50", e.PROXY_SCHLUESSEL)).status, 429, "gleiche Person über die Webseite gedrosselt");
  assert.equal((await ueber("203.0.113.51", e.PROXY_SCHLUESSEL)).status, 201, "andere Person über die Webseite nicht");
  for (let i = 0; i < 5; i++) await ueber("203.0.113." + (60 + i), "falsch".repeat(8));
  assert.equal((await ueber("203.0.113.70", "falsch".repeat(8))).status, 429, "ohne Schlüssel zählt die Leitung, nicht der Kopf");
});
