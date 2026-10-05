from flask import Blueprint, redirect, render_template, request, session, url_for

from errores import ErrorDeNegocio
from services import sesion

bp = Blueprint("auth", __name__)


@bp.get("/login")
def formulario():
    return render_template("login.html", error=None)


@bp.post("/login")
def entrar():
    try:
        usuario_id = sesion.autenticar(request.form.get("email", ""), request.form.get("password", ""))
    except ErrorDeNegocio as err:
        return render_template("login.html", error=err.mensaje), err.estado
    session.clear()
    session.permanent = True
    session["usuario_id"] = usuario_id
    destino = request.args.get("next", "")
    if not destino.startswith("/") or destino.startswith("//"):
        destino = url_for("salas.listado")
    return redirect(destino)


@bp.post("/logout")
def salir():
    session.clear()
    return redirect(url_for("auth.formulario"))
