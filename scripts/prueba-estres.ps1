# Pruebas de estrés — TP3 GlobalLogistics (Windows / PowerShell)
# Ejecuta Apache Benchmark DENTRO de un contenedor (no hace falta instalar ab)
# y guarda cada reporte en la carpeta results\.
#
# Uso (desde la carpeta del repo):
#   powershell -ExecutionPolicy Bypass -File .\scripts\prueba-estres.ps1

$ErrorActionPreference = "Continue"
Set-Location (Join-Path $PSScriptRoot "..")

$Red   = "tp3-globallogistics_backend"
$LB    = "http://load-balancer"
$AbImg = "httpd:2.4-alpine"   # imagen oficial de Apache, trae el binario ab
New-Item -ItemType Directory -Force -Path results | Out-Null

function Correr-AB($nombre, $n, $c, $ruta) {
    Write-Host ">> $nombre  (n=$n, c=$c, ruta=$ruta)" -ForegroundColor Cyan
    docker run --rm --network $Red $AbImg ab -l -s 30 -n $n -c $c "$LB$ruta" 2>&1 |
        Out-File -Encoding utf8 "results\$nombre.txt"
    Select-String -Path "results\$nombre.txt" -Pattern "Requests per second","Failed requests","Non-2xx","  95%","  99%" |
        ForEach-Object { $_.Line }
    # Pausa para que el sistema se recupere y NGINX vuelva a habilitar
    # las réplicas que haya marcado como caídas (fail_timeout=10s)
    Start-Sleep 15
}

Write-Host "== Verificando que el entorno esté arriba ==" -ForegroundColor Yellow
docker compose up -d --build
Start-Sleep 5

Write-Host "== ESCENARIO 1: concurrencia moderada (3 réplicas) ==" -ForegroundColor Yellow
Correr-AB "01_moderada_3replicas"       5000  100 "/"
Correr-AB "02_moderada_cpu_3replicas"   2000  100 "/cotizar"
Correr-AB "07_moderada_cpu_liviana_3replicas" 2000 100 "/cotizar?n=2000"

Write-Host "== ESCENARIO 2: concurrencia extrema / saturación (3 réplicas) ==" -ForegroundColor Yellow
Write-Host "   (Tip: en otra terminal corré 'docker stats' y sacá captura del CPU)"
Correr-AB "03_extrema_3replicas"       20000 1000 "/"
Correr-AB "04_extrema_cpu_3replicas"    3000  500 "/cotizar"

Write-Host "== COMPARACIÓN: misma carga con 1 sola réplica ==" -ForegroundColor Yellow
docker compose up -d --scale api=1
Start-Sleep 8
docker compose restart load-balancer; Start-Sleep 3
Correr-AB "05_moderada_cpu_1replica"    2000  100 "/cotizar"
Correr-AB "08_moderada_cpu_liviana_1replica" 2000 100 "/cotizar?n=2000"
Correr-AB "06_extrema_cpu_1replica"     3000  500 "/cotizar"

Write-Host "== Volviendo a 3 réplicas ==" -ForegroundColor Yellow
docker compose up -d --scale api=3
Start-Sleep 8
docker compose restart load-balancer

Write-Host "== Resumen ==" -ForegroundColor Yellow
docker run --rm -v "${PWD}:/w" -w /w node:20-alpine node scripts/resumen.js |
    Tee-Object -FilePath results\resumen.md
Write-Host "Listo. Reportes completos en results\" -ForegroundColor Green
