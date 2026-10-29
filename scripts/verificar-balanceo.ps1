# Muestra que peticiones consecutivas son atendidas por distintas réplicas.
# Uso: powershell -ExecutionPolicy Bypass -File .\scripts\verificar-balanceo.ps1
1..9 | ForEach-Object {
    $r = Invoke-RestMethod -Uri "http://localhost:8080/"
    Write-Host ("Petición {0} -> atendida por réplica {1}" -f $_, $r.hostname)
}
