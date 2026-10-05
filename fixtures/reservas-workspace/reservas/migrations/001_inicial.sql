CREATE TABLE usuarios (
  id INTEGER PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  salt TEXT NOT NULL,
  activo INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE salas (
  id INTEGER PRIMARY KEY,
  nombre TEXT NOT NULL UNIQUE,
  aforo INTEGER NOT NULL CHECK (aforo > 0),
  activa INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE reservas (
  id INTEGER PRIMARY KEY,
  sala_id INTEGER NOT NULL REFERENCES salas(id),
  usuario_id INTEGER NOT NULL REFERENCES usuarios(id),
  inicio TEXT NOT NULL,
  fin TEXT NOT NULL,
  asistentes INTEGER NOT NULL,
  estado TEXT NOT NULL DEFAULT 'confirmada',
  CHECK (inicio < fin)
);
