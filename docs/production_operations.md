# Operaciones de producción

Esta guía corresponde exclusivamente a Cita.pet. Los valores de dominio, servidor y registro son placeholders deliberados: deben definirse antes del primer deploy.

## Valores a definir antes del deploy

- `KAMAL_HOST`: IP o hostname del servidor de Cita.pet.
- `APP_HOST=cita.pet` y `APP_WWW_HOST=www.cita.pet` (o los dominios reales).
- `APP_HOSTS=cita.pet,www.cita.pet` más la IP de diagnóstico si hiciera falta.
- `DOG_GROOMING_DATABASE_PASSWORD`: contraseña nueva para PostgreSQL de producción.
- Credenciales de Mercado Pago y Resend propias.
- Los dos buckets R2 aislados: `dog-grooming` y `dog-grooming-service-images`.

No reutilices el servidor, dominio, base de datos, volúmenes ni buckets de otra instalación.

## Deploy con Kamal

`bin/kamal` lee `.env`. Configurá primero las variables productivas en el host o en el secret manager:

```sh
KAMAL_HOST=server.example.com
KAMAL_IMAGE=ghcr.io/your-org/dog_grooming
DOG_GROOMING_DATABASE_PASSWORD=una_contrasena_larga_y_unica
APP_HOST=cita.pet
APP_PROTOCOL=https
```

Validar sin desplegar:

```sh
bin/kamal secrets print
bin/kamal config
```

Desplegar:

```sh
bin/kamal setup
bin/kamal deploy
```

`compose.production.yml` publica 80/443 mediante Caddy. Si convivirá con otra app en el mismo host, configurá un proxy compartido antes de levantarlo.

## Backups PostgreSQL

`ops/backup_postgres.sh` genera el dump de la base `dog_grooming_production` y lo guarda en:

```text
s3://dog-grooming/backups/postgres/
```

Antes de automatizarlo, verificá que el token R2 pueda leer, escribir y listar ese bucket. Para restaurar, detené el servicio web, descargá el backup elegido al host de destino y restauralo solamente contra la base `dog_grooming_production`.

## Email

Para email productivo, verificá tu dominio en Resend y configurá, por ejemplo:

```sh
MAIL_FROM="Cita.pet <notificaciones@tu-dominio.com>"
RESEND_FROM="Cita.pet <notificaciones@tu-dominio.com>"
```

## Recordatorios de turnos y celulares

El scheduler de Solid Queue debe ejecutar `send_due_appointment_reminders` cada minuto y tener un worker para la cola `default`. Reiniciar workers/scheduler junto con el código que agrega `SendDueAppointmentRemindersJob` y `SendAppointmentReminderJob`. Verificar envío SMTP y revisar jobs fallidos; `notification_deliveries` guarda destinatario, plantilla `customer_reminder`, estado y fecha de envío. `appointments.reminder_sent_at` evita envíos repetidos normales y se reinicia al reprogramar.

Se envía cuando el turno confirmado entra en las próximas 24 horas, con la demora propia de la cola. Confirmaciones de último momento encolan inmediatamente. El job vuelve a comprobar fecha, email y estado antes de enviar. Un fallo entre entrega SMTP y commit puede causar un duplicado al reintentar; no marcar un envío como exitoso manualmente sin comprobarlo.

La migración de `mobile_area_code` es aditiva y debe aplicarse antes del código que usa ese campo. Revisar en configuración el código de área de cada negocio antes de normalizar datos antiguos. Auditar primero; la aplicación no fusiona clientes ni aplica esta corrección automáticamente:

```sh
docker compose -f compose.production.yml exec -T web bash -lc 'bin/rails customers:normalize_mobile_numbers'
# Sólo después de revisar el resultado y con backup vigente:
docker compose -f compose.production.yml exec -T web bash -lc 'APPLY=1 bin/rails customers:normalize_mobile_numbers'
```

La tarea informa cantidades sin imprimir contactos. Omite números incompletos y colisiones, incluyendo clientes eliminados lógicamente. La corrección sólo cambia la clave de búsqueda; conserva el contacto original. Un rollback de código puede conservar la columna aditiva y las claves normalizadas.

## Comprobación posterior

```sh
curl -I --max-time 20 https://cita.pet/up
docker compose -f compose.production.yml ps
docker compose -f compose.production.yml logs --tail=200 web
```

Comprobá una reserva pública, la carga de una mascota, el calendario, una seña y una invitación al equipo antes de abrir la operación real.
