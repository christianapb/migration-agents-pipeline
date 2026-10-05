from db import conexion

ACTIVAS = "('pendiente', 'confirmada')"


def solapadas(sala_id, inicio, fin):
    # Solo bloquean las reservas pendientes o confirmadas: una cancelada o
    # caducada deja libre su intervalo. Dos intervalos que se tocan no se solapan.
    fila = conexion().execute(
        f"""
        SELECT COUNT(*) AS n FROM reservas
        WHERE sala_id = ? AND estado IN {ACTIVAS} AND inicio < ? AND fin > ?
        """,
        (sala_id, fin, inicio),
    ).fetchone()
    return fila["n"]


def activas_de(usuario_id):
    fila = conexion().execute(
        f"""
        SELECT COUNT(*) AS n FROM reservas
        WHERE usuario_id = ? AND estado IN {ACTIVAS} AND fin > datetime('now', 'localtime')
        """,
        (usuario_id,),
    ).fetchone()
    return fila["n"]


def crear(sala_id, usuario_id, inicio, fin, asistentes):
    db = conexion()
    cur = db.execute(
        "INSERT INTO reservas (sala_id, usuario_id, inicio, fin, asistentes) VALUES (?, ?, ?, ?, ?)",
        (sala_id, usuario_id, inicio, fin, asistentes),
    )
    db.commit()
    return cur.lastrowid


def por_id(reserva_id):
    return conexion().execute("SELECT * FROM reservas WHERE id = ?", (reserva_id,)).fetchone()


def cambiar_estado(reserva_id, estado):
    db = conexion()
    db.execute("UPDATE reservas SET estado = ? WHERE id = ?", (estado, reserva_id))
    db.commit()


def de_usuario(usuario_id):
    # Las canceladas y caducadas dejan de mostrarse a los 30 días de su inicio
    return conexion().execute(
        """
        SELECT r.*, s.nombre AS sala
        FROM reservas r JOIN salas s ON s.id = r.sala_id
        WHERE r.usuario_id = ?
          AND NOT (r.estado IN ('cancelada', 'caducada') AND r.inicio < datetime('now', '-30 days'))
        ORDER BY r.inicio DESC
        """,
        (usuario_id,),
    ).fetchall()


def de_sala_en_dia(sala_id, dia):
    return conexion().execute(
        f"""
        SELECT inicio, fin, estado FROM reservas
        WHERE sala_id = ? AND estado IN {ACTIVAS} AND date(inicio) = ?
        ORDER BY inicio
        """,
        (sala_id, dia),
    ).fetchall()


def caducar_pendientes(minutos):
    db = conexion()
    cur = db.execute(
        "UPDATE reservas SET estado = 'caducada' "
        "WHERE estado = 'pendiente' AND creada_en < datetime('now', ?)",
        (f"-{minutos} minutes",),
    )
    db.commit()
    return cur.rowcount
