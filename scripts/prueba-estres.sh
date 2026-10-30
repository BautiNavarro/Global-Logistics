#!/usr/bin/env bash
# Pruebas de estrés — TP3 GlobalLogistics (Linux / macOS / Git Bash)
# Ejecuta Apache Benchmark DENTRO de un contenedor (no hace falta instalar ab)
# y guarda cada reporte en la carpeta results/.
#
# Uso:  ./scripts/prueba-estres.sh
set -euo pipefail
cd "$(dirname "$0")/.."

PROYECTO="tp3-globallogistics"
RED="${PROYECTO}_backend"
LB="http://load-balancer"
AB_IMG="httpd:2.4-alpine"   # imagen oficial de Apache, trae el binario ab
mkdir -p results

correr_ab () {  # $1 = nombre, $2 = peticiones, $3 = concurrencia, $4 = ruta
  echo ">> $1  (n=$2, c=$3, ruta=$4)"
  docker run --rm --network "$RED" "$AB_IMG" \
    ab -l -s 30 -n "$2" -c "$3" "$LB$4" > "results/$1.txt" 2>&1 || true
  grep -E "Requests per second|Failed requests|Non-2xx|  95%|  99%" "results/$1.txt" || true
  # Pausa para que el sistema se recupere y NGINX vuelva a habilitar
  # las réplicas que haya marcado como caídas (fail_timeout=10s)
  sleep 15
}

echo "== Verificando que el entorno esté arriba =="
docker compose up -d --build
sleep 5

echo "== ESCENARIO 1: concurrencia moderada (3 réplicas) =="
correr_ab "01_moderada_3replicas"        5000   100 "/"
correr_ab "02_moderada_cpu_3replicas"    2000   100 "/cotizar"
correr_ab "07_moderada_cpu_liviana_3replicas" 2000 100 "/cotizar?n=2000"

echo "== ESCENARIO 2: concurrencia extrema / saturación (3 réplicas) =="
echo "   (Tip: en otra terminal corré 'docker stats' y sacá captura del CPU)"
correr_ab "03_extrema_3replicas"        20000  1000 "/"
correr_ab "04_extrema_cpu_3replicas"     3000   500 "/cotizar"

echo "== COMPARACIÓN: misma carga con 1 sola réplica =="
docker compose up -d --scale api=1
sleep 8
docker compose restart load-balancer && sleep 3
correr_ab "05_moderada_cpu_1replica"     2000   100 "/cotizar"
correr_ab "08_moderada_cpu_liviana_1replica" 2000 100 "/cotizar?n=2000"
correr_ab "06_extrema_cpu_1replica"      3000   500 "/cotizar"

echo "== Volviendo a 3 réplicas =="
docker compose up -d --scale api=3
sleep 8
docker compose restart load-balancer

echo "== Resumen =="
docker run --rm -v "$PWD":/w -w /w node:20-alpine node scripts/resumen.js | tee results/resumen.md
echo "Listo. Reportes completos en results/"
