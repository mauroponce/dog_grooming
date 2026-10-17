# Registro de decisiones

Este directorio conserva decisiones funcionales o arquitectónicas duraderas que no son obvias desde una sola clase. `docs/product_context.md` y `docs/architecture.md` describen el estado vigente; estos registros explican el motivo y las consecuencias.

## Índice

| ID | Estado | Decisión |
| --- | --- | --- |
| [0001](0001-registration-google-and-public-slug.md) | Aceptada | Registro con Google OAuth y slug público único |
| [0002](0002-service-pricing-by-pet-size.md) | Aceptada | Servicio base con variantes por tamaño de mascota |
| [0003](0003-platform-subscription-by-bank-transfer.md) | Aceptada | Suscripción de Cita.pet pagada por transferencia y revisión manual |
| [0004](0004-customer-recognition-without-login.md) | Aceptada | Reconocimiento por celular sin login y ficha interna por mascota |
| [0005](0005-minimal-booking-and-operations.md) | Aceptada | Reserva pública y operación mínima sin IA ni autoservicio |

## Cuándo crear una decisión

Crear un registro cuando la elección:

- cambia comportamiento funcional importante o una frontera técnica;
- tiene alternativas razonables y consecuencias para trabajo futuro;
- afecta datos, integraciones, seguridad, tenancy, pagos o compatibilidad;
- sería costosa de inferir nuevamente sólo leyendo código local.

No crear registros para nombres de métodos, ajustes visuales, refactors locales ni planes temporales.

## Formato y ciclo de vida

Cada registro incluye estado, fecha, contexto, decisión, consecuencias y evidencia. Los estados admitidos son `Propuesta`, `Aceptada`, `Reemplazada` y `Descartada`. Una decisión aceptada no se reescribe para ocultar historia: se crea la nueva, se marca la anterior como reemplazada y se enlazan ambas.

Usar [`_template.md`](_template.md) como estructura y eliminar las secciones que no aporten información.
