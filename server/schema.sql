-- D1-Schema des Lumen-Fit-Servers. Idempotent: `wrangler d1 execute lumen-fit-<env> --remote --file schema.sql`.
CREATE TABLE IF NOT EXISTS konten (
  id TEXT PRIMARY KEY,
  hash TEXT NOT NULL,          -- SHA-256 des Geräte-Geheimnisses, das Geheimnis selbst liegt nie hier
  name TEXT NOT NULL,
  version TEXT NOT NULL DEFAULT '',
  erstellt TEXT NOT NULL,
  gesehen TEXT NOT NULL,
  gesperrt INTEGER NOT NULL DEFAULT 0,
  lovea_person TEXT,           -- ahmed | annika | NULL
  einstellungen TEXT NOT NULL DEFAULT '{}'
);
CREATE TABLE IF NOT EXISTS globale_config (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  einstellungen TEXT NOT NULL DEFAULT '{}'
);
INSERT OR IGNORE INTO globale_config (id, einstellungen) VALUES (1, '{}');

-- Einmal-Merker je Konto (z. B. lovea_import: wann der Lovea-Import fertig war), damit er nach Neuinstallation nicht nochmal läuft.
CREATE TABLE IF NOT EXISTS konto_merker (
  konto TEXT NOT NULL,
  schluessel TEXT NOT NULL,
  wert TEXT NOT NULL,
  PRIMARY KEY (konto, schluessel)
);
-- Nutzung je Konto und Tag: nur Zähler genutzter Bereiche und Funktionen, nie Inhalte oder Gesundheitswerte.
CREATE TABLE IF NOT EXISTS nutzung (
  konto TEXT NOT NULL,
  tag TEXT NOT NULL,           -- YYYY-MM-DD
  version TEXT NOT NULL DEFAULT '',
  bereiche TEXT NOT NULL DEFAULT '{}',
  funktionen TEXT NOT NULL DEFAULT '{}',
  PRIMARY KEY (konto, tag)
);
-- Letzte Zusammenfassung des Kontos für den Partner (nur freigegebene Felder, siehe SPEC 5.5/18).
CREATE TABLE IF NOT EXISTS partner_stand (
  konto TEXT PRIMARY KEY,
  aktualisiert TEXT NOT NULL,
  daten TEXT NOT NULL
);
-- KI-Foto-Mahlzeit: Fotos je Konto und Tag (nur der Zähler fürs Tageslimit, nie Bild oder Antwort).
CREATE TABLE IF NOT EXISTS ki_nutzung (
  konto TEXT NOT NULL,
  tag TEXT NOT NULL,           -- YYYY-MM-DD (Berlin)
  n INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (konto, tag)
);
-- Verbindungen zwischen Konten (QR-Einladung; die zwei Lovea-Konten entstehen von selbst). a hat gescannt, b besitzt den Code.
-- status: anfrage | aktiv | entfernt. a_einst/b_einst: Einstellungen je Seite als JSON (zeigt, ausblenden, pause, mitteilungen, favorit, name).
CREATE TABLE IF NOT EXISTS verbindungen (
  id TEXT PRIMARY KEY,
  a TEXT NOT NULL,
  b TEXT NOT NULL,
  status TEXT NOT NULL,
  auto INTEGER NOT NULL DEFAULT 0,
  a_einst TEXT NOT NULL DEFAULT '{}',
  b_einst TEXT NOT NULL DEFAULT '{}',
  erstellt TEXT NOT NULL,
  geaendert TEXT NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS verbindungen_paar ON verbindungen (a, b);
CREATE INDEX IF NOT EXISTS verbindungen_b ON verbindungen (b);
-- Einladungs-Token: nur der SHA-256-Hash, nie das Token. Läuft nach 10 Minuten ab, einmal nutzbar. laeuft_ab in Millisekunden.
CREATE TABLE IF NOT EXISTS einladungen (
  hash TEXT PRIMARY KEY,
  konto TEXT NOT NULL,
  laeuft_ab INTEGER NOT NULL,
  benutzt INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS einladungen_konto ON einladungen (konto);
-- Drossel je Schlüssel und Minute (Einladungs-Wege).
CREATE TABLE IF NOT EXISTS drossel (
  schluessel TEXT PRIMARY KEY,
  fenster INTEGER NOT NULL,
  n INTEGER NOT NULL
);
