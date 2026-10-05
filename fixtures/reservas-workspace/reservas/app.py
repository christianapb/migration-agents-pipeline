from flask import Flask, redirect, render_template, url_for

from config import Config
from db import cerrar_conexion
from errores import ErrorDeNegocio
from routes.auth import bp as auth_bp
from routes.reservas import bp as reservas_bp
from routes.salas import bp as salas_bp


def create_app(config=Config):
    app = Flask(__name__)
    app.config.from_object(config)
    app.teardown_appcontext(cerrar_conexion)

    app.register_blueprint(auth_bp)
    app.register_blueprint(salas_bp)
    app.register_blueprint(reservas_bp)

    @app.route("/")
    def inicio():
        return redirect(url_for("salas.listado"))

    @app.errorhandler(ErrorDeNegocio)
    def error_de_negocio(err):
        return render_template("error.html", codigo=err.codigo, mensaje=err.mensaje), err.estado

    @app.errorhandler(404)
    def no_encontrado(_err):
        return render_template("error.html", codigo="NO_ENCONTRADO", mensaje="No existe"), 404

    return app


app = create_app()
