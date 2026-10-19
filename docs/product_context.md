# Contexto funcional de Cita.pet

Este documento es la fuente canónica para el comportamiento estable del producto. Describe decisiones vigentes y evita que cada iniciativa tenga que reconstruir el dominio desde todo el código. Los detalles de implementación viven en `docs/architecture.md`; las razones de decisiones no obvias, en `docs/decisions/`.

## Producto y actores

Cita.pet es una plataforma para peluquerías caninas. Una empresa publica servicios y disponibilidad, recibe reservas, administra mascotas y responsables, cobra señas y paga una suscripción mensual a Cita.pet.

- **Responsable de la empresa:** administra una peluquería desde `/admin`.
- **Empleado:** opera la agenda, clientes, mascotas y señas de una empresa activa. No configura permisos individuales.
- **Cliente final:** reserva públicamente sin crear una cuenta administrativa. Para cancelar, reprogramar o consultar un caso particular contacta a la peluquería por WhatsApp.
- **Superadmin:** administra empresas, suscripciones, datos bancarios de Cita.pet y revisión de pagos desde `/super_admin`.
- **`Business`:** límite principal de tenencia. Servicios, clientes, mascotas, turnos, empleados y configuración pertenecen a una empresa.

## Registro de una empresa

- El registro público exige validar primero una identidad de Google OAuth. No se crean cuentas administrativas nuevas a partir de un login común sin el flujo explícito de registro.
- La persona ingresa nombre de la empresa, nombre del responsable, teléfono, plan y slug público.
- El slug se normaliza y valida en el servidor, debe ser globalmente único y será la identidad pública del negocio en `https://cita.pet/:slug`. Los dominios personalizados quedan fuera del beta inicial.
- La creación de usuario, empresa, suscripción inicial, catálogo y membresía propietaria es atómica.
- Una empresa nueva inicia una prueba de 14 días y continúa al onboarding de horarios.
- El catálogo inicial de peluquería canina queda precargado; el responsable lo configura, pero no parte de una pantalla vacía.

Decisión detallada: [`0001-registration-google-and-public-slug.md`](decisions/0001-registration-google-and-public-slug.md).

## Acceso administrativo

- Los botones **Ingresar** de la landing inician directamente la autenticación con Google, sin mostrar antes la pantalla `/acceder`.
- `/acceder` se conserva como pantalla de acceso y destino de recuperación cuando Google no puede verificar la identidad o la cuenta no está habilitada.

## Servicios y tamaño de mascota

- Cada servicio tiene un único precio y una única duración. No existen variantes ni configuración de precios por tamaño.
- Cuando una oferta cambia según el tamaño de la mascota, cada tamaño se publica como un servicio independiente dentro de la misma categoría; por ejemplo, `Baño + corte (Chico)`, `Baño + corte (Mediano)` y `Baño + corte (Grande)`.
- El nombre diferencia los tamaños y la descripción informa el límite aplicable: hasta 10 kg, hasta 20 kg o más de 20 kg.
- El catálogo inicial contiene nueve servicios: tres tamaños independientes para `Baño y secado`, `Sólo corte` y `Baño + corte`. Cada uno conserva su propio precio, duración y seña.
- La reserva pública y la agenda administrativa seleccionan directamente el servicio. El turno conserva sus importes y duración históricos mediante los snapshots generales del turno.

Decisión detallada: [`0006-independent-services-by-pet-size.md`](decisions/0006-independent-services-by-pet-size.md).

## Reservas y señas de clientes

- Cada peluquería vincula su propia cuenta de Mercado Pago mediante OAuth; es el único canal habilitado para cobrar señas de clientes.
- Una reserva usa el precio y la duración efectivos seleccionados para validar disponibilidad y capacidad global de la peluquería. No se asigna ni se elige un profesional durante la reserva pública.
- Los pagos, webhooks y cambios de estado deben ser idempotentes. Un turno no se confirma por un retorno del navegador sin validar el pago correspondiente.
- Si un servicio requiere seña y Mercado Pago no está conectado, el cliente puede consultar la disponibilidad pero no finalizar la reserva. Los servicios sin seña conservan la confirmación directa.
- La confirmación pública sólo muestra el estado de esa reserva. No ofrece portal, lista de espera, cancelación ni reprogramación autoservicio; estos pedidos se canalizan por WhatsApp.

Decisión detallada: [`0007-customer-deposits-by-mercado-pago.md`](decisions/0007-customer-deposits-by-mercado-pago.md).

## Clientes, mascotas y atención

- Reservar no requiere cuenta. Se solicita nombre del responsable, celular argentino y nombre de mascota; el email es opcional. Raza, manto y cuidados se completan internamente.
- El celular se normaliza incluyendo país y área. Si se omite el área, se usa la del negocio, configurable e inicialmente `11`; el número interpretado se muestra antes de confirmar.
- Se reconoce al cliente por celular completo y a la mascota por nombre dentro de ese cliente. Una coincidencia por email sólo sugiere una revisión al equipo. Las ambigüedades se corrigen desde el turno sin fusionar fichas.
- Los datos ingresados para reservar no habilitan acceso al perfil completo ni reemplazan los cuidados guardados.
- La ficha de mascota separa cuidados permanentes y preferencias del historial de atenciones, con servicio, fecha, autor del cierre y notas/fotos internas.
- Finalizar no exige nota ni foto. Se pueden agregar después, sin repetir los efectos del cierre. Editar cuidados permanentes sigue requiriendo permiso de edición de clientes.
- Con email se envía un recordatorio cuando faltan 24 horas; si se confirma con menos anticipación, se envía al confirmar. Sólo se recuerda un turno confirmado y futuro. El equipo puede reprogramar internamente un turno futuro y se habilita un nuevo recordatorio para el nuevo horario.

## Agenda y equipo mínimos

- La capacidad es global por peluquería; inicia en `1` y cada reserva consume un cupo del mismo calendario.
- Cada servicio inicia con una duración configurable por el responsable desde el catálogo.
- El responsable administra servicios, configuración, capacidad, equipo y suscripción. Los empleados activos acceden a la operación diaria: agenda, clientes, mascotas y señas.
- El responsable invita empleados por email. No hay interfaz de roles, permisos individuales ni configuración de agendas por profesional.
- La reprogramación se realiza sólo desde la agenda administrativa, conserva la mascota, el pago y el historial, y vuelve a validar la capacidad de forma atómica.

Decisión detallada: [`0005-minimal-booking-and-operations.md`](decisions/0005-minimal-booking-and-operations.md).

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
- No incorporar asistentes, chat, análisis ni otra lógica de inteligencia artificial sin una nueva decisión de producto y su correspondiente diseño de datos.
- Los escenarios de `db/seeds.rb` son sólo para desarrollo. Producción nace vacía y el primer superadmin se preaprovisiona por email con una tarea específica, sin contraseña local ni datos demo.

## Cómo mantener este documento

Actualizarlo en el mismo cambio que modifique comportamiento externo, actores, reglas de negocio, ciclos de vida o vocabulario. Mantenerlo breve y enlazar decisiones o código en vez de narrar implementaciones completas. Si una regla queda reemplazada, actualizar aquí el estado vigente y marcar el registro anterior como reemplazado.
