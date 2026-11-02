#!/usr/bin/env node
// Vergleicht den Import-Beleg eines Kontos (nur Zahlen, `GET /admin/import-beleg` bzw. MCP `lumenfit_import_beleg`) mit der echten Zählung je Op-Art aus Lovea.
// Liest zwei JSON-Dateien, keine Schlüssel, kein Netz:
//   node scripts/import-vergleich.mjs BELEG.json LOVEA.json [--konto ID]
//   node scripts/import-vergleich.mjs --selbsttest
// BELEG.json: der Beleg selbst, {"beleg": ...} oder die Admin-Antwort {"konten": [...]} (dann --konto ID, bei genau einem Konto ohne).
// LOVEA.json: {"arten": {"schritte.setzen": 1234, ...}, "gruppen": {"abgabe.lovea.gym.studioprofil": 1, ...}, "seqMax": 11698} (Anzahl Ops je Art der Person, gezählt bis seq <= seqMax des Belegs)
//   oder nur die Karte {art: Anzahl}. `gruppen` zählt dieselben Ops nach den Gruppen des Belegs (`uebernahme`, siehe `gruppeVon`); fehlt es, bleibt die Abgabe ungeprüft (Hinweis).
//   Die Zählung macht `node scripts/import-vergleich.mjs --zaehle OPS.json [--bis SEQ]` aus einer Liste [{seq, art, d}] (Ops der Person aus Lovea).
// Exit 0 nur, wenn für alle Health-Arten alles stimmt; sonst 1 (Abweichung), 2 (Eingabe unbrauchbar).
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { resolve } from "node:path";
import assert from "node:assert/strict";

// Gleiche Menge wie ProfilLoveaArten.uebernehmen + rohBehalten (Swift). Bei einer Änderung dort hier nachziehen.
export const HEALTH_ARTEN = [
  "gym.plan", "gym.checkin", "gym.uebung", "gym.checkout", "gym.loeschen", "cardio.setzen", "cardio.loeschen",
  "essen.setzen", "lebensmittel.setzen", "lebensmittel.favorit", "rezept.setzen", "fasten.setzen", "fasten.eintrag", "fasten.plan",
  "koerper.setzen", "food.anpassung", "habit.setzen", "habit.anlegen", "habit.aendern", "habit.ausblenden", "habit.loeschen",
  "schritte.setzen", "schlaf.setzen", "schlaf.zeiten", "stimmung.setzen",
  "coach.nachricht", "wecker.setzen", "einkauf.liste", "kuehl.setzen", "kuehl.weg",
];

// Arten, die im Beleg als Gruppe (`uebernahme`) mit eigener Zählung stehen, nicht nur als Art. Gleich wie ProfilLoveaUebernahme.opArten (Swift); der Test prüft das.
export const OP_ARTEN = ["coach.nachricht", "wecker.setzen", "einkauf.liste", "kuehl.setzen", "kuehl.weg"];

const GUELTIGE_ART = /^[a-z][A-Za-z0-9_.]{0,59}$/;

/** Gruppe einer Op im Beleg (`uebernahme`), gleiche Regel wie ProfilLoveaUebernahme.einordnen; null = keine Gruppe. */
export function gruppeVon(art, schluessel) {
  if (OP_ARTEN.includes(art)) return art;
  if (art !== "einstellung.setzen" || typeof schluessel !== "string") return null;
  if (schluessel.startsWith("abgabe.tagesform.gefuehl.")) return "abgabe.tagesform.gefuehl";
  if (schluessel.startsWith("abgabe.")) return GUELTIGE_ART.test(schluessel) ? schluessel : "abgabe.andere";
  if (schluessel.startsWith("coach.")) return "einstellung.coach";
  return null;
}

/** Zählt Ops [{seq, art, d}] nach Art und Gruppe, höchstens bis `bis` (seq). */
export function zaehle(ops, bis = Infinity) {
  const arten = {};
  const gruppen = {};
  let seqMax = 0;
  for (const op of ops) {
    if (!(op.seq <= bis)) continue;
    seqMax = Math.max(seqMax, op.seq);
    arten[op.art] = (arten[op.art] ?? 0) + 1;
    const g = gruppeVon(op.art, op.d?.schluessel);
    if (g && !OP_ARTEN.includes(g)) gruppen[g] = (gruppen[g] ?? 0) + 1;
  }
  return { arten, gruppen, seqMax };
}

const n = (x) => (Number.isInteger(x) ? x : 0);

/** Liefert { ok, zeilen[], probleme[] }. `beleg` ist der Beleg, `lovea` die Zählung. */
export function vergleiche(beleg, lovea) {
  const probleme = [];
  const zeilen = [];
  if (!beleg || typeof beleg !== "object" || beleg.typ !== "beleg" || typeof beleg.arten !== "object") return { ok: false, zeilen, probleme: ["Beleg unbrauchbar (typ beleg mit arten erwartet)"] };
  const zaehlung = lovea?.arten ?? lovea;
  if (!zaehlung || typeof zaehlung !== "object" || Array.isArray(zaehlung)) return { ok: false, zeilen, probleme: ["Lovea-Zählung unbrauchbar ({art: Anzahl} erwartet)"] };
  if (lovea?.arten && lovea.seqMax !== undefined && lovea.seqMax !== beleg.seqMax) {
    probleme.push(`Zählung bis seq ${lovea.seqMax}, Beleg bis seq ${beleg.seqMax}: nicht vergleichbar (Lovea bis seq <= ${beleg.seqMax} zählen)`);
  }
  if (!lovea?.arten) zeilen.push(`Hinweis: keine seqMax in der Zählung, sie muss bis seq <= ${beleg.seqMax} gezählt sein`);
  if (beleg.unlesbar > 0) probleme.push(`${beleg.unlesbar} unlesbare Einträge beim Holen (ohne Kennung, Art, seq oder Zeit)`);
  if (beleg.vollstaendig !== true) probleme.push("Beleg selbst sagt: nicht vollständig");
  const health = new Set(HEALTH_ARTEN);
  for (const art of [...new Set([...Object.keys(zaehlung), ...Object.keys(beleg.arten)])].sort()) {
    const l = n(zaehlung[art]);
    const b = beleg.arten[art];
    const ist = health.has(art) || (b && n(b.uebernommen) + n(b.roh) > 0);
    const fehler = [];
    if (!b) {
      if (l > 0) fehler.push(`Lovea ${l}, im Beleg nicht vorhanden`);
    } else {
      if (n(b.geholt) !== l) fehler.push(`geholt ${n(b.geholt)} statt ${l} (Lovea)`);
      const verteilt = n(b.uebernommen) + n(b.roh) + n(b.ausgeschlossen) + n(b.unbekannt);
      if (verteilt !== n(b.geholt)) fehler.push(`geholt ${n(b.geholt)}, aber nur ${verteilt} eingeordnet`);
      if (n(b.unbekannt) > 0) fehler.push(`${b.unbekannt} unbekannt`);
      const uebernommen = n(b.uebernommen) + n(b.roh);
      if (health.has(art) && uebernommen === 0 && l > 0 && art !== "einstellung.setzen") fehler.push(`Health-Art, aber ${n(b.ausgeschlossen)} ausgeschlossen, 0 übernommen`);
      if (n(b.zeitKaputt) > 0) fehler.push(`${b.zeitKaputt} mit unlesbarer Zeit verloren`);
      if (n(b.geplant) !== uebernommen - n(b.zeitKaputt)) fehler.push(`geplant ${n(b.geplant)} statt ${uebernommen - n(b.zeitKaputt)}`);
      if (n(b.wiedergefunden) + n(b.uebersprungen) !== n(b.geplant)) fehler.push(`lokal wiedergefunden ${n(b.wiedergefunden)} (+${n(b.uebersprungen)} bewusst älter) von ${n(b.geplant)}`);
    }
    const marke = fehler.length ? "FEHLER" : "ok    ";
    const rest = b ? `geholt ${n(b.geholt)} · übernommen ${n(b.uebernommen)} · roh ${n(b.roh)} · ausgeschlossen ${n(b.ausgeschlossen)}${b.grund ? ` (${b.grund})` : ""} · wiedergefunden ${n(b.wiedergefunden)}` : "-";
    zeilen.push(`${marke} ${ist ? "H" : " "} ${art.padEnd(24)} Lovea ${String(l).padStart(6)} | ${rest}${fehler.length ? "  <- " + fehler.join("; ") : ""}`);
    if (fehler.length && (ist || b?.unbekannt > 0 || !b || n(b.geholt) !== l)) probleme.push(`${art}: ${fehler.join("; ")}`);
  }
  uebernahmePruefen(beleg, lovea, zaehlung, zeilen, probleme);
  return { ok: probleme.length === 0, zeilen, probleme };
}

/** Gruppen ohne eigene Art: jede Einheit sichtbar oder bewusst roh, Zahlen stimmen mit Lovea überein, nichts unlesbar. */
function uebernahmePruefen(beleg, lovea, zaehlung, zeilen, probleme) {
  const u = beleg.uebernahme;
  if (u !== undefined && (typeof u !== "object" || u === null || Array.isArray(u))) { probleme.push("Beleg: uebernahme unbrauchbar"); return; }
  const ist = u ?? {};
  const soll = { ...(lovea?.gruppen ?? {}) };
  for (const art of OP_ARTEN) if (n(zaehlung[art]) > 0) soll[art] = n(zaehlung[art]);
  if (!lovea?.gruppen) zeilen.push("Hinweis: keine gruppen in der Zählung, die Abgabe (abgabe.*, einstellung.coach) bleibt ungeprüft (Zählung mit --zaehle machen)");
  for (const g of [...new Set([...Object.keys(ist), ...Object.keys(soll)])].sort()) {
    const b = ist[g];
    const l = n(soll[g]);
    const fehler = [];
    if (!b) {
      if (l > 0) fehler.push(`Lovea ${l}, im Beleg nicht vorhanden`);
    } else {
      const einheiten = n(b.uebernommen) + n(b.vorhanden) + n(b.roh) + n(b.unlesbar);
      if (lovea?.gruppen || OP_ARTEN.includes(g)) { if (n(b.geholt) !== l) fehler.push(`geholt ${n(b.geholt)} statt ${l} (Lovea)`); }
      if (n(b.geholt) !== n(b.aelter) + einheiten) fehler.push(`geholt ${n(b.geholt)}, aber ${n(b.aelter)} ältere + ${einheiten} Einheiten`);
      if (n(b.unlesbar) > 0) fehler.push(`${b.unlesbar} unlesbar oder nicht geschrieben`);
      if (n(b.geschrieben) > n(b.eintraege)) fehler.push(`geschrieben ${n(b.geschrieben)} > Einträge ${n(b.eintraege)}`);
    }
    const marke = fehler.length ? "FEHLER" : "ok    ";
    const rest = b ? `geholt ${n(b.geholt)} · sichtbar ${n(b.uebernommen)} · schon da ${n(b.vorhanden)} · nur im Log ${n(b.roh)} · Einträge ${n(b.geschrieben)}/${n(b.eintraege)}` : "-";
    zeilen.push(`${marke} G ${g.padEnd(32)} Lovea ${String(l).padStart(6)} | ${rest}${fehler.length ? "  <- " + fehler.join("; ") : ""}`);
    if (fehler.length) probleme.push(`${g}: ${fehler.join("; ")}`);
  }
}

function belegAus(roh, kontoId) {
  if (roh?.typ === "beleg") return roh;
  if (roh?.beleg) return roh.beleg;
  if (Array.isArray(roh?.konten)) {
    const k = kontoId ? roh.konten.find((x) => x.id === kontoId) : roh.konten.length === 1 ? roh.konten[0] : null;
    if (!k) throw new Error("mehrere Konten in der Datei: --konto ID angeben");
    if (!k.beleg) throw new Error("dieses Konto hat noch keinen Beleg");
    return k.beleg;
  }
  return roh;
}

export function selbsttest() {
  const gut = {
    typ: "beleg", vollstaendig: true, seqMax: 50, unlesbar: 0,
    arten: {
      "habit.setzen": { geholt: 4, uebernommen: 4, geplant: 4, wiedergefunden: 4 },
      "nachricht.neu": { geholt: 6, ausgeschlossen: 6, grund: "Chat" },
      "einstellung.setzen": { geholt: 5, uebernommen: 2, ausgeschlossen: 3, geplant: 2, wiedergefunden: 2 },
    },
  };
  const zahl = { arten: { "habit.setzen": 4, "nachricht.neu": 6, "einstellung.setzen": 5 }, seqMax: 50 };
  assert.equal(vergleiche(gut, zahl).ok, true, "volle Übereinstimmung");
  assert.equal(vergleiche(gut, { "habit.setzen": 4, "nachricht.neu": 6, "einstellung.setzen": 5 }).ok, true, "Zählung ohne seqMax");
  const kopie = (f) => { const k = structuredClone(gut); f(k); return k; };
  assert.equal(vergleiche(gut, { ...zahl, arten: { ...zahl.arten, "habit.setzen": 5 } }).ok, false, "Lovea hat mehr");
  assert.equal(vergleiche(gut, { ...zahl, arten: { ...zahl.arten, "schlaf.setzen": 2 } }).ok, false, "Art fehlt im Beleg");
  assert.equal(vergleiche(kopie((k) => { k.arten["habit.setzen"].wiedergefunden = 3; }), zahl).ok, false, "lokal weniger gefunden");
  assert.equal(vergleiche(kopie((k) => { k.arten["nachricht.neu"].unbekannt = 1; k.arten["nachricht.neu"].ausgeschlossen = 5; }), zahl).ok, false, "unbekannt");
  assert.equal(vergleiche(kopie((k) => { k.arten["habit.setzen"].zeitKaputt = 1; k.arten["habit.setzen"].geplant = 3; k.arten["habit.setzen"].wiedergefunden = 3; }), zahl).ok, false, "Zeit kaputt");
  assert.equal(vergleiche(kopie((k) => { k.unlesbar = 1; }), zahl).ok, false, "unlesbar");
  assert.equal(vergleiche(kopie((k) => { k.vollstaendig = false; }), zahl).ok, false, "Beleg unvollständig");
  assert.equal(vergleiche(gut, { ...zahl, seqMax: 60 }).ok, false, "andere seq");
  const zuAusgeschlossen = kopie((k) => { k.arten["schlaf.setzen"] = { geholt: 2, ausgeschlossen: 2 }; });
  assert.equal(vergleiche(zuAusgeschlossen, { ...zahl, arten: { ...zahl.arten, "schlaf.setzen": 2 } }).ok, false, "Health-Art nicht übernommen");
  assert.equal(vergleiche({}, zahl).ok, false);
  // Gruppen: Abgabe aus Lovea
  const grp = { geholt: 3, aelter: 2, uebernommen: 1, vorhanden: 0, roh: 0, unlesbar: 0, eintraege: 4, geschrieben: 4 };
  const mitGruppe = kopie((k) => { k.arten["wecker.setzen"] = { geholt: 2, roh: 2, geplant: 2, wiedergefunden: 2 }; k.uebernahme = { "abgabe.lovea.gym.studioprofil": grp, "wecker.setzen": { geholt: 2, roh: 2, eintraege: 2 } }; });
  const zahlG = { arten: { ...zahl.arten, "wecker.setzen": 2 }, gruppen: { "abgabe.lovea.gym.studioprofil": 3 }, seqMax: 50 };
  assert.equal(vergleiche(mitGruppe, zahlG).ok, true, "Gruppen gleich");
  assert.equal(vergleiche(mitGruppe, { ...zahlG, gruppen: { "abgabe.lovea.gym.studioprofil": 4 } }).ok, false, "Lovea hat mehr Abgabe-Ops");
  assert.equal(vergleiche(mitGruppe, { ...zahlG, gruppen: { ...zahlG.gruppen, "abgabe.lovea.wecker.v1": 1 } }).ok, false, "Gruppe fehlt im Beleg");
  assert.equal(vergleiche(mitGruppe, { ...zahlG, arten: { ...zahl.arten, "wecker.setzen": 3 } }).ok, false, "Wecker-Ops: Lovea hat mehr");
  assert.equal(vergleiche(kopie((k) => { k.uebernahme = { "abgabe.x": { ...grp, unlesbar: 1, uebernommen: 0 } }; }), { ...zahl, gruppen: { "abgabe.x": 3 } }).ok, false, "unlesbar");
  assert.equal(vergleiche(kopie((k) => { k.uebernahme = { "abgabe.x": { ...grp, aelter: 0 } }; }), { ...zahl, gruppen: { "abgabe.x": 3 } }).ok, false, "Einheiten passen nicht zu geholt");
  assert.equal(vergleiche(mitGruppe, { arten: zahlG.arten, seqMax: 50 }).ok, true, "ohne gruppen: Hinweis, kein Fehler");
  // Zählung
  const z = zaehle([
    { seq: 1, art: "einstellung.setzen", d: { schluessel: "abgabe.tagesform.gefuehl.2026-10-01" } },
    { seq: 2, art: "einstellung.setzen", d: { schluessel: "abgabe.tagesform.gefuehl.2026-10-02" } },
    { seq: 3, art: "einstellung.setzen", d: { schluessel: "coach.ton" } },
    { seq: 4, art: "einstellung.setzen", d: { schluessel: "ziel.schritte" } },
    { seq: 5, art: "wecker.setzen", d: {} },
    { seq: 99, art: "wecker.setzen", d: {} },
  ], 50);
  assert.deepEqual(z.gruppen, { "abgabe.tagesform.gefuehl": 2, "einstellung.coach": 1 });
  assert.equal(z.arten["wecker.setzen"], 1, "seq über der Grenze zählt nicht");
  assert.equal(z.arten["einstellung.setzen"], 4);
  assert.equal(z.seqMax, 5);
  assert.equal(gruppeVon("einstellung.setzen", "abgabe." + "x".repeat(70)), "abgabe.andere");
  assert.equal(gruppeVon("einstellung.setzen", "ziel.x"), null);
  assert.equal(belegAus({ konten: [{ id: "a", beleg: gut }] }).seqMax, 50);
  console.log("Selbsttest ok");
}

if (process.argv[1] && fileURLToPath(import.meta.url) === resolve(process.argv[1])) {
  const args = process.argv.slice(2);
  if (args.includes("--selbsttest")) { selbsttest(); process.exit(0); }
  if (args[0] === "--zaehle") {
    const bi = args.indexOf("--bis");
    const bis = bi >= 0 ? Number(args[bi + 1]) : Infinity;
    if (!args[1] || Number.isNaN(bis)) { console.error("Aufruf: import-vergleich.mjs --zaehle OPS.json [--bis SEQ]"); process.exit(2); }
    try { console.log(JSON.stringify(zaehle(JSON.parse(readFileSync(args[1], "utf8")), bis))); process.exit(0); }
    catch (e) { console.error("Eingabe unbrauchbar:", e.message); process.exit(2); }
  }
  const i = args.indexOf("--konto");
  const kontoId = i >= 0 ? args.splice(i, 2)[1] : undefined;
  if (args.length !== 2) { console.error("Aufruf: import-vergleich.mjs BELEG.json LOVEA.json [--konto ID] | --selbsttest"); process.exit(2); }
  let r;
  try {
    const beleg = belegAus(JSON.parse(readFileSync(args[0], "utf8")), kontoId);
    r = vergleiche(beleg, JSON.parse(readFileSync(args[1], "utf8")));
  } catch (e) {
    console.error("Eingabe unbrauchbar:", e.message);
    process.exit(2);
  }
  console.log(r.zeilen.join("\n"));
  if (r.ok) { console.log("\nALLES GLEICH: jede Op-Art stimmt, lokal wiedergefunden."); process.exit(0); }
  console.log("\nABWEICHUNGEN:\n- " + r.probleme.join("\n- "));
  process.exit(1);
}
