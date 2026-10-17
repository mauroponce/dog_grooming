# Arquitectura de Cita.pet

Esta es la fuente canónica de las fronteras técnicas e invariantes estables. Sirve como mapa inicial; antes de editar, se verifica únicamente el recorrido de código afectado.

## Forma de la aplicación

- Monolito Rails 8 con PostgreSQL.
- UI server-rendered con ERB, Tailwind, Turbo, Stimulus e import maps.
- Active Job para trabajo asíncrono, Action Mailer para correo y Active Storage para archivos.
- RSpec cubre modelos, servicios, jobs, policies y recorridos HTTP.
- El entorno local y todos los comandos del proyecto se ejecutan mediante Docker Compose según `AGENTS.md`.

## Límites de entrada

| Área | Entrada | Responsabilidad |
| --- | --- | --- |
| Sitio y reserva pública | `/:slug`, dominios personalizados, `PublicBookingController` | Presentación pública, selección de servicio/variante, disponibilidad y reserva |
| Operación de empresa | `/admin`, `Admin::BaseController` | Agenda, servicios, clientes, mascotas, equipo, señas y suscripción |
| Administración global | `/super_admin`, `SuperAdmin::BaseController` | Empresas, facturación de plataforma y tareas globales |
| Integraciones | controladores bajo `Webhooks::*` y callbacks OAuth | Validación del proveedor, idempotencia y traducción a servicios de dominio |

Las rutas administrativas y estáticas deben permanecer antes de los comodines públicos de slug. Los dominios personalizados sólo pueden llegar a controladores públicos permitidos.

## Tenencia, autenticación y autorización

- `Business` es el tenant principal.
- El área administrativa resuelve el tenant desde `current_user.primary_business` en `Admin::BaseController`.
- Todo controlador nuevo de `/admin` hereda de `Admin::BaseController` y registra su policy de área. Las colecciones usan `policy_scope` cuando contienen datos autorizables.
- Los registros hijos se buscan desde la asociación del negocio actual. No se busca globalmente para filtrar después.
- `/super_admin` usa su propia frontera y permisos; no comparte acciones administrativas de un tenant.
- El registro de propietarios usa una identidad Google temporal en sesión y persiste el usuario sólo dentro de la transacción de alta.

## Servicios, variantes y reservas

- `Service` es la entidad pública base. `pricing_mode` decide entre precio fijo y variantes por tamaño.
- `PetSizeBand` pertenece a `Business`; define la taxonomía compartida de peso.
- `ServiceVariant` pertenece a un `Service` y un `PetSizeBand`; aporta precio y duración. La validación impide cruzar empresas.
- `Bookings::ServiceSelection` es el valor efectivo usado durante disponibilidad y precio. Delega el servicio base y reemplaza precio/duración con la variante elegida.
- `Appointments::CreateBooking` valida que una variante activa pertenezca al servicio, usa la selección efectiva para disponibilidad/recursos/precio y persiste el `Service` base, la variante y sus snapshots.
- `Appointment` conserva `ends_at`, importes y datos de variante históricos. Los cambios posteriores del catálogo no los recalculan automáticamente.
- `Pet#pet_size_band` es una preferencia recordada, no una fuente suficiente para cotizar una nueva reserva pública.

Pruebas de referencia: `spec/services/grooming/booking_configuration_spec.rb`, `spec/requests/public_bookings_spec.rb` y los recorridos de agenda en `spec/requests/admin_shell_spec.rb`.

## Identificación y ficha de mascotas

- `PhoneNormalizer` normaliza móviles argentinos a `549` + diez dígitos nacionales. `Business#mobile_area_code` sólo completa números locales; no reemplaza áreas explícitas. El catálogo de áreas está versionado en `config/argentina_area_codes.json` con su fuente en el normalizador.
- `Customers::UpsertProfile` busca dentro del negocio por celular normalizado. El email no es una identidad verificada ni una autorización para asociar fichas. Los contactos del turno conservan lo ingresado en esa reserva.
- `Pets::Upsert` reutiliza sólo una coincidencia inequívoca de nombre. En reservas públicas conserva cuidados y preferencias; el rango elegido explícitamente puede actualizarse. Mascotas homónimas requieren corrección interna.
- El historial se deriva de `Appointment#pet`, `BookingNote` y `BookingAttachment`, bajo el scope de turnos autorizado. `Appointments::FinalizeService` cierra una sola vez y permite anexar información después sin repetir consumos ni eventos.
- `Appointments::LinkCustomer` corrige una reserva dentro del negocio, realinea sus notas/archivos/seguimientos y registra actor y asociaciones anterior/nueva. No modifica otras reservas, contactos ni elimina fichas.
- La confirmación pública y el correo enlazan únicamente al turno. Acceder al perfil completo conserva el circuito de acceso del portal.

## Separación de pagos

Existen dos contextos de pago independientes:

1. **Seña de un cliente a una peluquería.** Usa configuración del `Business`, cuentas de cobro del negocio y, cuando corresponde, la conexión Mercado Pago del negocio. El agregado raíz es `Appointment` con `AppointmentPayment` y comprobantes relacionados.
2. **Suscripción de una peluquería a Cita.pet.** Usa `Subscription`, `SubscriptionInvoice`, `SubscriptionPaymentProof` y `BillingTransferAccount`. La empresa carga un comprobante y el superadmin lo revisa mediante servicios bajo `Billing::*`.

No reutilizar cuentas, conexiones OAuth, webhooks, estados ni referencias externas entre ambos contextos. Una clase histórica de checkout de suscripción no convierte Mercado Pago en un canal aprobado para la plataforma.

## Transacciones, snapshots e idempotencia

- Altas que crean usuario, negocio, suscripción, catálogo y membresía se ejecutan en una transacción.
- Reservas y aprobación de pagos bloquean o transaccionan el agregado cuando un doble envío podría duplicar cupo, acreditación o estados.
- Webhooks y aprobaciones deben identificar de forma única el pago externo/interno y tolerar reintentos.
- Importes, períodos y atributos del servicio que explican una operación histórica se guardan en factura/turno; no se reconstruyen desde configuración mutable.
- Los archivos de comprobantes usan Active Storage y validaciones de tipo/tamaño; no se exponen por claves o URLs sin la autorización correspondiente.

## Trabajo asíncrono y correo

- Jobs y mailers reciben identificadores persistidos, vuelven a cargar estado y deben tolerar que el registro haya cambiado antes de ejecutarse.
- Las notificaciones no son la fuente de verdad de un pago. La aprobación o confirmación se persiste primero y luego se comunica.
- Los jobs recurrentes se declaran en `config/recurring.yml`; un cambio de frecuencia o responsabilidad operativa también actualiza `docs/production_operations.md`.
- `SendDueAppointmentRemindersJob` busca cada minuto turnos confirmados dentro de las próximas 24 horas; la confirmación de último momento también encola. `SendAppointmentReminderJob` vuelve a validar estado y fecha bajo bloqueo del turno, envía y registra `reminder_sent_at` y `NotificationDelivery`. Reprogramar reinicia la marca. El correo externo no participa de la transacción: un corte después de entregar y antes de persistir puede duplicarlo al reintentar.

## Dónde extender

- Reglas de negocio con más de una escritura o integración: servicio de dominio bajo `app/services/<dominio>`.
- Presentación/consultas compuestas sin mutación: presenter o query object existente del área.
- Autorización: policy y scopes, nunca condiciones dispersas en la vista.
- Comportamiento de UI local: controlador Stimulus existente o uno pequeño; evitar scripts globales cuando hay un ciclo de vida Turbo.
- Restricciones persistentes: validación de modelo más constraint/index de base cuando la invariancia debe resistir concurrencia.

## Fuentes y mantenimiento

- `docs/product_context.md` define qué debe hacer el producto.
- Este documento define fronteras e invariantes técnicas.
- `docs/decisions/` explica por qué se eligieron diseños duraderos.
- `docs/agent_guide.md` define cómo trabajar y verificar.
- `docs/production_operations.md` define cómo operar el sistema.

Actualizar este documento junto con cambios de fronteras, ownership, persistencia, integraciones o invariantes. No agregar inventarios exhaustivos de clases ni detalles que se puedan obtener con una búsqueda focalizada.
