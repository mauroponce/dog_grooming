# Cita.pet

Cita.pet es una aplicación Rails 8.1 para reservas de peluquerías caninas. El beta usa PostgreSQL, Hotwire/Tailwind, Google OAuth, Solid Queue, Active Storage sobre Cloudflare R2 y correo transaccional mediante Resend.

## Desarrollo con Docker

Todos los comandos de la aplicación se ejecutan dentro de Docker:

```sh
docker compose up --build
docker compose exec -T web bash -lc 'bin/rails db:prepare'
docker compose exec -T web bash -lc 'bin/rails db:seed'
docker compose exec -T web bash -lc 'bundle exec rspec'
```

La web queda en <http://localhost:3003>, PostgreSQL en `localhost:5435` sólo para diagnóstico y Mailpit en <http://localhost:8028>. Los seeds son escenarios de demostración, son reemplazables e idempotentes por slug, se omiten en `test` y abortan en `production`.

## Alcance del beta

- Registro y acceso administrativo mediante Google OAuth.
- Sitio y reserva pública en `https://cita.pet/:slug`.
- Agenda, clientes, mascotas, servicios y equipo.
- Capacidad global del negocio; la reserva pública no elige ni asigna profesional.
- Seña por transferencia con comprobante o por la cuenta de Mercado Pago vinculada por la peluquería.
- Recordatorios por email y archivos privados en R2.
- Suscripción de la peluquería por transferencia, revisada por superadmin.

Dominios personalizados, portal de cliente, lista de espera e IA no forman parte del lanzamiento inicial. Cancelaciones y reprogramaciones públicas se coordinan por WhatsApp.

## Producción

La guía canónica es [`docs/production_operations.md`](docs/production_operations.md). El despliegue se ejecuta desde el servidor con `deploy.sh`; no usa Kamal y nunca ejecuta `db:seed`.

El primer superadmin se preaprovisiona sólo por email:

```sh
docker compose -f compose.production.yml --env-file .env.production run --rm \
  -e SUPER_ADMIN_EMAIL=admin@cita.pet web bin/rails citapet:bootstrap_super_admin
```

La persona debe iniciar sesión con esa misma identidad de Google. La tarea es idempotente, no asigna contraseña y no modifica otros datos.

Variables obligatorias validadas antes de cada deploy:

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

También deben definirse `APP_PROTOCOL=https`, un remitente verificado en `RESEND_FROM` o `MAIL_FROM`, y las variables operativas descriptas en la guía. Las credenciales de analítica R2 son opcionales y sólo enriquecen `/super_admin/uso`.

## Documentación

- [`docs/product_context.md`](docs/product_context.md): comportamiento del producto.
- [`docs/architecture.md`](docs/architecture.md): fronteras e invariantes técnicas.
- [`docs/production_operations.md`](docs/production_operations.md): deploy, backup, restauración y verificación.
- [`docs/agent_guide.md`](docs/agent_guide.md): flujo de trabajo y comandos.
