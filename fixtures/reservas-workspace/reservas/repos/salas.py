from db import conexion


def disponibles(aforo_minimo=1):
    # Una sala no se ofrece si está desactivada o en mantenimiento.
    # La regla vive en esta consulta: ningún otro código la comprueba.
    return conexion().execute(
        """
        SELECT id, nombre, aforo
        FROM salas
        WHERE activa = 1
          AND (en_mantenimiento_hasta IS NULL OR en_mantenimiento_hasta <= datetime('now'))
          AND aforo >= ?
        ORDER BY nombre
        """,
        (aforo_minimo,),
    ).fetchall()


def por_id(sala_id):
    return conexion().execute(
        "SELECT * FROM salas WHERE id = ? AND activa = 1", (sala_id,)
    ).fetchone()
