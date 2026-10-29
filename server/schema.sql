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
