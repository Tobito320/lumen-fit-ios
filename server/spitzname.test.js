import { test } from "node:test";
import assert from "node:assert/strict";
import { spitznamePruefen } from "./spitzname.js";

const geht = (n) => assert.equal(spitznamePruefen(n).ok, true, `${n} sollte gehen: ${spitznamePruefen(n).grund}`);
const gehtNicht = (n, text) => {
  const r = spitznamePruefen(n);
  assert.equal(r.ok, false, `${n} sollte nicht gehen`);
  if (text) assert.equal(r.grund, text, n);
};

test("Spitzname: Form", () => {
  for (const n of ["Eisenfaust", "Max 1988", "Jörg_99", "Ali-Baba", "Mr. Muskel", "Çelik", "Ŝtefan"]) geht(n);
  assert.deepEqual(spitznamePruefen("  Eisen   Faust "), { ok: true, name: "Eisen Faust", norm: "eisenfaust" });
  gehtNicht("ab", "laenge");
  gehtNicht("a".repeat(21), "laenge");
  gehtNicht(undefined, "laenge");
  gehtNicht(42, "laenge");
  for (const n of ["Eisen😀", "Eisen/Faust", "Ей Faust", "Max\u200bFaust", "Max²³"]) gehtNicht(n, "zeichen");
  gehtNicht("12345", "buchstaben");
  gehtNicht("x 1.2", "buchstaben");
  for (const n of ["www.seite.de", "Muskel.com", "Max http", "lumen.app"]) gehtNicht(n, "unpassend");
});

test("Spitzname: Schimpfwörter auch mit Leetspeak, Umlauten, Abständen, Wiederholungen", () => {
  for (const n of [
    "Hurensohn", "Hur3ns0hn", "H u r e n s o h n", "Huuurensohn", "x_Fotze_x", "F0tze", "Fiiick", "W1chs3r", "Arschloch",
    "Arsch", "Ärsch", "Big Ass", "BigAss", "Nazi", "Hitler", "Hitler88", "Max88", "Leon 1488", "Nutte", "Neger", "Nigger", "N.i.g.g.e.r",
    "Schlampe", "Missgeburt", "Spasti", "Kurwa", "Siktir", "Fuck Off", "Bitch",
  ]) gehtNicht(n, "unpassend");
});

test("Spitzname: kurze Wörter nur als ganzes Wort, harmlose Namen gehen", () => {
  for (const n of ["Klassiker", "Schwarzenegger", "Hancock", "Nazim", "Minute Man", "Kanal Kai", "Barsch", "Badminton Bob", "Pedometer", "Amina", "Max 1988", "Lumina", "Assel Andi"]) geht(n);
});

test("Spitzname: reservierte Namen", () => {
  for (const n of ["Admin", "Lumen", "Lumi", "LumenFit Team", "Lumen_Fit", "Support", "Moderator", "Offiziell", "Lum3n"]) gehtNicht(n, "unpassend");
});

test("Spitzname: Vergleichsform für eindeutige Namen", () => {
  const norm = (n) => spitznamePruefen(n).norm;
  for (const n of ["Eisen Faust", "eisenfaust", "Eisen_Faust", "EISEN-FAUST", "Eisen.Faust", "E1senfaust"]) assert.equal(norm(n), "eisenfaust", n);
  assert.equal(norm("Müller"), norm("Muller"));
  assert.notEqual(norm("Eisenfaust"), norm("Eisenfaus"));
});
