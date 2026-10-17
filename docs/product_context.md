# Contexto funcional de Cita.pet

Este documento es la fuente canónica para el comportamiento estable del producto. Describe decisiones vigentes y evita que cada iniciativa tenga que reconstruir el dominio desde todo el código. Los detalles de implementación viven en `docs/architecture.md`; las razones de decisiones no obvias, en `docs/decisions/`.

## Producto y actores

Cita.pet es una plataforma para peluquerías caninas. Una empresa publica servicios y disponibilidad, recibe reservas, administra mascotas y responsables, cobra señas y paga una suscripción mensual a Cita.pet.

- **Responsable de la empresa:** administra una peluquería desde `/admin`.
- **Empleado:** opera dentro de los permisos concedidos para una empresa.
- **Cliente final:** reserva públicamente sin crear una cuenta administrativa y puede consultar sus turnos mediante el portal del responsable.
- **Superadmin:** administra empresas, suscripciones, datos bancarios de Cita.pet y revisión de pagos desde `/super_admin`.
- **`Business`:** límite principal de tenencia. Servicios, clientes, mascotas, turnos, empleados y configuración pertenecen a una empresa.

## Registro de una empresa

- El registro público exige validar primero una identidad de Google OAuth. No se crean cuentas administrativas nuevas a partir de un login común sin el flujo explícito de registro.
- La persona ingresa nombre de la empresa, nombre del responsable, teléfono, plan y slug público.
- El slug se normaliza y valida en el servidor, debe ser globalmente único y será la identidad pública del negocio en `/:slug` o su dominio personalizado.
- La creación de usuario, empresa, suscripción inicial, catálogo y membresía propietaria es atómica.
- Una empresa nueva inicia una prueba de 14 días y continúa al onboarding de horarios.
- El catálogo inicial de peluquería canina queda precargado; el responsable lo configura, pero no parte de una pantalla vacía.

Decisión detallada: [`0001-registration-google-and-public-slug.md`](decisions/0001-registration-google-and-public-slug.md).

## Servicios y tamaño de mascota

- Un servicio representa la oferta base y conserva nombre, descripción, categoría, imágenes, profesionales, disponibilidad y reglas de cobro.
- Un servicio puede tener **precio único** o **precio por tamaño de mascota**.
- Los rangos de tamaño pertenecen a la empresa y se reutilizan en todos sus servicios. Los valores iniciales son:
  - Chico: hasta 10 kg.
  - Mediano: de 11 a 20 kg.
  - Grande: más de 20 kg.
- El catálogo inicial contiene tres servicios base: `Baño y secado`, `Sólo corte` y `Baño + corte`. Cada uno tiene una variante por rango, con precio y duración propios.
- En una reserva pública de un servicio por tamaño, el cliente debe elegir el rango antes de ver horarios. La elección determina disponibilidad, duración, precio y seña.
- La mascota recuerda el último rango confirmado para ayudar en operaciones futuras, pero cada nueva reserva debe confirmarlo porque el peso puede cambiar.
- El turno guarda un snapshot del nombre de variante, precio y duración. Cambiar el catálogo después no reescribe turnos históricos.
- En la agenda administrativa también se elige la variante para un turno manual. Un administrador puede corregirla antes del inicio; la corrección recalcula precio y duración y actualiza el rango recordado de la mascota.
- Los servicios precargados por tamaño requieren una seña del 50% calculada sobre el precio efectivo de la variante.

Decisión detallada: [`0002-service-pricing-by-pet-size.md`](decisions/0002-service-pricing-by-pet-size.md).

## Reservas y señas de clientes

- Mercado Pago pertenece al flujo comercial de cada peluquería para cobrar señas de sus clientes. Sus credenciales y cobros no pertenecen a la facturación de Cita.pet.
- Una reserva usa el precio y la duración efectivos seleccionados para validar disponibilidad, recursos, capacidad y asignación profesional.
- Los pagos, webhooks y cambios de estado deben ser idempotentes. Un turno no se confirma por un retorno del navegador sin validar el pago correspondiente.
- Cuando una empresa habilita transferencia manual para sus clientes, el comprobante de la seña se revisa dentro del negocio; este flujo sigue separado del pago de la suscripción a Cita.pet.

## Clientes, mascotas y atención

- Reservar no requiere cuenta. Se solicita nombre del responsable, celular argentino y nombre de mascota; el email es opcional. Raza, manto y cuidados se completan internamente.
- El celular se normaliza incluyendo país y área. Si se omite el área, se usa la del negocio, configurable e inicialmente `11`; el número interpretado se muestra antes de confirmar.
- Se reconoce al cliente por celular completo y a la mascota por nombre dentro de ese cliente. Una coincidencia por email sólo sugiere una revisión al equipo. Las ambigüedades se corrigen desde el turno sin fusionar fichas.
- Los datos ingresados para reservar no habilitan acceso al perfil completo ni reemplazan los cuidados guardados. La elección explícita de tamaño sí actualiza el rango recordado.
- La ficha de mascota separa cuidados permanentes y preferencias del historial de atenciones, con servicio, fecha, profesional, autor del cierre y notas/fotos internas.
- Finalizar no exige nota ni foto. Se pueden agregar después, sin repetir los efectos del cierre. Editar cuidados permanentes sigue requiriendo permiso de edición de clientes.
- Con email se envía un recordatorio cuando faltan 24 horas; si se confirma con menos anticipación, se envía al confirmar. Sólo se recuerda un turno confirmado y futuro. Una reprogramación habilita un nuevo recordatorio para el nuevo horario.

Decisión detallada: [`0004-customer-recognition-without-login.md`](decisions/0004-customer-recognition-without-login.md).

## Suscripción de la empresa a Cita.pet

- La prueba dura 14 días. Al finalizar, la empresa debe tener un plan seleccionado y pagar el período para conservar el acceso según los estados y plazos de gracia vigentes.
- Los planes vigentes son Básico y PRO; importes y prestaciones se definen en `Subscription::PLANS` y no se duplican en esta documentación.
- El canal aprobado para pagar la suscripción es una transferencia bancaria directa a Cita.pet.
- El superadmin configura alias, CBU, titular, identificación fiscal y, opcionalmente, una constancia bancaria visible para la empresa.
- La empresa transfiere, carga un comprobante y queda en revisión. El superadmin recibe la tarea/notificación y aprueba o rechaza el pago.
- La aprobación acredita el período mensual y actualiza la vigencia de la suscripción. El rechazo devuelve la factura a un estado accionable y conserva el motivo.
- Mercado Pago no debe aparecer como método activo para cobrar la suscripción de Cita.pet. Puede existir código histórico de checkout mientras se elimina de forma segura, pero no debe reactivarse sin reemplazar esta decisión.

Decisión detallada: [`0003-platform-subscription-by-bank-transfer.md`](decisions/0003-platform-subscription-by-bank-transfer.md).

## Principios funcionales transversales

- La interfaz y los mensajes para usuarios están en español de Argentina.
- La información de una empresa nunca debe ser visible ni modificable por otra.
- Las decisiones económicas se guardan como snapshots en la operación correspondiente cuando el historial no debe variar con el catálogo actual.
- Los estados de pago, revisión, restricción y suspensión deben ser explícitos y recuperables; no se infieren sólo de la pantalla mostrada.
- No almacenar secretos ni credenciales en documentación, vistas, logs o metadatos de negocio.

## Cómo mantener este documento

Actualizarlo en el mismo cambio que modifique comportamiento externo, actores, reglas de negocio, ciclos de vida o vocabulario. Mantenerlo breve y enlazar decisiones o código en vez de narrar implementaciones completas. Si una regla queda reemplazada, actualizar aquí el estado vigente y marcar el registro anterior como reemplazado.
