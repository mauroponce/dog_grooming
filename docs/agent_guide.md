# Guía local de implementación

Esta guía aporta el mapa técnico y la verificación propios de Cita.pet. `AGENTS.md` es la entrada obligatoria de instrucciones del repositorio y las Dev Skills globales determinan el método de trabajo: esta guía no las reemplaza ni intenta definir una skill local.

Usarla después de leer `AGENTS.md` y sólo junto con la skill global aplicable. El comportamiento estable vive en `docs/product_context.md`, las fronteras técnicas en `docs/architecture.md` y las decisiones duraderas en `docs/decisions/`. Estos documentos reducen la exploración inicial, pero no reemplazan la inspección focalizada del código y de las pruebas cercanas al cambio.

## Producto y límites del dominio

Cita.pet es una aplicación Rails para que peluquerías caninas publiquen su agenda, reciban reservas y administren servicios, equipo, clientes, señas y facturación.

- Un `Business` es el límite de tenencia principal. El usuario autenticado llega al negocio mediante `current_user.primary_business`.
- El área privada del negocio vive bajo `/admin`; el área global bajo `/super_admin`; la reserva pública y las páginas del comercio viven bajo `/:slug` o un dominio personalizado.
- Las reservas, pagos/señas y el webhook de Mercado Pago son flujos sensibles: conservar la idempotencia, la autorización y el aislamiento por negocio.
- La facturación de la suscripción de Cita.pet es distinta de las cuentas de Mercado Pago que cada negocio conecta para cobrar sus propias señas.

## Mapa de la aplicación

| Necesidad | Punto de entrada | Lógica y pruebas cercanas |
| --- | --- | --- |
| Reserva pública y servicios | `PublicBookingController`, `PublicServicePagesController` | `app/services/appointments`, `app/services/bookings`, `app/services/availability`; `spec/requests/public_bookings_spec.rb`, `spec/services/grooming/booking_configuration_spec.rb` |
| Operación del negocio | `Admin::*Controller`, vistas `app/views/admin` | `app/services/appointments`, `availability`, `customers`, `services`, `team`; request specs `admin_*` |
| Administración global y facturación | `SuperAdmin::*Controller` | `app/services/billing`, modelos `Subscription*`; specs `super_admin_billing_spec.rb` y `admin_billing_spec.rb` |
| Pagos Mercado Pago | `Webhooks::MercadoPagoController`, `Admin::MercadoPagoConnectionsController` | `app/services/mercado_pago`, `app/jobs/mercado_pago`; specs de Mercado Pago y billing |
| Acceso y permisos | `Authentication` concern, `Admin::BaseController`, `SuperAdmin::BaseController` | `app/policies`; specs de policies y request specs del área afectada |
| Cola, correo y archivos | `app/jobs`, `app/mailers`, Active Storage | specs de jobs, mailers y `app/services/storage` |

Las rutas en `config/routes.rb` tienen precedencia significativa: las rutas estáticas y de administración deben mantenerse antes de los comodines `:slug` y `*unmatched`. Para un dominio personalizado, `CustomDomainConstraint` admite sólo controladores públicos establecidos en `ApplicationController`.

## Convenciones que preservan seguridad y consistencia

- En una acción de `/admin`, heredar de `Admin::BaseController`; éste resuelve el negocio, exige onboarding/acceso/facturación y autoriza el área mediante Pundit. No reemplazar esas guardas por comprobaciones ad hoc.
- Autorizar tanto el área como los registros cuando corresponda. Usar `policy_scope` para colecciones con datos del negocio; no buscar registros globalmente y filtrar después.
- Para cambios de modelo, inspeccionar `db/schema.rb` y las migraciones relacionadas antes de proponer una nueva. Toda modificación persistente debe considerar restricciones, índices y compatibilidad del deploy.
- Las operaciones de pagos, reservas y webhooks deben conservar transacciones, deduplicación/idempotencia y un camino de error verificable. No registrar secretos, tokens, comprobantes ni datos personales innecesarios.
- La UI usa ERB, Tailwind, import maps, Turbo y Stimulus. Antes de agregar JavaScript o estilos, localizar el controlador Stimulus y las clases/patrones que ya usa la pantalla.
- No agregar dependencias si Rails o una abstracción existente del proyecto resuelven el problema.

## Relación con las Dev Skills

- La skill global elegida decide el flujo de descubrimiento, planificación, implementación, revisión o release. No copiar sus pasos en documentos locales.
- Esta guía resuelve únicamente preguntas que una skill global no puede conocer: límites de Cita.pet, rutas, servicios, pruebas y comandos del repositorio.
- `AGENTS.md` indica qué fuentes locales leer y exige comprobar si esta documentación sigue vigente al cerrar un cambio. Los planes, notas de progreso y memoria entre sesiones viven fuera del repositorio, como establecen las Dev Skills.

## Ejecución local y verificación

Todos los comandos del proyecto se ejecutan dentro de Docker. La aplicación local está en `http://localhost:3003`; Mailpit en `http://localhost:8028`.

```sh
# Estado y arranque (host permitido para Docker Compose)
docker compose ps
docker compose up --build

# Base y pruebas focalizadas (dentro de web)
docker compose exec -T web bash -lc 'bin/rails db:prepare'
docker compose exec -T web bash -lc 'bundle exec rspec spec/requests/admin_billing_spec.rb'
docker compose exec -T web bash -lc 'bundle exec rspec spec/services/billing/create_mercado_pago_checkout_spec.rb'

# Calidad y seguridad, cuando el alcance lo justifique
docker compose exec -T web bash -lc 'bin/rubocop'
docker compose exec -T web bash -lc 'bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error'
docker compose exec -T web bash -lc 'bin/bundler-audit'
docker compose exec -T web bash -lc 'bin/importmap audit'
```

`spec/rails_helper.rb` fuerza `RAILS_ENV=test`, por lo que las specs no deben escribir en desarrollo. Si el stack aún no está levantado, iniciarlo con `docker compose up --build`; no ejecutar Rails, Bundler, RSpec ni clientes de base de datos en el host.

`bin/ci` cubre preparación, RuboCop y auditorías de seguridad, pero no ejecuta RSpec: correr explícitamente las specs afectadas. Antes de afirmar que una migración está lista, preparar la base en el contenedor y ejecutar las pruebas que cubren el flujo modificado.

## Cambios de alto riesgo

- **Esquema o datos:** inspeccionar migraciones y schema actuales; preferir operaciones compatibles con código antiguo/nuevo y explicar rollback/backfill cuando aplique.
- **Autorización o tenancy:** validar admin, empleado y super admin cuando el comportamiento alcance más de un rol; comprobar que no se cruza el `Business` actual.
- **Mercado Pago, webhooks o correo:** conservar contratos existentes, manejo de reintentos y secretos fuera del código. Añadir pruebas de éxito y fallo/duplicado pertinentes. No reintroducir IA, portal de cliente ni lista de espera sin una decisión explícita y una migración evaluada.
- **Rutas públicas o dominios personalizados:** comprobar ambas variantes de host y el orden de rutas para no capturar paths administrativos como slugs.
- **Producción:** consultar `docs/production_operations.md` y `deployment.md`. Un deploy requiere aprobación explícita; esta guía no autoriza cambios de infraestructura ni secretos.

## Documentación a mantener

- `docs/product_context.md`: producto, actores, vocabulario, flujos y reglas funcionales vigentes.
- `docs/architecture.md`: límites, invariantes, integraciones y puntos de extensión estables.
- `docs/decisions/`: motivo y consecuencias de decisiones duraderas y no obvias. Marcar una decisión anterior como reemplazada en vez de reescribir su historia.
- Actualizar esta guía sólo si cambia un límite operativo, un comando de verificación o una convención transversal.
- Mantener el README orientado a instalación y producto; mantener `docs/production_operations.md` para operación y despliegue.
- No duplicar la misma regla completa en varios archivos: usar enlaces y mantener una sola fuente canónica.
- No documentar secretos, valores reales de producción ni notas temporales de una tarea. El contexto temporal de planificación y progreso se conserva fuera del repositorio, como establecen las skills globales.
