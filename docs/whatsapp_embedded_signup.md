# WhatsApp Business App Coexistence

## Alcance y seguridad

El panel `/admin/configuracion` permite conectar la cuenta propia de cada peluquería mediante el SDK oficial de Facebook Login for Business. El proceso conserva WhatsApp Business en el celular. CitaPet no crea códigos QR, no usa WhatsApp Web ni registra/migra números con `/register` o `/deregister`.

El frontend solicita `response_type: "code"`, `override_default_response_type: true` y únicamente `extras.featureType: "whatsapp_business_app_onboarding"`. No envía `version: "v3"`, `sessionInfoVersion` ni una lista de permisos/productos antigua. La configuración de Facebook Login for Business determina Embedded Signup v4; la versión de Graph API es independiente.

Solo se acepta `FINISH_WHATSAPP_BUSINESS_APP_ONBOARDING`. Otros eventos de finalización detienen el proceso. Cancelaciones y errores limpian los datos locales, sin mostrar respuestas crudas de Meta. El QR o código de vinculación es exclusivamente el presentado por Meta. Si la pantalla ofrece migrar o eliminar el número de la app móvil, cancelar; nunca continuar como alternativa a Coexistence.

## Configuración y bloqueo v4

Variables usadas:

- `META_APP_ID`, `META_APP_SECRET`: aplicación de CitaPet; el secreto nunca llega al navegador.
- `META_CONFIG_ID`: configuración de Facebook Login for Business. Sustituye al nombre antiguo `META_SIGNUP_CONFIG_ID` en este flujo.
- `WHATSAPP_GRAPH_API_VERSION`: versión de Graph API (actualmente `v25.0`); compatibilidad con `META_GRAPH_VERSION` como fallback.
- `META_EMBEDDED_SIGNUP_V4_CONFIRMED`: apagado por defecto. Solo establecer `true` después de comprobar los productos en el panel de Meta. Si cambia el Configuration ID, volver a validar antes de conservar esta confirmación.
- `WHATSAPP_AUTOMATION_ENABLED`: permanece `false`. Cada conexión tiene además `automation_enabled=false`, incluso al reconectarla.

La consulta `GET /{APP_ID}?fields=config_ids`, con credenciales de la aplicación, permite comprobar que la configuración pertenece a la app. En la comprobación local devolvió el ID y nombre de la configuración de token de 60 días; **no devolvió su versión ni sus productos**. Consultar el nodo Configuration ID directamente respondió `100/33`; esto no prueba ni descarta compatibilidad con v4. No se infiere la versión por el nombre, la fecha, el ID ni la versión de Graph API.

Hasta confirmar v4, el botón aparece deshabilitado y Rails rechaza también el intento de conexión. No se degrada a v2/v3.

## Pasos manuales obligatorios en Meta

1. En **Facebook Login for Business → Configuraciones**, revisar la configuración elegida. Debe usar la variación **Registro insertado de WhatsApp / Embedded Signup** e incluir el paso **Productos**, con **Cloud API** seleccionado. Según Meta, seleccionar productos establece v4 automáticamente. Si la configuración no ofrece ese paso, crear una nueva desde la plantilla de Embedded Signup con token de 60 días, seleccionar Cloud API y actualizar `META_CONFIG_ID` localmente. No solicitar productos de anuncios o marketing que CitaPet no utiliza.
2. Confirmar los permisos `whatsapp_business_management` y `whatsapp_business_messaging`. Para peluquerías ajenas a los roles de prueba, completar la habilitación como **Tech Provider** (o Solution Partner), verificación empresarial y **App Review / Advanced Access** para los permisos seleccionados, y publicar la app según corresponda. Una llamada exitosa con la WABA de prueba no demuestra estas aprobaciones. Si Meta informa falta de permisos, no intentar eludir la revisión.
3. En la configuración OAuth, habilitar **Client OAuth Login**, **Web OAuth Login**, **Enforce HTTPS**, **Embedded Browser OAuth Login**, **Strict Mode** y **Login with the JavaScript SDK**. Autorizar el dominio público HTTPS en los dominios del SDK/app y la URL exacta de `/admin/configuracion` en las redirect URI permitidas. Repetir si cambia ngrok. No abrir el flujo desde `http://localhost:3003`.
4. Mantener el webhook HTTPS verificado. Además de `messages` y `smb_message_echoes`, suscribirse a **account_update**, **history** y **smb_app_state_sync**, exigidos por la implementación/Coexistence vigente. Estas suscripciones del producto/app son distintas de suscribir cada WABA a CitaPet.
5. Después de comprobar los pasos anteriores, establecer `META_EMBEDDED_SIGNUP_V4_CONFIRMED=true` y recrear `web` desde la raíz del proyecto:

   ```sh
   docker compose up -d --no-deps --force-recreate web
   ```

6. Iniciar sesión como dueño de una peluquería, abrir Configuración mediante HTTPS y pulsar **Conectar WhatsApp Business**. Usar un número real elegible con WhatsApp Business actualizado; el número virtual de prueba de Meta no sirve para probar Coexistence. Confirmar elegibilidad y restricciones en el flujo oficial. No borrar ni desinstalar la app móvil.

La integración no modifica automáticamente estas opciones en Meta ni inicia una vinculación durante las pruebas automatizadas.

## Backend y aislamiento

El POST autenticado conserva CSRF y la política `BusinessPolicy#settings?` (solo dueño administrador). Su estado de sesión se liga al usuario, al negocio y a un vencimiento de 15 minutos; se consume al intentar finalizar. Los parámetros del navegador no eligen el tenant.

Rails intercambia el código de corta duración inmediatamente, valida la aplicación y los permisos del token mediante `debug_token` y comprueba sus WABA autorizadas. Si faltan IDs, solo se elige automáticamente una WABA/número cuando no hay ambigüedad. La consulta de números usa cursores de Graph, nunca sigue URLs arbitrarias de paginación. No utiliza `WHATSAPP_WABA_ID`, `WHATSAPP_PHONE_NUMBER_ID` ni `WHATSAPP_ACCESS_TOKEN` globales para conectar una peluquería.

Se comprueba `is_on_biz_app=true` y `platform_type=CLOUD_API` en el número real. Solo entonces se suscribe la WABA con `POST /{WABA_ID}/subscribed_apps` y se guardan sus credenciales cifradas. Los índices únicos de número y negocio evitan compartir una conexión entre tenants. No se crean plantillas ni se envían mensajes de prueba al conectar.

Se registran fechas de conexión, verificación, suscripción, vencimiento y fallos de autorización. Los vencimientos se obtienen de Meta, con fallback conservador de 60 días para esta configuración. Si vencen datos/acceso, o Meta revoca el token, la conexión deja de ser operativa. La UI avisa desde siete días antes. La renovación soportada aquí es **Volver a conectar WhatsApp Business**; no se inventa un refresh token ni se garantiza un token permanente.

**Desconectar** borra las credenciales locales y apaga la automatización. No se desuscribe toda una WABA ni se revocan permisos compartidos, porque eso podría afectar otros números. Para desvinculación completa, el dueño debe usar **WhatsApp Business → Configuración → Cuenta → Plataforma empresarial → Desconectar cuenta**. Los eventos de baja `account_update` también apagan la conexión local. Un evento viejo no debe invalidar una conexión posterior.

`ACCOUNT_RECONNECTED` se registra incluso cuando la conexión está desconectada o tiene la automatización apagada. Es una auditoría, no una orden de reactivar: conserva el tenant, Phone Number ID, identificador determinístico, tipo y timestamp en el evento, sin restaurar tokens ni modificar la conexión. El índice único existente deduplica reintentos; la auditoría mínima permanece disponible después de procesar el job.

Para resolver una reconexión se exige coincidencia de WABA y, cuando Meta lo proporciona, Phone Number ID. Sin ese identificador solo se admite una única conexión para esa WABA. Si no hay coincidencia o hay ambigüedad, se genera el diagnóstico estructurado `whatsapp_account_reconnected_unmapped`, sin tenant, credenciales ni cuerpo del webhook. Cada entrega repetida puede generar una línea de diagnóstico, pero mantiene el mismo `event_id` para correlación y no crea registros de tenant ni jobs.

## Sincronización inicial de Coexistence

Meta exige iniciar sincronización de contactos/historial dentro de las primeras 24 horas. Tras confirmar la conexión, un job solicita `smb_app_state_sync` y `history` mediante `/{PHONE_NUMBER_ID}/smb_app_data`; esto no envía mensajes al cliente. Los webhooks se autentican y acusan, pero no se importa ni conserva contenido histórico ni se dispara el bot desde él.

Las solicitudes de sincronización son de una sola ejecución. Se guarda una marca antes de la llamada y el identificador devuelto después; un timeout queda `unknown` y no se repite a ciegas. `requested` persistente, `failed` o `unknown` requieren revisión antes de la prueba de mensajería. Meta puede requerir offboarding manual y nueva vinculación si se agotó la ventana; no se realiza automáticamente. El recuperador existente reencola únicamente tipos de sincronización todavía no solicitados. Un job viejo no puede sincronizar otra generación de credenciales.

Renovar credenciales de la misma línea conserva las marcas de sincronización para no repetir esas operaciones. Un cambio de número o un offboarding confirmado por webhook permite iniciar una nueva sincronización al vincular nuevamente.

## Bot preparado, no activado

- Primera respuesta: servicios activos del negocio y atención humana. Hasta nueve servicios directos más atención humana. Catálogos mayores: páginas de ocho servicios, navegación y atención humana (máximo diez filas).
- Seleccionar un servicio valida su pertenencia al negocio y reutiliza el enlace de reserva firmado existente. No se modifica disponibilidad, reservas ni Mercado Pago.
- No repite automáticamente el menú por cada mensaje. `menú` permite solicitarlo.
- Atención humana y ecos manuales pausan esa conversación durante 24 horas. Los ecos no abren ni renuevan la ventana de servicio de Cloud API.
- Los ecos manuales se reducen a `id`, destinatario y timestamp antes de persistir: no se guardan texto, captions, contenido interactivo, nombres ni otros datos del mensaje manual. Los jobs reciben únicamente el ID interno del evento. Los mensajes entrantes normales conservan los campos necesarios para procesar el chatbot.
- Los envíos verifican nuevamente la ventana de 24 horas y la conexión. Las conexiones Coexistence verificadas rechazan plantillas, incluso si quedaron pendientes antiguas.
- Después de una conexión/reconexión se exige un nuevo mensaje entrante para habilitar su ventana local; no se reutiliza la ventana de una línea anterior.
- No hay límites de consumo en el chatbot. Se conservan los flujos anteriores de notificaciones para conexiones heredadas; esta conexión nueva no crea ni habilita plantillas.

## Contabilización

Los eventos entrantes guardan el negocio y el Phone Number ID de origen. Las salidas guardan también la identidad del número al encolar, identificador Meta, timestamps `accepted/sent/delivered/read/failed` y metadatos de facturación disponibles (`pricing`, `conversation`). Los estados fuera de orden no degradan una entrega leída a enviada. Los estados y mensajes de otro número/tenant no reconcilian una entrega ajena.

`business.whatsapp_deliveries.monthly_usage` devuelve conteos mensuales por número, incluyendo entregados, leídos y facturables. Estos datos preparan el análisis de costos: **no son un importe monetario**, porque los webhooks no garantizan un precio unitario. No inventar tarifas ni bloquear envíos por consumo; cualquier estimación monetaria futura requiere un tarifario vigente y explícito.

## Verificación y rollout

```sh
docker compose exec -T web bash -lc 'bin/rails db:prepare'
docker compose exec -T web bash -lc 'bundle exec rspec spec/requests/admin_whatsapp_connections_spec.rb spec/requests/whatsapp_webhooks_spec.rb spec/requests/whatsapp_booking_flow_spec.rb spec/services/whatsapp'
docker compose exec -T web bash -lc 'node --test spec/javascript/whatsapp_signup_test.cjs'
```

Las pruebas JavaScript usan el runner estándar de Node y dobles del SDK, no una cuenta de Meta. Node es una herramienta de verificación opcional dentro de `web`, no una dependencia de producción ni requiere npm. Si la imagen local no lo incluye, instalarlo en el contenedor antes de ejecutar ese comando.

Aplicar la migración aditiva antes de usar el nuevo código. No elimina registros; apaga por defecto la automatización en las conexiones existentes y agrega datos opcionales. Un rollback de esquema pierde las nuevas fechas/metadatos, por lo que conviene volver primero al código anterior y conservar las columnas durante la reversión. No se desplegó a producción ni se conectó un número real durante esta implementación.

## Fuentes oficiales

- [Embedded Signup v4: productos, permisos y selección de versión](https://developers.facebook.com/documentation/business-messaging/whatsapp/embedded-signup/version-4)
- [Implementación, dominios OAuth, eventos y códigos](https://developers.facebook.com/documentation/business-messaging/whatsapp/embedded-signup/implementation)
- [Coexistence: comprobación del número y sincronización obligatoria](https://developers.facebook.com/documentation/business-messaging/whatsapp/embedded-signup/onboarding-business-app-users)
- [Onboarding como Tech Provider](https://developers.facebook.com/documentation/business-messaging/whatsapp/embedded-signup/onboarding-customers-as-a-tech-provider)
- [Resolución de WABA mediante el token autorizado](https://developers.facebook.com/documentation/business-messaging/whatsapp/solution-providers/manage-accounts)
