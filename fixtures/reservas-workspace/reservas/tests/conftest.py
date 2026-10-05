import sqlite3

import pytest

from app import create_app
from config import Config


@pytest.fixture
def app_con_datos(tmp_path):
    ruta = tmp_path / "reservas.db"
    db = sqlite3.connect(ruta)
    with open("schema.sql", encoding="utf-8") as esquema:
        db.executescript(esquema.read())
    db.executemany(
        "INSERT INTO usuarios (id, email, password_hash, salt) VALUES (?, ?, 'x', 'y')",
        [(1, "ana@oficina.test"), (2, "luis@oficina.test")],
    )
    db.executemany("INSERT INTO salas (id, nombre, aforo) VALUES (?, ?, ?)", [(1, "Andes", 6), (2, "Pacífico", 12)])
    db.commit()
    db.close()

    class ConfigDePrueba(Config):
        DATABASE = str(ruta)

    app = create_app(ConfigDePrueba)
    with app.app_context():
        yield app
