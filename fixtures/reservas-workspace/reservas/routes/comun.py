from functools import wraps

from flask import redirect, request, session, url_for


def requiere_sesion(vista):
    @wraps(vista)
    def envoltura(*args, **kwargs):
        if "usuario_id" not in session:
            return redirect(url_for("auth.formulario", next=request.path))
        return vista(*args, **kwargs)

    return envoltura
