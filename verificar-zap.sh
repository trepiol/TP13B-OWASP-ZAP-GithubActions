#!/bin/bash
set -euo pipefail

# V2: el contenedor necesita la red del host para acceder a localhost:8080.
# En esta VM Docker requiere sudo para acceder al socket.
echo "=== Verificando Plan de ZAP AF ==="
mkdir -p reports
sudo docker run --rm --network host \
  -e APP_USER -e APP_PASSWORD \
  -v "$(pwd):/zap/wrk/:rw" \
  -t ghcr.io/zaproxy/zaproxy:stable zap.sh \
  -cmd -port 8090 -autorun /zap/wrk/.zap/zap-plan.yml
