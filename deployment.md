# Deployment de Cita.pet

El procedimiento vigente está en [`docs/production_operations.md`](docs/production_operations.md).

Resumen:

1. Preparar `/opt/cita.pet/dog_grooming/.env.production`, DNS, R2 y Resend.
2. Instalar en el host Docker con Compose, Git, `curl` y AWS CLI.
3. Ejecutar `./deploy.sh` desde el servidor. El script valida configuración, hace backup, construye la imagen, corre el preflight, crea las bases faltantes sin datos, migra y verifica tres endpoints.
4. En una base vacía, ejecutar una sola vez `citapet:bootstrap_super_admin` con el email de Google del operador.
5. Completar la comprobación funcional posterior.

`db:seed` no se ejecuta en producción. Está protegido para uso exclusivo en desarrollo.
