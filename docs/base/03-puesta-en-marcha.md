# 03 · Puesta en marcha

La forma recomendada de trabajar es con **Docker + Dev Containers de VS Code**,
porque el contenedor trae Ruby, el cliente de Postgres, Tailwind, las CLIs (codex/opencode) y
las extensiones ya configuradas.

```mermaid
flowchart TD
    A["Requisitos: Docker +<br/>VS Code Dev Containers"] --> B["Configura PostgreSQL"]
    B --> C["cp .env.example .env"]
    C --> D["Dev Containers:<br/>Rebuild and Reopen in Container"]
    D --> E["bin/dev"]
    E --> F["Web :3000"]
    E --> G["Tailwind watch"]
    E --> H["Solid Queue worker"]
    F --> I["Mission Control /jobs"]
```

## Quick start (devcontainer)

**1. Arranca la base de datos compartida** (si no está corriendo):

```bash
docker start postgres-db
```

**2. Crea tu `.env`** (solo la primera vez, o en cada clone nuevo — es
gitignored, así que cada persona lo tiene):

```bash
cp .env.example .env
# añade claves opcionales si usarás Codex o GitHub CLI.
# OpenCode Go/Zen se autentica dentro de OpenCode con /connect.
```

**3. Abre el repo en VS Code** y ejecuta **Dev Containers: Rebuild and Reopen
in Container**. La primera compilación baja la imagen de Ruby y las herramientas
del contenedor — tarda unos minutos. Este template usa Importmap y Tailwind CSS
para Rails, así que no instala Node ni un gestor de paquetes JavaScript. Si una
aplicación derivada añade un `package.json`, puede habilitar la Feature Node en
su `devcontainer.json`.

Al crearse ejecuta el `postCreateCommand`: ajusta permisos de los volúmenes
solo si aún no están inicializados e instala las gems que falten. No exige
credenciales de servicios externos ni prepara o migra una base de datos
automáticamente.

**OpenCode Go/Zen (primera vez):** abre `opencode` en la terminal, ejecuta
`/connect`, selecciona **OpenCode Go** o **OpenCode Zen** e introduce la API
key de tu plan. Después ejecuta `/models` y elige el modelo. La sesión y las
credenciales se guardan en volúmenes persistentes, por lo que sobreviven a los
rebuilds del devcontainer. No se requiere poner estas claves en `.env`.

**4. Arranca la app** desde la terminal integrada:

```bash
bin/rails db:prepare  # después de confirmar el host y la base de destino
bin/dev
```

`db:prepare` puede crear o migrar la base de datos configurada. Ejecútalo
explícitamente después de revisar `DB_HOST` y los datos de conexión en
`config/credentials.yml.enc` o en las variables de entorno.

Esto lanza (vía **overmind**, que corre el `Procfile.dev` en una sesión tmux):

| Proceso | Comando | URL |
|---------|---------|-----|
| Servidor web | `bin/rails server` | http://localhost:3000 |
| Tailwind CSS | `bin/rails tailwindcss:watch` | — |
| Worker | `bin/rails solid_queue:start` | — |

**5. Inspecciona los trabajos** en Mission Control:
http://localhost:3000/jobs

**6. (Opcional) valida que el editor quedó cableado** — comprueba la
configuración del Ruby LSP **y** hace un handshake real con el servidor
(sugerencias, navegación, símbolos):

```bash
bin/rails lsp:check   # ver 08 · Pruebas y CI
```

## Base de datos: compartida (default) o local por proyecto

Por defecto Compose no arranca el servicio local `db`: Rails se conecta al host
Docker en `host.docker.internal:55432`. El listener del host puede tener cualquier
nombre; `DB_HOST`, `DB_PORT`, `DB_USERNAME` y `DB_PASSWORD` en `.env` definen
la conexión. El ejemplo `postgres-db` del README escucha en el puerto `55432`.

Solo si prefieres una base **aislada por proyecto**, habilita el perfil `local-db`
en `.env`:

```bash
# En .env, establece:
DB_HOST=db
COMPOSE_PROFILES=local-db
```

El servicio local usa PostgreSQL 18.6, arranca junto a Rails en la misma red
Compose, no publica un puerto al host y guarda sus datos en `postgres-data`,
aislado por proyecto. Después de cambiar `.env`, reconstruye el Dev Container y
ejecuta `bin/rails db:prepare` manualmente. Si ya tienes datos creados con
PostgreSQL 17 o anterior, PostgreSQL 18 no los abre directamente: respáldalos y
planifica una actualización mayor antes de cambiar la imagen. Para un servidor
PostgreSQL compartido, usa un usuario y permisos
propios de la aplicación y configura sus dos bases Rails (`<slug>_development`
y `<slug>_test`) antes de preparar la app.

## Selenium (solo para tests de sistema)

Selenium **no arranca por defecto**. Si necesitas system tests:

```bash
docker compose -f .devcontainer/compose.yaml up -d selenium
```

## Herramientas incluidas en el contenedor

- **codex** (binario autónomo) y **OpenCode v2**: se instala con el instalador
  oficial V2 al reconstruir el contenedor.
- **overmind** + **tmux** (ejecutan el Procfile)
- **Bundler** fijado a la versión del lockfile
- Usuario no root **`vscode`** con UID/GID sincronizados con tu host
  (`updateRemoteUserUID`), así lo que creas dentro es tuyo fuera
- `libvips` + `libpq-dev` (compilan/arrancan `ruby-vips` y `pg`)
- Extensiones de VS Code: Ruby LSP, Stimulus LSP, Tailwind CSS, rdbg, Git Graph…

### Volúmenes persistentes (sobreviven a los rebuilds)

| Volumen | Qué guarda |
|---------|------------|
| `bundle` | Gems instaladas (`/usr/local/bundle`) |
| `agent-data` | Estado y configuración de OpenCode/Codex, preferencias Git/GitHub CLI, posible autenticación guardada y extensiones `gh` |

El estado de Codex (`CODEX_HOME`) también queda dentro de `agent-data`, aislado
por proyecto. El volumen `bundle` contiene gems instaladas y sigue siendo
local a cada proyecto.

La configuración GitHub y las extensiones de `gh` son opcionales. Cuando las
necesites, ejecuta `bash .devcontainer/setup-gh.sh` dentro del contenedor.

> El modo predeterminado tiene dos volúmenes nombrados (`bundle` y
> `agent-data`); el perfil `local-db` añade `postgres-data`. El código se monta desde la raíz del repo
> (`..`) en `/workspaces/project`; esa ruta interna es fija para que el
> devcontainer siga funcionando después de renombrar el proyecto.
> `XDG_CONFIG_HOME`, `XDG_STATE_HOME` y `XDG_CACHE_HOME` apuntan dentro de
> `agent-data` para conservar la configuración local de OpenCode, Codex, Git y
> GitHub CLI.

## Git y GitHub desde el contenedor

Dentro del contenedor **no hay claves SSH** (`~/.ssh` solo tiene
`known_hosts`), así que un remote `git@github.com:...` falla siempre con
`Permission denied (publickey)`. El push va por **HTTPS** con el token de
`.env`, delegando en `gh` como helper de credenciales:

```bash
# 1. el remote debe ser HTTPS
git remote -v
git remote set-url origin https://github.com/<org>/<repo>.git

# 2. helper de credenciales SOLO para este repo
#    (el "" corta la lista heredada; así no tocamos ~/.gitconfig del host,
#     cuyo helper apunta al gh.exe de Windows y no corre en Linux)
git config credential.https://github.com.helper ""
git config credential.https://github.com.helper "!gh auth git-credential"

# 3. comprobar y empujar
gh auth status          # usa el token de .env; no necesitas `gh auth login`
git ls-remote origin    # debe listar las ramas sin pedirte nada
git push                # sin -f: el push es fast-forward
```

> ⚠️ Para subir cambios bajo `.github/workflows/` el token necesita el scope
> **`workflow`** (ver `.env.example`).

**¿Prefieres SSH?** Tendrías que crear la clave dentro del contenedor
(`ssh-keygen -t ed25519 -C "tu@email"`), añadir la pública en
GitHub → *Settings → SSH keys*, y volver a apuntar el remote a
`git@github.com:...`. Como `~/.ssh` **no está en ningún volumen**, la clave
se pierde al reconstruir el contenedor.

Sigue con [04 · Arquitectura web](04-arquitectura-web.md).
