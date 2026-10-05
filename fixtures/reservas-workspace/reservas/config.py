import os


class Config:
    SECRET_KEY = os.environ.get("SECRET_KEY", "dev")
    DATABASE = os.environ.get("RESERVAS_DB", "instance/reservas.db")
    # La sesión dura 20 minutos desde el último acceso
    PERMANENT_SESSION_LIFETIME = 20 * 60
    SESSION_REFRESH_EACH_REQUEST = True
    MAX_RESERVAS_DIA = int(os.environ.get("MAX_RESERVAS_DIA", "10"))
