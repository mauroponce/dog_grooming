# 0006 — Servicios independientes con precio único por tamaño de mascota

- Estado: Aceptada
- Fecha: 2026-10-19
- Reemplaza: [0002](0002-service-pricing-by-pet-size.md)

## Contexto

El modelo anterior agrupaba los precios y duraciones por tamaño dentro de un servicio base mediante `ServiceVariant` y rangos compartidos de peso. Antes de incorporar usuarios en producción se decidió simplificar el catálogo y evitar que un servicio tenga una configuración de precio adicional.

## Decisión

Cada `Service` tiene un único precio y una única duración. Cuando una oferta depende del tamaño, se crean servicios independientes dentro de la misma categoría y el tamaño se agrega al nombre, por ejemplo `Baño + corte (Chico)`, `Baño + corte (Mediano)` y `Baño + corte (Grande)`.

La descripción indica el límite de peso aplicable. La reserva pública y la agenda administrativa seleccionan directamente el servicio, sin una segunda selección de variante.

Como no existen usuarios ni datos productivos que conservar, se eliminan de forma destructiva las tablas, columnas y asociaciones de variantes y rangos, sin backfill ni compatibilidad transitoria.

## Consecuencias

- Precio, duración, disponibilidad, imágenes y reglas se administran por cada servicio independiente.
- El catálogo público puede mostrar más servicios, pero la selección y el modelo de datos son más simples.
- Los límites de peso son contenido descriptivo y no una taxonomía persistida en la mascota.
- Los turnos usan los snapshots generales de precio, duración e importes; no guardan snapshots específicos de variantes.

## Evidencia vigente

- `Service`
- `Appointments::CreateBooking`
- `Grooming::Catalog`
- `spec/services/grooming/booking_configuration_spec.rb`
- `spec/requests/public_bookings_spec.rb`
