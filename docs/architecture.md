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
| Sitio y reserva pública | `/:slug`, `PublicBookingController` | Presentación pública, selección de servicio, disponibilidad global, reserva y señas |
| Operación de empresa | `/admin`, `Admin::BaseController` | Agenda, servicios, clientes, mascotas, equipo, señas y suscripción |
| Administración global | `/super_admin`, `SuperAdmin::BaseController` | Empresas, facturación de plataforma y tareas globales |
| Integraciones | controladores bajo `Webhooks::*` y callbacks OAuth | Validación del proveedor, idempotencia y traducción a servicios de dominio |

Las rutas administrativas y estáticas deben permanecer antes de los comodines públicos de slug. El beta resuelve páginas públicas únicamente bajo el host canónico y mantiene desactivada la resolución de dominios personalizados.

## Tenencia, autenticación y autorización

- `Business` es el tenant principal.
- El área administrativa resuelve el tenant desde `current_user.primary_business` en `Admin::BaseController`.
- Todo controlador nuevo de `/admin` hereda de `Admin::BaseController` y registra su policy de área. Las colecciones usan `policy_scope` cuando contienen datos autorizables.
- Los registros hijos se buscan desde la asociación del negocio actual. No se busca globalmente para filtrar después.
- `/super_admin` usa su propia frontera y permisos; no comparte acciones administrativas de un tenant.
- El registro de propietarios usa una identidad Google temporal en sesión y persiste el usuario sólo dentro de la transacción de alta.

## Servicios y reservas

- `Service` es la entidad pública cotizable. Cada registro tiene un único precio y una única duración.
- Las ofertas que varían por tamaño se representan mediante servicios independientes dentro de una categoría compartida. El tamaño forma parte del nombre y su límite de peso se comunica en la descripción.
- `Appointments::CreateBooking` usa directamente el servicio para disponibilidad, recursos y precio, y persiste los snapshots generales del turno.
- `Availability::AvailableSlots` y `Appointments::CreateBooking` usan capacidad global del `Business`; la reserva pública no asigna `EmployeeMembership` ni consulta su disponibilidad.
- `Appointment` conserva `ends_at` e importes históricos. Los cambios posteriores del catálogo no los recalculan automáticamente.
- `Admin::AppointmentsController#reschedule` bloquea el negocio y el turno antes de mover una reserva futura. La validación normal del turno protege el cupo y el pago, la mascota y el historial se conservan.

Pruebas de referencia: `spec/services/grooming/booking_configuration_spec.rb`, `spec/requests/public_bookings_spec.rb` y los recorridos de agenda en `spec/requests/admin_shell_spec.rb`.

## Identificación y ficha de mascotas

- `PhoneNormalizer` normaliza móviles argentinos a `549` + diez dígitos nacionales. `Business#mobile_area_code` sólo completa números locales; no reemplaza áreas explícitas. El catálogo de áreas está versionado en `config/argentina_area_codes.json` con su fuente en el normalizador.
- `Customers::UpsertProfile` busca dentro del negocio por celular normalizado. El email no es una identidad verificada ni una autorización para asociar fichas. Los contactos del turno conservan lo ingresado en esa reserva.
- `Pets::Upsert` reutiliza sólo una coincidencia inequívoca de nombre. En reservas públicas conserva cuidados y preferencias; el rango elegido explícitamente puede actualizarse. Mascotas homónimas requieren corrección interna.
- El historial se deriva de `Appointment#pet`, `BookingNote` y `BookingAttachment`, bajo el scope de turnos autorizado. `Appointments::FinalizeService` cierra una sola vez y permite anexar información después sin repetir consumos ni eventos.
- `Appointments::LinkCustomer` corrige una reserva dentro del negocio, realinea sus notas/archivos/seguimientos y registra actor y asociaciones anterior/nueva. No modifica otras reservas, contactos ni elimina fichas.
- La confirmación pública y el correo enlazan únicamente al turno. No existe portal de cliente: la cancelación y la reprogramación se solicitan por WhatsApp.

## Separación de pagos

Existen dos contextos de pago independientes:

1. **Seña de un cliente a una peluquería.** Usa exclusivamente la cuenta de Mercado Pago que el negocio vincula mediante OAuth. El agregado raíz es `Appointment` con `AppointmentPayment`; el turno se confirma sólo al validar el pago acreditado mediante el webhook idempotente. El redirect OAuth usa una URL pública configurada por entorno y no depende del host de la request administrativa. Las estructuras históricas de comprobantes manuales permanecen fuera de los recorridos activos hasta una limpieza posterior.
2. **Suscripción de una peluquería a Cita.pet.** Usa `Subscription`, `SubscriptionInvoice`, `SubscriptionPaymentProof` y `BillingTransferAccount`. La empresa carga un comprobante y el superadmin lo revisa mediante servicios bajo `Billing::*`.

`Subscription#grace_ends_on` es la fecha efectiva e inclusiva hasta la que se mantiene el acceso por mora. Los valores nuevos parten de tres días posteriores al vencimiento y una extensión manual puede llevarla más adelante.

No reutilizar cuentas, conexiones OAuth, webhooks, estados ni referencias externas entre ambos contextos. Una clase histórica de checkout de suscripción no convierte Mercado Pago en un canal aprobado para la plataforma.

## Transacciones, snapshots e idempotencia

- Altas que crean usuario, negocio, suscripción, catálogo y membresía se ejecutan en una transacción.
- Reservas y aprobación de pagos bloquean o transaccionan el agregado cuando un doble envío podría duplicar cupo, acreditación o estados.
- Webhooks y aprobaciones deben identificar de forma única el pago externo/interno y tolerar reintentos.
- Importes, períodos y atributos del servicio que explican una operación histórica se guardan en factura/turno; no se reconstruyen desde configuración mutable.
- Los archivos de comprobantes usan Active Storage y validaciones de tipo/tamaño; no se exponen por claves o URLs sin la autorización correspondiente.

## Operación mínima y funcionalidades excluidas

- `BusinessPolicy` diferencia operación diaria de administración: empleados activos pueden operar agenda, clientes, mascotas y señas; sólo el responsable administra catálogo, capacidad, equipo, configuración y suscripción.
- Las invitaciones del equipo se materializan mediante `EmployeeMembership#invite!`; no se usa una matriz de permisos configurable desde la UI.
- No hay modelos, rutas ni jobs para asistente, chat, análisis o generación por IA, portal de cliente o lista de espera. La migración `20261017160000_remove_ai_customer_portal_and_waitlist` eliminó sus tablas y columnas, y es irreversible.
- Las funciones comerciales heredadas (campañas, promociones, rankings, packs, gift cards, referidos y formularios previos) no forman parte del flujo mínimo. No exponerlas ni crear dependencias nuevas sobre ellas sin una decisión explícita.
- `db/seeds.rb` rechaza cualquier entorno distinto de desarrollo y sólo reemplaza los tenants demo conocidos. `citapet:bootstrap_super_admin` es la única inicialización de datos prevista para una producción vacía y opera sobre un solo email.

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
