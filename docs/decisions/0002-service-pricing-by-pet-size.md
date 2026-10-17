# 0002 — Servicio base con variantes por tamaño de mascota

- Estado: Aceptada
- Fecha: 2026-10-17

## Contexto

Precio y duración de peluquería dependen del tamaño de la mascota. Modelar `Baño chico`, `Baño mediano` y `Baño grande` como servicios independientes duplica descripción, imágenes, categoría, profesionales y disponibilidad, y presenta una lista difícil de recorrer.

## Decisión

Mantener un `Service` por oferta y agregar `ServiceVariant` para precio y duración por `PetSizeBand`. Los rangos pertenecen al `Business` y se comparten entre servicios.

La reserva exige una variante para servicios con `pricing_mode = by_pet_size`. La variante efectiva participa en disponibilidad, precio y seña. El turno persiste la relación y snapshots de etiqueta, precio y duración. La mascota recuerda el rango, pero éste se confirma en cada reserva.

El catálogo inicial contiene tres servicios base con variantes Chico, Mediano y Grande. También se admite `pricing_mode = fixed` para servicios que no dependen del peso.

## Consecuencias

- Categorías, contenido, imágenes, profesionales y reglas se administran una sola vez por servicio.
- Disponibilidad y recursos deben recibir la duración efectiva, no la duración base por accidente.
- Historial y reportes usan snapshots del turno cuando necesitan explicar el valor cobrado.
- Cambiar límites o precios del catálogo no altera turnos existentes.
- La agenda manual y la reserva pública deben aplicar la misma selección de variante.

## Evidencia vigente

- `PetSizeBand`, `ServiceVariant`, `Service#pricing_mode`
- `Bookings::ServiceSelection`
- `Appointments::CreateBooking`
- `Grooming::Catalog`
- `spec/services/grooming/booking_configuration_spec.rb`
- `spec/requests/public_bookings_spec.rb`
