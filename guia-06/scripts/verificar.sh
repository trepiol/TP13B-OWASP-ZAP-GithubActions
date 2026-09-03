#!/usr/bin/env bash
set -Eeuo pipefail
BASE_URL=${1:-http://127.0.0.1:${FRONTEND_PORT:-8080}}
APP_USER=${APP_USER:-admin}
APP_PASSWORD=${APP_PASSWORD:-devops123}
COOKIE_JAR=$(mktemp)
trap 'rm -f "$COOKIE_JAR"' EXIT

wait_http(){ for _ in $(seq 1 90); do curl -fsS "$1" >/dev/null && return; sleep 1; done; return 1; }
wait_http "$BASE_URL/health"
curl -fsS "$BASE_URL/" | grep -q 'Notes App'

# Sin sesión, la API de notas debe rechazar con 401
code=$(curl -s -o /dev/null -w '%{http_code}' "$BASE_URL/api/notes")
[[ "$code" == "401" ]] || { echo "ERROR: se esperaba 401 sin login, se obtuvo $code" >&2; exit 1; }

# Login con credenciales incorrectas debe fallar
bad_code=$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'Content-Type: application/json' \
  -d '{"username":"nadie","password":"incorrecta"}' "$BASE_URL/api/login")
[[ "$bad_code" == "401" ]] || { echo "ERROR: se esperaba 401 con credenciales inválidas, se obtuvo $bad_code" >&2; exit 1; }

# Login correcto, guarda cookie de sesión
curl -fsS -c "$COOKIE_JAR" -X POST -H 'Content-Type: application/json' \
  -d "{\"username\":\"$APP_USER\",\"password\":\"$APP_PASSWORD\"}" "$BASE_URL/api/login" | jq -e '.message=="login ok"' >/dev/null

curl -fsS -b "$COOKIE_JAR" "$BASE_URL/api/session" | jq -e '.authenticated==true' >/dev/null
curl -fsS -b "$COOKIE_JAR" "$BASE_URL/api/notes" | jq -e 'type=="array"' >/dev/null

id=$(curl -fsS -b "$COOKIE_JAR" -X POST -H 'Content-Type: application/json' -d '{"title":"validacion","content":"persistencia"}' "$BASE_URL/api/notes" | jq -er .id)
curl -fsS -b "$COOKIE_JAR" "$BASE_URL/api/notes/$id" | jq -e '.title=="validacion"' >/dev/null
curl -fsS -b "$COOKIE_JAR" -X DELETE "$BASE_URL/api/notes/$id" | jq -e '.message=="nota eliminada"' >/dev/null

curl -fsS -b "$COOKIE_JAR" -c "$COOKIE_JAR" -X POST "$BASE_URL/api/logout" | jq -e '.message=="logout ok"' >/dev/null
after_logout=$(curl -s -o /dev/null -w '%{http_code}' -b "$COOKIE_JAR" "$BASE_URL/api/notes")
[[ "$after_logout" == "401" ]] || { echo "ERROR: se esperaba 401 tras logout, se obtuvo $after_logout" >&2; exit 1; }

echo "Login y CRUD verificados en $BASE_URL"
