import { test } from "node:test";
import assert from "node:assert/strict";
import { WERKZEUGE, werkzeugAufrufen } from "./mcp.mjs";

function falschesHolen() {
  const aufrufe = [];
  const holen = async (url, opt) => { aufrufe.push({ url, opt }); return Response.json({ ok: true }); };
  return { aufrufe, holen };
}

test("neun Werkzeuge, alle mit lumenfit_-Namen", () => {
  assert.deepEqual(WERKZEUGE.map((w) => w.name), ["lumenfit_konten", "lumenfit_konto_setzen", "lumenfit_nutzung", "lumenfit_fehler", "lumenfit_auswertung", "lumenfit_import_beleg", "lumenfit_schlaf_beleg", "lumenfit_config_setzen", "lumenfit_konto_sperren"]);
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
