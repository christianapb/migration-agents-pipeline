# Proceso programado: marca como caducadas las reservas pendientes que nadie
# confirmó a tiempo. Se ejecuta desde cron (ver crontab.txt), fuera de la web.
import sys

from app import create_app
from services.caducidad import caducar


def main():
    app = create_app()
    with app.app_context():
        n = caducar()
    print(f"reservas caducadas: {n}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
