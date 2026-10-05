from db import conexion


def por_email(email):
    # Los usuarios desactivados no existen para el inicio de sesión
    return conexion().execute(
        "SELECT * FROM usuarios WHERE email = ? AND activo = 1", (email,)
    ).fetchone()


def registrar_fallo(usuario_id):
    db = conexion()
    db.execute(
        "UPDATE usuarios SET intentos_fallidos = intentos_fallidos + 1 WHERE id = ?", (usuario_id,)
    )
    db.commit()


def reiniciar_fallos(usuario_id):
    db = conexion()
    db.execute("UPDATE usuarios SET intentos_fallidos = 0 WHERE id = ?", (usuario_id,))
    db.commit()
