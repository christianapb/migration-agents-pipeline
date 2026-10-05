from datetime import datetime, timedelta

from errores import ErrorDeNegocio
from repos import reservas, salas

# Máximo 8 horas por reserva
MAX_HORAS = 4
HORA_APERTURA = 7
HORA_CIERRE = 21
MAX_ACTIVAS = 3
ANTELACION_CANCELAR_HORAS = 2
FORMATO = "%Y-%m-%dT%H:%M"


def _fecha(texto):
    try:
        return datetime.strptime(texto, FORMATO)
    except (TypeError, ValueError):
        raise ErrorDeNegocio(422, "FORMATO", "Fecha con formato inválido")


def crear(usuario_id, sala_id, inicio_txt, fin_txt, asistentes_txt):
    inicio = _fecha(inicio_txt)
    fin = _fecha(fin_txt)
    try:
        asistentes = int(asistentes_txt)
    except (TypeError, ValueError):
        raise ErrorDeNegocio(422, "FORMATO", "Asistentes debe ser un número")

    sala = salas.por_id(sala_id)
    if sala is None:
        raise ErrorDeNegocio(404, "SALA", "La sala no existe")
    if inicio >= fin:
        raise ErrorDeNegocio(422, "INTERVALO", "El inicio debe ser anterior al fin")
    if inicio <= datetime.now():
        raise ErrorDeNegocio(422, "PASADO", "La reserva debe empezar en el futuro")
    if fin - inicio > timedelta(hours=MAX_HORAS):
        raise ErrorDeNegocio(422, "DURACION", "La reserva es demasiado larga")
    if inicio.date() != fin.date() or inicio.hour < HORA_APERTURA or (fin.hour, fin.minute) > (HORA_CIERRE, 0):
        raise ErrorDeNegocio(422, "HORARIO", "Fuera del horario de la oficina")
    if asistentes < 1 or asistentes > sala["aforo"]:
        raise ErrorDeNegocio(422, "AFORO", "Los asistentes no caben en la sala")
    if reservas.activas_de(usuario_id) >= MAX_ACTIVAS:
        raise ErrorDeNegocio(409, "LIMITE", "Ya tienes el máximo de reservas activas")
    if reservas.solapadas(sala_id, inicio_txt, fin_txt) > 0:
        raise ErrorDeNegocio(409, "SOLAPADA", "La sala ya está reservada en ese intervalo")
    return reservas.crear(sala_id, usuario_id, inicio_txt, fin_txt, asistentes)


def _propia(usuario_id, reserva_id):
    reserva = reservas.por_id(reserva_id)
    if reserva is None:
        raise ErrorDeNegocio(404, "RESERVA", "La reserva no existe")
    if reserva["usuario_id"] != usuario_id:
        raise ErrorDeNegocio(403, "AJENA", "La reserva es de otra persona")
    return reserva


def confirmar(usuario_id, reserva_id):
    reserva = _propia(usuario_id, reserva_id)
    if reserva["estado"] != "pendiente":
        raise ErrorDeNegocio(409, "ESTADO", "Solo se confirma una reserva pendiente")
    reservas.cambiar_estado(reserva_id, "confirmada")


def cancelar(usuario_id, reserva_id):
    reserva = _propia(usuario_id, reserva_id)
    if reserva["estado"] not in ("pendiente", "confirmada"):
        raise ErrorDeNegocio(409, "ESTADO", "La reserva ya no está activa")
    limite = datetime.strptime(reserva["inicio"], FORMATO) - timedelta(hours=ANTELACION_CANCELAR_HORAS)
    if datetime.now() > limite:
        raise ErrorDeNegocio(409, "TARDE", "Ya no se puede cancelar")
    reservas.cambiar_estado(reserva_id, "cancelada")
