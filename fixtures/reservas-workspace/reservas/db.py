import sqlite3

from flask import current_app, g


def conexion():
    if "db" not in g:
        g.db = sqlite3.connect(current_app.config["DATABASE"])
        g.db.row_factory = sqlite3.Row
        g.db.execute("PRAGMA foreign_keys = ON")
    return g.db


def cerrar_conexion(_exc=None):
    db = g.pop("db", None)
    if db is not None:
        db.close()
