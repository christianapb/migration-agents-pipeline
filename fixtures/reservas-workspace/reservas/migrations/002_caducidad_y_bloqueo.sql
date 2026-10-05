-- Las reservas nacen pendientes y caducan si nadie las confirma.
-- SQLite no permite cambiar un CHECK: se reconstruye la tabla.
ALTER TABLE usuarios ADD COLUMN intentos_fallidos INTEGER NOT NULL DEFAULT 0;
ALTER TABLE salas ADD COLUMN en_mantenimiento_hasta TEXT;

ALTER TABLE reservas RENAME TO reservas_v1;
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
-- Las reservas anteriores ya estaban confirmadas y se dan por creadas en su inicio
INSERT INTO reservas (id, sala_id, usuario_id, inicio, fin, asistentes, estado, creada_en)
  SELECT id, sala_id, usuario_id, inicio, fin, asistentes, 'confirmada', inicio FROM reservas_v1;
DROP TABLE reservas_v1;

CREATE INDEX idx_reservas_sala_inicio ON reservas (sala_id, inicio);
CREATE INDEX idx_reservas_estado_creada ON reservas (estado, creada_en);
