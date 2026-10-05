from flask import Blueprint, redirect, render_template, request, session, url_for

from repos import reservas as repo
from routes.comun import requiere_sesion
from services import reservas as servicio

bp = Blueprint("reservas", __name__)


@bp.get("/mis-reservas")
@requiere_sesion
def mias():
    return render_template("mis_reservas.html", reservas=repo.de_usuario(session["usuario_id"]))


@bp.post("/reservas")
@requiere_sesion
def crear():
    servicio.crear(
        session["usuario_id"],
        request.form.get("sala_id", type=int),
        request.form.get("inicio"),
        request.form.get("fin"),
        request.form.get("asistentes"),
    )
    return redirect(url_for("reservas.mias"), code=303)


@bp.post("/reservas/<int:reserva_id>/confirmar")
@requiere_sesion
def confirmar(reserva_id):
    servicio.confirmar(session["usuario_id"], reserva_id)
    return redirect(url_for("reservas.mias"), code=303)


@bp.post("/reservas/<int:reserva_id>/cancelar")
@requiere_sesion
def cancelar(reserva_id):
    servicio.cancelar(session["usuario_id"], reserva_id)
    return redirect(url_for("reservas.mias"), code=303)
