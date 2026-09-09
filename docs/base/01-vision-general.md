# 01 · Visión general

> **Xannhael** es un **template funcional de Rails 8** que combina una **app
> web** con un **cliente móvil Android (Hotwire Native)** que hablan entre sí.
> Está pensado para clonarlo, renombrarlo y convertirlo en cualquier proyecto:
> blog, ecommerce, SaaS, CRM…

```mermaid
flowchart LR
    subgraph Web["App web (Rails 8)"]
        Rails["Puma + Rails server"]
        TW["Tailwind CSS"]
        HQ["Solid Queue worker"]
    end

    subgraph Android["Cliente Android"]
        HN["Hotwire Native"]
        WV["WebView Turbo"]
    end

    PG[("PostgreSQL — DB principal")]
    SQL[("SQLite — Cache / Queue / Cable")]

    Browser["Navegador"] --> Rails
    Rails --> PG
    Rails --> SQL
    Android -->|"WebView carga Rails"| Rails
```

## Stack tecnológico

| Capa | Tecnología | Rol |
|------|-----------|-----|
| Framework | Ruby on Rails 8 (Ruby 4.0.2) | Backend + render del frontend |
| Frontend | Hotwire (Turbo + Stimulus) | HTML en tiempo real, sin SPA pesada |
| Estilos | Tailwind CSS | Diseño y tema "Omarchy" |
| DB principal | PostgreSQL | Datos de la aplicación |
| Colas/caché | Solid Queue · Solid Cache · Solid Cable | Trabajos en segundo plano, caché, websockets |
| Web móvil | Hotwire Native (Android) | Shell nativo + WebView |
| Despliegue | Kamal + Thruster + Docker | Producción en un comando |

## Cómo encaja todo

```mermaid
graph TB
    subgraph Dev["Desarrollo (devcontainer)"]
        Dev1["VS Code Dev Containers"] --> Dev2["Contenedor Rails"]
        Dev2 --> Dev3["overmind (bin/dev)"]
        Dev3 --> Dev4["Web server :3000"]
        Dev3 --> Dev5["Tailwind watch"]
        Dev3 --> Dev6["Solid Queue worker"]
        Dev2 --> Dev7["Postgres compartido<br/>(postgres-db)"]
        Dev2 --> Dev8["SQLite solid_* (storage/)"]
    end

    subgraph Prod["Producción"]
        P1["Kamal"] --> P2["Contenedor Docker"]
        P2 --> P3["Thruster + Puma"]
        P2 --> P4["Solid Queue en Puma"]
    end
```

## Flujo de una petición típica

```mermaid
sequenceDiagram
    participant N as Navegador / WebView
    participant R as Rails (Puma)
    participant P as PostgreSQL
    participant Q as Solid Queue

    N->>R: GET /?option=ruby
    R->>P: Consulta datos
    P-->>R: Resultados
    R-->>N: HTML + Turbo (partials por opción)
    N->>R: GET /jobs (Mission Control)
    R->>Q: Estado de trabajos en segundo plano
```

## ¿Qué se explora aquí?

- **Web**: un índice con 4 secciones (Ruby, Hotwire, Kamal, Omarchy) que cambia
  según el parámetro `?option=`. Incluye cambio de tema claro/oscuro, toasts
  y navegación con Turbo.
- **Móvil**: la misma web dentro de un shell Android con barra de pestañas
  nativa, conectado por **Turbo Native bridge**.
- **Fondo**: Solid Queue expone una UI de inspección en `/jobs`.

Sigue con [02 · Configuración](02-configuracion.md).
