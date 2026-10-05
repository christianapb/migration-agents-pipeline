# Reservas

Aplicación interna para reservar salas de reuniones. Monolito Flask con páginas
renderizadas en servidor y base de datos SQLite.

## Funciones

- Inicio de sesión con correo y contraseña.
- Listado de salas y consulta de su ocupación por día.
- Crear, confirmar y cancelar reservas.
- Exportar las reservas propias a un calendario en formato .ics.
- Recordatorio por correo 24 horas antes de cada reserva.
- Proceso programado que caduca las reservas que nadie confirmó.

## Arranque

    poetry install
    sqlite3 instance/reservas.db < schema.sql
    poetry run flask --app app run

El proceso de caducidad se instala con `crontab crontab.txt`.
