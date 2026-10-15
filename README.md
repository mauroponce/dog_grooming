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

Los turnos publicos quedan pendientes de confirmacion. Si el servicio requiere seña, el cliente ve alias/CBU/CVU o link externo, sube comprobante y el comercio confirma o rechaza manualmente desde el panel o desde un link firmado.

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
GEMINI_API_KEY
GEMINI_MODEL
GEMINI_RECEIPT_MODEL
GEMINI_INPUT_USD_PER_1M_TOKENS
GEMINI_OUTPUT_USD_PER_1M_TOKENS
GEMINI_MONTHLY_BUDGET_USD
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

El panel `/super_admin/uso` muestra el almacenamiento conocido por Active Storage y, si configurás `CLOUDFLARE_ACCOUNT_ID` junto con `CLOUDFLARE_R2_ANALYTICS_TOKEN` o `CLOUDFLARE_API_TOKEN`, también consulta métricas oficiales de R2 vía Cloudflare GraphQL. El uso de Gemini se registra localmente desde cada llamada de la app; los costos son estimados y requieren configurar las tarifas por millón de tokens.

## Pagos y señas

El comercio configura sus cuentas de cobro desde `/admin/configuracion`. Puede usar:

- Comprobante manual con alias/CBU/CVU y aprobacion del admin.
- Mercado Pago conectado por OAuth para cobrar la seña o el pago total y confirmar el turno automaticamente cuando el pago se acredita.

Para Mercado Pago configurá `MERCADO_PAGO_CLIENT_ID` y `MERCADO_PAGO_CLIENT_SECRET` con el App ID y Client Secret de la aplicación OAuth. También podés separar credenciales de API con `MERCADO_PAGO_TEST_*` y `MERCADO_PAGO_PRODUCTION_*`. `docker compose` local fuerza `MERCADO_PAGO_ENV=test` para intercambiar OAuth con `test_token=true` y checkout sandbox; producción fuerza `MERCADO_PAGO_ENV=production` y usa las credenciales `MERCADO_PAGO_PRODUCTION_*`. El webhook `/webhooks/mercado-pago` recibe las notificaciones de pago; si configurás `MERCADO_PAGO_WEBHOOK_SECRET`, la app valida la firma enviada por Mercado Pago.

Planes comerciales:

- Plan Profesional: $30.000 ARS/mes, 1 agenda activa, reservas online, señas manuales, comprobantes, chatbot y mensajes WhatsApp prearmados.
- Plan Centro: $50.000 ARS/mes, varias profesionales, roles, recursos compartidos, agenda por profesional, reportes, huecos libres y gestion avanzada.

La suscripción de Cita.pet se cobra con Checkout Pro de Mercado Pago: cada período genera un checkout nuevo para que el negocio elija cómo pagar, sin adherir una tarjeta a un débito automático. La cuenta receptora se vincula desde `/super_admin/cobros` y es distinta de las cuentas Mercado Pago que cada negocio conecta para cobrar sus señas.

## WhatsApp

La app no usa WhatsApp Cloud API. Usa links manuales `wa.me` con mensajes prearmados desde el panel y desde las vistas de revision:

- Confirmar turno.
- Pedir o reemplazar comprobante.
- Avisar cancelacion.
- Seguir una conversacion de chatbot o lista de espera.

## Chat IA

El chat publico aparece para negocios con chat activo y contexto cargado. Requiere `GEMINI_API_KEY`; el modelo por defecto es `gemini-flash-lite-latest` y puede cambiarse con `GEMINI_MODEL`. La revision inteligente de comprobantes usa el mismo API key y permite elegir un modelo multimodal especifico con `GEMINI_RECEIPT_MODEL`.

Funciones incluidas:

- Chat con deteccion de intencion de reserva y scroll automatico a servicios.
- Resumen diario de chats abiertos para seguimiento manual por WhatsApp.
- Los turnos se gestionan desde el calendario en `/admin/calendario`.
- Analisis de reseñas con alerta critica en el dashboard.

## Planes y Equipo

La arquitectura interna es una sola: todo negocio tiene profesionales. El Plan Profesional limita la operacion a 1 agenda activa; el Plan Centro habilita multiples profesionales, roles y recursos compartidos.

La diferencia del Plan Centro es operativa:

- Multiples sucursales.
- Empleados invitados por mail con link temporal.
- Agenda/calendario por empleado.
- Permisos configurables por empleado con Pundit.

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

El super admin vincula la cuenta de Mercado Pago receptora desde `/super_admin/cobros`. Cada factura mensual ofrece Checkout Pro en `/admin/suscripcion`; los webhooks de Mercado Pago acreditan el pago de forma automática e idempotente.

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
