from repos import reservas

# Una reserva pendiente que nadie confirma en 15 minutos deja libre la sala
MINUTOS_PARA_CONFIRMAR = 15


def caducar():
    return reservas.caducar_pendientes(MINUTOS_PARA_CONFIRMAR)
