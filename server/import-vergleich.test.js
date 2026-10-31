import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { selbsttest, HEALTH_ARTEN, OP_ARTEN } from "../scripts/import-vergleich.mjs";

test("import-vergleich: Selbsttest", () => { selbsttest(); });

// Die Tabellen stehen in Swift und im Skript. Weicht eine ab, meldet das Skript Fehler, die keine sind (oder übersieht echte).
const swift = (datei) => readFileSync(new URL(`../LumenFit/Sources/Module/Profil/${datei}`, import.meta.url), "utf8");
const liste = (quelle, name) => {
  const m = new RegExp(`static let ${name}[^=]*=\\s*\\[([\\s\\S]*?)\\]`).exec(quelle);
  assert.ok(m, `${name} nicht gefunden`);
  return [...m[1].replace(/\/\/.*$/gm, "").matchAll(/"([^"]+)"/g)].map((x) => x[1]);
};

test("import-vergleich: HEALTH_ARTEN gleich ProfilLoveaArten (uebernehmen + rohBehalten)", () => {
  const arten = swift("ProfilLoveaArten.swift");
  const erwartet = [...liste(arten, "uebernehmen"), ...liste(arten, "rohBehalten")].sort();
  assert.deepEqual([...HEALTH_ARTEN].sort(), erwartet);
});

test("import-vergleich: OP_ARTEN gleich ProfilLoveaUebernahme.opArten", () => {
  assert.deepEqual([...OP_ARTEN].sort(), liste(swift("ProfilLoveaUebernahme.swift"), "opArten").sort());
});
