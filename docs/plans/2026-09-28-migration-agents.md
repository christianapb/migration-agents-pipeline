# Agentes de migración: plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cuatro subagentes de Claude Code (`migration-indexer`, `migration-techlead`, `migration-qa`, `migration-pm`) que, ejecutados manualmente y en orden desde una carpeta padre con varios repos, generan índices de código, ADRs, specs por capacidad, tareas, planes de prueba y un backlog priorizado para migrar el proyecto a otro lenguaje.

**Architecture:** Cada agente es un archivo Markdown con frontmatter en `agents/`. Se prueban contra un fixture (`fixtures/sample-workspace/`, un frontend y un BFF mínimos) que un script copia a `.work/` e inicializa como repos git. Los scripts `scripts/verify-<agente>.sh` comprueban estructuralmente los artefactos que cada agente deja en `.work/sample-workspace/migration/`.

**Tech Stack:** Claude Code subagents (Markdown con frontmatter `name`, `description`, `tools`), Bash (Git Bash en Windows), `claude -p` para corridas no interactivas, git.

**Spec:** `docs/specs/2026-09-28-migration-agents-design.md`

## Global Constraints

- Todo el contenido que generan los agentes va en español. Identificadores técnicos (rutas, campos, códigos de error) se conservan tal cual.
- Los specs no contienen fragmentos de código del lenguaje origen. La evidencia son rutas de archivo.
- Los agentes solo usan Read, Glob, Grep, Bash (para `git ls-files` y listados), Write y Edit. No instalan nada ni ejecutan el código del proyecto.
- Artefactos con frontmatter `estado`: valores `generado`, `revisado`, y en ADRs también `observado` y `propuesto`. `revisado` nunca se sobreescribe.
- Artefactos derivados que se regeneran siempre: `index.md`, `_capacidades.md`, `_cobertura.md`, `backlog.md`.
- Detección de repos: subcarpeta directa con `.git`, `package.json`, `pom.xml`, `build.gradle`, `build.gradle.kts`, `go.mod`, `pyproject.toml`, `Cargo.toml` o `composer.json`.
- Exclusiones fijas del indexador: lockfiles, binarios e imágenes, fuentes, `dist/`, `build/`, `out/`, `coverage/`, `.next/`, `.nuxt/`, `*.min.*`, `__snapshots__/`, fixtures de test mayores a 50 KB, `*.generated.*`, `*.d.ts` de build.
- Los scripts se escriben para Git Bash (`#!/usr/bin/env bash`, `set -euo pipefail`) y se ejecutan desde la raíz del repo `spec-agent`.
- Cada commit termina con `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.

## Review Focus

1. **Ejecutar un agente desde dentro de un repo** (no desde la carpeta padre): no debe crear `migration/` ni `index.md` en el lugar equivocado, solo explicar el error. Test en Task 3, paso 9.
2. **Repo sin `.git`** en la carpeta padre: el indexador debe indexarlo igual con el listado recursivo. Test en Task 3, paso 10.
3. **Plantilla modificada por el humano** antes de una segunda corrida del indexador: la modificación debe sobrevivir. Test en Task 3, paso 11.
4. **Tarea con `depende_de` apuntando a un id inexistente o formando un ciclo**: el PM se detiene y no escribe `backlog.md`. Test en Task 6, paso 8.
5. **Spec marcado `revisado` y editado a mano** antes de una segunda corrida del tech lead: el contenido editado debe conservarse. Test en Task 7, paso 3.

---

## Estructura de archivos

```
spec-agent/
├── agents/
│   ├── migration-indexer.md      # Task 3
│   ├── migration-techlead.md     # Task 4
│   ├── migration-qa.md           # Task 5
│   └── migration-pm.md           # Task 6
├── fixtures/sample-workspace/    # Task 2
│   ├── frontend/                 # Vite + React mínimo
│   └── bff/                      # Express + TS mínimo
├── scripts/
│   ├── check-agent.sh            # Task 1: valida frontmatter de agents/*.md
│   ├── install.sh                # Task 1: copia agents/*.md a ~/.claude/agents/
│   ├── fixture-reset.sh          # Task 2: copia fixture a .work/ e inicializa git
│   ├── run-agent.sh              # Task 2: corre un agente con claude -p en .work/
│   ├── verify-indexer.sh         # Task 3
│   ├── verify-techlead.sh        # Task 4
│   ├── verify-qa.sh              # Task 5
│   ├── verify-pm.sh              # Task 6
│   └── verify-idempotency.sh     # Task 7
├── docs/specs/…                  # ya existe
├── docs/plans/…                  # este archivo
├── .gitignore                    # Task 1
└── README.md                     # Task 1 (inicial), Task 7 (final)
```

Responsabilidades: `agents/` es el producto. `fixtures/` es un dato de prueba inmutable. `scripts/` son la infraestructura de prueba e instalación. `.work/` es descartable.

---

### Task 1: Infraestructura base (validador de agentes, instalador, gitignore)

**Files:**
- Create: `.gitignore`
- Create: `scripts/check-agent.sh`
- Create: `scripts/install.sh`
- Create: `README.md`

**Interfaces:**
- Produces: `scripts/check-agent.sh [archivo...]` → sale con 0 si todos los agentes son válidos, 1 y mensaje `FAIL: ...` si no. Sin argumentos valida `agents/*.md`.
- Produces: `scripts/install.sh` → copia `agents/*.md` a `~/.claude/agents/`.

- [ ] **Step 1: Crear `.gitignore`**

```
.work/
```

- [ ] **Step 2: Escribir el test del validador con un agente inválido y uno válido**

Crear `scripts/test-check-agent.sh`:

```bash
#!/usr/bin/env bash
# Prueba scripts/check-agent.sh con un archivo válido y varios inválidos.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fails=0

cat > "$TMP/migration-ok.md" <<'EOF'
---
name: migration-ok
description: Agente de prueba válido.
tools: Read, Glob
---
Cuerpo del agente.

## 1. Sección
Contenido.
EOF

cat > "$TMP/migration-badname.md" <<'EOF'
---
name: otro-nombre
description: Nombre no coincide con el archivo.
tools: Read
---
## 1. Sección
EOF

cat > "$TMP/migration-notools.md" <<'EOF'
---
name: migration-notools
description: Sin tools.
---
## 1. Sección
EOF

cat > "$TMP/migration-nobody.md" <<'EOF'
---
name: migration-nobody
description: Sin cuerpo.
tools: Read
---
EOF

if ! "$ROOT/scripts/check-agent.sh" "$TMP/migration-ok.md" >/dev/null; then
  echo "FAIL: el agente válido fue rechazado"; fails=$((fails+1))
fi
for bad in badname notools nobody; do
  if "$ROOT/scripts/check-agent.sh" "$TMP/migration-$bad.md" >/dev/null 2>&1; then
    echo "FAIL: migration-$bad.md fue aceptado"; fails=$((fails+1))
  fi
done

if [ "$fails" -eq 0 ]; then echo "OK: check-agent.sh"; exit 0; fi
exit 1
```

- [ ] **Step 3: Ejecutar el test y verificar que falla**

Run: `bash scripts/test-check-agent.sh`
Expected: falla porque `scripts/check-agent.sh` no existe (`No such file or directory`), salida distinta de 0.

- [ ] **Step 4: Escribir `scripts/check-agent.sh`**

```bash
#!/usr/bin/env bash
# Valida la estructura de uno o más archivos de agente de Claude Code.
# Uso: scripts/check-agent.sh [archivo.md ...]   (sin argumentos: agents/*.md)
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
files=("$@")
if [ "${#files[@]}" -eq 0 ]; then files=("$ROOT"/agents/*.md); fi

status=0
fail() { echo "FAIL: $1: $2"; status=1; }

for f in "${files[@]}"; do
  base="$(basename "$f" .md)"
  [ -f "$f" ] || { fail "$f" "no existe"; continue; }
  [ "$(head -n1 "$f")" = "---" ] || { fail "$f" "no empieza con frontmatter"; continue; }
  # Frontmatter = líneas entre la primera y la segunda '---'
  fm="$(awk 'NR==1{next} /^---$/{exit} {print}' "$f")"
  body="$(awk 'NR==1{next} f{print} /^---$/{f=1}' "$f")"
  name="$(printf '%s\n' "$fm" | sed -n 's/^name:[[:space:]]*//p' | head -n1)"
  desc="$(printf '%s\n' "$fm" | sed -n 's/^description:[[:space:]]*//p' | head -n1)"
  tools="$(printf '%s\n' "$fm" | sed -n 's/^tools:[[:space:]]*//p' | head -n1)"
  [ -n "$name" ] || fail "$f" "falta name"
  [ "$name" = "$base" ] || fail "$f" "name '$name' no coincide con el archivo '$base'"
  [ -n "$desc" ] || fail "$f" "falta description"
  [ -n "$tools" ] || fail "$f" "falta tools"
  printf '%s\n' "$body" | grep -q '^## ' || fail "$f" "el cuerpo no tiene secciones '## '"
done

[ "$status" -eq 0 ] && echo "OK: ${#files[@]} agente(s) válido(s)"
exit "$status"
```

- [ ] **Step 5: Ejecutar el test y verificar que pasa**

Run: `bash scripts/test-check-agent.sh`
Expected: `OK: check-agent.sh`, salida 0.

- [ ] **Step 6: Escribir `scripts/install.sh`**

```bash
#!/usr/bin/env bash
# Copia los agentes a ~/.claude/agents/ para usarlos desde cualquier carpeta.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$HOME/.claude/agents"
"$ROOT/scripts/check-agent.sh"
mkdir -p "$DEST"
cp "$ROOT"/agents/*.md "$DEST/"
echo "Instalados en $DEST:"
ls "$DEST" | grep '^migration-'
```

- [ ] **Step 7: Escribir `README.md` inicial**

```markdown
# spec-agent

Subagentes de Claude Code para generar la documentación de migración de un proyecto (índices de código, ADRs, specs por capacidad, tareas, planes de prueba y backlog) a partir de su código, con el objetivo de reimplementarlo en otro lenguaje.

Diseño: `docs/specs/2026-09-28-migration-agents-design.md`.

## Instalación

```bash
bash scripts/install.sh
```

Copia `agents/*.md` a `~/.claude/agents/`. Alternativa por proyecto: copiar los archivos a `<carpeta padre>/.claude/agents/`.

## Uso

Abrir Claude Code en la carpeta padre que contiene los repositorios (no dentro de uno de ellos) y pedir, en orden y revisando entre pasos:

1. `Usa el subagente migration-indexer`
2. `Usa el subagente migration-techlead con destino Kotlin`
3. `Usa el subagente migration-qa`
4. `Usa el subagente migration-pm`

Los artefactos quedan en `migration/`. Los `index.md` quedan en la raíz de cada repo.

## Pruebas

Ver la sección al final de este archivo (se completa en Task 7).
```

- [ ] **Step 8: Commit**

```bash
git add .gitignore scripts/check-agent.sh scripts/test-check-agent.sh scripts/install.sh README.md
git commit -m "chore: validador de agentes, instalador y README inicial

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 2: Fixture de prueba y scripts de corrida

**Files:**
- Create: `fixtures/sample-workspace/bff/…` (14 archivos, listados abajo)
- Create: `fixtures/sample-workspace/frontend/…` (11 archivos, listados abajo)
- Create: `scripts/fixture-reset.sh`
- Create: `scripts/run-agent.sh`
- Test: `scripts/test-fixture.sh`

**Interfaces:**
- Produces: `scripts/fixture-reset.sh` → deja `.work/sample-workspace/{frontend,bff}` como repos git con un commit, y `.work/sample-workspace/.claude/agents/` con copia de `agents/*.md`.
- Produces: `scripts/run-agent.sh <nombre-agente> [texto extra]` → ejecuta `claude -p` en `.work/sample-workspace` (o en `$WORKDIR` si está definido) pidiendo invocar ese subagente. Imprime la respuesta.

- [ ] **Step 1: Escribir el test del fixture**

Crear `scripts/test-fixture.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="$ROOT/.work/sample-workspace"
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }

bash "$ROOT/scripts/fixture-reset.sh" >/dev/null || fail "fixture-reset.sh falló"

for r in frontend bff; do
  [ -d "$W/$r/.git" ] || fail "$r no es repo git"
  ( cd "$W/$r" && git log --oneline 2>/dev/null | grep -q fixture ) || fail "$r sin commit"
done
( cd "$W/bff" && git ls-files | grep -q '^dist/' ) && fail "bff/dist está trackeado; debe estar en .gitignore"
( cd "$W/bff" && git ls-files | grep -q 'package-lock.json' ) || fail "bff lockfile debería estar trackeado (prueba exclusión fija)"
( cd "$W/bff" && git ls-files | grep -q '__snapshots__' ) || fail "bff snapshot debería estar trackeado"
( cd "$W/frontend" && git ls-files | grep -q 'public/logo.png' ) || fail "frontend logo.png debería estar trackeado"
[ -d "$W/.claude/agents" ] || fail "no se copiaron los agentes"
[ -f "$W/bff/src/routes/products.ts" ] || fail "falta products.ts"
grep -q 'status(200).end()' "$W/bff/src/routes/products.ts" || fail "falta la ambigüedad 200 vacío"
grep -q 'getPriceCents' "$W/bff/src/routes/cart.ts" || fail "falta dependencia cruzada carrito→catálogo"

[ "$fails" -eq 0 ] && { echo "OK: fixture"; exit 0; }
exit 1
```

- [ ] **Step 2: Ejecutar el test y verificar que falla**

Run: `bash scripts/test-fixture.sh`
Expected: `FAIL: fixture-reset.sh falló` y otros FAIL; salida 1.

- [ ] **Step 3: Crear el fixture del BFF**

`fixtures/sample-workspace/bff/package.json`:
```json
{
  "name": "shop-bff",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "build": "tsc",
    "start": "node dist/server.js",
    "test": "jest"
  },
  "dependencies": {
    "axios": "^1.7.0",
    "express": "^4.19.0",
    "jsonwebtoken": "^9.0.0",
    "zod": "^3.23.0"
  },
  "devDependencies": {
    "@types/express": "^4.17.21",
    "jest": "^29.7.0",
    "ts-jest": "^29.2.0",
    "typescript": "^5.5.0"
  }
}
```

`fixtures/sample-workspace/bff/package-lock.json`:
```json
{
  "name": "shop-bff",
  "version": "1.0.0",
  "lockfileVersion": 3,
  "packages": {
    "": { "name": "shop-bff", "version": "1.0.0" },
    "node_modules/express": { "version": "4.19.2", "resolved": "https://registry.npmjs.org/express/-/express-4.19.2.tgz" }
  }
}
```

`fixtures/sample-workspace/bff/.gitignore`:
```
node_modules/
dist/
```

`fixtures/sample-workspace/bff/.env.example`:
```
PORT=3000
JWT_SECRET=change-me
IDENTITY_URL=http://identity.internal
```

`fixtures/sample-workspace/bff/tsconfig.json`:
```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "CommonJS",
    "outDir": "dist",
    "rootDir": "src",
    "strict": true,
    "esModuleInterop": true
  },
  "include": ["src"]
}
```

`fixtures/sample-workspace/bff/src/server.ts`:
```ts
import express from "express";
import { authRouter } from "./routes/auth";
import { productsRouter } from "./routes/products";
import { cartRouter } from "./routes/cart";
import { errorHandler } from "./errors";

const app = express();
app.use(express.json());
app.use("/auth", authRouter);
app.use("/products", productsRouter);
app.use("/cart", cartRouter);
app.use(errorHandler);

const port = Number(process.env.PORT ?? 3000);
app.listen(port, () => console.log(`bff listening on ${port}`));
```

`fixtures/sample-workspace/bff/src/errors.ts`:
```ts
import type { NextFunction, Request, Response } from "express";

export class AppError extends Error {
  constructor(public status: number, public code: string, message: string) {
    super(message);
  }
}

export function errorHandler(err: unknown, _req: Request, res: Response, _next: NextFunction) {
  if (err instanceof AppError) {
    res.status(err.status).json({ error: { code: err.code, message: err.message } });
    return;
  }
  res.status(500).json({ error: { code: "INTERNAL", message: "Unexpected error" } });
}
```

`fixtures/sample-workspace/bff/src/middleware/auth.ts`:
```ts
import type { NextFunction, Request, Response } from "express";
import jwt from "jsonwebtoken";
import { AppError } from "../errors";

const SECRET = process.env.JWT_SECRET ?? "dev-secret";

export interface AuthedRequest extends Request {
  userId?: string;
}

export function requireAuth(req: AuthedRequest, _res: Response, next: NextFunction) {
  const header = req.headers.authorization ?? "";
  const token = header.startsWith("Bearer ") ? header.slice(7) : "";
  if (!token) return next(new AppError(401, "UNAUTHENTICATED", "Missing bearer token"));
  try {
    const payload = jwt.verify(token, SECRET) as { sub: string };
    req.userId = payload.sub;
    next();
  } catch {
    next(new AppError(401, "TOKEN_EXPIRED", "Token invalid or expired"));
  }
}
```

`fixtures/sample-workspace/bff/src/services/identity.ts`:
```ts
import axios from "axios";

const IDENTITY_URL = process.env.IDENTITY_URL ?? "http://identity.internal";

export interface Credentials {
  email: string;
  password: string;
}

export async function verifyCredentials(creds: Credentials): Promise<{ userId: string } | null> {
  const res = await axios.post(`${IDENTITY_URL}/verify`, creds, { validateStatus: () => true });
  if (res.status === 200) return { userId: res.data.id };
  return null;
}
```

`fixtures/sample-workspace/bff/src/services/catalog.ts`:
```ts
export interface Product {
  id: string;
  name: string;
  priceCents: number;
  hidden: boolean;
}

const PRODUCTS: Product[] = [
  { id: "p1", name: "Teclado", priceCents: 4990, hidden: false },
  { id: "p2", name: "Mouse", priceCents: 1990, hidden: false },
  { id: "p3", name: "Monitor (descontinuado)", priceCents: 0, hidden: true },
];

export function listProducts(): Product[] {
  return PRODUCTS.filter((p) => !p.hidden);
}

export function findProduct(id: string): Product | undefined {
  return PRODUCTS.find((p) => p.id === id);
}

export function getPriceCents(id: string): number {
  const p = findProduct(id);
  if (!p) throw new Error(`unknown product ${id}`);
  return p.priceCents;
}
```

`fixtures/sample-workspace/bff/src/routes/auth.ts`:
```ts
import { Router } from "express";
import jwt from "jsonwebtoken";
import { z } from "zod";
import { AppError } from "../errors";
import { verifyCredentials } from "../services/identity";

const SECRET = process.env.JWT_SECRET ?? "dev-secret";
const loginSchema = z.object({ email: z.string().email(), password: z.string().min(8) });

export const authRouter = Router();

authRouter.post("/login", async (req, res, next) => {
  const parsed = loginSchema.safeParse(req.body);
  if (!parsed.success) return next(new AppError(400, "VALIDATION", "Invalid credentials payload"));
  const user = await verifyCredentials(parsed.data);
  if (!user) return next(new AppError(401, "BAD_CREDENTIALS", "Email or password incorrect"));
  const accessToken = jwt.sign({ sub: user.userId }, SECRET, { expiresIn: "15m" });
  const refreshToken = jwt.sign({ sub: user.userId, type: "refresh" }, SECRET, { expiresIn: "7d" });
  res.json({ accessToken, refreshToken });
});

authRouter.post("/refresh", (req, res, next) => {
  const { refreshToken } = req.body ?? {};
  if (!refreshToken) return next(new AppError(400, "VALIDATION", "refreshToken required"));
  try {
    const payload = jwt.verify(refreshToken, SECRET) as { sub: string; type?: string };
    if (payload.type !== "refresh") throw new Error("wrong token type");
    res.json({ accessToken: jwt.sign({ sub: payload.sub }, SECRET, { expiresIn: "15m" }) });
  } catch {
    next(new AppError(401, "TOKEN_EXPIRED", "Refresh token invalid or expired"));
  }
});
```

`fixtures/sample-workspace/bff/src/routes/products.ts` (contiene la ambigüedad deliberada: 200 vacío para ocultos, 404 para inexistentes, sin comentario):
```ts
import { Router } from "express";
import { findProduct, listProducts } from "../services/catalog";

export const productsRouter = Router();

productsRouter.get("/", (_req, res) => {
  res.json({ items: listProducts() });
});

productsRouter.get("/:id", (req, res) => {
  const product = findProduct(req.params.id);
  if (!product) return res.status(404).end();
  if (product.hidden) return res.status(200).end();
  res.json(product);
});
```

`fixtures/sample-workspace/bff/src/routes/cart.ts` (dependencia cruzada con el catálogo):
```ts
import { Router } from "express";
import { z } from "zod";
import { AppError } from "../errors";
import { AuthedRequest, requireAuth } from "../middleware/auth";
import { findProduct, getPriceCents } from "../services/catalog";

interface CartLine {
  productId: string;
  qty: number;
}

const carts = new Map<string, CartLine[]>();
const addSchema = z.object({ productId: z.string(), qty: z.number().int().min(1).max(10) });

export const cartRouter = Router();
cartRouter.use(requireAuth);

cartRouter.get("/", (req: AuthedRequest, res) => {
  const lines = carts.get(req.userId!) ?? [];
  const items = lines.map((l) => ({ ...l, unitPriceCents: getPriceCents(l.productId) }));
  const totalCents = items.reduce((sum, i) => sum + i.unitPriceCents * i.qty, 0);
  res.json({ items, totalCents });
});

cartRouter.post("/items", (req: AuthedRequest, res, next) => {
  const parsed = addSchema.safeParse(req.body);
  if (!parsed.success) return next(new AppError(400, "VALIDATION", "productId and qty 1-10 required"));
  const product = findProduct(parsed.data.productId);
  if (!product || product.hidden) return next(new AppError(404, "PRODUCT_NOT_FOUND", "Product not available"));
  const lines = carts.get(req.userId!) ?? [];
  const existing = lines.find((l) => l.productId === parsed.data.productId);
  if (existing) existing.qty = Math.min(10, existing.qty + parsed.data.qty);
  else lines.push(parsed.data);
  carts.set(req.userId!, lines);
  res.status(201).json({ items: lines });
});

cartRouter.delete("/items/:productId", (req: AuthedRequest, res) => {
  const lines = (carts.get(req.userId!) ?? []).filter((l) => l.productId !== req.params.productId);
  carts.set(req.userId!, lines);
  res.status(204).end();
});
```

`fixtures/sample-workspace/bff/tests/cart.test.ts`:
```ts
import { getPriceCents } from "../src/services/catalog";

describe("catalog prices", () => {
  it("returns the price of a known product", () => {
    expect(getPriceCents("p1")).toBe(4990);
  });
  it("throws on unknown product", () => {
    expect(() => getPriceCents("nope")).toThrow();
  });
});
```

`fixtures/sample-workspace/bff/tests/__snapshots__/cart.test.ts.snap`:
```
// Jest Snapshot v1, https://goo.gl/fbAQLP

exports[`cart total 1`] = `
Object {
  "totalCents": 6980,
}
`;
```

`fixtures/sample-workspace/bff/dist/server.js` (queda fuera de git por `.gitignore`, pero existe en disco):
```js
"use strict";var e=require("express"),a=e();a.use(e.json());a.listen(3000);
```

- [ ] **Step 4: Crear el fixture del frontend**

`fixtures/sample-workspace/frontend/package.json`:
```json
{
  "name": "shop-frontend",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "test": "vitest"
  },
  "dependencies": {
    "react": "^18.3.0",
    "react-dom": "^18.3.0",
    "react-router-dom": "^6.26.0"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.3.0",
    "typescript": "^5.5.0",
    "vite": "^5.4.0",
    "vitest": "^2.0.0"
  }
}
```

`fixtures/sample-workspace/frontend/package-lock.json`:
```json
{
  "name": "shop-frontend",
  "version": "1.0.0",
  "lockfileVersion": 3,
  "packages": {
    "": { "name": "shop-frontend", "version": "1.0.0" },
    "node_modules/react": { "version": "18.3.1", "resolved": "https://registry.npmjs.org/react/-/react-18.3.1.tgz" }
  }
}
```

`fixtures/sample-workspace/frontend/.gitignore`:
```
node_modules/
dist/
```

`fixtures/sample-workspace/frontend/index.html`:
```html
<!doctype html>
<html lang="es">
  <head><meta charset="UTF-8" /><title>Shop</title></head>
  <body><div id="root"></div><script type="module" src="/src/main.tsx"></script></body>
</html>
```

`fixtures/sample-workspace/frontend/vite.config.ts`:
```ts
import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";

export default defineConfig({
  plugins: [react()],
  server: { proxy: { "/api": { target: "http://localhost:3000", rewrite: (p) => p.replace(/^\/api/, "") } } },
});
```

`fixtures/sample-workspace/frontend/src/main.tsx`:
```tsx
import React from "react";
import ReactDOM from "react-dom/client";
import { BrowserRouter, Route, Routes } from "react-router-dom";
import { Cart } from "./pages/Cart";
import { Login } from "./pages/Login";
import { Products } from "./pages/Products";

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route path="/" element={<Products />} />
        <Route path="/cart" element={<Cart />} />
      </Routes>
    </BrowserRouter>
  </React.StrictMode>,
);
```

`fixtures/sample-workspace/frontend/src/store/session.ts`:
```ts
const KEY = "shop.session";

export interface Session {
  accessToken: string;
  refreshToken: string;
}

export function getSession(): Session | null {
  const raw = localStorage.getItem(KEY);
  return raw ? (JSON.parse(raw) as Session) : null;
}

export function setSession(s: Session | null) {
  if (s) localStorage.setItem(KEY, JSON.stringify(s));
  else localStorage.removeItem(KEY);
}
```

`fixtures/sample-workspace/frontend/src/api/client.ts`:
```ts
import { getSession, setSession } from "../store/session";

async function refresh(): Promise<boolean> {
  const s = getSession();
  if (!s) return false;
  const res = await fetch("/api/auth/refresh", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ refreshToken: s.refreshToken }),
  });
  if (!res.ok) {
    setSession(null);
    return false;
  }
  const { accessToken } = await res.json();
  setSession({ ...s, accessToken });
  return true;
}

export async function api(path: string, init: RequestInit = {}, retry = true): Promise<Response> {
  const s = getSession();
  const headers = new Headers(init.headers);
  headers.set("Content-Type", "application/json");
  if (s) headers.set("Authorization", `Bearer ${s.accessToken}`);
  const res = await fetch(`/api${path}`, { ...init, headers });
  if (res.status === 401 && retry && (await refresh())) return api(path, init, false);
  if (res.status === 401) window.location.assign("/login");
  return res;
}
```

`fixtures/sample-workspace/frontend/src/pages/Login.tsx`:
```tsx
import { FormEvent, useState } from "react";
import { useNavigate } from "react-router-dom";
import { api } from "../api/client";
import { setSession } from "../store/session";

export function Login() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const navigate = useNavigate();

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    const res = await api("/auth/login", { method: "POST", body: JSON.stringify({ email, password }) });
    if (!res.ok) {
      const body = await res.json().catch(() => null);
      setError(body?.error?.code === "BAD_CREDENTIALS" ? "Correo o contraseña incorrectos" : "Error inesperado");
      return;
    }
    setSession(await res.json());
    navigate("/");
  }

  return (
    <form onSubmit={onSubmit}>
      <input value={email} onChange={(e) => setEmail(e.target.value)} placeholder="Correo" />
      <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} placeholder="Contraseña" />
      {error && <p role="alert">{error}</p>}
      <button type="submit">Entrar</button>
    </form>
  );
}
```

`fixtures/sample-workspace/frontend/src/pages/Products.tsx`:
```tsx
import { useEffect, useState } from "react";
import { api } from "../api/client";

interface Product {
  id: string;
  name: string;
  priceCents: number;
}

export function Products() {
  const [items, setItems] = useState<Product[]>([]);

  useEffect(() => {
    api("/products").then((r) => r.json()).then((b) => setItems(b.items));
  }, []);

  async function add(id: string) {
    await api("/cart/items", { method: "POST", body: JSON.stringify({ productId: id, qty: 1 }) });
  }

  return (
    <ul>
      {items.map((p) => (
        <li key={p.id}>
          {p.name} — ${(p.priceCents / 100).toFixed(2)}
          <button onClick={() => add(p.id)}>Agregar</button>
        </li>
      ))}
    </ul>
  );
}
```

`fixtures/sample-workspace/frontend/src/pages/Cart.tsx`:
```tsx
import { useEffect, useState } from "react";
import { api } from "../api/client";

interface Line {
  productId: string;
  qty: number;
  unitPriceCents: number;
}

export function Cart() {
  const [lines, setLines] = useState<Line[]>([]);
  const [total, setTotal] = useState(0);

  async function load() {
    const b = await api("/cart").then((r) => r.json());
    setLines(b.items);
    setTotal(b.totalCents);
  }

  useEffect(() => {
    load();
  }, []);

  async function remove(id: string) {
    await api(`/cart/items/${id}`, { method: "DELETE" });
    await load();
  }

  return (
    <div>
      <ul>
        {lines.map((l) => (
          <li key={l.productId}>
            {l.productId} × {l.qty} — ${((l.unitPriceCents * l.qty) / 100).toFixed(2)}
            <button onClick={() => remove(l.productId)}>Quitar</button>
          </li>
        ))}
      </ul>
      <p>Total: ${(total / 100).toFixed(2)}</p>
    </div>
  );
}
```

`fixtures/sample-workspace/frontend/public/logo.png` (archivo binario de 8 bytes, cabecera PNG):

Run: `mkdir -p fixtures/sample-workspace/frontend/public && printf '\x89PNG\r\n\x1a\n' > fixtures/sample-workspace/frontend/public/logo.png`

- [ ] **Step 5: Escribir `scripts/fixture-reset.sh`**

```bash
#!/usr/bin/env bash
# Copia el fixture a .work/sample-workspace, inicializa git en cada repo
# y copia los agentes al .claude/agents del workspace.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$ROOT/.work/sample-workspace"

rm -rf "$WORK"
mkdir -p "$ROOT/.work"
cp -r "$ROOT/fixtures/sample-workspace" "$WORK"

for repo in "$WORK"/*/; do
  (
    cd "$repo"
    git init -q
    git add -A
    git -c user.name=fixture -c user.email=fixture@example.com commit -qm "fixture"
  )
done

mkdir -p "$WORK/.claude/agents"
if ls "$ROOT"/agents/*.md >/dev/null 2>&1; then
  cp "$ROOT"/agents/*.md "$WORK/.claude/agents/"
fi
echo "workspace listo en $WORK"
```

- [ ] **Step 6: Escribir `scripts/run-agent.sh`**

```bash
#!/usr/bin/env bash
# Ejecuta un subagente en el workspace de prueba con claude -p.
# Uso: scripts/run-agent.sh <nombre-agente> [texto adicional para el prompt]
# Variables: WORKDIR (carpeta donde correr; por defecto .work/sample-workspace)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AGENT="${1:?nombre del agente}"
shift || true
EXTRA="${*:-}"
DIR="${WORKDIR:-$ROOT/.work/sample-workspace}"

cd "$DIR"
claude -p "Invoca el subagente $AGENT con la herramienta Agent, sobre la carpeta actual. $EXTRA Cuando termine, reproduce su resumen final tal cual y no hagas nada más." \
  --dangerously-skip-permissions
```

Nota: `--dangerously-skip-permissions` es aceptable porque el workspace es una copia descartable. Nunca usar este script fuera de `.work/`.

- [ ] **Step 7: Ejecutar el test del fixture y verificar que pasa**

Run: `bash scripts/test-fixture.sh`
Expected: `OK: fixture`, salida 0.

- [ ] **Step 8: Verificar que `git status` no muestra `.work/`**

Run: `git status --short`
Expected: aparecen `fixtures/` y `scripts/` como nuevos, y nada bajo `.work/`.

- [ ] **Step 9: Commit**

```bash
git add fixtures scripts/fixture-reset.sh scripts/run-agent.sh scripts/test-fixture.sh docs/specs
git commit -m "test: fixture sample-workspace y scripts de corrida

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 3: Agente `migration-indexer`

**Files:**
- Create: `agents/migration-indexer.md`
- Create: `scripts/verify-indexer.sh`

**Interfaces:**
- Produces en el workspace: `<repo>/index.md` por repo; `migration/README.md` con frontmatter `destino:` y `generado:`; `migration/templates/{adr,spec,task,test-plan,backlog}.md`.
- Los agentes siguientes leen `index.md` y `migration/templates/*.md`.

- [ ] **Step 1: Escribir `scripts/verify-indexer.sh`**

```bash
#!/usr/bin/env bash
# Verifica los artefactos del indexador en .work/sample-workspace.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="${WORKDIR:-$ROOT/.work/sample-workspace}"
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }

for r in frontend bff; do
  f="$W/$r/index.md"
  [ -f "$f" ] || { fail "$r/index.md no existe"; continue; }
  grep -q "^# Índice: $r" "$f" || fail "$r/index.md sin encabezado '# Índice: $r'"
  for k in "Stack:" "Entrada:" "Build:" "Dependencias clave:" "Generado:"; do
    grep -q "^$k" "$f" || fail "$r/index.md sin línea '$k'"
  done
  grep -q '^## ' "$f" || fail "$r/index.md sin secciones por carpeta"
  grep -q 'Índice incompleto' "$f" && fail "$r/index.md marcado incompleto"
done

# Exclusiones fijas (los archivos están trackeados en git, así que solo la lista fija los saca)
grep -q 'package-lock.json' "$W/bff/index.md" && fail "bff: lockfile indexado"
grep -q 'package-lock.json' "$W/frontend/index.md" && fail "frontend: lockfile indexado"
grep -q '\.snap' "$W/bff/index.md" && fail "bff: snapshot indexado"
grep -q 'logo.png' "$W/frontend/index.md" && fail "frontend: imagen indexada"
grep -q '`server.js`' "$W/bff/index.md" && fail "bff: dist/server.js indexado"

# Inclusiones: todo archivo de código y de configuración relevante
for f in server.ts errors.ts auth.ts products.ts cart.ts identity.ts catalog.ts cart.test.ts package.json tsconfig.json .env.example; do
  grep -q "\`$f\`" "$W/bff/index.md" || fail "bff: falta $f en el índice"
done
for f in main.tsx client.ts session.ts Login.tsx Products.tsx Cart.tsx package.json vite.config.ts index.html; do
  grep -q "\`$f\`" "$W/frontend/index.md" || fail "frontend: falta $f en el índice"
done

# Bootstrap de migration/
[ -f "$W/migration/README.md" ] || fail "migration/README.md no existe"
grep -q '^destino:' "$W/migration/README.md" || fail "README sin campo destino"
grep -q 'migration-indexer' "$W/migration/README.md" || fail "README sin flujo"
for t in adr spec task test-plan backlog; do
  [ -f "$W/migration/templates/$t.md" ] || fail "falta plantilla $t.md"
done
grep -q '^## 12\. Preguntas abiertas' "$W/migration/templates/spec.md" || fail "spec.md sin sección 12"
grep -q '^bloqueada_por:' "$W/migration/templates/task.md" || fail "task.md sin bloqueada_por"
grep -q '^implicacion_migracion:' "$W/migration/templates/adr.md" || fail "adr.md sin implicacion_migracion"

[ "$fails" -eq 0 ] && { echo "OK: indexer"; exit 0; }
exit 1
```

- [ ] **Step 2: Ejecutar el verificador sobre un workspace limpio y comprobar que falla**

Run: `bash scripts/fixture-reset.sh && bash scripts/verify-indexer.sh`
Expected: varios `FAIL:` empezando por `frontend/index.md no existe`; salida 1.

- [ ] **Step 3: Escribir `agents/migration-indexer.md`**

````markdown
---
name: migration-indexer
description: Primer paso del flujo de migración. Genera un index.md por repositorio con los archivos de código real y dos líneas de resumen por archivo, y crea la carpeta migration/ con README y plantillas. Ejecutar desde la carpeta padre que contiene los repositorios, nunca desde dentro de uno.
tools: Read, Glob, Grep, Bash, Write, Edit
---

Eres el indexador del flujo de migración. Produces un mapa fiel del código de cada repositorio y preparas la carpeta `migration/`. Todo lo que escribes va en español. No ejecutas el código del proyecto, no instalas nada y no modificas ningún archivo de los repositorios salvo `index.md` en su raíz.

## 1. Detectar repositorios

Lista las subcarpetas directas de la carpeta actual. Un repositorio es una subcarpeta que contiene alguno de: `.git`, `package.json`, `pom.xml`, `build.gradle`, `build.gradle.kts`, `go.mod`, `pyproject.toml`, `Cargo.toml`, `composer.json`. Ignora `migration/`, `.claude/` y carpetas ocultas.

Si no detectas ningún repositorio, detente sin crear nada y responde exactamente con este mensaje, sustituyendo la ruta:

> No encontré repositorios en `<ruta actual>`. Este agente debe ejecutarse desde la carpeta padre que contiene los repositorios (por ejemplo, la que contiene `frontend/` y `bff/`), no desde dentro de uno de ellos.

## 2. Listar archivos candidatos por repositorio

Para cada repositorio:

- Si tiene `.git`, ejecuta `git -C <repo> ls-files` para obtener la lista. Esto ya excluye lo que está en `.gitignore`.
- Si no tiene `.git`, usa Glob con `<repo>/**/*` y descarta cualquier ruta que contenga `node_modules/`, `.git/`, `vendor/`, `target/`, `.venv/` o `__pycache__/`.

Sobre esa lista aplica las exclusiones fijas. Descarta:

- Lockfiles: `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `bun.lockb`, `Gemfile.lock`, `poetry.lock`, `Cargo.lock`, `composer.lock`, `gradle.lockfile`.
- Binarios e imágenes: `.png`, `.jpg`, `.jpeg`, `.gif`, `.webp`, `.svg`, `.ico`, `.pdf`, `.zip`, `.jar`, `.exe`, `.dll`, `.so`, `.wasm`.
- Fuentes: `.woff`, `.woff2`, `.ttf`, `.otf`, `.eot`.
- Carpetas de salida: cualquier ruta bajo `dist/`, `build/`, `out/`, `coverage/`, `.next/`, `.nuxt/`, `.turbo/`, `.cache/`.
- Minificados: nombres que contengan `.min.`.
- Snapshots de test: rutas bajo `__snapshots__/` y archivos `.snap`.
- Generados: nombres que contengan `.generated.`; archivos `.d.ts` que estén junto a un `.js` del mismo nombre.
- Fixtures de test mayores a 50 KB: archivos bajo `fixtures/`, `__fixtures__/` o `testdata/` cuyo tamaño supere 50 KB.

Conserva siempre, aunque parezcan configuración: `package.json`, `tsconfig*.json`, `vite.config.*`, `webpack.config.*`, `next.config.*`, `.eslintrc*`, `eslint.config.*`, `.prettierrc*`, `.env.example`, `Dockerfile*`, `docker-compose*`, archivos bajo `.github/workflows/`, `Makefile`, `pom.xml`, `build.gradle*`, `settings.gradle*`, `go.mod`, `pyproject.toml`, `Cargo.toml`.

## 3. Resumir cada archivo

Lee cada archivo conservado con Read. Escribe exactamente dos frases:

1. Qué contiene: el tipo de artefacto y sus elementos principales (rutas expuestas, componentes, funciones exportadas, esquemas, configuración).
2. Para qué se usa o quién lo consume: su papel en el sistema, con qué otros archivos se relaciona.

Si el archivo supera 300 líneas, lee las primeras 80 líneas y luego usa Grep sobre él para localizar `export`, `function`, `class`, `router.`, `app.` y definiciones de tipos. Añade al final de la segunda frase: "(resumen a partir de encabezado y firmas)".

Sé concreto. "Rutas de autenticación" es peor que "Endpoints POST /login y POST /refresh que emiten JWT tras validar contra el servicio de identidad".

## 4. Escribir `index.md` de forma incremental

Escribe `<repo>/index.md` con este formato:

```markdown
# Índice: <nombre de la carpeta del repo>

Stack: <lenguaje, runtime y frameworks principales, inferidos de package.json o equivalente>
Entrada: <archivo o comando de arranque>
Build: <comando>. Tests: <comando y framework>.
Dependencias clave: <5 a 10 dependencias más relevantes, separadas por coma>
Generado: <fecha de hoy AAAA-MM-DD> por migration-indexer

## <carpeta relativa, o "raíz" para archivos en la raíz>
- `<nombre de archivo>` — <frase 1>. <frase 2>.
```

Procedimiento obligatorio para que un corte deje un índice usable:

1. Escribe el archivo con Write conteniendo solo el encabezado y la primera sección de carpeta.
2. Por cada carpeta siguiente, añade su sección al final del archivo con Edit (usa como `old_string` la última línea que escribiste y como `new_string` esa misma línea seguida de la nueva sección).
3. Agrupa por carpeta en orden alfabético, y dentro de cada carpeta los archivos en orden alfabético. Los archivos de la raíz van en la sección `## raíz`, al principio.
4. Si detectas que te estás quedando sin capacidad para continuar, escribe como última línea `> Índice incompleto: falta desde <carpeta>` y termina informándolo.

Si ya existe `index.md`, sobreescríbelo completo. El índice es derivado del código y no se edita a mano.

## 5. Bootstrapear `migration/`

Si `migration/README.md` no existe, créalo con este contenido, rellenando fecha y repos:

```markdown
---
destino:
generado: <AAAA-MM-DD>
---
# Migración

## Flujo
1. [x] migration-indexer — <AAAA-MM-DD>
2. [ ] migration-techlead — indicar el lenguaje destino en `destino:` arriba o en el prompt
3. [ ] migration-qa
4. [ ] migration-pm

## Repos detectados
- <repo>: <stack en una línea>

## Cómo continuar
Revisa los `index.md` de cada repo. Luego, desde esta misma carpeta, pide: "Usa el subagente migration-techlead con destino <lenguaje>".
```

Si `migration/README.md` ya existe, no lo toques.

Crea `migration/templates/` y escribe cada plantilla de abajo **solo si el archivo no existe**. Nunca sobreescribas una plantilla existente, aunque difiera de la tuya: el equipo puede haberla ajustado.

### Plantilla `migration/templates/adr.md`

```markdown
---
id: 0000
titulo:
estado: observado
fecha:
implicacion_migracion:
---
<!-- estado: observado (decisión que el código ya tomó) | propuesto (decisión que la migración obliga a tomar) | revisado (validado por un humano; no se regenera) -->
<!-- implicacion_migracion: conservar | reemplazar | reevaluar. Solo en observados. -->
# ADR 0000: <título>

## Contexto
<!-- Qué problema o necesidad resuelve la decisión. En observados: qué se ve en el código que la revela. -->

## Decisión
<!-- Observados: lo que el código hace hoy, en términos de diseño, no de sintaxis. Propuestos: opciones numeradas con ventajas y desventajas, y una recomendación marcada explícitamente. -->

## Evidencia
<!-- Rutas de archivo del código original que sustentan la decisión. Solo rutas, sin fragmentos de código. -->

## Consecuencias
<!-- Efectos positivos y negativos de la decisión tal como está. -->

## Implicación para la migración
<!-- Observados: conservar, reemplazar o reevaluar, con justificación. Propuestos: qué tareas quedan bloqueadas hasta que un humano decida. -->
```

### Plantilla `migration/templates/spec.md`

```markdown
---
capacidad:
estado: generado
repos: []
adrs: []
---
<!-- estado: generado | revisado. Un spec revisado no se regenera. -->
# Spec: <nombre de la capacidad>

## 1. Resumen
<!-- Dos o tres frases: qué permite hacer esta capacidad y a quién. -->

## 2. Actores
<!-- Usuarios, sistemas externos o procesos que participan. -->

## 3. Alcance por repo
<!-- Qué parte de la capacidad vive en cada repositorio. -->

## 4. Flujos de comportamiento
<!-- Paso a paso de cada flujo, en listas numeradas. Sin código. -->

## 5. Contratos de API
<!-- Por cada endpoint: método, ruta, forma de entrada, forma de salida, códigos de error y su significado. Tipos genéricos: texto, entero, decimal, booleano, lista de X, opcional. -->

## 6. Modelos de datos
<!-- Entidades y campos con tipos genéricos, relaciones y restricciones. -->

## 7. Reglas de negocio
<!-- Numeradas RN-1, RN-2... Una regla por línea, verificable. -->

## 8. Casos borde y errores
<!-- Numerados CB-1, CB-2... Qué pasa ante entradas inválidas, ausencias, límites, fallos externos. -->

## 9. Dependencias externas
<!-- Servicios, APIs o librerías de terceros de las que depende la capacidad, y para qué. -->

## 10. ADRs relacionados
<!-- Lista de ids de ADR con una línea de por qué aplican. -->

## 11. Evidencia en el código original
<!-- Rutas de archivo. Solo rutas. -->

## 12. Preguntas abiertas
<!-- Todo lo que no se pudo determinar con certeza a partir del código. Nunca se inventa comportamiento: se anota aquí. -->
```

### Plantilla `migration/templates/task.md`

```markdown
---
id: T-000
titulo:
spec:
repo_destino:
depende_de: []
tamaño: M
adrs: []
estado: generado
fase:
prioridad:
bloqueada_por: []
---
<!-- spec: nombre de archivo del spec sin extensión; vacío en tareas fundacionales. -->
<!-- tamaño: S (menos de medio día), M (uno o dos días), L (más de dos días). -->
<!-- fase y prioridad: los rellena migration-pm. -->
<!-- bloqueada_por: ids de ADR propuestos sin revisar o "PA:<spec>:<n>" para preguntas abiertas. -->
# T-000: <título>

## Objetivo
<!-- Qué queda construido cuando esta tarea termina. -->

## Criterios de aceptación
<!-- Lista verificable. Cita las RN y CB del spec que cubre. -->

## Notas para el destino
<!-- Indicaciones específicas del lenguaje o framework destino. Aquí sí se nombra la tecnología. -->
```

### Plantilla `migration/templates/test-plan.md`

```markdown
---
capacidad:
spec:
estado: generado
---
<!-- El nombre de archivo debe ser el mismo que el del spec. -->
# Plan de pruebas: <capacidad>

## Alcance y supuestos
<!-- Qué cubre este plan y qué da por sentado. -->

## Matriz de cobertura
<!-- Tabla: RN o CB del spec → ids de casos que lo cubren. Incluir filas sin cobertura marcadas como "sin cubrir". -->

## Casos: camino feliz
<!-- Cada caso con el formato de abajo. -->

## Casos: casos borde
## Casos: errores
## Casos: contratos de API

<!-- Formato de cada caso:
### TC-<capacidad>-<nnn>: <título>
- Prioridad: crítica | alta | media
- Nivel sugerido: unitario | integración | extremo a extremo
- Cubre: <RN-n, CB-n, contrato ...>
- Tareas: <ids de tarea>
- Dado <estado inicial>
- Cuando <acción>
- Entonces <resultado observable>
-->

## Casos pendientes de definición
<!-- Uno por pregunta abierta del spec, citando la pregunta. Sin resultado esperado. -->

## Hallazgos para el tech lead
<!-- Ambigüedades del spec que impidieron escribir un caso. -->
```

### Plantilla `migration/templates/backlog.md`

```markdown
---
generado:
---
# Backlog de migración

## Resumen ejecutivo
<!-- Cantidad de tareas, fases, tareas bloqueadas, tamaño total por fase. -->

## Criterio de priorización
<!-- Fijo: (a) fundacionales y las que desbloquean más tareas; (b) capacidades con más dependientes o con ADRs marcados reemplazar/reevaluar; (c) el resto. -->

## Fases
<!-- ### Hito 0: fundaciones
| Orden | Tarea | Título | Tamaño | Depende de |
Cada fase termina con al menos una capacidad completa. -->

## Bloqueos
<!-- Tabla: tarea, motivo (ADR propuesto sin revisar o pregunta abierta), qué se necesita para desbloquear. -->

## Riesgos
<!-- Riesgos detectados durante la planificación. -->
```

## 6. Resumen final

Termina siempre con este resumen:

- Repositorios detectados y cantidad de archivos indexados en cada uno.
- Archivos creados y archivos sobreescritos.
- Índices incompletos, si los hay.
- Siguiente paso: revisar los `index.md`, rellenar `destino:` en `migration/README.md` o pasarlo por prompt, y ejecutar `migration-techlead`.
````

- [ ] **Step 4: Validar la estructura del agente**

Run: `bash scripts/check-agent.sh agents/migration-indexer.md`
Expected: `OK: 1 agente(s) válido(s)`.

- [ ] **Step 5: Correr el agente sobre el fixture**

Run: `bash scripts/fixture-reset.sh && bash scripts/run-agent.sh migration-indexer`
Expected: la respuesta termina con un resumen que menciona `frontend` y `bff`, la cantidad de archivos indexados y el siguiente paso.

- [ ] **Step 6: Ejecutar el verificador**

Run: `bash scripts/verify-indexer.sh`
Expected: `OK: indexer`. Si falla, corregir el prompt del agente (no el verificador, salvo que el verificador tenga un error evidente), volver a Step 5.

- [ ] **Step 7: Revisión manual del índice**

Run: `cat .work/sample-workspace/bff/index.md`
Comprobar a ojo: cada archivo tiene dos frases; las frases son concretas (mencionan rutas o funciones reales); no hay archivos de `dist/`. Si los resúmenes son vagos, ajustar la sección 3 del prompt con un ejemplo negativo más y repetir desde Step 5.

- [ ] **Step 8: Segunda corrida no marca nada como incompleto y regenera el índice**

Run: `bash scripts/run-agent.sh migration-indexer && bash scripts/verify-indexer.sh`
Expected: `OK: indexer`.

- [ ] **Step 9: Test de Review Focus 1, ejecución desde dentro de un repo**

Run: `WORKDIR=.work/sample-workspace/bff bash scripts/run-agent.sh migration-indexer; ls .work/sample-workspace/bff`
Expected: la respuesta contiene "carpeta padre"; en `bff/` no aparece ninguna carpeta `migration/` nueva y no hay `index.md` dentro de `bff/src`.

- [ ] **Step 10: Test de Review Focus 2, repo sin `.git`**

Run: `bash scripts/fixture-reset.sh && rm -rf .work/sample-workspace/frontend/.git && bash scripts/run-agent.sh migration-indexer && bash scripts/verify-indexer.sh`
Expected: `OK: indexer` (el frontend se indexó por listado recursivo y las exclusiones fijas siguen aplicando).

- [ ] **Step 11: Test de Review Focus 3, plantilla modificada sobrevive**

Run:
```bash
bash scripts/fixture-reset.sh && bash scripts/run-agent.sh migration-indexer
echo "## Sección personalizada del equipo" >> .work/sample-workspace/migration/templates/spec.md
bash scripts/run-agent.sh migration-indexer
grep -q "Sección personalizada del equipo" .work/sample-workspace/migration/templates/spec.md && echo "OK: plantilla preservada" || echo "FAIL: plantilla sobreescrita"
```
Expected: `OK: plantilla preservada`.

- [ ] **Step 12: Commit**

```bash
git add agents/migration-indexer.md scripts/verify-indexer.sh
git commit -m "feat: agente migration-indexer con bootstrap de plantillas

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 4: Agente `migration-techlead`

**Files:**
- Create: `agents/migration-techlead.md`
- Create: `scripts/verify-techlead.sh`

**Interfaces:**
- Consumes: `<repo>/index.md`, `migration/templates/{adr,spec,task}.md`, `destino:` en `migration/README.md` o en el prompt.
- Produces: `migration/specs/_capacidades.md` (tabla con columnas Capacidad, Descripción, Repos, Archivos principales); `migration/specs/<capacidad>.md` (frontmatter `capacidad`, `estado`, `repos`, `adrs`; 12 secciones `## N. …`); `migration/adr/NNNN-<slug>.md` (frontmatter `id`, `titulo`, `estado`, `fecha`, `implicacion_migracion`); `migration/tasks/T-NNN-<slug>.md` (frontmatter según plantilla task.md). Los nombres de capacidad son slugs en minúsculas sin acentos ni espacios (guiones).

- [ ] **Step 1: Escribir `scripts/verify-techlead.sh`**

```bash
#!/usr/bin/env bash
# Verifica los artefactos del tech lead en .work/sample-workspace/migration.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="${WORKDIR:-$ROOT/.work/sample-workspace}"
M="$W/migration"
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }

# Mapa de capacidades
[ -f "$M/specs/_capacidades.md" ] || fail "_capacidades.md no existe"
rows=$(grep -c '^| [a-z0-9-]* |' "$M/specs/_capacidades.md" 2>/dev/null || echo 0)
[ "$rows" -ge 3 ] || fail "_capacidades.md tiene $rows filas, se esperaban al menos 3"

# Specs
specs=$(ls "$M"/specs/*.md 2>/dev/null | grep -v '/_' || true)
[ -n "$specs" ] || fail "no hay specs"
for s in $specs; do
  n=$(basename "$s")
  for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
    grep -q "^## $i\. " "$s" || fail "$n: falta la sección $i"
  done
  grep -q '^estado: ' "$s" || fail "$n: sin estado"
  grep -q 'RN-1' "$s" || fail "$n: sin reglas numeradas RN-n"
  grep -q 'CB-1' "$s" || fail "$n: sin casos borde numerados CB-n"
  # Sin código JS/TS en el cuerpo
  if grep -Eq '^\s*(import |export |const |let |function |=> |app\.use|router\.(get|post))' "$s"; then
    fail "$n: contiene código del lenguaje origen"
  fi
  grep -q '```' "$s" && fail "$n: contiene bloques de código"
done

# La ambigüedad de products debe aparecer como pregunta abierta en algún spec
if ! grep -l '^## 12\. Preguntas abiertas' $specs | xargs -I{} awk '/^## 12\. Preguntas abiertas/{f=1;next} f' {} | grep -Eiq '200|vac[ií]o|oculto|hidden'; then
  fail "ninguna pregunta abierta menciona el caso del producto oculto (200 vacío vs 404)"
fi

# ADRs
[ -d "$M/adr" ] || fail "no hay carpeta adr"
grep -lq '^estado: observado' "$M"/adr/*.md 2>/dev/null || fail "no hay ADR observado"
grep -lq '^estado: propuesto' "$M"/adr/*.md 2>/dev/null || fail "no hay ADR propuesto"
for a in "$M"/adr/*.md; do
  n=$(basename "$a")
  echo "$n" | grep -Eq '^[0-9]{4}-[a-z0-9-]+\.md$' || fail "$n: nombre no sigue NNNN-slug.md"
  grep -q '^## Implicación para la migración' "$a" || fail "$n: sin sección de implicación"
  grep -q '^## Evidencia' "$a" || fail "$n: sin evidencia"
done

# Tareas
tasks=$(ls "$M"/tasks/T-*.md 2>/dev/null || true)
[ -n "$tasks" ] || fail "no hay tareas"
fund=0
for t in $tasks; do
  n=$(basename "$t")
  echo "$n" | grep -Eq '^T-[0-9]{3}-[a-z0-9-]+\.md$' || fail "$n: nombre no sigue T-NNN-slug.md"
  id=$(sed -n 's/^id:[[:space:]]*//p' "$t" | head -n1)
  case "$n" in "$id"-*) ;; *) fail "$n: id '$id' no coincide con el archivo";; esac
  grep -q '^estado: ' "$t" || fail "$n: sin estado"
  grep -q '^depende_de: ' "$t" || fail "$n: sin depende_de"
  grep -q '^tamaño: [SML]$' "$t" || fail "$n: tamaño inválido"
  grep -q '^## Criterios de aceptación' "$t" || fail "$n: sin criterios de aceptación"
  spec=$(sed -n 's/^spec:[[:space:]]*//p' "$t" | head -n1)
  if [ -z "$spec" ]; then
    fund=$((fund+1))
  else
    [ -f "$M/specs/$spec.md" ] || fail "$n: spec '$spec' no existe"
  fi
done
[ "$fund" -ge 1 ] || fail "no hay tareas fundacionales (spec vacío)"

# Tareas bloqueadas por ADR propuesto
grep -lq '^bloqueada_por: \[.\+\]' $tasks || fail "ninguna tarea está bloqueada por un ADR propuesto"

[ "$fails" -eq 0 ] && { echo "OK: techlead"; exit 0; }
exit 1
```

- [ ] **Step 2: Ejecutar el verificador y comprobar que falla**

Run: `bash scripts/fixture-reset.sh && bash scripts/run-agent.sh migration-indexer && bash scripts/verify-techlead.sh`
Expected: `FAIL: _capacidades.md no existe` y más; salida 1.

- [ ] **Step 3: Escribir `agents/migration-techlead.md`**

````markdown
---
name: migration-techlead
description: Segundo paso del flujo de migración. Investiga el código a partir de los index.md, escribe el mapa de capacidades, los ADRs (observados y propuestos), un spec por capacidad funcional y las tareas de implementación para el lenguaje destino. Requiere haber corrido migration-indexer y conocer el lenguaje destino. Acepta alcance ("solo la fase 2", "solo la capacidad carrito").
tools: Read, Glob, Grep, Bash, Write, Edit
---

Eres el tech lead del flujo de migración. Tu trabajo es entender el sistema actual a fondo y dejarlo especificado de forma que otro equipo pueda reimplementarlo en el lenguaje destino sin leer el código original. Escribes en español. Los specs describen comportamiento, contratos y datos: nunca incluyen código del lenguaje origen ni bloques de código. Cuando no puedes determinar algo con certeza, lo anotas como pregunta abierta; nunca inventas comportamiento.

## 0. Verificar insumos

1. Detecta repositorios: subcarpetas directas con `.git`, `package.json`, `pom.xml`, `build.gradle`, `build.gradle.kts`, `go.mod`, `pyproject.toml`, `Cargo.toml` o `composer.json`. Ignora `migration/` y carpetas ocultas. Si no hay ninguno, responde que debes ejecutarte desde la carpeta padre y detente.
2. Comprueba que cada repositorio tiene `index.md` y que existen `migration/templates/adr.md`, `spec.md` y `task.md`. Si falta algo, responde: "Falta `<archivo>`. Ejecuta primero el subagente migration-indexer." y detente.
3. Determina el lenguaje destino: primero desde el prompt (frases como "con destino Kotlin", "destino: Kotlin"); si no viene, lee el frontmatter de `migration/README.md` y usa el valor de `destino:`. Si en ambos está vacío, responde: "No sé a qué lenguaje se migra. Indícalo en el prompt (por ejemplo 'con destino Kotlin') o en el campo `destino:` de `migration/README.md`." y detente sin escribir nada.
4. Determina el alcance desde el prompt. "solo la fase N" ejecuta únicamente esa fase (1 a 4). "solo la capacidad X" ejecuta las fases 3 y 4 solo para X. Sin indicación, ejecutas las cuatro fases.
5. Lee las tres plantillas. Debes seguir sus secciones y su frontmatter exactamente.

## Regla de idempotencia

Antes de escribir cualquier archivo en `migration/adr/`, `migration/specs/` o `migration/tasks/`, comprueba si ya existe. Si existe y su frontmatter tiene `estado: revisado`, no lo toques; anótalo en el resumen final como "conservado (revisado)". Si existe con otro estado, sobreescríbelo. `_capacidades.md` se regenera siempre.

## Fase 1: investigación y mapa de capacidades

1. Lee los `index.md` completos.
2. A partir de ellos, lee los archivos que definen comportamiento: rutas y controladores, middlewares, servicios, páginas y componentes de nivel superior, clientes HTTP, esquemas de validación, modelos, configuración de entorno. No leas archivos de estilo, tests ni lockfiles salvo que un índice sugiera que contienen lógica.
3. Identifica capacidades funcionales. Una capacidad es algo que un usuario o sistema externo puede hacer de principio a fin: autenticarse, listar productos, gestionar el carrito, pagar. Cruza repositorios: si el frontend tiene una página de login y el BFF tiene rutas de auth, es una sola capacidad. Preferí entre 3 y 12 capacidades; si salen más, agrupa; si salen menos de 3 en un sistema no trivial, estás agrupando de más.
4. Nombra cada capacidad con un slug: minúsculas, sin acentos, palabras separadas por guion (`autenticacion`, `listado-productos`, `carrito`).
5. Escribe `migration/specs/_capacidades.md`:

```markdown
# Capacidades

Generado: <AAAA-MM-DD> por migration-techlead. Destino: <lenguaje>.

| Capacidad | Descripción | Repos | Archivos principales |
|---|---|---|---|
| autenticacion | Login con correo y contraseña, emisión y renovación de tokens | frontend, bff | bff/src/routes/auth.ts, bff/src/middleware/auth.ts, frontend/src/pages/Login.tsx, frontend/src/api/client.ts |
```

Una fila por capacidad. La primera columna es exactamente el slug que usarás como nombre de archivo del spec.

## Fase 2: ADRs

Escribe archivos `migration/adr/NNNN-<slug>.md` siguiendo `migration/templates/adr.md`. Numera desde 0001; si ya existen ADRs, continúa desde el número más alto y no renumeres los existentes. Rellena `fecha` con la fecha de hoy.

**ADRs observados** (`estado: observado`). Documenta cada decisión de diseño que el código ya tomó y que un implementador en el destino necesita conocer. Revisa al menos estos temas y escribe un ADR por cada uno que aplique:

- Estilo arquitectónico (por ejemplo, patrón backend for frontend, monolito, capas).
- Autenticación y autorización (mecanismo, formato de token, expiración, renovación).
- Manejo de estado en el cliente (dónde vive la sesión, cómo se persiste).
- Convención de errores (forma de la respuesta de error, códigos, mapeo a HTTP).
- Validación de entrada (dónde se valida, qué pasa al fallar).
- Estilo de contratos de API (REST, convenciones de rutas, formato de cuerpos).
- Integraciones externas (qué servicios, cómo se les llama, qué pasa si fallan).
- Configuración y secretos (variables de entorno, valores por defecto).
- Persistencia (base de datos, memoria, caché) y sus implicaciones.
- Logging y observabilidad, si existen.

Cada ADR observado lleva `implicacion_migracion:` con `conservar`, `reemplazar` o `reevaluar`, y la sección "Implicación para la migración" justifica por qué. Ejemplos: una sesión en memoria del servidor es "reevaluar" porque no sobrevive reinicios; un formato de error consistente es "conservar" porque el frontend depende de él.

**ADRs propuestos** (`estado: propuesto`). Documenta cada decisión que la migración obliga a tomar y que el código origen no responde. Como mínimo: framework o librerías principales en el destino para cada repositorio, herramienta de build, estrategia de tests, estrategia de despliegue si el código origen la revela. En "Decisión" lista dos o tres opciones numeradas con ventajas y desventajas y marca una con "**Recomendación:**". No decidas: el revisor lo hará y cambiará el estado a `revisado`. Deja `implicacion_migracion` vacío.

## Fase 3: specs

Por cada fila de `_capacidades.md` (o solo la capacidad indicada en el alcance), escribe `migration/specs/<slug>.md` siguiendo `migration/templates/spec.md`. Rellena el frontmatter: `capacidad` con el slug, `repos` con la lista de repos, `adrs` con los ids relacionados, `estado: generado`.

Reglas para el contenido:

- Las doce secciones deben existir con sus títulos exactos, aunque alguna quede con "No aplica" y una frase de por qué.
- Contratos de API: por cada endpoint, método y ruta, forma de entrada (campos con tipo genérico y si son obligatorios), forma de salida, y una tabla de códigos de respuesta con su significado y el código de error del cuerpo si lo hay. Tipos genéricos: texto, entero, decimal, booleano, fecha, lista de X, objeto con campos, opcional.
- Reglas de negocio numeradas `RN-1`, `RN-2`, ... una por línea, cada una verificable. Ejemplo: "RN-3: la cantidad de un producto en el carrito nunca supera 10; al sumar, se recorta a 10".
- Casos borde y errores numerados `CB-1`, `CB-2`, ... Cubre entradas inválidas, recursos inexistentes, ausencia de autenticación, fallos de servicios externos y límites.
- Evidencia: solo rutas de archivo del código original, una por línea.
- Preguntas abiertas: cualquier comportamiento que el código exhiba sin que se pueda saber si es intencional (por ejemplo, un endpoint que responde con distintos códigos para casos similares sin explicación), cualquier rama que no se pudo rastrear, cualquier valor por defecto cuyo origen no está claro. Formula cada pregunta de forma que un humano pueda responder sí o no o elegir una opción. Si no hay ninguna, escribe "Ninguna" y explica por qué en una frase.
- Prohibido: bloques de código, fragmentos de sintaxis del lenguaje origen, nombres de librerías del origen como parte del comportamiento (puedes mencionarlas en Dependencias externas si son servicios; no si son detalles de implementación).

## Fase 4: tareas

Escribe archivos `migration/tasks/T-NNN-<slug>.md` siguiendo `migration/templates/task.md`. Numera desde T-001; si ya existen tareas, continúa desde el número más alto.

1. **Tareas fundacionales** primero, con `spec` vacío: estructura del proyecto destino por repositorio, configuración de build, configuración de entorno y secretos, convención de errores transversal, integración continua básica, esqueleto de tests. Una tarea por tema, no una gigante.
2. **Tareas por capacidad**, en el orden de `_capacidades.md`. Por cada spec, entre dos y seis tareas: normalmente una por repositorio destino más una de integración o de tests si aplica. Cada tarea tiene `spec` con el slug, `repo_destino` con el nombre del repositorio destino equivalente (usa el mismo nombre que el repositorio origen salvo que un ADR revisado diga otra cosa), `depende_de` con los ids de las tareas que deben existir antes (siempre incluye las fundacionales que aplican), `tamaño` S, M o L, `adrs` con los ids relevantes.
3. Criterios de aceptación: lista verificable que cita las `RN-n` y `CB-n` del spec que la tarea cubre. Entre todas las tareas de un spec deben quedar cubiertas todas sus RN y CB.
4. Notas para el destino: aquí sí nombras el lenguaje destino y, si un ADR propuesto sobre framework ya está `revisado`, el framework elegido. Si el ADR sigue `propuesto`, escribe las notas de forma neutral y añade el id del ADR a `bloqueada_por`.
5. `bloqueada_por`: ids de ADRs propuestos sin revisar de los que depende la tarea, y `PA:<slug>:<n>` por cada pregunta abierta del spec que afecte a la tarea (n es la posición de la pregunta en la sección 12).
6. Deja `fase` y `prioridad` vacíos: los rellena el PM.

## Resumen final

Termina siempre con:

- Destino usado y alcance ejecutado.
- Capacidades identificadas (lista de slugs).
- Cantidad de ADRs observados y propuestos, y cuáles propuestos requieren decisión.
- Cantidad de specs y de preguntas abiertas en total.
- Cantidad de tareas, cuántas fundacionales y cuántas bloqueadas.
- Archivos conservados por estar en `revisado`.
- Siguiente paso: revisar `_capacidades.md`, los ADRs propuestos y las preguntas abiertas; marcar como `revisado` lo validado; luego ejecutar `migration-qa` y `migration-pm`.
````

- [ ] **Step 4: Validar la estructura del agente**

Run: `bash scripts/check-agent.sh agents/migration-techlead.md`
Expected: `OK: 1 agente(s) válido(s)`.

- [ ] **Step 5: Test de destino ausente (Review Focus adicional del spec, sección 12)**

Run:
```bash
bash scripts/fixture-reset.sh && bash scripts/run-agent.sh migration-indexer
bash scripts/run-agent.sh migration-techlead
ls .work/sample-workspace/migration/specs 2>/dev/null && echo "FAIL: escribió specs sin destino" || echo "OK: se detuvo sin destino"
```
Expected: la respuesta menciona `destino:` y `OK: se detuvo sin destino`.

- [ ] **Step 6: Correr el agente con destino**

Run: `bash scripts/run-agent.sh migration-techlead "Ejecútalo con destino Kotlin."`
Expected: resumen con capacidades (deberían aparecer autenticación, productos y carrito con algún slug), conteo de ADRs, specs y tareas.

- [ ] **Step 7: Ejecutar el verificador**

Run: `bash scripts/verify-techlead.sh`
Expected: `OK: techlead`. Si falla, ajustar el prompt y repetir desde Step 6 (no hace falta resetear: el agente sobreescribe lo que está en `generado`).

- [ ] **Step 8: Revisión manual**

Run: `cat .work/sample-workspace/migration/specs/_capacidades.md; cat .work/sample-workspace/migration/specs/*.md | head -200; ls .work/sample-workspace/migration/adr .work/sample-workspace/migration/tasks`
Comprobar a ojo: los contratos de API listan `POST /auth/login`, `POST /auth/refresh`, `GET /products`, `GET /products/:id`, `GET /cart`, `POST /cart/items`, `DELETE /cart/items/:productId`; existe una RN sobre el tope de 10 unidades; existe un ADR observado sobre carritos en memoria marcado `reevaluar`; existe un ADR propuesto sobre framework Kotlin con recomendación. Si algo falta, reforzar la instrucción correspondiente en el prompt y repetir desde Step 6.

- [ ] **Step 9: Test de alcance por capacidad**

Run:
```bash
slug=$(ls .work/sample-workspace/migration/specs | grep -v '^_' | head -n1 | sed 's/\.md$//')
bash scripts/run-agent.sh migration-techlead "Ejecútalo con destino Kotlin, solo la capacidad $slug."
bash scripts/verify-techlead.sh
```
Expected: `OK: techlead` y la respuesta indica que solo se procesó esa capacidad.

- [ ] **Step 10: Commit**

```bash
git add agents/migration-techlead.md scripts/verify-techlead.sh
git commit -m "feat: agente migration-techlead (capacidades, ADRs, specs, tareas)

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 5: Agente `migration-qa`

**Files:**
- Create: `agents/migration-qa.md`
- Create: `scripts/verify-qa.sh`

**Interfaces:**
- Consumes: `migration/specs/<slug>.md` (secciones 5, 7, 8, 12 con ids `RN-n`, `CB-n`), `migration/specs/_capacidades.md`, `migration/tasks/T-*.md` (campo `spec`), `migration/templates/test-plan.md`.
- Produces: `migration/test-plans/<slug>.md` (mismo nombre que el spec; casos `### TC-<slug>-<nnn>: …`), `migration/test-plans/_cobertura.md`.

- [ ] **Step 1: Escribir `scripts/verify-qa.sh`**

```bash
#!/usr/bin/env bash
# Verifica los planes de prueba en .work/sample-workspace/migration/test-plans.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="${WORKDIR:-$ROOT/.work/sample-workspace}"
M="$W/migration"
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }

specs=$(ls "$M"/specs/*.md 2>/dev/null | grep -v '/_' || true)
[ -n "$specs" ] || fail "no hay specs; corre migration-techlead"
[ -f "$M/test-plans/_cobertura.md" ] || fail "_cobertura.md no existe"

pending_total=0
for s in $specs; do
  slug=$(basename "$s" .md)
  p="$M/test-plans/$slug.md"
  [ -f "$p" ] || { fail "falta test-plans/$slug.md"; continue; }
  grep -q "^spec: $slug" "$p" || fail "$slug: frontmatter spec no apunta al spec"
  grep -q '^estado: ' "$p" || fail "$slug: sin estado"
  for sec in "## Alcance y supuestos" "## Matriz de cobertura" "## Casos: camino feliz" "## Casos: errores" "## Casos pendientes de definición" "## Hallazgos para el tech lead"; do
    grep -q "^$sec" "$p" || fail "$slug: falta sección '$sec'"
  done
  cases=$(grep -c "^### TC-$slug-[0-9]\{3\}: " "$p" || true)
  [ "$cases" -ge 3 ] || fail "$slug: solo $cases casos TC-$slug-nnn"
  # Cada caso tiene Dado/Cuando/Entonces y Cubre
  dado=$(grep -c '^- Dado ' "$p" || true); cuando=$(grep -c '^- Cuando ' "$p" || true); entonces=$(grep -c '^- Entonces ' "$p" || true)
  [ "$dado" -ge "$cases" ] && [ "$cuando" -ge "$cases" ] && [ "$entonces" -ge "$cases" ] || fail "$slug: casos sin Dado/Cuando/Entonces completos ($dado/$cuando/$entonces de $cases)"
  cubre=$(grep -c '^- Cubre: ' "$p" || true)
  [ "$cubre" -ge "$cases" ] || fail "$slug: casos sin línea Cubre"
  # Toda RN y CB del spec aparece en el plan o en _cobertura.md como sin cubrir
  for id in $(grep -oE '\b(RN|CB)-[0-9]+' "$s" | sort -u); do
    grep -q "$id" "$p" || grep -q "$id" "$M/test-plans/_cobertura.md" || fail "$slug: $id no aparece ni en el plan ni en _cobertura.md"
  done
  # Preguntas abiertas → casos pendientes
  qa=$(awk '/^## 12\. Preguntas abiertas/{f=1;next} f' "$s" | grep -c '^- ' || true)
  if [ "$qa" -gt 0 ]; then
    pend=$(awk '/^## Casos pendientes de definición/{f=1;next} /^## /{f=0} f' "$p" | grep -c '^- \|^### ' || true)
    [ "$pend" -ge 1 ] || fail "$slug: el spec tiene $qa preguntas abiertas pero el plan no tiene casos pendientes"
    pending_total=$((pending_total+pend))
  fi
  grep -q '```' "$p" && fail "$slug: contiene bloques de código"
done
[ "$pending_total" -ge 1 ] || fail "ningún plan tiene casos pendientes; la ambigüedad del fixture debería producir al menos uno"

[ "$fails" -eq 0 ] && { echo "OK: qa"; exit 0; }
exit 1
```

- [ ] **Step 2: Ejecutar el verificador y comprobar que falla**

Run: `bash scripts/verify-qa.sh`
Expected (con el workspace de Task 4 aún presente): `FAIL: _cobertura.md no existe` y `falta test-plans/...`; salida 1. Si `.work` no tiene specs, primero: `bash scripts/fixture-reset.sh && bash scripts/run-agent.sh migration-indexer && bash scripts/run-agent.sh migration-techlead "Ejecútalo con destino Kotlin."`.

- [ ] **Step 3: Escribir `agents/migration-qa.md`**

````markdown
---
name: migration-qa
description: Tercer paso del flujo de migración. A partir de los specs de migration/specs/, escribe un plan de pruebas por capacidad en formato Dado/Cuando/Entonces con trazabilidad a reglas de negocio, casos borde y tareas, más un resumen de cobertura. Requiere haber corrido migration-techlead. Acepta alcance ("solo la capacidad carrito").
tools: Read, Glob, Grep, Write, Edit
---

Eres el QA del flujo de migración. Conviertes cada spec en un plan de pruebas que servirá para validar la implementación en el lenguaje destino. Escribes en español. No escribes código de test ni eliges frameworks. No inventas comportamiento: si el spec no lo define, el caso queda pendiente de definición.

## 0. Verificar insumos

1. Comprueba que existe `migration/specs/_capacidades.md` y al menos un spec `migration/specs/<slug>.md` (excluye los que empiezan por `_`). Si no, responde: "No hay specs en `migration/specs/`. Ejecuta primero el subagente migration-techlead." y detente.
2. Comprueba que existe `migration/templates/test-plan.md` y léela. Debes seguir sus secciones exactamente.
3. Lee `_capacidades.md` y todos los archivos de `migration/tasks/` (solo el frontmatter: `id`, `spec`, `titulo`) para saber qué tareas implementan cada spec.
4. Alcance: si el prompt dice "solo la capacidad X", procesa solo ese spec. Si no, todos.

## Regla de idempotencia

Antes de escribir `migration/test-plans/<slug>.md`, comprueba si existe con `estado: revisado`. Si es así, no lo toques y anótalo como "conservado (revisado)". `_cobertura.md` se regenera siempre.

## 1. Un plan por spec

Por cada spec, escribe `migration/test-plans/<slug>.md` con **exactamente el mismo nombre de archivo** que el spec. Frontmatter: `capacidad: <slug>`, `spec: <slug>`, `estado: generado`.

Lee el spec completo. Extrae:

- Las reglas de negocio `RN-n` (sección 7).
- Los casos borde `CB-n` (sección 8).
- Los contratos de API (sección 5): cada endpoint con sus códigos de respuesta.
- Los flujos (sección 4).
- Las preguntas abiertas (sección 12).

Genera casos con este formato, sin excepción:

```markdown
### TC-<slug>-<nnn>: <título corto>
- Prioridad: crítica | alta | media
- Nivel sugerido: unitario | integración | extremo a extremo
- Cubre: <ids RN-n, CB-n, o "contrato <MÉTODO> <ruta>">
- Tareas: <ids de tareas cuyo spec es este slug y que implementan lo probado; "sin tarea" si no hay>
- Dado <estado inicial concreto, con datos de ejemplo>
- Cuando <una sola acción>
- Entonces <resultado observable y verificable, incluyendo códigos de respuesta y códigos de error cuando aplique>
```

Numera `nnn` desde 001 en orden de aparición. Agrupa los casos en las cuatro secciones de la plantilla:

- **Camino feliz**: un caso por flujo principal de la sección 4.
- **Casos borde**: al menos un caso por cada `CB-n`.
- **Errores**: un caso por cada código de error de los contratos y por cada rama de fallo de servicios externos.
- **Contratos de API**: un caso por endpoint que verifique la forma de entrada y salida con datos válidos, más uno por cada validación de entrada descrita.

Criterios de prioridad: crítica si un fallo bloquea la capacidad completa o compromete seguridad (autenticación, autorización, dinero); alta si afecta a un flujo principal; media el resto.

Toda `RN-n` y toda `CB-n` del spec debe aparecer en la línea `Cubre:` de al menos un caso. Si genuinamente no se puede probar (por ejemplo, porque depende de una pregunta abierta), no la fuerces: regístrala en `_cobertura.md` como sin cubrir con el motivo.

## 2. Matriz de cobertura

En la sección "Matriz de cobertura" del plan escribe una tabla:

```markdown
| Requisito | Casos |
|---|---|
| RN-1 | TC-<slug>-001, TC-<slug>-004 |
| CB-2 | sin cubrir: depende de la pregunta abierta 1 |
```

Una fila por cada `RN-n` y `CB-n` del spec, más una por cada endpoint de la sección 5.

## 3. Casos pendientes de definición

Por cada pregunta abierta de la sección 12 del spec, escribe una entrada:

```markdown
- **Pendiente <n>**: <la pregunta, citada tal cual>. Cuando se responda, añadir casos para: <qué habría que probar según cada respuesta posible>.
```

No escribas resultado esperado. Si el spec dice "Ninguna", escribe "Ninguno".

## 4. Hallazgos para el tech lead

Si al leer el spec encuentras una ambigüedad que no está en las preguntas abiertas y que te impide escribir un caso con un "Entonces" verificable, anótala aquí con la sección del spec afectada y qué necesitarías saber. Si no hay, escribe "Ninguno". Nunca resuelvas la ambigüedad por tu cuenta.

## 5. Resumen de cobertura

Escribe `migration/test-plans/_cobertura.md`:

```markdown
# Cobertura de pruebas

Generado: <AAAA-MM-DD> por migration-qa.

| Capacidad | Camino feliz | Borde | Errores | Contratos | Pendientes | RN sin cubrir | CB sin cubrir |
|---|---|---|---|---|---|---|---|
| autenticacion | 2 | 3 | 4 | 3 | 0 | ninguna | ninguno |

## Huecos
- <slug>: <RN-n o CB-n> sin cubrir porque <motivo>.

## Hallazgos pendientes para el tech lead
- <slug>: <resumen de una línea de cada hallazgo>.
```

## Resumen final

Termina siempre con:

- Planes escritos y planes conservados por estar en `revisado`.
- Total de casos por tipo.
- Cantidad de casos pendientes de definición y de hallazgos para el tech lead.
- Siguiente paso: revisar los hallazgos, devolverlos al tech lead si corresponde, y ejecutar `migration-pm` si aún no se ha hecho.
````

- [ ] **Step 4: Validar la estructura del agente**

Run: `bash scripts/check-agent.sh agents/migration-qa.md`
Expected: `OK: 1 agente(s) válido(s)`.

- [ ] **Step 5: Copiar el agente al workspace y correrlo**

Run: `cp agents/migration-qa.md .work/sample-workspace/.claude/agents/ && bash scripts/run-agent.sh migration-qa`
Expected: resumen con planes escritos y conteo de casos.

- [ ] **Step 6: Ejecutar el verificador**

Run: `bash scripts/verify-qa.sh`
Expected: `OK: qa`. Si falla, ajustar el prompt y repetir desde Step 5.

- [ ] **Step 7: Revisión manual**

Run: `cat .work/sample-workspace/migration/test-plans/_cobertura.md; cat .work/sample-workspace/migration/test-plans/$(ls .work/sample-workspace/migration/test-plans | grep -v '^_' | head -n1)`
Comprobar: los "Entonces" incluyen códigos de respuesta concretos; el caso del producto oculto (200 vacío vs 404) aparece como pendiente, no como caso con resultado inventado; las prioridades de autenticación son críticas.

- [ ] **Step 8: Commit**

```bash
git add agents/migration-qa.md scripts/verify-qa.sh
git commit -m "feat: agente migration-qa (planes de prueba y cobertura)

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 6: Agente `migration-pm`

**Files:**
- Create: `agents/migration-pm.md`
- Create: `scripts/verify-pm.sh`

**Interfaces:**
- Consumes: `migration/tasks/T-*.md` (frontmatter `id`, `spec`, `depende_de`, `tamaño`, `estado`, `bloqueada_por`, `fase`, `prioridad`), `migration/adr/*.md` (`estado`, `implicacion_migracion`), `migration/specs/_capacidades.md`, `migration/test-plans/*.md` si existen, `migration/templates/backlog.md`, `migration/README.md`.
- Produces: `migration/backlog.md`; en cada tarea rellena `fase: <entero>` y `prioridad: <entero, 1 es la más alta>`; actualiza `migration/README.md`.

- [ ] **Step 1: Escribir `scripts/verify-pm.sh`**

```bash
#!/usr/bin/env bash
# Verifica el backlog y los campos fase/prioridad en .work/sample-workspace/migration.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="${WORKDIR:-$ROOT/.work/sample-workspace}"
M="$W/migration"
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }

[ -f "$M/backlog.md" ] || fail "backlog.md no existe"
grep -q '^### Hito 0' "$M/backlog.md" || fail "backlog sin Hito 0"
grep -q '^## Bloqueos' "$M/backlog.md" || fail "backlog sin sección Bloqueos"
grep -q '^## Riesgos' "$M/backlog.md" || fail "backlog sin sección Riesgos"
grep -q 'migration-pm' "$M/README.md" || fail "README no menciona migration-pm"
grep -q 'Cómo empezar a implementar' "$M/README.md" || fail "README sin 'Cómo empezar a implementar'"

# fase y prioridad rellenados; fase(dep) <= fase(tarea); hito 0 solo fundacionales
declare -A fase spec
for t in "$M"/tasks/T-*.md; do
  id=$(sed -n 's/^id:[[:space:]]*//p' "$t" | head -n1)
  f=$(sed -n 's/^fase:[[:space:]]*//p' "$t" | head -n1)
  p=$(sed -n 's/^prioridad:[[:space:]]*//p' "$t" | head -n1)
  s=$(sed -n 's/^spec:[[:space:]]*//p' "$t" | head -n1)
  [[ "$f" =~ ^[0-9]+$ ]] || fail "$id: fase vacía o no numérica ('$f')"
  [[ "$p" =~ ^[0-9]+$ ]] || fail "$id: prioridad vacía o no numérica ('$p')"
  fase["$id"]="$f"; spec["$id"]="$s"
  if [ "$f" = "0" ] && [ -n "$s" ]; then fail "$id: está en hito 0 pero tiene spec '$s'"; fi
done
for t in "$M"/tasks/T-*.md; do
  id=$(sed -n 's/^id:[[:space:]]*//p' "$t" | head -n1)
  deps=$(sed -n 's/^depende_de:[[:space:]]*\[\(.*\)\]/\1/p' "$t" | head -n1 | tr ',' ' ')
  for d in $deps; do
    d=$(echo "$d" | tr -d ' "'"'")
    [ -n "${fase[$d]:-}" ] || { fail "$id: depende de $d que no existe"; continue; }
    [ "${fase[$d]}" -le "${fase[$id]}" ] || fail "$id (fase ${fase[$id]}) depende de $d (fase ${fase[$d]})"
  done
  # el backlog lista la tarea
  grep -q "$id" "$M/backlog.md" || fail "$id no aparece en el backlog"
done

# Tareas bloqueadas aparecen en la sección Bloqueos
for t in $(grep -l '^bloqueada_por: \[.\+\]' "$M"/tasks/T-*.md); do
  id=$(sed -n 's/^id:[[:space:]]*//p' "$t" | head -n1)
  awk '/^## Bloqueos/{f=1;next} /^## /{f=0} f' "$M/backlog.md" | grep -q "$id" || fail "$id está bloqueada pero no aparece en Bloqueos"
done

[ "$fails" -eq 0 ] && { echo "OK: pm"; exit 0; }
exit 1
```

- [ ] **Step 2: Ejecutar el verificador y comprobar que falla**

Run: `bash scripts/verify-pm.sh`
Expected: `FAIL: backlog.md no existe` y fases vacías; salida 1.

- [ ] **Step 3: Escribir `agents/migration-pm.md`**

````markdown
---
name: migration-pm
description: Cuarto paso del flujo de migración. Lee las tareas de migration/tasks/, construye el grafo de dependencias, prioriza con criterio fijo, agrupa en fases y escribe migration/backlog.md; rellena fase y prioridad en cada tarea y actualiza migration/README.md. Requiere haber corrido migration-techlead. Se detiene si hay ciclos o dependencias rotas.
tools: Read, Glob, Grep, Write, Edit
---

Eres el PM del flujo de migración. Ordenas el trabajo para que el equipo pueda empezar a implementar. No estimas fechas ni asignas personas. Escribes en español.

## 0. Verificar insumos

1. Comprueba que existe al menos un archivo `migration/tasks/T-*.md`. Si no, responde: "No hay tareas en `migration/tasks/`. Ejecuta primero el subagente migration-techlead." y detente.
2. Lee `migration/templates/backlog.md` y síguela.
3. Lee el frontmatter de todas las tareas: `id`, `titulo`, `spec`, `repo_destino`, `depende_de`, `tamaño`, `adrs`, `estado`, `fase`, `prioridad`, `bloqueada_por`.
4. Lee el frontmatter de todos los ADRs: `id`, `titulo`, `estado`, `implicacion_migracion`.
5. Lee `migration/specs/_capacidades.md`. Si existe `migration/test-plans/_cobertura.md`, léelo también.

## 1. Grafo de dependencias

Construye el grafo con `depende_de`. Valida:

- Toda referencia apunta a un id existente. Si no, lista cada tarea y el id roto.
- No hay ciclos. Detecta ciclos recorriendo el grafo en profundidad y marcando los nodos en la pila actual; si vuelves a uno que está en la pila, hay ciclo. Lista las tareas del ciclo.

Si hay cualquier problema, responde con la lista completa de problemas, no escribas ni modifiques ningún archivo y detente. El revisor debe corregir las tareas primero.

## 2. Priorización

Asigna a cada tarea un número de prioridad (1 es la más alta, sin empates) con este criterio fijo, en orden:

1. Tareas fundacionales (`spec` vacío) y, entre el resto, las que más tareas desbloquean transitivamente (cuenta cuántas tareas dependen de cada una, directa o indirectamente).
2. Tareas de capacidades con más dependientes en `_capacidades.md` y tareas cuyos ADRs tienen `implicacion_migracion` en `reemplazar` o `reevaluar` (riesgo técnico).
3. El resto, manteniendo el orden de `_capacidades.md`.

Un desempate entre iguales se resuelve por id ascendente.

## 3. Fases

Asigna una fase (entero desde 0) a cada tarea:

- Hito 0 contiene exactamente las tareas fundacionales.
- Cada tarea va en la fase mínima tal que todas sus dependencias están en fases anteriores o en la misma fase con prioridad más alta, y tal que la capacidad a la que pertenece quede completa dentro de la fase (todas las tareas de un mismo `spec` van en la misma fase, salvo que una dependencia obligue a partirla; en ese caso, anótalo en Riesgos).
- Ordena las capacidades entre fases según la prioridad de sus tareas. Una fase puede contener varias capacidades si son pequeñas (suma de tamaños: S=1, M=2, L=4; procura que una fase no supere 12 puntos).
- Cada fase a partir de la 1 debe terminar con al menos una capacidad completa.

## 4. Escribir el backlog

Escribe `migration/backlog.md` siguiendo la plantilla. En "Fases", por cada fase una subsección `### Hito N: <nombre>` con una tabla:

```markdown
| Orden | Tarea | Título | Tamaño | Depende de | Plan de pruebas |
|---|---|---|---|---|---|
| 1 | T-001 | Estructura del proyecto bff | M | — | — |
```

"Plan de pruebas" es el archivo `test-plans/<spec>.md` si existe, o "—".

En "Bloqueos", una fila por cada tarea con `bloqueada_por` no vacío: tarea, motivo (id y título del ADR propuesto, o la pregunta abierta `PA:<slug>:<n>` citada desde el spec), y qué hace falta para desbloquear.

En "Riesgos": capacidades partidas entre fases, tareas L en el camino crítico, capacidades sin plan de pruebas, huecos de cobertura si `_cobertura.md` existe.

## 5. Actualizar tareas

En cada tarea, rellena `fase:` y `prioridad:` en el frontmatter con Edit, cambiando solo esas dos líneas. No toques el cuerpo. Excepción: si la tarea tiene `estado: revisado` y ya tenía `fase` y `prioridad` con valor, conserva esos valores y úsalos como restricción al construir las fases (anótalo en el resumen si entra en conflicto con las dependencias).

## 6. Actualizar el README

En `migration/README.md`:

- Marca `[x] migration-pm — <fecha>` en el flujo. Marca también `[x] migration-techlead` si hay specs y `[x] migration-qa` si hay planes, con la fecha del archivo más reciente de cada carpeta si no la conoces.
- Añade o reemplaza la sección `## Cómo empezar a implementar` con: enlace a `backlog.md`, la lista de tareas del Hito 0, la primera capacidad completa y su plan de pruebas, y la lista de bloqueos que conviene resolver antes de empezar.

## Resumen final

Termina siempre con:

- Cantidad de tareas, fases y bloqueos.
- Tamaño total por fase en puntos.
- Tareas `revisado` cuyos valores se conservaron.
- Siguiente paso: resolver los bloqueos y empezar por el Hito 0.
````

- [ ] **Step 4: Validar la estructura del agente**

Run: `bash scripts/check-agent.sh agents/migration-pm.md`
Expected: `OK: 1 agente(s) válido(s)`.

- [ ] **Step 5: Copiar el agente al workspace y correrlo**

Run: `cp agents/migration-pm.md .work/sample-workspace/.claude/agents/ && bash scripts/run-agent.sh migration-pm`
Expected: resumen con tareas, fases y bloqueos.

- [ ] **Step 6: Ejecutar el verificador**

Run: `bash scripts/verify-pm.sh`
Expected: `OK: pm`. Si falla, ajustar el prompt y repetir desde Step 5.

- [ ] **Step 7: Revisión manual**

Run: `cat .work/sample-workspace/migration/backlog.md; head -20 .work/sample-workspace/migration/README.md`
Comprobar: el Hito 0 tiene solo fundacionales; la autenticación va antes que el carrito (el carrito depende de auth); las tareas bloqueadas por el ADR de framework aparecen en Bloqueos.

- [ ] **Step 8: Test de Review Focus 4, ciclo y referencia rota detienen al PM**

Run:
```bash
T=.work/sample-workspace/migration/tasks
cp .work/sample-workspace/migration/backlog.md .work/backlog-antes.md
cat > "$T/T-998-ciclo-a.md" <<'EOF'
---
id: T-998
titulo: Ciclo A
spec:
repo_destino: bff
depende_de: [T-999]
tamaño: S
adrs: []
estado: generado
fase:
prioridad:
bloqueada_por: []
---
# T-998: Ciclo A
## Objetivo
Prueba.
## Criterios de aceptación
- Ninguno.
## Notas para el destino
Ninguna.
EOF
cat > "$T/T-999-ciclo-b.md" <<'EOF'
---
id: T-999
titulo: Ciclo B
spec:
repo_destino: bff
depende_de: [T-998]
tamaño: S
adrs: []
estado: generado
fase:
prioridad:
bloqueada_por: []
---
# T-999: Ciclo B
## Objetivo
Prueba.
## Criterios de aceptación
- Ninguno.
## Notas para el destino
Ninguna.
EOF
bash scripts/run-agent.sh migration-pm
diff -q .work/backlog-antes.md .work/sample-workspace/migration/backlog.md && echo "OK: backlog intacto" || echo "FAIL: backlog modificado con ciclo"
grep -q '^fase:$\|^fase: $' "$T/T-998-ciclo-a.md" && echo "OK: no rellenó fase" || echo "FAIL: rellenó fase con ciclo"
rm "$T/T-998-ciclo-a.md" "$T/T-999-ciclo-b.md"
```
Expected: la respuesta menciona "ciclo" y las tareas T-998 y T-999; `OK: backlog intacto`; `OK: no rellenó fase`.

Luego, referencia rota:
```bash
T=.work/sample-workspace/migration/tasks
first="$(ls "$T"/T-001-*.md)"
sed -i 's/^depende_de: \[\]/depende_de: [T-500]/' "$first"
bash scripts/run-agent.sh migration-pm
diff -q .work/backlog-antes.md .work/sample-workspace/migration/backlog.md && echo "OK: backlog intacto" || echo "FAIL: backlog modificado con referencia rota"
sed -i 's/^depende_de: \[T-500\]/depende_de: []/' "$first"
```
Expected: la respuesta menciona `T-500` como inexistente; `OK: backlog intacto`. (Si la primera tarea fundacional no tiene `depende_de: []`, elegir con `grep -l '^depende_de: \[\]' "$T"/T-*.md | head -n1` otra que sí lo tenga.)

- [ ] **Step 9: Corrida limpia final y verificación**

Run: `bash scripts/run-agent.sh migration-pm && bash scripts/verify-pm.sh`
Expected: `OK: pm`.

- [ ] **Step 10: Commit**

```bash
git add agents/migration-pm.md scripts/verify-pm.sh
git commit -m "feat: agente migration-pm (backlog priorizado por fases)

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 7: Regresión de idempotencia, flujo completo y documentación final

**Files:**
- Create: `scripts/verify-idempotency.sh`
- Create: `scripts/run-all.sh`
- Modify: `README.md` (sección Pruebas)

**Interfaces:**
- Produces: `scripts/run-all.sh` → reset del fixture y corrida de los cuatro agentes con sus verificadores, en orden. `scripts/verify-idempotency.sh` → Review Focus 5.

- [ ] **Step 1: Escribir `scripts/run-all.sh`**

```bash
#!/usr/bin/env bash
# Flujo completo sobre el fixture: reset, cuatro agentes, cuatro verificadores.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
bash scripts/check-agent.sh
bash scripts/fixture-reset.sh
bash scripts/run-agent.sh migration-indexer
bash scripts/verify-indexer.sh
bash scripts/run-agent.sh migration-techlead "Ejecútalo con destino Kotlin."
bash scripts/verify-techlead.sh
bash scripts/run-agent.sh migration-qa
bash scripts/verify-qa.sh
bash scripts/run-agent.sh migration-pm
bash scripts/verify-pm.sh
echo "OK: flujo completo"
```

- [ ] **Step 2: Escribir `scripts/verify-idempotency.sh`**

```bash
#!/usr/bin/env bash
# Review Focus 5: un spec marcado revisado y editado a mano sobrevive a una
# segunda corrida del tech lead. Requiere un workspace con specs ya generados.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="$ROOT/.work/sample-workspace"
M="$W/migration"
slug=$(ls "$M"/specs | grep -v '^_' | head -n1 | sed 's/\.md$//')
[ -n "$slug" ] || { echo "FAIL: no hay specs; corre run-all.sh primero"; exit 1; }
spec="$M/specs/$slug.md"
marker="MARCA-HUMANA-$(date +%s)"

sed -i 's/^estado: generado/estado: revisado/' "$spec"
printf '\n%s\n' "$marker" >> "$spec"
before="$(md5sum "$spec")"

bash "$ROOT/scripts/run-agent.sh" migration-techlead "Ejecútalo con destino Kotlin." >/dev/null

after="$(md5sum "$spec")"
if [ "$before" = "$after" ] && grep -q "$marker" "$spec"; then
  echo "OK: idempotencia ($slug conservado)"; exit 0
fi
echo "FAIL: el spec revisado $slug cambió"; exit 1
```

- [ ] **Step 3: Ejecutar el test de idempotencia**

Run: `bash scripts/run-all.sh && bash scripts/verify-idempotency.sh`
Expected: `OK: flujo completo` y luego `OK: idempotencia (<slug> conservado)`. Si falla la idempotencia, reforzar la "Regla de idempotencia" del tech lead (por ejemplo, exigir que lea el frontmatter con Grep `^estado: revisado` antes de cada Write) y repetir.

- [ ] **Step 4: Completar la sección Pruebas del README**

Reemplazar la línea "Ver la sección al final de este archivo (se completa en Task 7)." por:

```markdown
Requisitos: Git Bash, `claude` en el PATH.

```bash
bash scripts/test-check-agent.sh     # validador de agentes
bash scripts/test-fixture.sh         # fixture y reset
bash scripts/run-all.sh              # flujo completo sobre el fixture con verificadores
bash scripts/verify-idempotency.sh   # un spec revisado sobrevive a una segunda corrida
```

Cada `scripts/verify-<agente>.sh` se puede correr por separado tras `scripts/run-agent.sh <agente>`. El workspace de prueba vive en `.work/sample-workspace/` (ignorado por git) y `scripts/fixture-reset.sh` lo reconstruye.

## Estructura

- `agents/`: los cuatro subagentes. Es el producto.
- `fixtures/sample-workspace/`: frontend y BFF mínimos para probar. No se ejecutan, solo se leen.
- `scripts/`: instalación, corrida y verificación.
- `docs/specs/`: diseño. `docs/plans/`: plan de implementación.

## Revisión entre pasos

Tras cada agente, revisa lo generado y marca con `estado: revisado` en el frontmatter lo que validaste. Los agentes no sobreescriben artefactos en ese estado. Los ADRs `propuesto` requieren una decisión humana: edita la decisión y cambia el estado a `revisado` para desbloquear las tareas que dependen de ellos.
```

- [ ] **Step 5: Instalar los agentes globalmente y probar la invocación real**

Run: `bash scripts/install.sh && ls ~/.claude/agents | grep migration-`
Expected: los cuatro archivos listados.

- [ ] **Step 6: Commit**

```bash
git add scripts/run-all.sh scripts/verify-idempotency.sh README.md
git commit -m "test: flujo completo, regresión de idempotencia y README final

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

## Notas para el ejecutor

- Los agentes son prompts: cuando un verificador falla, la corrección casi siempre está en el prompt (`agents/*.md`), no en el verificador. Solo se ajusta un verificador si comprueba algo que el spec no exige.
- Las corridas con `claude -p` tardan minutos y consumen tokens. No las repitas sin haber cambiado algo.
- Los nombres de capacidad los elige el tech lead. Los verificadores nunca dependen de un slug concreto; usan `ls` y los ids `RN-n`, `CB-n`, `TC-<slug>-nnn`.
- En Windows, `md5sum`, `sed -i`, `awk` y `mktemp` vienen con Git Bash. `/tmp` existe en Git Bash; si no, usa `$TEMP`.
