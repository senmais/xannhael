# Xannhael

Ruby on Rails 8 application. Runs on Ruby 4.0.2 with PostgreSQL as its primary
database. In development, Solid Cache, Solid Queue and Solid Cable each run on
their own SQLite3 file so no extra infrastructure is needed.

## Requirements

- Docker with the VS Code "Dev Containers" extension (recommended)
- A shared Postgres container named `postgres-db` (port `55432 -> 5432` on the host)

## Quick start (devcontainer)

1. Start the shared database container if it is not running:
   ```bash
   docker start postgres-db
   ```
   (`onCreateCommand` also tries to start it when the container boots.)

2. Open the repo in VS Code and run **Dev Containers: Rebuild and Reopen in Container**.
   The first build pulls the Rails Ruby image, Node and tooling — allow a few minutes.

3. Start the app from the integrated terminal:
   ```bash
   bin/dev
   ```
   This runs the web server (http://localhost:3000), the Tailwind CSS watcher
   and the Solid Queue worker via overmind.

4. Inspect background jobs in Mission Control: http://localhost:3000/jobs

Selenium is **not** started by default (it is only needed for system tests).
Launch it on demand with:
```bash
docker compose -f .devcontainer/compose.yaml up -d selenium
```

## Environment variables

The devcontainer injects these from the host via `.devcontainer/devcontainer.json`
(`${localEnv:...}`). Export them in your host shell profile so the tools
authenticate automatically:

| Variable              | Used by  | Purpose                                |
|-----------------------|----------|----------------------------------------|
| `OPENAI_API_KEY`      | codex    | OpenAI authentication                  |
| `OPENCODE_API_KEY`    | opencode | OpenCode Zen and Go providers          |
| `KAMAL_REGISTRY_PASSWORD` | kamal | Registry authentication for deploys |

`DB_HOST`, `PGHOST`, `PGPORT`, `PGUSER` and `PGPASSWORD` are set inside the
devcontainer to reach the shared `postgres-db` container
(`host.docker.internal:55432`, user `postgres`).

## Database

The primary database connection for development comes from the Rails
credentials (`config/credentials.yml.enc`), under the `database` key (host,
port, username, password). Edit it with:

```bash
bin/rails credentials:edit
```

`config/database.yml` defines the development setup: the primary database is
PostgreSQL (`xannhael_development`), while Solid Cache, Solid Queue and Solid
Cable use their own SQLite3 files under `storage/`. Run `bin/rails db:prepare`
to create everything.

## Background jobs

- Solid Queue with the Mission Control web UI mounted at `/jobs`.
- `bin/dev` starts `worker: bin/rails solid_queue:start` next to the web server.
- Inspect, retry and discard jobs at http://localhost:3000/jobs.

## Devcontainer tooling

The container image installs codex and opencode (standalone binaries), overmind
and tmux, and pins bundler to the lockfile version. Persistent named volumes
keep codex/opencode sessions and authentication across container rebuilds:

- `codex-home` → `/home/vscode/.codex`
- `opencode-config` → `/home/vscode/.config/opencode`
- `opencode-data` → `/home/vscode/.local/share/opencode`

VS Code extensions are installed automatically: Ruby LSP, Stimulus LSP, Tailwind
CSS, rdbg, Rails fast nav, ERB beautify, Git Graph, GitHub PRs and GitHub Actions.

## Tests

```bash
bin/rails db:test:prepare
bin/rails test
```