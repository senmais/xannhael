# 10 · Infraestructura de desarrollo

Este documento describe la infraestructura que trae el template y las reglas
para mantenerla ligera, reproducible y segura al crear proyectos derivados.

## Auditoría de partida

Revisado el 23 de octubre de 2026: `.devcontainer/`, ambos Dockerfiles,
Compose, ignores, hooks, configuración Rails de datos, Gemfile, configuración
Android y documentación de inicio.

### Estado observado

- El Dev Container usa un servicio Rails y Selenium opcional. PostgreSQL no
  está definido en Compose: la configuración espera un contenedor externo
  llamado `postgres-db` en `host.docker.internal:55432`.
- `config/database.yml` fija `xannhael_development` y `xannhael_test`, y los
  valores de conexión de desarrollo se leen de credenciales Rails. Los
  proyectos derivados pueden colisionar en la instancia compartida si no
  renombran también esas bases. La conexión documentada usa el usuario
  superusuario `postgres`.
- `bundle` y `agent-data` son volúmenes nombrados administrados por Compose.
  Sus nombres efectivos llevan el prefijo del proyecto Compose, por lo que no
  se comparten entre clones. El primero contiene gems instaladas, no solo
  descargas reutilizables; compartirlo sin una clave de compatibilidad no es
  seguro. `agent-data` conserva estado sensible y debe permanecer aislado.
- El código fuente y `storage/` son locales al proyecto. Solid Cache, Queue y
  Cable usan tres archivos SQLite en `storage/`; no se debe compartir ese
  directorio.
- El Dockerfile del Dev Container instala utilidades, Codex y OpenCode durante
  el build. `devcontainer.json` añade GitHub CLI, cliente PostgreSQL y
  Docker-outside-of-Docker. Bundler instala gems en un volumen persistente y
  `postCreateCommand` usa `bundle check` antes de instalar.
- `postCreateCommand` exigía una clave OpenAI y un token de GitHub, y preparaba
  automáticamente la base con `db:prepare`. Esto mezclaba credenciales de
  herramientas opcionales con la creación del contenedor y podía migrar la base
  compartida sin una confirmación explícita. También recorre recursivamente
  los volúmenes de gems y agentes con `chown`.
- Node y pnpm se especifican como `lts` y `latest`; las Features usan tags de
  versión mayor. Overmind y Codex/OpenCode tienen mecanismos de instalación
  distintos, con versiones no todas fijadas en la configuración del template.
- Android se desarrolla fuera del Dev Container, desde Android Studio. Los
  directorios `.gradle`, `build` y `local.properties` están excluidos de Git;
  no se instala un segundo SDK Android dentro de la imagen Rails.
- `.dockerignore` excluye entorno local, credenciales, estado de desarrollo,
  Android y configuración del Dev Container; `.gitignore` conserva
  `.env.example` y excluye secretos, SQLite y artefactos locales.
- Git usa HTTPS con GitHub CLI según la documentación actual. No se monta
  `~/.ssh` ni se copian claves privadas en la imagen.
- `CODEX_HOME` por defecto es `~/.codex`, fuera del volumen `agent-data`;
  reconstruir el contenedor podía perder la configuración y las sesiones de
  Codex.
- El repositorio no contiene `package.json` ni lockfile de npm, pnpm o Yarn;
  usa Importmap y Tailwind CSS desde Gems. Node y pnpm se retiraron del
  contenedor base. Una aplicación derivada con dependencias JavaScript puede
  habilitar la Feature Node en su configuración.

### Riesgos y decisiones de arquitectura

1. El nombre de la base Rails y sus credenciales deben seguir la identidad
   renombrada de cada aplicación. Un PostgreSQL compartido solo es seguro si
   cada proyecto tiene bases separadas y, de ser posible, un usuario propio.
2. El PostgreSQL compartido debe ser optativo y configurable. El template no
   debe arrancar ni modificar bases externas, ni crear, migrar o borrar datos
   automáticamente fuera de las bases de la aplicación.
3. Gems instaladas, `node_modules`, SQLite, uploads, credenciales y estado de
   agentes se mantienen por proyecto. Si se añade una caché global, se limita
   a artefactos descargados y se documenta su compatibilidad y nombre estable.
4. La configuración de agentes persiste por proyecto para no mezclar sesiones
   ni credenciales. El código y los volúmenes de datos de Compose también
   permanecen separados por clon.
5. Android sigue siendo opcional y externo al contenedor web. Su caché de
   descargas puede persistir en el perfil del desarrollador, mientras que
   builds e intermediarios permanecen propios de cada aplicación.
6. El hook `postCreateCommand` solo instala gems y prepara directorios. Las
   credenciales externas son opcionales, `setup-gh.sh` se ejecuta bajo demanda
   y las bases se preparan manualmente después de revisar el destino.
   `CODEX_HOME` apunta al volumen aislado del proyecto.

### Línea base disponible

El repositorio estaba limpio al iniciar la auditoría. El entorno de esta sesión
no devolvió metadatos del servidor Docker, imágenes ni espacio de volúmenes;
por ello no se pudo medir una línea base de ejecución. No se estiman cifras.

| Métrica | Antes | Después |
|---|---|---|
| Tamaño de imagen Dev Container | No disponible: daemon Docker no accesible en esta sesión | Pendiente de validar |
| Espacio de volúmenes | No disponible: daemon Docker no accesible en esta sesión | Pendiente de validar |
| Caché de build | No disponible: daemon Docker no accesible en esta sesión | Pendiente de validar |
| Build inicial / rebuild | No medido | Pendiente de validar |
| Arranque / RAM / procesos | No medido | Pendiente de validar |

## Reglas de uso

- Revisa `.devcontainer/compose.yaml` y `config/database.yml` al renombrar una
  copia del template; la identidad de la app debe coincidir en Rails y en su
  base de datos.
- Usa recursos de aplicación locales para datos persistentes. No ejecutes
  limpiezas globales de Docker para liberar espacio de un proyecto.
- No compartas un directorio de gems instaladas, `node_modules`, Android
  `build/` ni datos de agentes entre proyectos.
- La eliminación de un contenedor o la reconstrucción del Dev Container no
  debe implicar eliminar volúmenes ni bases de datos.
- Consulta `docker system df` y el listado de volúmenes para diagnosticar el
  consumo. Antes de retirar un recurso, identifica qué proyectos lo usan y
  conserva una copia de los datos que necesites.
