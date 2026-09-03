# TP13B - OWASP ZAP y GitHub Actions

Integré la Notes App con OWASP ZAP Automation Framework para ejecutar un análisis DAST en cada `push` a `main` o `develop` y en los pull requests dirigidos a `main`.

## Archivos principales

- `.zap/zap-plan.yml`: contexto, Spider, AJAX Spider, espera del análisis pasivo, Active Scan y reporte HTML.
- `.github/workflows/zap-security.yml`: levanta la aplicación, comprueba `/health`, ejecuta ZAP y publica el reporte durante siete días.
- `verificar-zap.sh`: reproduce el plan en la VM antes del push.

## Versión 1 y versión 2

La versión inicial, conservada en el commit `5eaa12b`, reproduce el enunciado. Al ejecutarla comprobé estas limitaciones relevantes:

1. El Compose del TP06 publicaba el frontend en el puerto 80, pero el plan buscaba `localhost:8080`.
2. El script local ejecutaba ZAP en una red Docker separada; desde allí `localhost` no era la VM.
3. El workflow hacía un segundo `actions/checkout`, que podía limpiar el directorio `reports/` antes de subir el artefacto.
4. La entrada `token` no existe en `zaproxy/action-af@v0.3.0` y GitHub la informa como entrada inesperada.
5. La Notes App del TP06 no implementa autenticación. Los secretos se transfieren al contenedor como pide la guía, pero todavía no son consumidos por la aplicación.
6. ZAP intenta abrir su proxy en el puerto 8080 por defecto. Al usar ese mismo puerto para la Notes App, la prueba local devolvió `java.net.BindException: Address already in use`.

En la versión 2 alineé Compose con el puerto 8080, reemplacé `sleep 30` por una espera activa de `/health`, eliminé el segundo checkout y la entrada no admitida, agregué `--network host` al verificador local y reservé el puerto 8090 para el proxy interno de ZAP.

## Comprobación local

```bash
docker compose up -d --build
curl --fail http://localhost:8080/health
export APP_USER=zap-test
export APP_PASSWORD='<secreto de prueba>'
./verificar-zap.sh
```

El reporte resultante queda en `reports/zap-report.html`. No registro ni muestro el valor de `APP_PASSWORD`.

## Propuesta de autenticación para una futura versión

Para que el escaneo sea realmente autenticado, primero agregaría autenticación a la Notes App. Si la API utilizara un token HTTP, reemplazaría los secretos genéricos por las variables admitidas directamente por ZAP:

```yaml
env:
  ZAP_AUTH_HEADER: Authorization
  ZAP_AUTH_HEADER_VALUE: ${{ secrets.ZAP_AUTH_HEADER_VALUE }}
  ZAP_AUTH_HEADER_SITE: localhost
```

Así el secreto tendría un uso verificable y el plan podría comparar rutas públicas y protegidas.
