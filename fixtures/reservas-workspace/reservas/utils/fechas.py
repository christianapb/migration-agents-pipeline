from datetime import datetime

FORMATO_PANTALLA = "%d/%m/%Y %H:%M"


def para_pantalla(texto_iso):
    return datetime.strptime(texto_iso, "%Y-%m-%dT%H:%M").strftime(FORMATO_PANTALLA)


def hoy():
    return datetime.now().strftime("%Y-%m-%d")


def recargo_fin_de_semana(inicio, horas):
    # Los sábados y domingos cada hora de sala lleva un recargo del 25 %
    if inicio.weekday() >= 5:
        return round(horas * 1.25, 2)
    return horas
