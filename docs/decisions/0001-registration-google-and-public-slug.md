# 0001 — Registro con Google OAuth y slug público único

- Estado: Aceptada
- Fecha: 2026-10-17

## Contexto

La plataforma necesita identificar al propietario de una peluquería, evitar cuentas creadas accidentalmente desde el login y entregar una URL pública estable desde el alta.

## Decisión

El alta pública comienza con Google OAuth y guarda la identidad validada temporalmente en sesión. Después solicita datos de empresa, responsable, teléfono, plan y slug. El servidor normaliza y comprueba la unicidad global del slug.

La transacción de registro crea el usuario propietario, `Business`, suscripción inicial, catálogo precargado y membresía administrativa. La empresa comienza una prueba de 14 días y continúa al onboarding de horarios.

## Consecuencias

- El login de una identidad desconocida no crea por sí solo una empresa.
- La disponibilidad mostrada por la UI es orientativa; la validación definitiva del slug ocurre dentro del alta y tolera conflictos concurrentes.
- Cualquier nuevo dato obligatorio del alta debe integrarse en la misma transacción o contar con una recuperación explícita.
- Cambiar el slug afecta identidad pública, enlaces y dominios; no se trata como un campo decorativo.

## Evidencia vigente

- `GoogleAuthenticationController`
- `RegistrationsController`
- `Registrations::CreateBusinessAccount`
- `Slugs::GenerateUnique`
- `spec/requests/signup_slugs_spec.rb`
