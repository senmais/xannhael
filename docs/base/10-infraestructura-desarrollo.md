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
- Git y GitHub CLI guardaban su configuración en `/home/vscode/.config`, que
  no estaba montada. La configuración de Git, GitHub CLI y extensiones debe
  quedar en el volumen del proyecto.
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
   agentes se mantienen por proyecto. Solo los archivos descargados de gems
   se comparten en un volumen externo estable; instalaciones y extensiones
   compiladas se mantienen locales.
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

## Cambios aplicados

- Las credenciales de Codex y GitHub dejaron de ser requisitos del ciclo de
  creación. GitHub CLI se configura bajo demanda. El hook ya no prepara bases
  automáticamente ni inicia PostgreSQL externo.
- `init-volumes.sh` guarda un marcador en cada volumen tras el ajuste inicial
  de propietario. Los rebuilds posteriores evitan recorrer nuevamente todas
  las gems y sesiones persistentes.
- Se retiraron Node y pnpm de la imagen base porque esta app usa Importmap y
  Gems y no contiene manifiestos JavaScript. Un proyecto derivado puede activar
  la Feature Node cuando la necesite.
- `CODEX_HOME` persiste en `agent-data`, separado por proyecto. Los volúmenes de
  Gems y agentes no se comparten entre proyectos. Git y GitHub CLI usan ahora
  el mismo volumen para sus preferencias, autenticación y extensiones.
- PostgreSQL acepta `DB_HOST`, `DB_PORT`, `DB_USERNAME` y `DB_PASSWORD`. El modo
  compartido usa un listener del host configurable. El perfil `local-db` crea
  un servicio y volumen aislados, sin publicar su puerto.
- El primer arranque de base es explícito: se revisa la conexión y se ejecuta
  `bin/rails db:prepare` a mano. Las bases de desarrollo y test reciben nombres
  derivados del slug que `scaffold:rename` escribe en `config/database.yml`.
- Las imágenes del servicio local de PostgreSQL 18.6 y de Selenium tienen etiquetas
  fijas. PostgreSQL local y Selenium no tienen política de reinicio autónomo;
  se inician desde el perfil o bajo demanda.
- Las gems instaladas y sus archivos de instalación quedan dentro del volumen
  `bundle` de cada proyecto. No se comparte un árbol de instalación compatible
  solo por nombre: Ruby, arquitectura y extensiones nativas pueden diferir.
- Un volumen Docker externo y estable comparte los archivos descargados de
  gems entre clones. Bundler conserva las instalaciones en `bundle` por
  proyecto; índices y extensiones no se montan en ese volumen.
- El contexto de la imagen Rails de producción excluye documentación, tests,
  cliente Android, Procfile de desarrollo y configuración de agentes; no son
  archivos de ejecución de esa imagen.

La compilación y el arranque no se midieron porque el daemon Docker no estaba
disponible en la sesión. Los checks de configuración locales pasan; consulta el
resultado final de la auditoría para las limitaciones de validación.
