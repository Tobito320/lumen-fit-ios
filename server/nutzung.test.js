import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fakeD1 } from "./fake-d1.js";
import { handleFetch } from "./index.js";
import { NAMEN } from "./nutzung-namen.js";
import { ERLAUBT, MEHR_ARTEN, fehlerAuswerten, auswertungBauen, zusammenfuehren } from "./nutzung.js";

const SCHEMA = readFileSync(new URL("./schema.sql", import.meta.url), "utf8");
const APP = "app-key-test", ADMIN = "admin-key-test";
const ID = "a".repeat(32), GEHEIM = "g".repeat(48);
const umgebung = () => ({ DB: fakeD1(SCHEMA), APP_KEY: APP, ADMIN_KEY: ADMIN });
const app = (extra = {}) => ({ "X-App-Key": APP, "X-Konto": ID, "X-Geheimnis": GEHEIM, "X-App-Version": "1.3", ...extra });
const admin = { "X-Admin-Key": ADMIN };
async function ruf(env, methode, pfad, { headers = {}, body, roh } = {}) {
  const r = await handleFetch(new Request("https://x.test" + pfad, { method: methode, headers, body: roh ?? (body === undefined ? undefined : JSON.stringify(body)) }), env);
  const text = await r.text();
  let json = null;
  try { json = JSON.parse(text); } catch {}
  return { status: r.status, json };
}
const registrieren = (env) => ruf(env, "POST", "/konto", { headers: { "X-App-Key": APP }, body: { id: ID, geheimnis: GEHEIM, name: "Test", version: "1.0" } });
const heute = () => new Date().toISOString().slice(0, 10);
const vor = (n) => new Date(Date.now() - n * 864e5).toISOString().slice(0, 10);
const senden = (env, body, headers) => ruf(env, "POST", "/nutzung", { headers: app(headers), body });
const zeilen = (env) => env.DB.roh.prepare("SELECT * FROM nutzung_mehr").all();

test("Namenliste: alle Namen haben feste Form, keine Duplikate, jede Art hat eine Liste", () => {
  for (const art of MEHR_ARTEN) assert.ok(ERLAUBT[art].size > 0, art);
  const form = /^[a-z][A-Za-z0-9_.>]{0,89}$/;
  for (const [art, menge] of Object.entries(ERLAUBT)) for (const n of menge) assert.match(n, form, `${art}: ${n}`);
  for (const liste of [NAMEN.bereiche, NAMEN.funktionen, NAMEN.eintraege, NAMEN.stand, NAMEN.fehler, NAMEN.erster]) assert.equal(new Set(liste).size, liste.length);
});

test("Beweis: verbotene Felder, Werte und Freitext kommen am Server nicht durch", async () => {
  const env = umgebung();
  await registrieren(env);
  const r = await senden(env, {
    tag: heute(),
    bereiche: { "tab.gym": 1, gewicht_82: 3, "seite.profil.einstellungen": 1 },
    funktionen: { training: 1, training_bankdruecken: 2 },
    gruppen: {
      fehler: { speichern: 2, datei_users_ahmed_nicht_gefunden: 1 },
      stand: { theme_graphit: 1, gewicht_82kg: 1 },
      getippt: { profil_konto: 1, studio_Fitnessloft_Hagen: 1 },
      route: { "konto.s500": 1, "konto.s200": 4, "evil.s500": 1 },
      standort: { lat_51_36: 1 },
      notiz: { hallo: 1 },
    },
    name: "Ahmed", gewicht: 82, text: "Mama", standort: "Hagen", studio: "Fitnessloft", ios: "26.1 (Ahmeds iPhone)", geraet: "Ahmeds iPhone",
  });
  assert.equal(r.status, 200);
  const alt = env.DB.roh.prepare("SELECT * FROM nutzung").get();
  assert.deepEqual(JSON.parse(alt.bereiche), { "tab.gym": 1 });
  assert.deepEqual(JSON.parse(alt.funktionen), { training: 1 });
  const z = zeilen(env);
  assert.equal(z.length, 1);
  assert.deepEqual(JSON.parse(z[0].daten), { fehler: { speichern: 2 }, stand: { theme_graphit: 1 }, getippt: { profil_konto: 1 }, route: { "konto.s500": 1 } });
  assert.equal(z[0].ios, "", "freie iOS-Angabe wird verworfen");
  assert.equal(z[0].geraet, "", "freie Geräteangabe wird verworfen");
  const alles = JSON.stringify([z, alt]);
  for (const verboten of ["Ahmed", "Mama", "Hagen", "Fitnessloft", "82", "lat_51", "Users", "bankdruecken"]) assert.ok(!alles.includes(verboten), verboten);
});

test("Gültige Form: iOS und Gerätetyp werden gespeichert, Bündel addieren, der Stand ersetzt", async () => {
  const env = umgebung();
  await registrieren(env);
  const g = { ios: "26.1", geraet: "iPhone17,1" };
  assert.equal((await senden(env, { tag: heute(), ...g, gruppen: { start: { anzahl: 1, block_morgen: 1 }, fehler: { absturz: 1 }, stand: { theme_wald: 1, bereich_gym: 1 } } })).status, 200);
  assert.equal((await senden(env, { tag: heute(), ...g, gruppen: { start: { anzahl: 1 }, fehler: { absturz: 2, haenger: 1 }, stand: { theme_stahl: 1 } } })).status, 200);
  const z = zeilen(env);
  assert.equal(z.length, 1);
  assert.equal(z[0].version, "1.3");
  assert.equal(z[0].ios, "26.1");
  assert.equal(z[0].geraet, "iPhone17,1");
  assert.deepEqual(JSON.parse(z[0].daten), { start: { anzahl: 2, block_morgen: 1 }, fehler: { absturz: 3, haenger: 1 }, stand: { theme_stahl: 1 } });
  await senden(env, { tag: heute(), ios: "26.0", geraet: "iPad16,3", gruppen: { fehler: { absturz: 1 } } }, { "X-App-Version": "1.4" });
  assert.equal(zeilen(env).length, 2, "je Version, iOS und Gerät eine Zeile");
});

test("Grenzen: zu groß 413, falsche Form 400, unbekannte Arten fallen weg, alte App ohne Gruppen geht", async () => {
  const env = umgebung();
  await registrieren(env);
  assert.equal((await ruf(env, "POST", "/nutzung", { headers: app(), roh: JSON.stringify({ tag: heute(), x: "y".repeat(20000) }) })).status, 413);
  for (const schlecht of [
    { tag: heute(), gruppen: [] }, { tag: heute(), gruppen: { fehler: [] } }, { tag: heute(), gruppen: { fehler: { speichern: 1.5 } } },
    { tag: heute(), gruppen: { fehler: { speichern: -1 } } }, { tag: heute(), gruppen: { fehler: { "Freitext mit Leerzeichen": 1 } } },
    { tag: heute(), gruppen: { fehler: Object.fromEntries(Array.from({ length: 61 }, (_, i) => [`n${i}`, 1])) } },
    { tag: heute(), gruppen: { fehler: { speichern: 10000 } } },
  ]) assert.equal((await senden(env, schlecht)).status, 400, JSON.stringify(schlecht).slice(0, 80));
  assert.equal((await ruf(env, "POST", "/nutzung", { headers: app(), roh: "kein json" })).status, 400);
  assert.equal((await senden(env, { tag: heute(), gruppen: { unbekannteArt: { x: 1 } } })).status, 200);
  assert.equal(zeilen(env).length, 0, "nur unbekannte Gruppen: nichts in nutzung_mehr");
  assert.equal((await senden(env, { tag: heute(), bereiche: { "tab.gym": 1 }, funktionen: {} })).status, 200, "alte App ohne Gruppen");
  assert.equal((await ruf(env, "POST", "/nutzung", { headers: app({ "X-Geheimnis": "x".repeat(48) }), body: { tag: heute() } })).status, 401);
});

test("Aufräumen: alte Tage aller Konten verschwinden mit jeder Meldung, auch von Konten die nie wieder melden", async () => {
  const env = umgebung();
  await registrieren(env);
  env.DB.roh.prepare("INSERT INTO nutzung (konto, tag) VALUES ('anderes', ?)").run(vor(100));
  env.DB.roh.prepare("INSERT INTO nutzung_mehr (konto, tag, daten) VALUES ('anderes', ?, '{}')").run(vor(100));
  env.DB.roh.prepare("INSERT INTO nutzung_mehr (konto, tag, daten) VALUES ('anderes', ?, '{}')").run(vor(10));
  await senden(env, { tag: heute() });
  assert.equal(env.DB.roh.prepare("SELECT COUNT(*) AS n FROM nutzung WHERE konto = 'anderes'").get().n, 0);
  assert.deepEqual(zeilen(env).map((z) => z.tag), [vor(10)]);
});

const mehrZeile = (konto, tag, version, daten, ios = "26.1", geraet = "iPhone17,1") => ({ konto, tag, version, ios, geraet, daten: JSON.stringify(daten) });

test("Fehler: je Version, Anzahl Konten, neu und Einzelfall; Route nur Fehlschläge", () => {
  const z = [
    mehrZeile("k1", vor(0), "1.3", { fehler: { absturz: 2 }, route: { "partner_put.s500": 3 } }),
    mehrZeile("k2", vor(1), "1.3", { fehler: { absturz: 1, speichern: 1 } }),
    mehrZeile("k1", vor(20), "1.2", { fehler: { absturz: 4 } }),
    mehrZeile("k3", vor(50), "1.1", { fehler: { absturz: 9 } }),
  ];
  const r = fehlerAuswerten(z, { tage: 30 });
  assert.equal(r.konten_mit_meldung, 2, "k3 liegt außerhalb des Fensters");
  assert.equal(r.einzelfall, true);
  const a13 = r.fehler.find((e) => e.name === "absturz" && e.version === "1.3");
  assert.deepEqual([a13.anzahl, a13.konten, a13.neu, a13.einzelfall], [3, 2, true, true], "neu = erst in den letzten 3 Tagen aufgetreten, obwohl das Fenster länger zurückreicht");
  assert.equal(r.fehler.find((e) => e.name === "absturz" && e.version === "1.2").neu, false);
  const s = r.fehler.find((e) => e.name === "speichern");
  assert.equal(s.neu, true);
  assert.equal(r.fehler.find((e) => e.name === "absturz" && e.version === "1.2").anzahl, 4);
  assert.equal(r.fehler[0].anzahl, 4, "häufigster zuerst");
  assert.equal(r.server_aufrufe_fehlgeschlagen[0].name, "partner_put.s500");
  assert.deepEqual(a13.ios, { "26.1": 3 });
});

test("Auswertung: erster Griff, Abbrüche, gesehen aber nie getippt; Streichkandidaten erst nach 30 Tagen und mit mehreren Konten", () => {
  const alt = [
    { konto: "k1", tag: vor(1), bereiche: JSON.stringify({ "tab.gym": 5 }), funktionen: JSON.stringify({ training: 2 }) },
    { konto: "k2", tag: vor(2), bereiche: JSON.stringify({ "tab.gym": 1, "tab.essen": 1 }), funktionen: "{}" },
  ];
  const mehr = [
    mehrZeile("k1", vor(1), "1.3", { erster: { "tab.gym": 1, "fn.training": 1 }, start: { anzahl: 2, block_abend: 2 }, dauer: { m1_5: 1 }, weg: { "tab.heute>tab.gym": 2 },
      begonnen: { qr: 3 }, fertig: { qr: 1 }, abbruch: { "qr.wartet": 2 }, gesehen: { profil_konto: 2, profil_ziele: 1 }, getippt: { profil_ziele: 1 },
      stand: { theme_wald: 1 }, ziel: { "training.lt30s": 1 } }),
    mehrZeile("k2", vor(2), "1.3", { erster: { "tab.essen": 1 }, stand: { theme_graphit: 1 } }),
  ];
  const r = auswertungBauen(alt, mehr, { tage: 30 });
  assert.equal(r.erster_griff.tab[0].name, "gym");
  assert.equal(r.erster_griff.funktion[0].name, "training");
  assert.deepEqual(r.abbrueche.qr, { begonnen: 3, fertig: 1, abgebrochen: { wartet: 2 }, abbruchquote: 0.67 });
  assert.deepEqual(r.gesehen_nie_getippt, [{ name: "profil_konto", gesehen: 2, konten_gesehen: 1 }]);
  assert.equal(r.wege[0].name, "tab.heute>tab.gym");
  assert.deepEqual(r.einstellungen_stand, { theme_wald: 1, theme_graphit: 1 });
  assert.equal(r.ziel_zeit_ab_oeffnen.training.lt30s, 1);
  assert.equal(r.einzelfall, true, "2 Konten sind kein Trend");
  assert.equal(r.streichkandidaten.bereit, false);
  assert.match(r.streichkandidaten.grund, /zu früh/);
  assert.deepEqual(r.streichkandidaten.liste, []);
  // Mit 40 Tagen Daten und zwei Konten wird die Liste gefüllt: nur Namen mit Nutzung 0.
  const alt40 = [...alt, { konto: "k1", tag: vor(40), bereiche: "{}", funktionen: "{}" }];
  const r2 = auswertungBauen(alt40, [...mehr, mehrZeile("k1", vor(40), "1.3", {})], { tage: 60 });
  assert.equal(r2.streichkandidaten.bereit, true);
  const namen = r2.streichkandidaten.liste.map((e) => e.name);
  assert.ok(namen.includes("seite.uebung") && namen.includes("habit") && namen.includes("profil_konto"), "profil_konto: gesehen, aber nie getippt, Nutzung 0: Kandidat");
});

test("Zusammenführen: Namen über der Grenze werden nicht mehr aufgenommen", () => {
  const alt = { fehler: Object.fromEntries(Array.from({ length: 60 }, (_, i) => [`n${i}`, 1])) };
  const r = zusammenfuehren(alt, { fehler: { neu: 1, n0: 1 } });
  assert.equal(r.fehler.neu, undefined);
  assert.equal(r.fehler.n0, 2);
});

test("Admin: /admin/fehler und /admin/auswertung brauchen den Admin-Key und liefern die Auswertung", async () => {
  const env = umgebung();
  await registrieren(env);
  await senden(env, { tag: heute(), ios: "26.1", geraet: "iPhone17,1", bereiche: { "tab.gym": 1 }, gruppen: { fehler: { absturz: 1 }, erster: { "tab.gym": 1 } } });
  for (const p of ["/admin/fehler", "/admin/auswertung"]) assert.equal((await ruf(env, "GET", p)).status, 401);
  const f = (await ruf(env, "GET", "/admin/fehler?tage=7", { headers: admin })).json;
  assert.equal(f.fehler[0].name, "absturz");
  assert.equal(f.tage, 7);
  const a = (await ruf(env, "GET", "/admin/auswertung", { headers: admin })).json;
  assert.equal(a.erster_griff.tab[0].name, "gym");
  assert.ok(!JSON.stringify([f, a]).includes(GEHEIM));
});
