# Pruebas de fidelidad y segundo fixture: diseño

Fecha: 2026-10-05
Estado: implementado (decisiones tomadas con los valores recomendados en el encargo; las propias están en §2)
Convive con todo lo que hay en `master` y con la rama `fix/orquestador-estable`, de la que parte.

## 1. Propósito

Todo el flujo estaba validado contra un único proyecto de ejemplo, un frontend React y un BFF Express en TypeScript de unos veinte archivos. Eso dejaba tres huecos:

1. Casi ninguna prueba comprobaba que los specs digan lo que el código hace. Los verificadores miran estructura.
2. Ninguna prueba comprobaba lo contrario: que el flujo no afirme cosas que el código no hace.
3. No se sabía si los prompts funcionan fuera de TypeScript con Express. La comprobación de "el spec no contiene código del lenguaje origen" solo reconocía JavaScript.

**Criterio de éxito:** una lista de hechos por fixture, comprobada de forma automática; un segundo fixture en otro lenguaje, con otra arquitectura, con sus hechos y con trampas; un arnés que acepta más de un fixture sin invalidar las instantáneas del actual; y un informe de cómo se comporta el flujo en el fixture nuevo, incluido lo que hace mal.

## 2. Decisiones

| Tema | Decisión |
|---|---|
| Dónde viven los hechos | `fixtures/hechos/<fixture>.txt`, fuera de la carpeta que se copia como workspace. |
| Formato | Una línea por hecho: `tipo \| id \| capacidad \| patrones \| descripción`. |
| Contra qué se comprueba | Las líneas `RN-n` y `CB-n` no retiradas de los specs cuyo slug casa con la expresión de capacidad. |
| Patrones | Expresiones regulares unidas por `&&`; todas deben cumplirse en una misma línea. `!patrón` exige que no se cumpla. |
| Tipos | `hecho`, `trampa`, `mejora`, `no-pregunta`, y para el indexador `indice` y `no-indice`. |
| Activación | Solo con `FIXTURE=1`, el mecanismo que ya separa las comprobaciones del fixture. `FIXTURE_NAME` elige el fixture. |
| Comprobador | `scripts/verify-hechos.sh`. No se entrega a quien usa el flujo. |
| Producto oculto | El caso fijo de `verify-tl-specs.sh` pasa a ser tres líneas del archivo de hechos. |
| Listas del indexador | Las listas fijas de `verify-indexer.sh` pasan a líneas `indice` y `no-indice`. |
| Segundo fixture | `fixtures/reservas-workspace/reservas`: monolito Flask con SQLite y páginas en servidor, sobre reserva de salas. Destino Go. |
| Arnés | `FIXTURE_NAME` en `snapshot.sh`; instantáneas propias en `.work/snapshots-<nombre>`; textos de prompt en `fixtures/hechos/<nombre>.prompts.sh`. |
| Prueba del segundo fixture | `scripts/test-reservas.sh`, fuera de la corrida por defecto: `bash scripts/test-agents.sh fixture-reservas`. |
| Fallos conocidos | `CONOCIDOS="id ..."`: se informan y no hacen fallar. |

### 2.1 Por qué los patrones se apoyan en números y códigos

El modelo redacta la misma regla de formas distintas, pero no cambia un `422`, un `SOLAPADA` ni un `/login`. Los hechos se escriben con lo que no varía. Cuando un hecho no tiene número ni código (por ejemplo, "el listado excluye las salas en mantenimiento"), se usa la palabra del dominio que el código impone.

### 2.2 Por qué una trampa necesita patrones negados

La comprobación de una trampa es que ninguna regla afirme lo falso. Pero una regla puede nombrar la señal engañosa para decir la verdad: "la ruta `/admin` existe en el código y no está registrada". El patrón negado deja pasar esas líneas. Que la señal aparezca como pregunta abierta, como mejora o como hallazgo del auditor es correcto y no se comprueba.

### 2.3 Por qué el segundo fixture no entra en la corrida por defecto

Es otra cadena completa de siete agentes más el auditor. Correrla en cada cambio duplicaría el coste de `test-agents.sh`. Se lanza por nombre cuando cambian prompts que afectan a la generación.

## 3. Hechos del fixture actual

Escritos leyendo `bff/src` y `frontend/src`, antes de mirar ningún spec: 10 de autenticación, 6 de catálogo más la mejora y la no-pregunta del producto oculto, y 10 de carrito. El fixture no cambia y sus instantáneas no se invalidan: los hechos se comprueban sobre las que ya existen.

## 4. Segundo fixture

29 archivos de código Python, SQL, HTML y CSS. Tiene lo que el primero no tiene:

- Base de datos SQLite con `schema.sql` y dos migraciones.
- Un proceso programado (`scripts/caducar_reservas.py`, lanzado por cron cada 5 minutos) que caduca las reservas pendientes a los 15 minutos.
- Reglas que viven en SQL y no en el código de la aplicación: el listado excluye las salas en mantenimiento; solo bloquean el intervalo las reservas pendientes o confirmadas; dos intervalos que se tocan no se solapan; las canceladas dejan de listarse a los 30 días.
- Páginas renderizadas en servidor: no hay API JSON; los errores son páginas con código de estado.
- Ruido para el indexador: `poetry.lock`, la carpeta `build/` y `static/logo.png`.

Trampas:

| Id | Señal engañosa | Lo que hace el código |
|---|---|---|
| T1 | Un comentario dice "máximo 8 horas por reserva" | `MAX_HORAS = 4` |
| T2 | `recargo_fin_de_semana` aplica un 25 % los fines de semana | Nadie la llama |
| T3 | El README describe exportar a `.ics` y un recordatorio por correo | No existen |
| T4 | `MAX_RESERVAS_DIA = 10` en la configuración | Nadie la lee; el límite real son 3 reservas activas |
| T5 | `routes/admin.py` define `/admin/salas/<id>/desactivar` | `app.py` no registra ese blueprint |

## 5. "Sin código origen"

`verify-tl-specs.sh` reconoce, al inicio de línea, código de JavaScript y TypeScript, de Python (`def`, `class`, `from ... import`, decoradores, `return` con llamada, sentencias que terminan en dos puntos) y de la familia de Java (modificadores de acceso, `fun`, `val`, `var`, `package`, sentencias con llaves). El código citado dentro de una frase no cuenta. `test-verifiers.sh` lleva quince muestras que deben fallar y diez frases en español que deben pasar.

## 6. Lo que este cambio no pide al flujo

El fixture nuevo tiene base de datos y un proceso programado, y el flujo no tiene instrucciones para la migración de datos ni para procesos sin interfaz. Ninguna prueba lo exige y los prompts no se cambian para cubrirlo. `test-reservas.sh` solo informa de dónde aparecieron esas piezas: en el mapa de capacidades, en los ADRs, en los specs y en las tareas.

## 7. Fuera de alcance

- Instrucciones para migración de datos y para procesos sin interfaz.
- Ejecutar el código de los fixtures.
- Repetir sobre el segundo fixture las pruebas del resolver, del orquestador y las demás.
