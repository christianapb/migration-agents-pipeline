from datetime import datetime, timedelta

import pytest

from errores import ErrorDeNegocio
from services import reservas

MANANA = (datetime.now() + timedelta(days=1)).strftime("%Y-%m-%d")


def test_una_reserva_de_cuatro_horas_es_valida(app_con_datos):
    assert reservas.crear(1, 1, f"{MANANA}T09:00", f"{MANANA}T13:00", "2") > 0


def test_mas_de_cuatro_horas_se_rechaza(app_con_datos):
    with pytest.raises(ErrorDeNegocio) as err:
        reservas.crear(1, 1, f"{MANANA}T09:00", f"{MANANA}T13:30", "2")
    assert err.value.codigo == "DURACION"
    assert err.value.estado == 422


def test_intervalos_que_se_tocan_no_se_solapan(app_con_datos):
    reservas.crear(1, 1, f"{MANANA}T09:00", f"{MANANA}T10:00", "2")
    assert reservas.crear(2, 1, f"{MANANA}T10:00", f"{MANANA}T11:00", "2") > 0


def test_la_cuarta_reserva_activa_se_rechaza(app_con_datos):
    for hora in (9, 11, 13):
        reservas.crear(1, 1, f"{MANANA}T{hora:02d}:00", f"{MANANA}T{hora + 1:02d}:00", "1")
    with pytest.raises(ErrorDeNegocio) as err:
        reservas.crear(1, 2, f"{MANANA}T15:00", f"{MANANA}T16:00", "1")
    assert err.value.codigo == "LIMITE"
