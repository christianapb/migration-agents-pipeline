import hashlib
import hmac

from errores import ErrorDeNegocio
from repos import usuarios

MAX_INTENTOS = 5


def _hash(password, salt):
    return hashlib.sha256((salt + password).encode("utf-8")).hexdigest()


def autenticar(email, password):
    usuario = usuarios.por_email(email.strip().lower())
    if usuario is None:
        raise ErrorDeNegocio(401, "CREDENCIALES", "Credenciales incorrectas")
    if usuario["intentos_fallidos"] >= MAX_INTENTOS:
        raise ErrorDeNegocio(423, "BLOQUEADA", "Cuenta bloqueada por intentos fallidos")
    if not hmac.compare_digest(_hash(password, usuario["salt"]), usuario["password_hash"]):
        usuarios.registrar_fallo(usuario["id"])
        raise ErrorDeNegocio(401, "CREDENCIALES", "Credenciales incorrectas")
    usuarios.reiniciar_fallos(usuario["id"])
    return usuario["id"]
