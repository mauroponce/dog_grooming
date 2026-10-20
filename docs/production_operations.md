# Operaciones de producción

Esta es la guía canónica para desplegar y operar el beta de Cita.pet. Producción usa `compose.production.yml` y el script raíz `deploy.sh` desde el propio servidor.

## 1. Dependencias y aislamiento

El host necesita Docker con Compose, Git, `curl` y AWS CLI. La instalación vive por defecto en `/opt/cita.pet/dog_grooming` y no debe compartir base, volúmenes ni buckets con otra aplicación.

Preparar antes del primer deploy:

- DNS de `cita.pet` hacia el servidor y puertos 80/443 libres para Caddy.
- Una aplicación Google OAuth con callback productivo autorizado.
- Una aplicación Mercado Pago con el redirect OAuth `https://cita.pet/admin/configuracion/mercadopago/callback` autorizado.
- Un dominio remitente verificado en Resend.
- Buckets R2 privados y exclusivos: uno general/backups y otro para imágenes de servicios.
- Una credencial R2 capaz de leer, escribir y listar el bucket de backups.

## 2. Configuración

Copiar [`.env.production.example`](../.env.production.example) a `/opt/cita.pet/dog_grooming/.env.production`, reemplazar todos los placeholders y mantener el archivo real fuera de Git. El preflight exige:

```text
SECRET_KEY_BASE
DOG_GROOMING_DATABASE_PASSWORD
APP_HOST=cita.pet
GOOGLE_CLIENT_ID
GOOGLE_CLIENT_SECRET
RESEND_API_KEY
CLOUDFLARE_ACCESS_KEY_ID
CLOUDFLARE_SECRET_ACCESS_KEY
CLOUDFLARE_R2_ENDPOINT
CLOUDFLARE_R2_BUCKET
CLOUDFLARE_R2_SERVICE_IMAGES_BUCKET
```

Configurar además:

```text
APP_PROTOCOL=https
APP_WWW_HOST=www.cita.pet
APP_HOSTS=cita.pet,www.cita.pet
RESEND_FROM=Cita.pet <notificaciones@cita.pet>
MAIL_FROM=Cita.pet <notificaciones@cita.pet>
FORCE_SSL=true
MERCADO_PAGO_REDIRECT_URI=https://cita.pet/admin/configuracion/mercadopago/callback
```

`CLOUDFLARE_ACCOUNT_ID` y `CLOUDFLARE_R2_ANALYTICS_TOKEN` son opcionales para métricas oficiales en `/super_admin/uso`. Para habilitar el cobro de señas por Mercado Pago también se configuran las credenciales OAuth productivas y `MERCADO_PAGO_WEBHOOK_SECRET`; la cuenta de cada peluquería se vincula luego desde su configuración.

Validar la interpolación sin arrancar servicios:

```sh
docker compose -f compose.production.yml --env-file .env.production config --quiet
```

## 3. Deploy

Primer arranque desde una máquina con acceso SSH:

```sh
scp deploy.sh citapet_production:/opt/cita.pet/dog_grooming/deploy.sh
ssh citapet_production 'cd /opt/cita.pet/dog_grooming && chmod +x deploy.sh && ./deploy.sh'
```

Deploys posteriores:

```sh
ssh citapet_production 'cd /opt/cita.pet/dog_grooming && ./deploy.sh'
```

El script aborta si faltan `.env.production`, configuración obligatoria o si hay cambios locales rastreados. Por defecto despliega `main`; para fijar o volver a una revisión exacta:

```sh
REVISION=<sha-o-tag> ./deploy.sh
```

Antes de migrar hace un backup, construye la imagen, ejecuta `citapet:production_preflight`, corre `db:create` y `db:migrate`, levanta los servicios y verifica `/up`, `/acceder` y `/`. `RUN_BACKUP=0` existe sólo para una emergencia explícita.

### Base vacía y superadmin

El deploy crea esquemas pero nunca datos de aplicación. No ejecutar `db:seed` en producción; la tarea aborta explícitamente en ese entorno.

Después del primer deploy, preaprovisionar el operador con el mismo email que usará en Google:

```sh
docker compose -f compose.production.yml --env-file .env.production run --rm \
  -e SUPER_ADMIN_EMAIL=admin@cita.pet \
  -e SUPER_ADMIN_NAME='Operaciones Cita.pet' \
  web bin/rails citapet:bootstrap_super_admin
```

La tarea es idempotente, no asigna contraseña y rechaza reutilizar un usuario común existente.

## 4. Backups y restauración

`ops/backup_postgres.sh` crea un dump comprimido de `dog_grooming_production`, lo sube a `s3://$CLOUDFLARE_R2_BUCKET/backups/postgres/`, borra la copia temporal local y elimina objetos remotos más antiguos que `POSTGRES_BACKUP_RETENTION_DAYS` (30 por defecto).

Además del backup automático previo a cada deploy, programar el script diariamente en el host. Comprobar periódicamente que los objetos existen y hacer una restauración de ensayo.

Restauración controlada:

1. Detener `web` y conservar `db` activo.
2. Descargar un dump elegido desde R2 a un directorio temporal con permisos restringidos.
3. Crear una base de restauración aislada y cargar allí el dump primero.
4. Verificar integridad y sólo entonces restaurar la base productiva, con una ventana aprobada.
5. Eliminar la copia temporal y ejecutar las comprobaciones posteriores.

La migración `20261017160000_remove_ai_customer_portal_and_waitlist` es irreversible y elimina datos. No aplicarla sin un backup restaurable.

## 5. Verificación posterior

```sh
curl -I --max-time 20 https://cita.pet/up
docker compose -f compose.production.yml --env-file .env.production ps
docker compose -f compose.production.yml --env-file .env.production logs --tail=200 web
```

Verificar manualmente:

- acceso Google del superadmin y de un negocio;
- alta/onboarding de un negocio de prueba controlado;
- página pública `https://cita.pet/:slug` y reserva sin profesional;
- seña manual, carga de comprobante, aprobación y email;
- vinculación de una cuenta de Mercado Pago y cobro de una seña de prueba controlada;
- agenda, cliente, mascota, reprogramación e invitación al equipo;
- objeto privado visible por Active Storage y entrega de Resend;
- ejecución del scheduler y workers de Solid Queue.

No abrir el beta si falla un flujo crítico, el backup no está disponible o los logs muestran migraciones/jobs fallidos.

## 6. Rollback

Para un problema de código sin migración incompatible, desplegar la revisión anterior con `REVISION=<sha> ./deploy.sh` y repetir la verificación. No intentar revertir la migración irreversible mencionada: restaurar el backup bajo una ventana controlada. Las restauraciones o cambios destructivos requieren aprobación operativa explícita.

## 7. Mantenimiento de celulares

La normalización de números antiguos se audita primero y sólo se aplica tras revisar el resultado y confirmar backup:

```sh
docker compose -f compose.production.yml --env-file .env.production exec -T web bash -lc 'bin/rails customers:normalize_mobile_numbers'
docker compose -f compose.production.yml --env-file .env.production exec -T web bash -lc 'APPLY=1 bin/rails customers:normalize_mobile_numbers'
```

La tarea no imprime contactos y omite números incompletos o colisiones.

## 8. Procesamiento y comunicaciones de facturación

`Billing::DailyJob` corre cada quince minutos. Aplica vencimientos y suspensiones desde el comienzo del día correspondiente en `America/Argentina/Buenos_Aires`, y recupera recordatorios `pending` o `failed` cuyo lease de una hora venció. Antes de reencolar consulta el `active_job_id` en Solid Queue; si la cola no está disponible, conserva el recordatorio sin duplicarlo y registra el error para reintentar en la próxima ejecución.

`Billing::DailyNotificationsJob` corre una vez por día a las 08:30 de `America/Argentina/Buenos_Aires`. En esa ejecución crea y encola los recordatorios ordinarios que correspondan y envía el resumen diario al superadmin. La zona está incluida explícitamente en el cron de `config/recurring.yml`, por lo que el horario no depende de la zona del servidor. La recuperación de un aviso fallido sigue ocurriendo cada quince minutos y puede reencolarlo fuera de esa ventana; el procesador frecuente no crea avisos ordinarios nuevos.

Los correos tienen semántica de entrega al menos una vez. Si el proveedor acepta un mensaje y el worker cae antes de persistir `sent`, una recuperación posterior puede repetirlo. Ante duplicados, revisar juntos el recordatorio, los jobs con ese `active_job_id` y los logs del proveedor; no cambiar manualmente una suscripción ni su suspensión para corregir el aviso.

Antes del primer deploy desde una revisión anterior a `20261019140000_make_billing_reminders_retryable`, comprobar el estado de las migraciones y que no existan recordatorios históricos. La migración simplificada presupone la base vacía declarada para el lanzamiento:

```sh
docker compose -f compose.production.yml --env-file .env.production exec -T web bash -lc 'bin/rails db:migrate:status'
docker compose -f compose.production.yml --env-file .env.production exec -T db \
  psql -U dog_grooming -d dog_grooming_production -c 'SELECT COUNT(*) AS billing_reminders_count FROM billing_reminders;'
```

Si `20261019140000` todavía figura pendiente y el conteo no es cero, detener el despliegue. Eliminar esos datos o reiniciar una base requiere backup y autorización operativa explícita.
