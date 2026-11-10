import { test } from "node:test";
import assert from "node:assert/strict";
import { WERKZEUGE, werkzeugAufrufen } from "./mcp.mjs";

function falschesHolen() {
  const aufrufe = [];
  const holen = async (url, opt) => { aufrufe.push({ url, opt }); return Response.json({ ok: true }); };
  return { aufrufe, holen };
}

test("18 Werkzeuge, alle mit lumenfit_-Namen", () => {
  assert.deepEqual(WERKZEUGE.map((w) => w.name), ["lumenfit_konten", "lumenfit_konto_setzen", "lumenfit_nutzung", "lumenfit_fehler", "lumenfit_auswertung", "lumenfit_import_beleg", "lumenfit_schlaf_beleg", "lumenfit_config_setzen", "lumenfit_konto_sperren", "lumenfit_plan_setzen", "lumenfit_plan_lesen", "lumenfit_verlauf", "lumenfit_uebungen", "lumenfit_plan_vorschlag", "lumenfit_plan_anwenden", "lumenfit_plan_rueckgaengig", "lumenfit_freunde", "lumenfit_einladen"]);
});

test("konten: GET /admin/konten auf live, Admin-Key im Header", async () => {
  const { aufrufe, holen } = falschesHolen();
  await werkzeugAufrufen("lumenfit_konten", {}, { holen, key: "K", basis: { live: "https://live.test", test: "https://test.test" } });
  assert.equal(aufrufe[0].url, "https://live.test/admin/konten");
  assert.equal(aufrufe[0].opt.headers["X-Admin-Key"], "K");
});

test("konto_setzen: nur gesetzte Felder, Schalter als einstellungen, Test-Umgebung wählbar", async () => {
  const { aufrufe, holen } = falschesHolen();
  const opt = { holen, key: "K", basis: { live: "https://live.test", test: "https://test.test" } };
  await werkzeugAufrufen("lumenfit_konto_setzen", { id: "abc", umgebung: "test", lovea_person: "annika", einstellungen: { loveaVerbinden: true } }, opt);
  assert.equal(aufrufe[0].url, "https://test.test/admin/konto/abc");
  assert.equal(aufrufe[0].opt.method, "PATCH");
  assert.deepEqual(JSON.parse(aufrufe[0].opt.body), { lovea_person: "annika", einstellungen: { loveaVerbinden: true } });
});

test("config_setzen und konto_sperren", async () => {
  const { aufrufe, holen } = falschesHolen();
  const opt = { holen, key: "K", basis: { live: "https://live.test", test: "https://test.test" } };
  await werkzeugAufrufen("lumenfit_config_setzen", { einstellungen: { nameAendernTage: 3 } }, opt);
  assert.equal(aufrufe[0].url, "https://live.test/admin/config");
  assert.deepEqual(JSON.parse(aufrufe[0].opt.body), { nameAendernTage: 3 });
  await werkzeugAufrufen("lumenfit_konto_sperren", { id: "abc", gesperrt: false }, opt);
  assert.deepEqual(JSON.parse(aufrufe[1].opt.body), { gesperrt: false });
});

test("Fehler vom Server werden zu Fehlertext, Key steht nie in der Meldung", async () => {
  const holen = async () => Response.json({ fehler: "ungültig" }, { status: 400 });
  await assert.rejects(werkzeugAufrufen("lumenfit_konten", {}, { holen, key: "GEHEIM", basis: { live: "https://l.test" } }), (e) => /400/.test(e.message) && !e.message.includes("GEHEIM"));
  await assert.rejects(werkzeugAufrufen("lumenfit_konto_setzen", { id: "abc" }, { holen, key: "K", basis: { live: "https://l.test" } }), /mindestens/);
  await assert.rejects(werkzeugAufrufen("nope", {}, { holen, key: "K", basis: {} }), /unbekannt/);
});

test("nutzung: GET /admin/nutzung; konto_setzen kann den Import-Merker zurücksetzen", async () => {
  const { aufrufe, holen } = falschesHolen();
  const opt = { holen, key: "K", basis: { live: "https://live.test", test: "https://test.test" } };
  await werkzeugAufrufen("lumenfit_nutzung", { umgebung: "test" }, opt);
  assert.equal(aufrufe[0].url, "https://test.test/admin/nutzung");
  assert.equal(aufrufe[0].opt.method, "GET");
  await werkzeugAufrufen("lumenfit_konto_setzen", { id: "abc", lovea_import_zuruecksetzen: true }, opt);
  assert.deepEqual(JSON.parse(aufrufe[1].opt.body), { lovea_import: null });
});

test("fehler und auswertung: GET mit Fenster in Tagen, falsche Tage werden abgewiesen", async () => {
  const { aufrufe, holen } = falschesHolen();
  const opt = { holen, key: "K", basis: { live: "https://live.test" } };
  await werkzeugAufrufen("lumenfit_fehler", {}, opt);
  await werkzeugAufrufen("lumenfit_auswertung", { tage: 7 }, opt);
  assert.deepEqual(aufrufe.map((a) => a.url), ["https://live.test/admin/fehler", "https://live.test/admin/auswertung?tage=7"]);
  assert.ok(aufrufe.every((a) => a.opt.method === "GET"));
  await assert.rejects(werkzeugAufrufen("lumenfit_fehler", { tage: 0 }, opt), /tage/);
  await assert.rejects(werkzeugAufrufen("lumenfit_auswertung", { tage: "7; DROP" }, opt), /tage/);
});

test("schlaf_beleg: GET /admin/schlaf-beleg mit konto und limit, ungültiges limit wird abgelehnt", async () => {
  const { aufrufe, holen } = falschesHolen();
  const opt = { holen, key: "K", basis: { live: "https://live.test", test: "https://test.test" } };
  await werkzeugAufrufen("lumenfit_schlaf_beleg", { konto: "abc", limit: 3 }, opt);
  assert.equal(aufrufe[0].url, "https://live.test/admin/schlaf-beleg?konto=abc&limit=3");
  await assert.rejects(() => werkzeugAufrufen("lumenfit_schlaf_beleg", { konto: "abc", limit: 99 }, opt));
  await assert.rejects(() => werkzeugAufrufen("lumenfit_schlaf_beleg", {}, opt));
});

const PLAN = { tage: [{ id: "t", name: "Push", wochentage: [1], uebungen: [{ id: "u", uebung: "eigen", name: "Bank", saetze: [{ wdh: 8, failure: false }] }] }] };

test("plan_setzen: ohne anwenden nur Vorschau (kein Abruf), mit anwenden POST ins Postfach, kaputter Plan abgewiesen", async () => {
  const { aufrufe, holen } = falschesHolen();
  const opt = { holen, key: "K", basis: { live: "https://live.test" } };
  const v = await werkzeugAufrufen("lumenfit_plan_setzen", { konto: "abc", plan: PLAN }, opt);
  assert.equal(v.vorschau, true);
  assert.equal(aufrufe.length, 0);
  await werkzeugAufrufen("lumenfit_plan_setzen", { konto: "abc", plan: PLAN, anwenden: true }, opt);
  assert.equal(aufrufe[0].url, "https://live.test/admin/postfach");
  assert.deepEqual(JSON.parse(aufrufe[0].opt.body), { konto: "abc", art: "gym.plan", daten: PLAN });
  await assert.rejects(werkzeugAufrufen("lumenfit_plan_setzen", { konto: "abc", plan: { tage: [] }, anwenden: true }, opt), /tage/);
  await werkzeugAufrufen("lumenfit_plan_lesen", { konto: "abc" }, opt);
  assert.equal(aufrufe[1].url, "https://live.test/admin/postfach/plan?konto=abc");
});

test("Coach-Wege: X-Coach-Key statt Admin-Key, Vorschlag, Anwenden, Rückgängig, Suche", async () => {
  const { aufrufe, holen } = falschesHolen();
  const opt = { holen, key: "ADMIN", coachKey: "COACH", basis: { live: "https://l.test", test: "https://t.test" } };
  await werkzeugAufrufen("lumenfit_verlauf", {}, opt);
  await werkzeugAufrufen("lumenfit_uebungen", { suche: "bank drücken", umgebung: "test" }, opt);
  await werkzeugAufrufen("lumenfit_plan_vorschlag", { aenderungen: [{ tag: "Push", uebung: "Bank", kg: 60 }] }, opt);
  await werkzeugAufrufen("lumenfit_plan_anwenden", { token: "t1" }, opt);
  await werkzeugAufrufen("lumenfit_plan_rueckgaengig", {}, opt);
  assert.deepEqual(aufrufe.map((x) => `${x.opt.method} ${x.url}`), [
    "GET https://l.test/coach/verlauf", "GET https://t.test/coach/uebungen?suche=bank%20dr%C3%BCcken",
    "POST https://l.test/coach/vorschlag", "POST https://l.test/coach/anwenden", "POST https://l.test/coach/rueckgaengig"]);
  for (const x of aufrufe) { assert.equal(x.opt.headers["X-Coach-Key"], "COACH"); assert.equal(x.opt.headers["X-Admin-Key"], undefined); }
  assert.deepEqual(JSON.parse(aufrufe[2].opt.body), { aenderungen: [{ tag: "Push", uebung: "Bank", kg: 60 }] });
  assert.deepEqual(JSON.parse(aufrufe[3].opt.body), { token: "t1" });
  await assert.rejects(werkzeugAufrufen("lumenfit_plan_vorschlag", {}, opt), /aenderungen/);
  await assert.rejects(werkzeugAufrufen("lumenfit_plan_anwenden", {}, opt), /token/);
  await assert.rejects(werkzeugAufrufen("lumenfit_uebungen", { suche: " " }, opt), /suche/);
  await werkzeugAufrufen("lumenfit_plan_lesen", { konto: "k" }, opt);
  assert.equal(aufrufe.at(-1).opt.headers["X-Admin-Key"], "ADMIN");
});

test("einladen: Status und Einladen rufen die CLI mit passenden Argumenten, Fehler mit Exit-Code", async () => {
  const argvs = [];
  const einladen = async (argv) => { argvs.push(argv); return argv[0] === "x@y.de" ? { code: 2, text: "asc.json fehlt" } : { code: 0, text: "ok" }; };
  assert.deepEqual(await werkzeugAufrufen("lumenfit_einladen", { status: true }, { einladen }), { ok: true, ausgabe: "ok" });
  await werkzeugAufrufen("lumenfit_einladen", { status: true, email: "a@b.de" }, { einladen });
  await werkzeugAufrufen("lumenfit_einladen", { email: " c@d.de ", gruppe: "Wir" }, { einladen });
  await assert.rejects(werkzeugAufrufen("lumenfit_einladen", { email: "x@y.de" }, { einladen }), /Exit 2: asc.json fehlt/);
  await assert.rejects(werkzeugAufrufen("lumenfit_einladen", {}, { einladen }), /email oder status/);
  assert.deepEqual(argvs, [["--status"], ["--status", "a@b.de"], ["c@d.de", "--gruppe", "Wir"], ["x@y.de"]]);
});

test("freunde: GET /admin/freunde mit Admin-Key, optional ein Konto", async () => {
  const { aufrufe, holen } = falschesHolen();
  const opt = { holen, key: "ADMIN", basis: { live: "https://l.test" } };
  await werkzeugAufrufen("lumenfit_freunde", {}, opt);
  await werkzeugAufrufen("lumenfit_freunde", { konto: "a b" }, opt);
  assert.deepEqual(aufrufe.map((x) => x.url), ["https://l.test/admin/freunde", "https://l.test/admin/freunde?konto=a%20b"]);
  assert.equal(aufrufe[0].opt.headers["X-Admin-Key"], "ADMIN");
});
