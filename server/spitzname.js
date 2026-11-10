// Spitznamen für Stats "Alle": Form, Schimpfwörter (auch mit Leetspeak, Umlauten, Abständen, Wiederholungen) und reservierte Namen.
// Antwort { ok: true, name, norm } oder { ok: false, grund } mit grund laenge | zeichen | buchstaben | unpassend; die App zeigt dazu ihren eigenen Text.
// norm ist die Vergleichsform für "schon vergeben" (Groß/Klein, Akzente, Leetspeak und Trennzeichen egal).

// Nur lateinische Schrift: keine Doppelgänger-Buchstaben aus anderen Schriften ("Нitler" mit kyrillischem Н).
const ZEICHEN = /^[\p{Script=Latin}0-9 ._-]+$/u;
const LINK = /https?|www|\.(com|de|net|org|io|app|me|tv|gg|ly|to|info|eu|at|ch)(\W|$)/;
// Teilwörter: verboten auch mitten im Namen. Jede Folge gleicher Buchstaben darf sich verlängern ("Huuurensohn"), nicht verkürzen.
const TEIL = [
  "hurensohn", "hurenkind", "hurenbock", "wichser", "wixer", "fotze", "schlampe", "missgeburt", "arschloch", "arschgeige", "arschkriecher",
  "drecksau", "scheisse", "kackbratze", "spast", "mongoloid", "behindert", "schwuchtel", "kanake", "kanacke", "nigger", "nigga", "hitler", "siegheil",
  "holocaust", "auschwitz", "fick", "fuck", "porn", "pimmel", "schwanz", "penis", "vagina", "muschi", "titten", "blowjob", "dildo", "bitch", "whore",
  "slut", "faggot", "retard", "vergewaltig", "paedophil", "pedophil", "orospu", "siktir", "aminakoyim", "koyim", "sharmut", "scharmut", "kahbe", "yarak",
  "kurwa", "blyat", "bljad", "pizda", "pisser", "lumenfit",
];
// Ganze Wörter: kurz oder in harmlosen Wörtern enthalten ("Klassiker", "Kanal", "Schwarzenegger", "Nazim"): nur als eigenes Wort.
const GANZ = [
  "ass", "arsch", "sex", "anal", "cock", "dick", "cunt", "fag", "rape", "pedo", "nazi", "nazis", "neger", "nutte", "hure", "mongo", "amk", "isis",
  "suka", "kahba", "fuk", "tits", "piss", "nsdap", "ss", "kkk", "acab",
  "admin", "administrator", "moderator", "mod", "support", "team", "lumen", "lumi", "apple", "system", "offiziell", "official", "staff", "service", "hilfe", "help", "root",
];
// Zahlen-Codes der rechten Szene, nur als ganze Ziffernfolge ("Max1988" geht).
const CODES = ["88", "1488", "8814", "4188"];

const lauf = (w) => w.replace(/(.)\1*/g, (folge, b) => `${b}{${folge.length},}`);
const TEIL_MUSTER = TEIL.map((w) => new RegExp(lauf(w)));
const GANZ_MUSTER = GANZ.map((w) => new RegExp(`^${lauf(w)}$`));

const ERSATZ = { ı: "i", ł: "l", ø: "o", đ: "d", ð: "d", ħ: "h", ŧ: "t", ſ: "s", æ: "ae", œ: "oe", ɑ: "a", ɡ: "g", þ: "th" };
const LEET = { 0: "o", 3: "e", 4: "a", 5: "s", 7: "t", 8: "b", 9: "g", 6: "g", 2: "z" };
const ohneAkzent = (s) => s.normalize("NFKD").replace(/\p{M}/gu, "").replace(/[ıłøđðħŧſæœɑɡþ]/g, (c) => ERSATZ[c]);
// Lesarten eines Teils: Umlaute als ae/oe/ue/ss oder ohne Punkte, die 1 als i oder l.
function lesarten(teil) {
  const klein = teil.toLowerCase();
  const basen = [ohneAkzent(klein.replace(/ä/g, "ae").replace(/ö/g, "oe").replace(/ü/g, "ue").replace(/ß/g, "ss")), ohneAkzent(klein)];
  return [...new Set(basen.flatMap((b) => ["i", "l"].map((eins) => b.replace(/[0-9]/g, (z) => (z === "1" ? eins : LEET[z] ?? z)))))];
}
// Wörter: an Leerzeichen, Punkt, Strichen und an Binnenmajuskeln ("BigAss").
const woerter = (name) => name.split(/[ ._-]+|(?<=\p{Ll})(?=\p{Lu})/u).filter(Boolean);

function unpassend(name) {
  if (LINK.test(name.toLowerCase())) return true;
  if ((name.match(/[0-9]+/g) ?? []).some((z) => CODES.includes(z))) return true;
  const ganzes = lesarten(name.replace(/[ ._-]/g, ""));
  if (ganzes.some((l) => TEIL_MUSTER.some((m) => m.test(l)) || GANZ_MUSTER.some((m) => m.test(l)))) return true;
  return woerter(name).some((w) => lesarten(w).some((l) => GANZ_MUSTER.some((m) => m.test(l)) || TEIL_MUSTER.some((m) => m.test(l))));
}

export function spitznamePruefen(roh) {
  const name = typeof roh === "string" ? roh.normalize("NFC").trim().replace(/ {2,}/g, " ") : "";
  if ([...name].length < 3 || [...name].length > 20) return { ok: false, grund: "laenge" };
  if (!ZEICHEN.test(name)) return { ok: false, grund: "zeichen" };
  if ((name.match(/\p{L}/gu) ?? []).length < 2) return { ok: false, grund: "buchstaben" };
  if (unpassend(name)) return { ok: false, grund: "unpassend" };
  const norm = ohneAkzent(name.toLowerCase()).replace(/[ ._-]/g, "").replace(/[0-9]/g, (z) => (z === "1" ? "i" : LEET[z] ?? z));
  return { ok: true, name, norm };
}
