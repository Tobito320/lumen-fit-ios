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
