# Diagnóstico estable del orquestador: diseño

Fecha: 2026-10-05
Estado: implementado
Modifica: el procedimiento de "Siguiente paso" y la salida de `migration-orchestrator`, y `scripts/test-orchestrator.sh`. No cambia qué considera desactualizado ni la completitud por capacidad.

## 1. Problema

`test-orchestrator.sh` hacía unas 18 llamadas al orquestador y aplicaba aserciones literales sobre su respuesta en texto libre. En tres corridas seguidas falló cada vez en un caso distinto, y los casos fallidos daban la respuesta correcta al reproducirlos. Tres causas, ninguna un error de diagnóstico:

1. **Prioridad ambigua.** Con varias cosas pendientes (destino vacío, preguntas abiertas, ADRs propuestos, un paso sin hacer), el prompt dejaba competir "pendientes de revisión" con "siguiente agente del orden", y el orquestador elegía distinto de una corrida a otra.
2. **Aserciones sobre la redacción.** "No debe mencionar `migration-analyst`" fallaba si lo nombraba al explicar qué vendría después.
3. **Estados que dependían de lo generado.** Según esa generación trajera preguntas abiertas o hallazgos, el estado de partida era otro.

## 2. Decisiones

| Tema | Decisión |
|---|---|
| Siguiente paso | Procedimiento fijo en cinco pasos; el orquestador no elige por criterio entre cosas pendientes. |
| Pendiente de revisión | Nunca cambia el agente del siguiente paso, salvo tres puertas explícitas. |
| Puertas | Antes de `migration-tl-adrs` o `migration-tl-tasks`: destino pendiente. Antes de `migration-tl-tasks`: ADRs propuestos y hallazgos `H-n` sin resolver. Nada más. |
| Salida | Sección final `## Datos` con siete líneas `clave: valor`. |
| Prueba | Lee `## Datos`, no la prosa. Cada caso prepara su estado. |
| Criterio de estabilidad | Seis corridas completas seguidas en verde. |

## 3. Procedimiento del siguiente paso

Se aplica el primero que corresponda:

- **a.** Paso 1 incompleto: `migration-indexer`.
- **b.** Artefactos sin versión: `migration-tl-resolver`, `registra las versiones`.
- **c.** El agente de la posición más temprana de la cadena con algo que falte o esté desactualizado: analista (2), ADRs (3), specs (4), auditor (4,5), QA (5), tareas (6), PM (7). El alcance son las capacidades afectadas en esa posición; en paralelo si son varias y el agente lo admite. La auditoría ausente solo cuenta si los specs están completos y aún no existe ningún plan ni ninguna tarea.
- **d.** Puertas: si el candidato tiene una puerta sin resolver, el siguiente paso es el resolver con un solo prompt, y el candidato queda como camino alternativo.
- **e.** Nada falta ni está desactualizado: no hay agente; se revisa lo pendiente y se empieza a implementar.

La puerta de los hallazgos `H-n` es nueva: antes era una recomendación del tutorial. Es coherente con poner QA antes que las tareas, cuyo sentido es resolver los hallazgos antes de derivar nada del spec. Quien no quiera resolverlos tiene el prompt de `migration-tl-tasks` como camino alternativo.

## 4. Sección `## Datos`

```
## Datos
agente: migration-qa
motivo: falta
alcance: autenticacion, carrito, listado-productos
paralelo: sí
faltan: planes:autenticacion, planes:carrito, planes:listado-productos
desactualizado: nada
sin-version: nada
```

- `agente`: uno de los diez agentes o `ninguno`.
- `motivo`: `indexar`, `sin-version`, `falta`, `desactualizado`, `auditar`, `completo`, o las puertas `destino`, `decidir`, `hallazgos` (varias separadas por coma).
- `alcance`: `todo`, slugs o repositorios, `cobertura` o `versiones`.
- `paralelo`: `sí` o `no`.
- `faltan`: `specs:<slug>`, `planes:<slug>`, `tareas:<slug>`, `tareas:fundacionales`, `cobertura`, o `nada`.
- `desactualizado`: `plan:<slug>`, `tarea:<id>`, `cobertura`, `auditoria:<slug>`, `backlog`, `spec:<slug>`, `adr:<id>`, o `nada`.
- `sin-version`: rutas relativas a `migration/`, o `nada`.

Va al final, sin formato, y no puede contradecir las secciones anteriores. Sirve también a quien quiera automatizar sobre el orquestador.

## 5. Prueba

Veinte casos, cada uno con su estado: restaura una instantánea y la ajusta con funciones que fijan el destino, deciden los ADRs, marcan resueltos los hallazgos o plantan una auditoría al día, para que solo cuente lo que el caso cambia. Las aserciones comparan valores de `## Datos`; las listas se comparan como conjuntos.

`CASOS="a b"` ejecuta solo esos casos y `ORQ_LOG=<carpeta>` guarda la respuesta de cada uno, para diagnosticar sin volver a llamar al agente.

## 6. Fuera de alcance

- Que el diagnóstico lo calcule un script (anotado en el diseño del backlog por script, §8).
- `test-auditor.sh`, cuya primera comprobación depende de que el spec generado no tenga ninguna imprecisión real.
