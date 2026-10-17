# 0003 — Suscripción de Cita.pet pagada por transferencia

- Estado: Aceptada
- Fecha: 2026-10-17

## Contexto

Cobrar la suscripción de cada peluquería mediante Mercado Pago agrega comisión y demora de retiro. La plataforma puede verificar la acreditación en su banco y necesita una forma explícita de vincularla con la factura mensual.

## Decisión

La empresa paga su suscripción por transferencia bancaria directa. El superadmin mantiene los datos de la cuenta y una constancia opcional. La empresa selecciona plan, ve esos datos, transfiere y adjunta un comprobante a su factura.

La carga crea una revisión pendiente y notifica al superadmin. Sólo la aprobación del superadmin marca la factura pagada y extiende la vigencia; el rechazo conserva un motivo y permite corregir el comprobante.

Mercado Pago queda reservado para pagos de clientes a las peluquerías, principalmente señas. No es un método activo de cobro de la suscripción de Cita.pet.

## Consecuencias

- `BillingTransferAccount` es configuración global de la plataforma, no una cuenta de un tenant.
- `SubscriptionPaymentProof` y su archivo siempre pertenecen a una `SubscriptionInvoice` del mismo `Business`.
- Emails y tareas ayudan a revisar, pero el estado persistido de factura/suscripción es la fuente de verdad.
- Servicios y tablas históricos de checkout pueden permanecer durante una transición, pero ninguna UI nueva debe ofrecerlos como canal aprobado.
- Una futura automatización bancaria debe reconciliar contra facturas sin mezclar conexiones Mercado Pago de los negocios.

## Evidencia vigente

- `Admin::BillingController`
- `SuperAdmin::BillingController`
- `Billing::UploadPaymentProof`, `Billing::ApprovePayment`, `Billing::RejectPayment`
- `BillingTransferAccount`, `SubscriptionInvoice`, `SubscriptionPaymentProof`
- `spec/requests/admin_billing_spec.rb`
- `spec/requests/super_admin_billing_spec.rb`
