from flask import Blueprint, redirect, url_for

from db import conexion
from routes.comun import requiere_sesion

bp = Blueprint("admin", __name__, url_prefix="/admin")


@bp.post("/salas/<int:sala_id>/desactivar")
@requiere_sesion
def desactivar_sala(sala_id):
    db = conexion()
    db.execute("UPDATE salas SET activa = 0 WHERE id = ?", (sala_id,))
    db.execute("UPDATE reservas SET estado = 'cancelada' WHERE sala_id = ? AND estado = 'pendiente'", (sala_id,))
    db.commit()
    return redirect(url_for("salas.listado"))
