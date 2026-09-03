# TP13B — OWASP ZAP y GitHub Actions

En este repositorio integré la Notes App autenticada de `guia-06/` con OWASP ZAP Automation Framework y GitHub Actions.

## Qué comprobé

Comprobé dos estados antes de escanear:

- sin sesión, `GET /api/notes` responde HTTP 401;
- con el usuario `notes-user`, ZAP ejecuta el login JSON contra `POST /api/login`, conserva la cookie de Flask y accede a `/api/session` y `/api/notes` con HTTP 200.

Después ejecuté Spider, AJAX Spider, análisis pasivo, Active Scan y el reporte HTML moderno usando ese usuario autenticado.

## Preparación local

```bash
cp guia-06/.env.example guia-06/.env
chmod +x guia-06/instalar.sh guia-06/operaciones.sh \
  guia-06/scripts/verificar.sh guia-06/backend/entrypoint.sh verificar-zap.sh
cd guia-06
sudo docker compose up -d --build --wait
FRONTEND_PORT=8080 ./scripts/verificar.sh
cd ..
./verificar-zap.sh
```

No versioné `guia-06/.env`. El plan toma `APP_USER` y `APP_PASSWORD` del entorno mediante `${APP_USER}` y `${APP_PASSWORD}`.

## GitHub Actions

Configuré los Repository secrets `APP_USER` y `APP_PASSWORD`. En el workflow pasé los mismos valores tanto a Docker Compose como al contenedor de ZAP; de esa manera, la aplicación y el escáner usan el mismo par de credenciales.

El workflow publica `zap-authenticated-security-report` durante siete días, incluso si una ejecución falla.

## Cambios que apliqué respecto de la versión base

La guía base describe correctamente un primer escaneo anónimo. Para demostrar autenticación real agregué en `.zap/zap-plan.yml`:

- autenticación JSON contra `/api/login`;
- manejo de sesión por cookie;
- verificación periódica mediante `/api/session`;
- un usuario llamado `notes-user` cuyas credenciales provienen de secretos;
- trabajos `requestor` que validan HTTP 401 sin sesión y HTTP 200 con sesión;
- el parámetro `user: notes-user` en Spider, AJAX Spider y Active Scan;
- exclusión de `/api/logout` y `logoutAvoidance: true`.

También eliminé la entrada `token` del ejemplo porque `zaproxy/action-af@v0.3.0` no la declara, y mantuve el proxy interno de ZAP en 8091 para evitar la colisión con la aplicación en 8080.

