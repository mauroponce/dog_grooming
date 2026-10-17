# Cita.pet

MVP Rails 8.1 para reservas online de peluquerías caninas. Usa PostgreSQL, Hotwire/Tailwind, auth nativa con bcrypt, Solid Queue, Active Storage, Action Mailer con Mailpit en desarrollo, Resend en producción y Kamal 2.

## Desarrollo con Docker

Para el contexto técnico y el flujo de cambios para agentes, consultá [`docs/agent_guide.md`](docs/agent_guide.md).

```sh
docker compose up --build
```

La app queda en `http://localhost:3003`, PostgreSQL queda expuesto en `localhost:5435` y Mailpit captura los emails locales en `http://localhost:8028`.

Comandos utiles:

```sh
docker compose ps
docker compose logs -f web
docker compose down
```

En `development`, Action Mailer siempre usa Mailpit aunque exista una clave de Resend en `.env`. Resend queda reservado para `production`.

Para preparar la base o ejecutar comandos de Rails, usá siempre el contenedor `web`:

```sh
docker compose exec -T web bash -lc 'bin/rails db:prepare'
```

## Flujo MVP

- `/signup`: registro del profesional/admin y primer paso del onboarding.
- `/onboarding/horarios`: horario semanal base.
- `/onboarding/servicio`: primer servicio.
- `/onboarding/listo`: link publico listo para compartir.
- `/admin`: panel privado del negocio.
- `/:slug`: pagina publica para que clientes reserven sin cuenta.
- `/super_admin`: panel global para el super admin.

Los turnos públicos quedan pendientes de confirmación. Si el servicio requiere seña, el cliente ve alias/CBU/CVU o Mercado Pago, y puede subir comprobante. El comercio confirma o rechaza manualmente desde el panel. Para cancelar o reprogramar, el cliente contacta a la peluquería por WhatsApp.

## Super Admin

Para crear el super admin inicial:

```sh
docker compose exec -T web bash -lc "SUPER_ADMIN_EMAIL=tu-email@example.com SUPER_ADMIN_PASSWORD='password-largo' bin/rails db:seed"
```

El super admin puede ver negocios, impersonar admins y deshabilitar/habilitar negocios.

## Variables

Requeridas en produccion:

```sh
APP_HOST
RAILS_MASTER_KEY
DOG_GROOMING_DATABASE_PASSWORD
```

Opcionales:

```sh
ACTIVE_STORAGE_SERVICE
APP_PROTOCOL
MERCADO_PAGO_CLIENT_ID
MERCADO_PAGO_CLIENT_SECRET
MERCADO_PAGO_ENV
MERCADO_PAGO_PUBLIC_KEY
MERCADO_PAGO_ACCESS_TOKEN
MERCADO_PAGO_TEST_PUBLIC_KEY
MERCADO_PAGO_TEST_ACCESS_TOKEN
MERCADO_PAGO_TEST_CLIENT_ID
MERCADO_PAGO_TEST_CLIENT_SECRET
MERCADO_PAGO_PRODUCTION_PUBLIC_KEY
MERCADO_PAGO_PRODUCTION_ACCESS_TOKEN
MERCADO_PAGO_PRODUCTION_CLIENT_ID
MERCADO_PAGO_PRODUCTION_CLIENT_SECRET
MERCADO_PAGO_WEBHOOK_SECRET
RESEND_API_KEY
RESEND_FROM
RESEND_ENDPOINT
MAIL_FROM
R2_BUCKET
R2_ENDPOINT
R2_ACCESS_KEY_ID
R2_SECRET_ACCESS_KEY
CLOUDFLARE_ACCOUNT_ID
CLOUDFLARE_R2_BUCKET
CLOUDFLARE_R2_SERVICE_IMAGES_BUCKET
CLOUDFLARE_R2_ENDPOINT
CLOUDFLARE_ACCESS_KEY_ID
CLOUDFLARE_SECRET_ACCESS_KEY
CLOUDFLARE_R2_ANALYTICS_TOKEN
CLOUDFLARE_API_TOKEN
SMTP_*
```

El panel `/super_admin/uso` muestra el almacenamiento conocido por Active Storage y, si configurás `CLOUDFLARE_ACCOUNT_ID` junto con `CLOUDFLARE_R2_ANALYTICS_TOKEN` o `CLOUDFLARE_API_TOKEN`, también consulta métricas oficiales de R2 vía Cloudflare GraphQL.

## Pagos y señas

El comercio configura sus cuentas de cobro desde `/admin/configuracion`. Puede usar:

- Comprobante manual con alias/CBU/CVU y aprobacion del admin.
- Mercado Pago conectado por OAuth para cobrar la seña o el pago total y confirmar el turno automaticamente cuando el pago se acredita.

Para Mercado Pago configurá `MERCADO_PAGO_CLIENT_ID` y `MERCADO_PAGO_CLIENT_SECRET` con el App ID y Client Secret de la aplicación OAuth. También podés separar credenciales de API con `MERCADO_PAGO_TEST_*` y `MERCADO_PAGO_PRODUCTION_*`. `docker compose` local fuerza `MERCADO_PAGO_ENV=test` para intercambiar OAuth con `test_token=true` y checkout sandbox; producción fuerza `MERCADO_PAGO_ENV=production` y usa las credenciales `MERCADO_PAGO_PRODUCTION_*`. El webhook `/webhooks/mercado-pago` recibe las notificaciones de pago; si configurás `MERCADO_PAGO_WEBHOOK_SECRET`, la app valida la firma enviada por Mercado Pago.

Los planes y sus prestaciones vigentes viven en `Subscription::PLANS`. La suscripción de Cita.pet se paga por transferencia y comprobante revisado por superadmin; es independiente de Mercado Pago y de las señas de cada peluquería.

Funciones incluidas:

- Reserva pública de servicio y variante por tamaño, con capacidad global de la peluquería.
- Señas por transferencia/comprobante o Mercado Pago.
- Agenda administrativa, clientes, mascotas, servicios e invitaciones al equipo.
- Reprogramación interna de turnos futuros.

## Equipo

El responsable invita empleados por email. Los empleados activos comparten las herramientas operativas de agenda, clientes, mascotas y señas; el responsable conserva servicios, capacidad, configuración, equipo y suscripción. No hay roles configurables ni agenda pública por profesional.

Las invitaciones de empleados y notificaciones usan Action Mailer. En desarrollo, todos los emails quedan capturados en Mailpit. En producción, la app envía por Resend usando la API HTTP sin gema externa.

En producción, Resend debe usar el dominio que configures y verifiques para Cita.pet:

```sh
MAIL_FROM="Cita.pet <notificaciones@tu-dominio.example>"
RESEND_FROM="Cita.pet <notificaciones@tu-dominio.example>"
```

El remitente `onboarding@resend.dev` solo sirve para pruebas limitadas de onboarding.

## Active Storage / Cloudflare R2

Cita.pet reutiliza las credenciales y el endpoint R2 existentes, pero nunca los buckets de otra instalación. Antes de activar R2 creá los dos buckets aislados: `dog-grooming` para Active Storage general y backups, y `dog-grooming-service-images` para las imágenes de servicios.

```sh
ACTIVE_STORAGE_SERVICE=r2
CLOUDFLARE_ACCOUNT_ID=<tu-cloudflare-account-id>
CLOUDFLARE_R2_BUCKET=dog-grooming
CLOUDFLARE_R2_SERVICE_IMAGES_BUCKET=dog-grooming-service-images
CLOUDFLARE_R2_ENDPOINT=https://<tu-cloudflare-account-id>.r2.cloudflarestorage.com
CLOUDFLARE_ACCESS_KEY_ID=...
CLOUDFLARE_SECRET_ACCESS_KEY=...
```

Si las credenciales no tienen permiso para crear o acceder a esos buckets, usá `ACTIVE_STORAGE_SERVICE=local` en desarrollo hasta emitir o configurar el token adecuado. Los objetos siguen siendo privados y Active Storage entrega enlaces firmados.

Los archivos quedan agrupados por slug del negocio dentro de su bucket:

```txt
dog-grooming/
  peluqueria-canina/
    comprobantes/
      2026-06/
        booking-123/
          20260630153000-comprobante-sena-a1b2c3d4e5f6a7b8.pdf
    imagenes/
      logos/
        2026-06/
          business-12/
            20260630153000-logo-patitas-a1b2c3d4e5f6a7b8.webp
```

## Cobros de suscripción

El negocio paga la suscripción por transferencia a Cita.pet y carga un comprobante desde `/admin/suscripcion`. El superadmin revisa y acredita ese pago. Esta operación es independiente de las cuentas de Mercado Pago que cada peluquería conecta para cobrar señas a sus clientes.

Los nombres `R2_*` siguen soportados como compatibilidad.

## Deploy con Kamal

`bin/kamal` carga `.env` automáticamente. Para desplegar, definí valores de producción propios; el `.env` local queda configurado para `localhost:3003`.

```sh
KAMAL_HOST=tu-servidor.example
KAMAL_IMAGE=mauroponce/dog_grooming
KAMAL_REGISTRY_SERVER=ghcr.io
KAMAL_REGISTRY_USERNAME=mauroponce
KAMAL_REGISTRY_PASSWORD=<token-del-registry>
APP_HOST=cita.pet
APP_PROTOCOL=https
APP_HOSTS=cita.pet,www.cita.pet
DOG_GROOMING_DATABASE_PASSWORD=<password-postgres-produccion>
```

`compose.production.yml` usa Caddy y los puertos 80/443; no lo ejecutes junto a otra producción en el mismo host sin configurar un proxy compartido y un dominio propio. También configurá `APP_WWW_HOST` si querés redirigir el subdominio `www`.

Validar config:

```sh
bin/kamal config
```

Primer deploy:

```sh
bin/kamal setup
bin/kamal deploy
```

Nota: antes del primer deploy conviene hacer el primer commit. Si no existe `HEAD`, Kamal muestra un aviso y usa `HEAD` como tag.
