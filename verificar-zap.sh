#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(dirname "$0")"

if [[ ! -f guia-06/.env ]]; then
  echo "Falta guia-06/.env. Copialo desde guia-06/.env.example." >&2
  exit 1
fi

set -a
# shellcheck disable=SC1091
source guia-06/.env
set +a

docker_cmd=(docker)
if (( EUID != 0 )); then
  docker_cmd=(sudo docker)
fi

echo "=== Verificando Notes App con login ==="
(cd guia-06 && "${docker_cmd[@]}" compose up -d --build --wait)
FRONTEND_PORT="${FRONTEND_PORT:-8080}" guia-06/scripts/verificar.sh

echo "=== Verificando protección sin sesión ==="
codigo=$(curl --silent --output /dev/null --write-out '%{http_code}' \
  "http://127.0.0.1:${FRONTEND_PORT:-8080}/api/notes")
[[ "$codigo" == "401" ]]
echo "Sin sesión, /api/notes respondió HTTP $codigo"

echo "=== Ejecutando ZAP AF con el usuario notes-user ==="
mkdir -p reports
chmod -R a+rwx reports
"${docker_cmd[@]}" run --rm --network host \
  -e APP_USER -e APP_PASSWORD \
  -v "$(pwd):/zap/wrk/:rw" \
  -t ghcr.io/zaproxy/zaproxy:stable \
  zap.sh -cmd -port 8091 -autorun /zap/wrk/.zap/zap-plan.yml
