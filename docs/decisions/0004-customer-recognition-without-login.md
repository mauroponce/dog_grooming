# 0004 — Reconocimiento por celular sin login y ficha interna por mascota

- Estado: Aceptada
- Fecha: 2026-10-17

## Contexto

La reserva debe requerir pocos datos y la atención debe poder cerrarse sin completar un formulario. Es necesario reconocer visitas anteriores sin confundir personas de distintas localidades ni publicar fichas al ingresar un contacto ajeno.

## Decisión

Identificar internamente al cliente por su celular argentino completo y normalizado, dentro del negocio. Completar números locales con el área configurada del negocio y mostrar el resultado antes de confirmar. No identificar por la terminación del número.

Reutilizar una mascota sólo cuando su nombre coincide inequívocamente dentro del cliente. El email es opcional para recordatorios y sugerencias internas, nunca una causa automática de fusión. El equipo puede corregir una asociación por turno, dejando registro del cambio.

Separar cuidados permanentes de notas y fotos de cada atención. El cierre es idempotente y no exige contenido adicional; anexar información posteriormente no vuelve a cerrar. Conservar permisos separados para atención y edición de clientes.

## Consecuencias

- La reserva no exige login ni expone un listado de mascotas guardadas. Sus enlaces habilitan sólo ese turno.
- Coincidencia de contacto es reconocimiento operativo, no prueba de identidad. El perfil completo mantiene su acceso independiente.
- Un cambio de nombre o contacto puede crear una ficha adicional hasta que el equipo confirme la relación; las ambigüedades no se resuelven automáticamente.
- Números antiguos se auditan antes de normalizar; colisiones, incluso con fichas eliminadas, quedan para revisión.
- No se incorporan SMS, OTP ni verificación de titularidad del celular.

## Evidencia vigente

- `PhoneNormalizer`, `Customers::UpsertProfile`, `Pets::Upsert`
- `Appointments::FinalizeService`, `Appointments::LinkCustomer`
- `spec/requests/admin_pet_care_spec.rb`, `spec/services/phone_normalizer_spec.rb`
