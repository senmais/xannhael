# 09 · Reutilizar como template

Xannhael es un **template de trabajo**: web Rails + cliente Android que hablan
entre sí. Para empezar un proyecto nuevo (blog, ecommerce, SaaS, CRM…) se
**clona y se renombra en el lugar** con `scaffold:rename`.

```mermaid
flowchart LR
    A["git clone <template>"] --> B["cd <clone>"]
    B --> C["bin/rails scaffold:rename<br/>SLUG=blog PACKAGE=com.acme.blog"]
    C --> D["git remote add origin <tu-repo>"]
    D --> E["git add -A && git commit"]
    E --> F["bin/dev + Android"]
```

## Uso

```bash
git clone <this-template-url>
cd <clone>
# Renombra Android + Rails en el lugar y elimina el remote 'origin'
bin/rails scaffold:rename SLUG=blog PACKAGE=com.acme.blog

git remote add origin <tu-nuevo-repo-url>
git add -A && git commit
```

### Opciones

| Opción | Descripción | Default |
|--------|-------------|---------|
| `SLUG` | Nuevo slug (minúsculas, ej. `blog`). Nombres de DB, rootProject, URLs | Nombre de la carpeta |
| `PACKAGE` | Nuevo `applicationId`/namespace Android, ej. `com.acme.blog` | `com.example.<slug>` |
| `STRIP_SECRETS=1` | También borra `master.key` + `credentials.yml.enc` | Conservadas |

> 🔎 La tarea **detecta los nombres antiguos del contenido del repo** (el
> namespace Android y el módulo Rails), no de la carpeta. Así funciona aunque
> el template se llamara de otra forma.

## Qué renombra

```mermaid
flowchart TB
    subgraph Android["Android"]
        A1["applicationId / namespace"]
        A2["Directorios e imports de paquete"]
        A3["Clase/theme/label (Xannhael → Blog)"]
    end
    subgraph Rails["Rails"]
        R1["Nombres de DB"]
        R2["rootProject.name / módulo"]
        R3["Locales (es.yml/en.yml)"]
        R4["Devcontainer + compose<br/>(volúmenes xannhael-*, ruta /workspaces/…)"]
        R5["ENV['XANNHAEL_DATABASE_PASSWORD']"]
        R6[".env.example"]
    end
    Task["scaffold:rename"] --> Android
    Task --> Rails
```

## Qué NO toca

- **`.git`** — conserva el historial; solo elimina el remote `origin`.
- Archivos locales/generados: `local.properties`, `build/`, `.gradle/`,
  `.idea/`, `log/`, `tmp/`, `storage/`, `.ruby-lsp/`.
- **Credenciales** (`master.key`, `credentials.yml.enc`) — se conservan porque
  el devcontainer las necesita para arrancar. Pasa `STRIP_SECRETS=1` para
  borrarlas y después ejecuta `bin/rails credentials:edit`.
- **`.env` local** — sí se reescribe si existe (lleva
  `XANNHAEL_DATABASE_PASSWORD`); al ser gitignored, cada persona lo suya.
  Si no existe, créalo: `cp .env.example .env`.

## Devcontainer y volúmenes tras el rename

La tarea reescribe `.devcontainer/compose.yaml` (volúmenes `xannhael-*`,
ruta `/workspaces/xannhael`) y `.env.example`. Ojo con dos cosas:

1. **Los volúmenes Docker no se renombran**: los creados con el nombre viejo
   quedan huérfanos.

   ```bash
   # conservar el contenido (gems ya instaladas, auth de opencode…):
   docker volume create blog-bundle && docker volume rm xannhael-bundle
   # …o empezar de cero:
   docker volume rm xannhael-bundle xannhael-user-config xannhael-user-data \
     xannhael-user-cache xannhael-codex
   ```

2. **El `SLUG` debe coincidir con el nombre de la carpeta del clone**: la ruta
   de montaje del compose (`/workspaces/<slug>`) tiene que igualar el
   `workspaceFolder: "/workspaces/${localWorkspaceFolderBasename}"` de
   `devcontainer.json`. Si renombras con un `SLUG` distinto del nombre de la
   carpeta, edita esa ruta a mano.

Tras renombrar, **reconstruye el contenedor** para que aplique todo.

## Después de renombrar

1. `git remote add origin <tu-nuevo-repo-url>`
2. `git add -A && git commit`
3. Rebuild del contenedor (Dev Containers: Rebuild and Reopen in Container)
4. `bin/dev` + abre la app Android desde `mobile/android` (Android Studio
   recrea su propio `local.properties`)

> Si usaste `STRIP_SECRETS=1`, ejecuta `bin/rails credentials:edit` y añade la
> clave `database` (ver [02 · Configuración](02-configuracion.md)).

Detalles completos en `lib/tasks/scaffold.rake`.
