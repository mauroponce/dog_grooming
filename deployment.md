# Deployment de Cita.pet

Esta aplicación es independiente de cualquier instalación anterior. Antes del primer deploy definí servidor, dominio, imagen de contenedor y secretos propios; no reutilices bases de datos, volúmenes ni buckets de otra app.

La guía operativa vigente está en [`docs/production_operations.md`](docs/production_operations.md). Resume:

- variables productivas y secretos pendientes;
- deploy con Kamal y validaciones previas;
- uso aislado de los buckets R2 `dog-grooming` y `dog-grooming-service-images`;
- backups de `dog_grooming_production`;
- comprobaciones de reservas, mascotas, calendario y portal luego del deploy.

Para desarrollo local, iniciá la aplicación con:

```sh
docker compose up --build
```

La web queda disponible en <http://localhost:3003>.
