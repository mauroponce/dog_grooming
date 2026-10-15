# Webhook de WhatsApp Cloud API

## Fase 1: recepción sin respuestas automáticas

La ruta pública es `/webhooks/whatsapp`, antes de las rutas por slug. No depende de una sesión de usuario ni de la configuración de reservas o Mercado Pago.

- `GET`: exige `hub.mode=subscribe` y compara `hub.verify_token` con `WHATSAPP_WEBHOOK_VERIFY_TOKEN`. Devuelve el challenge exacto como `text/plain`, o `403`.
- `POST`: verifica `X-Hub-Signature-256` con HMAC-SHA256 sobre el cuerpo original y `META_APP_SECRET`. Una firma incorrecta o un secreto ausente devuelve `401`; un JSON/envelope inválido devuelve `400`.
- Solo el POST de este controlador omite CSRF; la firma de Meta autentica ese endpoint. Las demás protecciones de Rails no cambian.
- Cada número debe existir en `WhatsAppConnection`, asociado explícitamente a un negocio, con `phone_number_id`, `waba_id` y sin desconexión. No se asignan tenants a partir de las credenciales globales de `.env`. Un número desconocido se acusa con `200`, se ignora y genera un log sin datos del cliente.
- Los mensajes, estados y ecos manuales se persisten antes de responder `200`. El índice único por negocio, identificador Meta y tipo deduplica los reintentos. `WhatsApp::ProcessEventJob` procesa fuera de la solicitud y no repite eventos ya procesados.
- Un webhook repetido vuelve a encolar el evento si sigue pendiente. `WhatsApp::RecoverPendingJob` recupera eventos pendientes; ya está programado cada cinco minutos en producción. Usa el adaptador Active Job existente (Solid Queue en producción; async en desarrollo). En desarrollo, después de reiniciar el proceso, se puede ejecutar `bin/rails runner 'WhatsApp::RecoverPendingJob.perform_now'` dentro de `web`.
- El job reintenta fallos transitorios de conexión y locks. Si falla la persistencia o el encolado, no se acusa la solicitud como exitosa: Meta puede reenviarla.
- `WHATSAPP_AUTOMATION_ENABLED` está apagado por defecto. El bot no genera respuestas y el job de envío no consume pendientes mientras esté apagado. No habilitarlo hasta completar las pruebas acordadas; los pendientes existentes deben revisarse antes de habilitar envíos.
- Los logs de recepción solo incluyen IDs internos. Se filtran el token de verificación, el contenido de los eventos y los atributos sensibles de los modelos. No registrar headers de autorización, firmas, payloads completos ni URLs con tokens.

## Configuración local y pasos manuales de Meta

1. Mantener el valor existente de `WHATSAPP_WEBHOOK_VERIFY_TOKEN`. Completar `META_APP_SECRET` localmente con el secreto de la aplicación correcta; no compartirlo en chats ni versionarlo. Las credenciales de Graph API no reemplazan ese secreto.
2. Arrancar ngrok con inspección deshabilitada (`ngrok http 3003 --inspect=false`), ya que el handshake necesariamente transporta el verify token en la query string. Deshabilitar también cualquier captura externa de solicitudes/URLs sensibles.
3. Autorizar el hostname exacto en development mediante `APP_HOSTS` o la lista existente de `config.hosts`. HTTPS termina en ngrok, que reenvía al puerto HTTP local 3003; no hace falta desactivar TLS ni forzar SSL globalmente en development.
4. Recrear `web` si cambian variables de Compose: `docker compose up -d --no-deps web`. Un simple restart no actualiza las variables inyectadas al crear el contenedor.
5. En Meta Developers, en la configuración del webhook de WhatsApp Business, ingresar la URL pública HTTPS seguida de `/webhooks/whatsapp` y el verify token local existente. Presionar **Verificar y guardar** después de comprobar el challenge público.
6. Detenerse tras esta verificación. La suscripción al campo `messages`, el POST a `/{WABA_ID}/subscribed_apps` y las pruebas de envío requieren la confirmación del usuario para iniciar Fase 2. Usar exclusivamente el número de prueba y destinatarios autorizados.
7. Antes de procesar eventos reales, asociar el número de prueba al negocio explícitamente elegido mediante el mecanismo de conexión existente. No seleccionar un negocio automáticamente.

Las fases de chatbot, estadísticas de consumo y Embedded Signup no forman parte de esta entrega de Fase 1. Se conserva la infraestructura previa sin activarla.

Contrato de Meta: [verificación del challenge y firma](https://whatsapp.github.io/WhatsApp-Nodejs-SDK/api-reference/webhooks/start/).

## Pruebas

```sh
docker compose exec -T web bash -lc 'bundle exec rspec spec/requests/whatsapp_webhooks_spec.rb spec/requests/whatsapp_booking_flow_spec.rb spec/services/whatsapp/automation_spec.rb'
```
