// Nutzungsdaten: Prüfung der Meldung der App (nur feste Namen aus nutzung-namen.js, nur Zähler) und die Auswertungen für den MCP.
// Rein und ohne Datenbank, damit es unter Node getestet wird. Nie Freitext, nie Werte, nie Kennungen.
import { NAMEN } from "./nutzung-namen.js";

const produkt = (a, b, mit) => a.flatMap((x) => b.map((y) => `${x}${mit}${y}`));
const ablaeufe = Object.keys(NAMEN.ablauf);
export const ERLAUBT = {
  bereiche: new Set(NAMEN.bereiche),
  funktionen: new Set(NAMEN.funktionen),
  start: new Set(NAMEN.start),
  dauer: new Set(NAMEN.dauer),
  erster: new Set(NAMEN.erster),
  weg: new Set(produkt(NAMEN.weg.von, NAMEN.weg.nach, ">")),
  absprung: new Set(NAMEN.absprung),
  ziel: new Set(produkt(NAMEN.ziel.namen, NAMEN.ziel.bucket, ".")),
  begonnen: new Set(ablaeufe),
  fertig: new Set(ablaeufe),
  abbruch: new Set(ablaeufe.flatMap((a) => NAMEN.ablauf[a].map((s) => `${a}.${s}`))),
  gesehen: new Set(NAMEN.eintraege),
  getippt: new Set(NAMEN.eintraege),
  stand: new Set(NAMEN.stand),
  fehler: new Set(NAMEN.fehler),
  route: new Set(produkt(NAMEN.route.namen, NAMEN.route.status, ".")),
  tempo: new Set(produkt(NAMEN.tempo.namen, NAMEN.tempo.bucket, ".")),
};
// Gruppen, die neben `bereiche` und `funktionen` in nutzung_mehr liegen.
export const MEHR_ARTEN = Object.keys(ERLAUBT).filter((a) => a !== "bereiche" && a !== "funktionen");
const MAX_JE_ART = { route: 160, weg: 120, tempo: 80 };
export const maxNamen = (art) => MAX_JE_ART[art] ?? 60;
const ROH_FORM = /^[a-z][A-Za-z0-9_.>]{0,89}$/;
export const IOS_FORM = /^\d{1,2}(\.\d{1,2}){0,2}$/;
export const GERAET_FORM = /^(iPhone|iPad)\d{1,2},\d{1,2}$/;

const istObjekt = (x) => x !== null && typeof x === "object" && !Array.isArray(x);

// Zähler { name: Anzahl } einer Art prüfen. null bei falscher Form (Typ, Größe, Namensform): die ganze Meldung ist ungültig.
// Gut geformte, aber unbekannte Namen (ältere oder neuere App, falsche Einträge) fliegen einzeln raus, ohne Fehler.
export function zaehlerPruefen(art, x) {
  if (x === undefined) return {};
  if (!istObjekt(x) || Object.keys(x).length > maxNamen(art)) return null;
  const aus = {};
  for (const [k, v] of Object.entries(x)) {
    if (!ROH_FORM.test(k) || !Number.isInteger(v) || v < 0 || v > 9999) return null;
    if (ERLAUBT[art].has(k)) aus[k] = v;
  }
  return aus;
}

// Die Gruppen { art: { name: Anzahl } }: unbekannte Arten fliegen raus, null bei falscher Form.
export function gruppenPruefen(x) {
  if (x === undefined) return {};
  if (!istObjekt(x) || Object.keys(x).length > 40) return null;
  const aus = {};
  for (const [art, namen] of Object.entries(x)) {
    if (!MEHR_ARTEN.includes(art)) continue;
    const z = zaehlerPruefen(art, namen);
    if (!z) return null;
    if (Object.keys(z).length) aus[art] = z;
  }
  return aus;
}

const summe = (a, b, grenze) => {
  const o = { ...a };
  for (const [k, v] of Object.entries(b)) if (k in o || Object.keys(o).length < grenze) o[k] = Math.min(9999, (o[k] ?? 0) + v);
  return o;
};
// Zählt neue Gruppen zu den gespeicherten. "stand" ist ein Zustand, kein Zähler: der letzte Stand ersetzt den alten.
export function zusammenfuehren(alt, neu) {
  const aus = {};
  for (const art of new Set([...Object.keys(alt), ...Object.keys(neu)])) {
    aus[art] = art === "stand" && neu.stand ? neu.stand : summe(alt[art] ?? {}, neu[art] ?? {}, maxNamen(art));
  }
  return aus;
}

// --- Auswertung ---
const lesen = (t) => { try { return JSON.parse(t) ?? {}; } catch { return {}; } };
const tagVor = (jetzt, n) => new Date(jetzt - n * 864e5).toISOString().slice(0, 10);
export const EINZELFALL_UNTER = 5;
const fenster = (tage) => Math.max(1, Math.min(90, Number(tage) || 30));

// Neue und häufigste Fehler je Version: Anzahl, Anzahl Konten, erster und letzter Tag, iOS und Gerätetyp. Route-Zähler sind nur Fehlschläge.
export function fehlerAuswerten(mehr, { jetzt = Date.now(), tage = 30 } = {}) {
  tage = fenster(tage);
  const ab = tagVor(jetzt, tage - 1), neuAb = tagVor(jetzt, 2);
  const karte = new Map(), konten = new Set();
  for (const z of mehr) {
    if (z.tag < ab) continue;
    konten.add(z.konto);
    const d = lesen(z.daten);
    for (const art of ["fehler", "route"]) {
      for (const [name, n] of Object.entries(d[art] ?? {})) {
        const k = `${art}|${name}|${z.version}`;
        const e = karte.get(k) ?? { art, name, version: z.version, anzahl: 0, konten: new Set(), erster_tag: z.tag, letzter_tag: z.tag, ios: {}, geraet: {} };
        e.anzahl += n;
        e.konten.add(z.konto);
        if (z.tag < e.erster_tag) e.erster_tag = z.tag;
        if (z.tag > e.letzter_tag) e.letzter_tag = z.tag;
        if (z.ios) e.ios[z.ios] = (e.ios[z.ios] ?? 0) + n;
        if (z.geraet) e.geraet[z.geraet] = (e.geraet[z.geraet] ?? 0) + n;
        karte.set(k, e);
      }
    }
  }
  // "neu": der Fehler tritt in dieser Version erst in den letzten 3 Tagen auf, obwohl das Fenster länger zurückreicht.
  const liste = [...karte.values()].map((e) => ({
    ...e, konten: e.konten.size, neu: e.erster_tag >= neuAb && ab < neuAb, einzelfall: e.konten.size < EINZELFALL_UNTER,
  })).sort((a, b) => b.anzahl - a.anzahl);
  return {
    tage, konten_mit_meldung: konten.size, einzelfall: konten.size < EINZELFALL_UNTER,
    hinweis: "Nur Konten, die der Nutzungsmeldung zugestimmt haben. Unter 5 Konten sind es Einzelfälle, kein Trend.",
    fehler: liste.filter((e) => e.art === "fehler"),
    server_aufrufe_fehlgeschlagen: liste.filter((e) => e.art === "route"),
  };
}

const oben = (o, n = 10) => Object.entries(o).sort((a, b) => b[1] - a[1]).slice(0, n).map(([name, anzahl]) => ({ name, anzahl }));
const addiere = (o, k, n) => { o[k] = (o[k] ?? 0) + n; };

// Erster Griff am Tag, Top und Flop, Wege, Abbruchstellen, Streichkandidaten. `alt`: Zeilen aus `nutzung` (bereiche, funktionen), `mehr`: aus `nutzung_mehr`.
export function auswertungBauen(alt, mehr, { jetzt = Date.now(), tage = 30 } = {}) {
  tage = fenster(tage);
  const ab = tagVor(jetzt, tage - 1);
  const im = (z) => z.tag >= ab;
  const bereiche = {}, funktionen = {}, bereichKonten = {}, funktionKonten = {};
  const kontenAlt = new Set();
  const ersteTage = [];
  for (const z of alt) {
    ersteTage.push(z.tag);
    if (!im(z)) continue;
    kontenAlt.add(z.konto);
    for (const [k, v] of Object.entries(lesen(z.bereiche))) { addiere(bereiche, k, v); (bereichKonten[k] ??= new Set()).add(z.konto); }
    for (const [k, v] of Object.entries(lesen(z.funktionen))) { addiere(funktionen, k, v); (funktionKonten[k] ??= new Set()).add(z.konto); }
  }
  const arten = Object.fromEntries(MEHR_ARTEN.map((a) => [a, {}]));
  const artKonten = Object.fromEntries(MEHR_ARTEN.map((a) => [a, {}]));
  const kontenMehr = new Set();
  const letzterStand = new Map();
  for (const z of mehr) {
    ersteTage.push(z.tag);
    if (!im(z)) continue;
    kontenMehr.add(z.konto);
    const d = lesen(z.daten);
    for (const a of MEHR_ARTEN) for (const [k, v] of Object.entries(d[a] ?? {})) { addiere(arten[a], k, v); (artKonten[a][k] ??= new Set()).add(z.konto); }
    if (d.stand && (!letzterStand.has(z.konto) || letzterStand.get(z.konto).tag <= z.tag)) letzterStand.set(z.konto, { tag: z.tag, stand: d.stand });
  }
  const datenSeit = ersteTage.sort()[0] ?? null;
  const datenTage = datenSeit ? Math.floor((Date.parse(tagVor(jetzt, 0)) - Date.parse(datenSeit)) / 864e5) + 1 : 0;
  const konten = Math.max(kontenAlt.size, kontenMehr.size);

  const ersterTab = {}, ersteFunktion = {};
  for (const [k, v] of Object.entries(arten.erster)) (k.startsWith("tab.") ? ersterTab : ersteFunktion)[k.slice(k.indexOf(".") + 1)] = v;
  const stand = {};
  for (const { stand: s } of letzterStand.values()) for (const k of Object.keys(s)) addiere(stand, k, 1);

  const ablauf = {};
  for (const a of ablaeufe) {
    const abbruch = {};
    for (const [k, v] of Object.entries(arten.abbruch)) if (k.startsWith(`${a}.`)) abbruch[k.slice(a.length + 1)] = v;
    const begonnen = arten.begonnen[a] ?? 0, fertig = arten.fertig[a] ?? 0;
    ablauf[a] = { begonnen, fertig, abgebrochen: abbruch, abbruchquote: begonnen ? Math.round((1 - Math.min(fertig, begonnen) / begonnen) * 100) / 100 : null };
  }
  const ziel = {};
  for (const [k, v] of Object.entries(arten.ziel)) { const [fn, b] = k.split("."); (ziel[fn] ??= {})[b] = v; }

  const alle = [
    ...NAMEN.bereiche.map((n) => ({ name: n, art: "bereich", anzahl: bereiche[n] ?? 0, konten: bereichKonten[n]?.size ?? 0 })),
    ...NAMEN.funktionen.map((n) => ({ name: n, art: "funktion", anzahl: funktionen[n] ?? 0, konten: funktionKonten[n]?.size ?? 0 })),
    ...NAMEN.eintraege.map((n) => ({ name: n, art: "eintrag", anzahl: arten.getippt[n] ?? 0, konten: artKonten.getippt[n]?.size ?? 0 })),
  ];
  const nurAlt = alle.filter((e) => e.art !== "eintrag");
  const gesehenNieGetippt = NAMEN.eintraege
    .filter((n) => (arten.gesehen[n] ?? 0) > 0 && !(arten.getippt[n] > 0))
    .map((n) => ({ name: n, gesehen: arten.gesehen[n], konten_gesehen: artKonten.gesehen[n].size }));
  const bereit = datenTage >= 30 && Math.min(kontenAlt.size, kontenMehr.size) >= 2;
  const streich = !bereit ? [] : [
    ...nurAlt.filter((e) => e.anzahl === 0),
    ...alle.filter((e) => e.art === "eintrag" && e.anzahl === 0),
  ].map(({ name, art }) => ({ name, art }));
  return {
    tage, konten_mit_meldung: konten, konten_mit_neuen_messpunkten: kontenMehr.size,
    einzelfall: konten < EINZELFALL_UNTER,
    hinweis: "Nur Konten, die der Nutzungsmeldung zugestimmt haben. Unter 5 Konten sind es Einzelfälle, kein Trend.",
    daten_seit: datenSeit, daten_tage: datenTage,
    erster_griff: { tab: oben(ersterTab, 5), funktion: oben(ersteFunktion, 6) },
    tageszeit_der_starts: Object.fromEntries(Object.entries(arten.start).filter(([k]) => k.startsWith("block_"))),
    starts: arten.start.anzahl ?? 0,
    sitzungsdauer: arten.dauer,
    top: oben(Object.fromEntries(nurAlt.map((e) => [e.name, e.anzahl])), 8).filter((e) => e.anzahl > 0),
    flop: nurAlt.slice().sort((a, b) => a.anzahl - b.anzahl).slice(0, 8).map(({ name, anzahl, konten: k }) => ({ name, anzahl, konten: k })),
    wege: oben(arten.weg, 10),
    absprung: oben(arten.absprung, 8),
    ziel_zeit_ab_oeffnen: ziel,
    abbrueche: ablauf,
    gesehen_nie_getippt: gesehenNieGetippt,
    einstellungen_stand: stand,
    tempo: arten.tempo,
    streichkandidaten: {
      bereit,
      grund: bereit ? "Nutzung 0 im ganzen Fenster, mindestens 30 Tage Daten, mehrere Konten." : `Noch zu früh: ${datenTage} Tage Daten (nötig 30) und ${Math.min(kontenAlt.size, kontenMehr.size)} Konten mit Meldung (nötig 2).`,
      einzelfall: konten < EINZELFALL_UNTER,
      liste: streich,
    },
  };
}
