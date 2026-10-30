# TP3 — Despliegue de Arquitectura Cloud-Native (GlobalLogistics S.A.)

Arquitectura de Sistemas · Licenciatura en Sistemas de Información · Universidad Champagnat · 2026
Integrantes: Bautista Navarro · Joel Aisama

Este repositorio levanta, con un solo comando, **1 balanceador de carga (NGINX)** y **3 réplicas** de un microservicio REST (Node.js + Express). Además incluye los scripts para reproducir las pruebas de estrés con Apache Benchmark.

```
                              ┌──► api (réplica 1)
Cliente ──► NGINX :8080 ──────┼──► api (réplica 2)
            Round Robin +     └──► api (réplica 3)
            health checks
```

## Requisitos

- Docker Desktop (o Docker Engine) con **Docker Compose v2** (`docker compose version`).
- Nada más: Apache Benchmark se ejecuta dentro de un contenedor (`httpd:2.4-alpine`), no hace falta instalarlo.

## 1. Levantar el entorno

```bash
git clone https://github.com/BautiNavarro/Global-Logistics.git
cd Global-Logistics
docker compose up -d --build
```

Verificar que estén los 4 contenedores (1 `load-balancer` + 3 `api`) en estado `healthy`:

```bash
docker compose ps
```

## 2. Comprobar el balanceo de carga

Cada respuesta incluye el `hostname` (ID del contenedor) que la atendió:

```bash
curl http://localhost:8080/
# {"servicio":"globallogistics-shipment-api","hostname":"3f2c9a1b7d4e","timestamp":"..."}
```

Peticiones consecutivas son atendidas por réplicas distintas:

| Sistema | Comando |
| --- | --- |
| Windows (PowerShell) | `powershell -ExecutionPolicy Bypass -File .\scripts\verificar-balanceo.ps1` |
| Linux / macOS / Git Bash | `./scripts/verificar-balanceo.sh` |

### Endpoints

| Ruta | Para qué sirve |
| --- | --- |
| `GET /` | Endpoint principal. Devuelve el hostname / ID del contenedor. |
| `GET /health` | Health check de la réplica (lo usa Docker). |
| `GET /cotizar?n=20000` | Simula un cálculo pesado (CPU) para llevar las réplicas a saturación. |
| `GET /nginx-health` | Health check del balanceador. |

## 3. Reproducir las pruebas de estrés

| Sistema | Comando |
| --- | --- |
| Windows (PowerShell) | `powershell -ExecutionPolicy Bypass -File .\scripts\prueba-estres.ps1` |
| Linux / macOS / Git Bash | `./scripts/prueba-estres.sh` |

El script ejecuta estos escenarios y guarda cada reporte de `ab` en `results/`:

| # | Escenario | Peticiones (`-n`) | Concurrencia (`-c`) | Ruta |
| --- | --- | --- | --- | --- |
| 01 | Moderada, 3 réplicas | 5.000 | 100 | `/` |
| 02 | Moderada con CPU, 3 réplicas | 2.000 | 100 | `/cotizar` |
| 03 | Extrema, 3 réplicas | 20.000 | 1.000 | `/` |
| 04 | Extrema con CPU (saturación), 3 réplicas | 3.000 | 500 | `/cotizar` |
| 05 | Moderada con CPU, **1 réplica** | 2.000 | 100 | `/cotizar` |
| 06 | Extrema con CPU, **1 réplica** | 3.000 | 500 | `/cotizar` |
| 07 | Moderada con CPU liviana, 3 réplicas | 2.000 | 100 | `/cotizar?n=2000` |
| 08 | Moderada con CPU liviana, **1 réplica** | 2.000 | 100 | `/cotizar?n=2000` |

Al final genera `results/resumen.md` con latencia promedio, p50, p95, p99, máxima y porcentaje de errores de cada escenario.

Para correr una prueba suelta a mano:

```bash
docker run --rm --network tp3-globallogistics_backend httpd:2.4-alpine \
  ab -l -n 5000 -c 100 http://load-balancer/
```

Mientras corre el escenario extremo, en otra terminal:

```bash
docker stats
```

## 4. Probar la resiliencia (health checks)

```bash
docker compose ps                     # anotar el nombre de una réplica
docker stop tp3-globallogistics-api-2  # "matar" una réplica
./scripts/verificar-balanceo.sh       # el tráfico sigue, repartido entre las 2 que quedan
docker start tp3-globallogistics-api-2
```

## 5. Apagar todo

```bash
docker compose down
```

## Decisiones de diseño

- **Una réplica por contenedor, sin puerto publicado.** Solo el balanceador expone un puerto (`8080`). Así Compose puede crear las 3 réplicas con `deploy.replicas: 3`.
- **NGINX apunta al nombre del servicio (`api:3000`), nunca a `localhost`.** Dentro de Docker, `localhost` es el propio contenedor de NGINX. El DNS interno de Docker (`127.0.0.11`) resuelve `api` a las IPs de las 3 réplicas, y con `resolve` NGINX las vuelve a consultar si un contenedor se reinicia.
- **Health checks en dos niveles.**
  - Docker comprueba `/health` en cada réplica cada 10 s y reinicia las que fallan (`restart: unless-stopped`). NGINX no arranca hasta que las réplicas están sanas.
  - NGINX hace health check pasivo: si una réplica falla 2 veces en 10 s (`max_fails=2 fail_timeout=10s`), la saca de la rotación y reintenta la petición en otra (`proxy_next_upstream`).
  - NGINX open source no tiene health checks activos (son de NGINX Plus); por eso se combinan con los de Docker.
- **Límite de CPU por réplica (`0.50` núcleos).** Hace que la saturación sea reproducible en cualquier computadora y permite comparar 1 réplica contra 3.
- **Imagen liviana** (`node:20-alpine`), usuario sin privilegios y respuesta JSON de largo fijo, para que `ab` no cuente respuestas válidas como fallidas.
