# Evidencia por regla y agente auditor: diseño

Fecha: 2026-10-01
Estado: pendiente de revisión escrita
Modifica: `docs/specs/2026-09-29-migration-agents-v2-design.md` (v2) y se integra con `docs/specs/2026-10-01-politica-paridad-design.md` (paridad). Lo que este documento no cambia sigue rigiendo según esos dos y v1.

## 1. Propósito

Nada en el flujo comprueba que un spec sea fiel al código:

- Los `scripts/verify-*.sh` validan estructura. Un spec con una regla inventada los pasa.
- La sección 11 del spec lista archivos para todo el spec. Para contrastar una regla hay que releer los archivos enteros.
- Ningún agente usa los tests del origen como fuente de verdad, y `migration-analyst` indica no leerlos.

Con la política de paridad esto pesa más: los specs afirman más hechos (112 reglas y casos borde en el fixture: autenticación 50, carrito 41, listado-productos 21) y cada hecho llega a tareas y pruebas como requisito.

**Criterio de éxito:** cada `RN-n` y `CB-n` cita ruta y línea de su respaldo; un agente auditor relee el código citado y da un veredicto por regla sin modificar los specs; los tests del origen cuentan como evidencia; y una prueba automática demuestra que el auditor detecta errores plantados y no inventa contradicciones.

## 2. Decisiones

| Tema | Decisión |
|---|---|
| Cita por regla | Entre corchetes al final de la línea de cada `RN-n` y `CB-n`: `[bff/src/routes/cart.ts:32]`. |
| Reglas deducidas de una ausencia | `[ausente: bff/src/routes/cart.ts]`, sin línea. |
| Reglas que son decisiones | `[decisión: MJ-2]`, `[decisión: PA 3]` o `[decisión: ADR 0011]`. No tienen respaldo en el código y no se auditan. |
| Commit de origen | Se adopta. El indexador anota el commit de cada repo en el índice general; `migration-tl-specs` lo copia al frontmatter del spec. |
| Auditor | Agente nuevo `migration-auditor`, de solo lectura sobre los specs. Escribe el derivado `migration/specs/_auditoria.md`. |
| Lugar en el flujo | Agente transversal, sin número de paso, como el orquestador y el resolver. Recomendado después de `migration-tl-specs` y antes de `migration-tl-tasks`. No se renumeran los pasos 5 a 7. |
| Hallazgos | Prefijo `AU-n`, numerados por capacidad dentro de `_auditoria.md`. No chocan con `H-n` de QA. |
| Resolución de hallazgos | No hay marca de "resuelto". El derivado se regenera: un hallazgo corregido desaparece en la siguiente auditoría. |
| Tests del origen | Evidencia válida. Se citan como cualquier archivo. Si contradicen la implementación, es un hallazgo. |

### 2.1 Por qué anotar el commit

Los números de línea caducan cuando cambia el código. Sin referencia, una cita que ya no coincide no se distingue de una regla inventada. Con el commit, el auditor y el orquestador pueden decir "el código cambió desde que se escribió este spec" en vez de reportar decenas de falsas contradicciones.

Lo escribe el indexador, que ya usa git y tiene Bash, en una columna `Commit` del índice general (`git -C "<repo>" rev-parse --short HEAD`, o `sin-git`). Los demás agentes, que no tienen Bash, lo leen de ahí. Limitación asumida: el commit refleja el momento de la última indexación y no detecta cambios sin commitear; el tutorial ya pide repetir el indexador cuando cambia el código.

## 3. Formato de las citas

```
RN-6: la cantidad de un producto en el carrito nunca supera 10; al sumar, se recorta a 10 sin avisar. [bff/src/routes/cart.ts:32]
CB-3: una cantidad fuera de 1 a 10 responde 400 VALIDATION. [bff/src/routes/cart.ts:13, bff/src/routes/cart.ts:27-28]
RN-12: no existe operación para vaciar el carrito. [ausente: bff/src/routes/cart.ts]
RN-22: quitar una línea que no existe responde 404. [decisión: MJ-1]
```

- Ruta relativa a la carpeta padre, empezando por el nombre del repo. Línea o rango `:30-33`. Varias citas separadas por coma.
- La cita va al final de la línea, después del texto y antes de cualquier marca `(retirado ...)`.
- Sigue prohibido incluir código: la cita es solo ruta y línea.
- Se cita la línea donde el comportamiento se decide (la condición, la constante, la respuesta), no el archivo en general. Como mucho tres citas por regla.
- Si un test del origen fija el comportamiento, se añade su línea además de la de la implementación.
- `[ausente: <ruta>]` cita el archivo donde estaría el comportamiento si existiera.
- `[decisión: ...]` lo escribe el resolver al aplicar una mejora, convertir una respuesta en regla o reflejar un ADR.
- Las `MJ-n` no llevan cita: ya citan la regla que describe el comportamiento actual.
- La sección 11 se mantiene como lista de archivos leídos.

Frontmatter del spec, campo nuevo:

```yaml
commits: {bff: 3f2a91c, frontend: 8b1d0e4}
```

## 4. `migration-auditor`

**Herramientas:** Read, Glob, Grep, Write. Sin Edit ni Bash: no puede modificar un spec por accidente; Write es solo para `_auditoria.md`.

**Insumos:** bloque de `CLAUDE.md`, índice general (para los commits actuales), specs en cualquier estado, también `revisado`. Alcance `solo la capacidad X`.

**Procedimiento, del código hacia la regla.** Por cada regla no retirada y sin `[decisión: ...]`:

1. Lee solo el id y la cita, no el texto de la regla.
2. Abre el archivo en las líneas citadas, con contexto suficiente para entender la rama o función.
3. Escribe para sí, en una frase, qué hace ese código.
4. Solo entonces lee el texto de la regla y compara.
5. Clasifica:
   - **respaldada**: el código citado hace lo que la regla dice.
   - **sin respaldo**: la cita existe pero no muestra ese comportamiento. Antes de darla por sin respaldo, busca con Grep en los archivos de la sección 11; si el respaldo está en otra línea, es respaldada con el hallazgo "cita imprecisa" y la línea correcta.
   - **contradicha**: el código hace algo distinto de lo que la regla afirma (otro valor, otro código de respuesta, otra condición).
   - **cita no localizable**: el archivo no existe o la línea está fuera del archivo.
   - Para `[ausente: ...]`: respaldada si una búsqueda en ese archivo y en los de la sección 11 no encuentra el comportamiento; contradicha si lo encuentra.
6. Para valores (números, códigos, textos literales) compara el valor exacto. Una regla que dice 20 con un código que dice 10 es contradicha, no "aproximadamente respaldada".

**Segunda pasada, acotada.** Recorre los archivos de la sección 11 de cada spec y lista comportamiento visible que ninguna regla recoge: endpoints, ramas de error, validaciones, constantes de negocio. Solo eso; no opina sobre estilo ni sobre mejoras. Cada omisión es un hallazgo de tipo "omitido".

**Commits.** Si el `commits:` del spec difiere del índice general, lo indica al principio de la sección de esa capacidad: los hallazgos pueden deberse a que el código cambió. Si el spec no tiene `commits:` (specs anteriores), lo dice y audita igual.

**Salida:** `migration/specs/_auditoria.md`, derivado. Con alcance, reescribe solo la sección de esa capacidad y conserva las demás.

```markdown
# Auditoría de specs

Generado: <AAAA-MM-DD> por migration-auditor.

## Resumen

| Capacidad | Reglas | Respaldadas | Sin respaldo | Contradichas | No localizables | Decisiones | Omitidos |
|---|---|---|---|---|---|---|---|

## carrito

Auditada: <AAAA-MM-DD>. Commits del spec: bff 3f2a91c, frontend 8b1d0e4 (coinciden con el índice).

| Regla | Veredicto | Cita | Nota |
|---|---|---|---|
| RN-6 | contradicha | bff/src/routes/cart.ts:32 | El código recorta a 10; la regla dice 20. |

### Hallazgos

- **AU-1** (contradicha, RN-6): el tope en el código es 10 y la regla dice 20.
  Corrección: `Usa el subagente migration-tl-resolver: en el spec carrito, RN-6: el tope es 10`
```

Una fila por cada regla auditada, también las respaldadas. Sin hallazgos, la sección dice "Ninguno".

**Lo que no hace:** no edita specs, tareas ni planes; no decide qué versión es la correcta cuando hay contradicción (lo decide el usuario: puede que el spec esté mal o que se quiera una mejora); no ejecuta código ni tests.

## 5. Cambios en los demás agentes

### 5.1 `migration-indexer`

- Índice general: columna `Commit` por repo.
- Plantilla `spec.md`: `commits:` en el frontmatter; los comentarios de las secciones 7 y 8 indican la cita al final de cada regla.
- Bloque de `CLAUDE.md`: convención de citas (§3), identificador `AU-n`, `_auditoria.md` en la lista de derivados, `migration-auditor` entre los agentes transversales.

### 5.2 `migration-tl-specs`

- Cita por regla según §3. Regla sin cita no se escribe: si no puede señalar la línea, o es una pregunta abierta o no es un hecho.
- Usa los tests del origen: los lee cuando existen para los archivos de la capacidad, los cita como evidencia adicional y, si un test afirma algo que la implementación no hace, lo anota como pregunta abierta (es una incógnita real: no se sabe cuál de los dos es el requisito).
- Copia `commits:` desde el índice general.
- Al regenerar un spec conserva la numeración y actualiza las citas a las líneas actuales.

### 5.3 `migration-analyst`

- Deja de indicar que no se lean los tests. Los tests se leen cuando existen, como evidencia del comportamiento esperado, aunque no definen capacidades por sí solos.

### 5.4 `migration-tl-resolver`

- Al crear una `RN-n` o `CB-n` (edición libre, mejora aplicada, respuesta convertida en regla, hallazgo de QA), añade la cita: la del código si el usuario la da o el resolver la encuentra, o `[decisión: ...]` si la regla nace de una decisión.
- Al corregir una regla por un hallazgo `AU-n`, actualiza también su cita si el hallazgo trae la línea correcta.
- Se niega a editar `_auditoria.md` e indica que lo regenera `migration-auditor`.
- No marca hallazgos como resueltos: recomienda repetir `migration-auditor, solo la capacidad X`.

### 5.5 `migration-orchestrator`

- Pendiente de revisión: hallazgos `AU-n` de `_auditoria.md` cuya capacidad no se haya vuelto a auditar.
- Desactualizado: sección de auditoría más antigua que su spec, y specs cuyo `commits:` difiere del índice general.
- Siguiente paso tras `migration-tl-specs`: recomienda la auditoría antes de `migration-tl-tasks`, y menciona en una línea que es opcional.
- Las reglas respaldadas no generan ruido: solo se listan hallazgos.

### 5.6 `migration-tl-tasks`, `migration-qa`, `migration-pm`

Sin cambios de comportamiento. Leen las reglas igual: la cita va al final de la línea y sus identificadores siguen al inicio. Los prompts de tareas y QA añaden una frase: la cita entre corchetes no forma parte del requisito y no se copia a criterios ni casos.

## 6. Verificadores y pruebas

**`verify-tl-specs.sh`:**
- Cada `RN-n` y `CB-n` no retirada termina en una cita entre corchetes con formato válido.
- Cada ruta citada existe en el workspace y cada número de línea está dentro del archivo.
- `[ausente: ...]` cita un archivo existente; `[decisión: ...]` se acepta sin comprobar ruta.
- El frontmatter tiene `commits:`.

**`verify-indexer.sh`:** columna `Commit` en el índice general, `commits:` en la plantilla y `AU-n` y `_auditoria.md` en el bloque.

**`verify-auditor.sh`** (nuevo): `_auditoria.md` existe; tiene tabla resumen y una sección por capacidad auditada; cada regla no retirada del spec aparece en la tabla de su capacidad con un veredicto del conjunto permitido; los hallazgos están numerados `AU-n` y cada uno trae un prompt del resolver; los totales del resumen cuadran con las tablas.

**`verify-qa.sh` y `verify-tl-tasks.sh`:** extraen ids con `^(- )?(RN|CB)-[0-9]+:`, que la cita al final no altera. Se añade un caso en `test-verifiers.sh` que lo fija: un workspace con citas sigue pasando.

**`test-verifiers.sh`** (sin agentes): workspace sintético con citas y `commits:`. Casos que deben fallar: regla sin cita, cita a un archivo inexistente, línea fuera de rango, formato de cita inválido; y para `verify-auditor.sh`: regla del spec ausente de la tabla, veredicto desconocido, hallazgo sin prompt, resumen que no cuadra.

**`test-prompts.sh`** (sin agentes): presencia de las reglas de §3 a §5 en los prompts.

**`test-auditor.sh`** (con agentes), la prueba que importa. Sobre la instantánea `tl-specs`:

1. Audita los specs sin alterar. Exige que ninguna regla quede como contradicha. Si aparece alguna, la prueba falla y se investiga si el error es del auditor o del spec antes de tocar nada.
2. Altera el spec de carrito:
   - cambia el valor de una regla verdadera: el tope de cantidad, de 10 a 20;
   - añade una regla inventada con una cita plausible a una línea real;
   - añade una regla cuya cita apunta a un archivo que no existe.
3. Calcula el hash de todos los specs y ejecuta `migration-auditor, solo la capacidad carrito`.
4. Comprueba que: la regla del tope queda **contradicha**; la inventada queda **sin respaldo** o contradicha; la del archivo inexistente queda **cita no localizable**; ninguna de las reglas no tocadas queda contradicha; hay un hallazgo `AU-n` por cada una de las tres; los hashes de los specs no cambiaron; y las secciones de las otras capacidades en `_auditoria.md` se conservaron.

**Infraestructura:** `test-agents.sh` añade `migration-auditor` con `test-auditor`; `snapshot.sh` no gana etapa, porque el auditor no alimenta a los agentes siguientes; `test-runner.sh` actualiza el número de pruebas esperado; `install.sh` no cuenta agentes y no cambia; `check-agent.sh` pasa a validar diez.

## 7. Compatibilidad

- Specs anteriores sin citas: `verify-tl-specs.sh` los rechaza; se regeneran con `migration-tl-specs`. Los `revisado` no se regeneran: el auditor los audita igual, buscando el respaldo en los archivos de la sección 11 y reportando cada regla sin cita como hallazgo "sin cita" con la línea que encontró, para que el usuario la añada con el resolver.
- Workspaces existentes reciben la columna `Commit` y el bloque nuevo al repetir el indexador. La plantilla `spec.md` no se sobrescribe; `migration-tl-specs` escribe `commits:` y las citas aunque la plantilla sea anterior.

## 8. Documentación

`docs/tutorial.md`: "Son 10 subagentes"; el auditor en la lista de agentes transversales; en el paso 4, qué es una cita y cómo usarla al revisar; un apartado "Auditar los specs" entre los pasos 4 y 5; filas en "Qué repetir después de un cambio" (cambió el código: repetir indexador, specs y auditor) y en "Si algo falla". `README.md`: tabla de agentes, convenciones y pruebas.

## 9. Medición

Al final se informa, por capacidad, de cuántas reglas auditó el auditor sobre los specs sin alterar y cuántas quedaron en cada categoría; del resultado de la prueba de errores plantados; y de cualquier contradicción reportada sobre specs sin alterar, con el análisis de si el error era del auditor o del spec.

## 10. Fuera de alcance

- Que el auditor corrija specs o decida entre spec y código.
- Auditar tareas o planes de prueba contra los specs.
- Ejecutar los tests del origen.
- Detectar cambios sin commitear en los repos.
- Citas en ADRs o en las posibles mejoras.
