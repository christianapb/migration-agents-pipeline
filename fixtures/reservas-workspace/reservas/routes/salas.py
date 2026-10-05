from flask import Blueprint, render_template, request

from errores import ErrorDeNegocio
from repos import reservas, salas
from routes.comun import requiere_sesion
from utils.fechas import hoy

bp = Blueprint("salas", __name__)


@bp.get("/salas")
@requiere_sesion
def listado():
    try:
        aforo = int(request.args.get("aforo", "1"))
    except ValueError:
        raise ErrorDeNegocio(400, "AFORO", "El aforo mínimo debe ser un número")
    return render_template("salas.html", salas=salas.disponibles(aforo), aforo=aforo)


@bp.get("/salas/<int:sala_id>")
@requiere_sesion
def detalle(sala_id):
    sala = salas.por_id(sala_id)
    if sala is None:
        raise ErrorDeNegocio(404, "SALA", "La sala no existe")
    dia = request.args.get("fecha") or hoy()
    return render_template("sala.html", sala=sala, dia=dia, ocupacion=reservas.de_sala_en_dia(sala_id, dia))
