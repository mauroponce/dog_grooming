# Operaciones de producción

Esta guía corresponde exclusivamente a Dog Grooming. Los valores de dominio, servidor y registro son placeholders deliberados: deben definirse antes del primer deploy.

## Valores a definir antes del deploy

- `KAMAL_HOST`: IP o hostname del servidor de Dog Grooming.
- `APP_HOST=dog-grooming.example.com` y `APP_WWW_HOST=www.dog-grooming.example.com` (o los dominios reales).
- `APP_HOSTS=dog-grooming.example.com,www.dog-grooming.example.com` más la IP de diagnóstico si hiciera falta.
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
APP_HOST=dog-grooming.example.com
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
MAIL_FROM="Dog Grooming <notificaciones@tu-dominio.com>"
RESEND_FROM="Dog Grooming <notificaciones@tu-dominio.com>"
```

## Comprobación posterior

```sh
curl -I --max-time 20 https://dog-grooming.example.com/up
docker compose -f compose.production.yml ps
docker compose -f compose.production.yml logs --tail=200 web
```

Comprobá una reserva pública, la carga de una mascota, el calendario y el portal del responsable antes de abrir la operación real.
