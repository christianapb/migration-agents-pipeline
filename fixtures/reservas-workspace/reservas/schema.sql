-- Esquema completo. Las migraciones de migrations/ llevan una base antigua a este estado.
CREATE TABLE usuarios (
  id INTEGER PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  salt TEXT NOT NULL,
  activo INTEGER NOT NULL DEFAULT 1,
  intentos_fallidos INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE salas (
  id INTEGER PRIMARY KEY,
  nombre TEXT NOT NULL UNIQUE,
  aforo INTEGER NOT NULL CHECK (aforo > 0),
  activa INTEGER NOT NULL DEFAULT 1,
  en_mantenimiento_hasta TEXT
);

CREATE TABLE reservas (
  id INTEGER PRIMARY KEY,
  sala_id INTEGER NOT NULL REFERENCES salas(id),
  usuario_id INTEGER NOT NULL REFERENCES usuarios(id),
  inicio TEXT NOT NULL,
  fin TEXT NOT NULL,
  asistentes INTEGER NOT NULL,
  estado TEXT NOT NULL DEFAULT 'pendiente'
    CHECK (estado IN ('pendiente', 'confirmada', 'cancelada', 'caducada')),
  creada_en TEXT NOT NULL DEFAULT (datetime('now')),
  CHECK (inicio < fin)
);

CREATE INDEX idx_reservas_sala_inicio ON reservas (sala_id, inicio);
CREATE INDEX idx_reservas_estado_creada ON reservas (estado, creada_en);
