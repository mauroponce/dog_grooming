# 0005 — Reserva y operación mínima para peluquerías caninas

- Estado: Aceptada
- Fecha: 2026-10-17

## Contexto

El sistema heredó portal de cliente, cancelación y reprogramación autónomas, lista de espera, selección y asignación de profesionales, permisos configurables e inteligencia artificial. Esas funciones agregaban estados, permisos, datos y recorridos que no son necesarios para validar el uso inicial de una peluquería canina.

## Decisión

Mantener un producto centrado en reserva pública, señas y operación administrativa básica.

La reserva pública usa la capacidad global de la peluquería y no permite elegir profesional. El cliente reserva y consulta el estado de esa reserva, pero para cancelar, reprogramar o pedir otro horario debe contactar por WhatsApp. La reprogramación es una acción exclusiva del equipo desde el calendario.

El responsable invita empleados por email. Los empleados activos acceden a agenda, clientes, mascotas y señas; el responsable conserva catálogo, capacidad, equipo, configuración y suscripción. No se expone una configuración de roles o permisos individuales.

Eliminar el asistente, chat, análisis, generación y cualquier persistencia de IA. También eliminar portal de cliente y lista de espera, junto con sus rutas, jobs, tablas y columnas.

## Consecuencias

- Menos estados públicos, tokens, autorización y datos que mantener.
- Los pedidos de excepción se resuelven inicialmente por WhatsApp; un flujo nuevo sólo se agrega cuando exista evidencia de uso y una decisión específica.
- La capacidad debe seguir validándose de forma atómica al crear o reprogramar un turno.
- La migración `20261017160000_remove_ai_customer_portal_and_waitlist` es irreversible porque destruye datos de funcionalidades retiradas. Antes de desplegarla se requiere backup verificable.
- Código comercial heredado que no participa del flujo mínimo no debe exponerse ni extenderse.

## Evidencia vigente

- `PublicBookingController`, `Appointments::CreateBooking` y `Availability::AvailableSlots`
- `Admin::AppointmentsController#reschedule`
- `Admin::EmployeeMembershipsController` y `BusinessPolicy`
- `db/migrate/20261017160000_remove_ai_customer_portal_and_waitlist.rb`
- `spec/requests/public_bookings_spec.rb`
- `spec/requests/admin_employee_memberships_spec.rb`
- `spec/services/grooming/concurrent_capacity_spec.rb`
