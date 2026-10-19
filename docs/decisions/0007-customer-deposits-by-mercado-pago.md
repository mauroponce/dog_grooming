# 0007 — Señas de clientes cobradas mediante Mercado Pago

- Estado: Aceptada
- Fecha: 2026-10-19

## Contexto

La transferencia bancaria exigía que el cliente cargara un comprobante y que la peluquería lo revisara manualmente. Ese recorrido agregaba demoras, estados operativos y riesgo de confirmar una reserva sin una acreditación verificable.

## Decisión

Los servicios que requieren seña se cobran exclusivamente mediante la cuenta de Mercado Pago que cada `Business` conecta por OAuth. Cita.pet crea el pago pendiente y confirma el turno solamente después de validar la acreditación mediante el webhook de Mercado Pago.

Si Mercado Pago no está conectado, una reserva que requiere seña no puede finalizar. Los servicios sin seña continúan confirmándose sin pago online. El importe y el vencimiento permanecen configurados por servicio.

La transferencia bancaria para pagar la suscripción de Cita.pet sigue siendo un contexto independiente y conserva la decisión [0003](0003-platform-subscription-by-bank-transfer.md).

## Consecuencias

- La configuración del negocio ofrece una única integración de cobro y no administra Alias, CBU ni cuentas manuales.
- Los payloads públicos de transferencia se rechazan aunque se envíen fuera de la interfaz.
- Firma, importe, moneda, cobrador, referencia externa e idempotencia del webhook siguen siendo invariantes del flujo.
- Las estructuras históricas de comprobantes manuales pueden permanecer temporalmente en el esquema, pero no forman parte de recorridos activos ni de los defaults de nuevas cuentas.

## Evidencia vigente

- `Admin::MercadoPagoConnectionsController`
- `Appointments::CreateBooking`
- `MercadoPago::CreateBookingPreference`, `MercadoPago::ApproveBookingPayment`
- `Webhooks::MercadoPagoController`, `MercadoPago::ProcessWebhookJob`
- `spec/services/appointments/create_booking_spec.rb`
- `spec/jobs/mercado_pago/process_webhook_job_spec.rb`
