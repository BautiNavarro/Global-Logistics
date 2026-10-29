#!/usr/bin/env bash
# Muestra que peticiones consecutivas son atendidas por distintas réplicas.
for i in $(seq 1 9); do
  host=$(curl -s http://localhost:8080/ | sed -E 's/.*"hostname":"([^"]+)".*/\1/')
  echo "Petición $i -> atendida por réplica $host"
done
