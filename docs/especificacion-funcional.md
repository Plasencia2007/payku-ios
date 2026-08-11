# Especificación funcional de Payku — para reconstrucción en Swift/SwiftUI

> Este documento describe **QUÉ hace** la app Payku (originalmente Android/Kotlin), no cómo está implementada. Sirve como prompt de referencia para reconstruirla en iOS con Swift/SwiftUI. No contiene código.

---

## ⚠️ Nota crítica antes de empezar (leer sí o sí)

Payku captura los pagos leyendo las **notificaciones del sistema** de las apps Yape y Plin mediante un servicio de escucha de notificaciones de Android (`NotificationListenerService`). **iOS NO tiene equivalente**: no permite que una app lea las notificaciones de otras apps. Este es el corazón de la app y el mayor obstáculo del port.

Al reconstruir en iOS, la parte de "captura" debe replantearse por completo (p. ej.: que el pago entre al backend por otra vía —Notification Service Extension muy limitada, integración bancaria, ingreso manual, o un dispositivo Android dedicado como sensor—). **Todo lo demás del sistema es portable**: la cola local, la sincronización con el backend, el historial, la caja del día, los avisos, la vinculación por QR, el visor en vivo del cajero y el push. La recomendación práctica es: en iOS, el rol "cajero/espejo" (que solo recibe y muestra) es 100% reconstruible; el rol "sensor/captura" necesita otra fuente de datos.

---

## 1. Propósito general de la app

Payku es una app para **bodegas y negocios pequeños de Perú** que cobran por **Yape** y **Plin** (billeteras móviles peruanas). Convierte cada notificación de cobro en un registro en la "caja del día", sin que el comerciante tenga que anotar nada a mano. Resuelve tres problemas:

1. **Anotar ventas automáticamente**: cada Yape que llega al celular se registra solo, con hora y monto.
2. **Cuadrar caja**: al final del día el total cobrado sale solo, con desglose e historial.
3. **Antifraude en el mostrador**: un empleado puede confirmar en vivo si un cobro entró de verdad, para que nadie lo engañe con una captura de pantalla falsa.

Es en realidad **un sistema de dos apps** que trabajan juntas sobre el mismo negocio:

- **App del dueño (rol SENSOR / "watcher")**: se instala en el celular fijo del local. **Captura** las notificaciones de Yape/Plin, las guarda y las sube al servidor. Es la fuente de datos.
- **App del cajero (rol EMPLEADO / "espejo")**: la usa el empleado del mostrador. **No captura nada**: es un visor en vivo que muestra y "canta" en voz alta cada cobro que el celular del dueño detecta. Sirve para verificar cobros al instante.

Un backend central (Node + Fastify + Prisma, REST) une ambas: recibe el texto crudo del sensor, lo **interpreta** (extrae nombre, monto, código) y sirve la versión ya parseada al espejo y de vuelta al dueño.

**Idioma**: español peruano. **Moneda**: soles, mostrada como "S/". **Zona horaria de negocio**: siempre America/Lima (fija, no la del celular).

---

## 2. Pantallas / screens

### 2A. App del DUEÑO (SENSOR)

**Pantallas de entrada / onboarding:**

1. **Intro (onboarding fase 1)** — Carrusel de 4 páginas que se ve **una sola vez, antes de vincular**. Explica qué es Payku con animaciones:
   - P1: bienvenida ("Payku convierte los Yape de tu negocio en tu caja del día. Sin apuntar nada a mano.").
   - P2: "Así de fácil" — 3 pasos (vincula el celular / cobras por Yape como siempre / Payku lo anota solo).
   - P3: "Escucha tus Yape solo" (cada Yape se anota al instante).
   - P4: "Nada se te escapa" (cada cobro con su hora y monto; la caja cuadra sola). Botón final "Vincular mi celular".

2. **Vinculación / Entrada** — La única puerta de acceso. No hay registro ni contraseña: se canjea un código `PYK-XXXXXX` (o su QR) por un token de dispositivo. Contiene: logo + "Payku", tarjeta grande "Escanear QR" (abre cámara), campo de texto para escribir el código (fuerza mayúsculas, placeholder `PYK-XXXXXX`), botón "Entrar", y ayuda ("Pídele el código al dueño desde el panel de Payku"). Escáner con opción "Escanear desde una foto" (decodifica un QR recibido por WhatsApp desde la galería).

3. **Setup (onboarding fase 2)** — Carrusel de 3 páginas que se ve **una sola vez, después de vincular**:
   - P1 "Permisos": lista de permisos con botón "Activar" cada uno (lleva a ajustes del sistema).
   - P2 "Prueba un cobro": tarjeta animada "Nuevo Yape · S/ 0.10"; pide hacer un Yape de prueba; enlace "Saltar".
   - P3 "¡Todo listo!": animación de check; botón "Comenzar a usar Payku".

4. **Splash / Apertura** — Se ve en **cada arranque** ya vinculado (~1.8 s, o toca para saltar). Logo animado + saludo según la hora ("Buenos días" 0–11h / "Buenas tardes" 12–17h / "Buenas noches" resto) + píldora "Captura activa".

**Pantallas principales (con barra inferior de 3 pestañas: Inicio, Historial, Ajustes):**

5. **Inicio / Dashboard** — La caja del día. Muestra:
   - Cabecera: logo + nombre del comercio + nombre del celular + sucursal + badge "DUEÑO".
   - Tarjeta grande "Cobrado hoy": monto total del día, píldora "EN VIVO" (si la captura está activa), nº de yapes, y comparación "▲/▼ X% vs ayer".
   - Dos métricas: "Capturados" (pagos de hoy) y "En cola" (pendientes de enviar, con chip "pendiente" si >0).
   - Banner "N cobros sin enviar · toca para reintentar ahora" (solo si hay pendientes).
   - Lista "Últimos yapes" (con enlace "Ver todo" al historial), o estado vacío ("Hoy todavía no entró ningún yape").

6. **Historial** — Todos los pagos capturados. Muestra: tarjeta resumen ("Total recibido" + pastillas Pagos / Enviados / En cola), buscador (por nombre o monto), chips de filtro por estado (Todos / Enviados / En cola / Con error / No leídos), banner de reintento, y la lista **agrupada por día** (con subtotal por día) con scroll infinito. Botones: filtrar por fecha (Hoy / 7 días / Este mes / Todo / rango personalizado) y exportar a CSV. Estados vacíos contextuales según el filtro.

7. **Detalle de un pago** — Ficha de un cobro (solo lectura / diagnóstico). Muestra: avatar + monto grande + "{nombre} te envió un pago", y filas de datos: Estado (badge de color), Billetera, Recibido (fecha y hora completas), Cód. de seguridad (con botón copiar), Intentos de envío. Si hubo error de envío o si no se pudo leer, muestra tarjetas explicativas. Al final, el **texto crudo** original de la notificación (con botón copiar, para diagnosticar formatos nuevos por WhatsApp). **No** tiene botones de reintentar/descartar (el reintento es global; "descartado" llega del servidor).

8. **Ajustes** — Secciones:
   - Captura de pagos: tarjeta "Permisos" (estado, lleva a Configuración), fila "Avisos" (con contador), y **toggle "Sincronización instantánea"** (envío inmediato al volver la red).
   - Cuenta: fila de perfil (avatar del comercio + "Ver mi perfil").
   - Datos: fila "Almacenamiento" (N pagos · tamaño).
   - Soporte: "Centro de ayuda", "Acerca de Payku" (con versión).
   - Botón "Cerrar sesión" (aclara: "La captura de yapes sigue activa").

9. **Almacenamiento** — Gestión del espacio local. Muestra: tamaño en disco + nº pagos, barra segmentada y leyenda (Últimos 90 días / Anteriores a 90 días / Sin enviar). Tarjeta "Borrado automático" (switch + slider de días a conservar 1–90, con vista previa de cuántos borraría). Botones de borrado manual: "Borrar los ya enviados", "Borrar anteriores a 90 días", "Borrar todo el historial" (con confirmación). Advierte si se perderían pagos sin enviar.

10. **Avisos** — Bandeja de **problemas** (no de pagos). Lista de tarjetas ordenadas por gravedad (crítico/atención/info), cada una con título, detalle, y acción que lleva a donde se arregla. Estado vacío: "Todo en orden". (Ver sección 6 para el catálogo de avisos.)

11. **Configuración / Permisos** — Estado y activación de permisos. Hero de estado (todo bien / falta activar N), barra de progreso por permiso, lista de permisos (Notificaciones, Batería, Avisos, Fabricante) cada uno con estado y enlace "Abrir ajustes". Incluye una tarjeta "Últimos 7 días" con % de uptime de la captura. Botón inferior "Todo listo" (deshabilitado si falta el permiso de notificaciones).

12. **Perfil** — Solo lectura. Avatar + nombre del comercio + "Vinculado". Datos: Comercio, Sucursal (o "Todo el comercio"), Este celular. Nota: para cambiarlos se usa el panel web.

13. **Acerca de Payku** — Descripción de la app, "Cómo funciona" (3 pasos), "Por qué usarlo" (3 beneficios), tarjeta "Buscar actualizaciones" (Play Store), info de versión/compilación + changelog, enlaces legales (términos, privacidad).

14. **Centro de ayuda** — Buscador + chips de categoría (Captura / Pagos / Privacidad) + FAQs en acordeón + contacto (WhatsApp y correo).

15. **Prueba de 7 días / Uptime** — Registro de continuidad de la captura: estado (sin caídas / hubo una caída), nº de comprobaciones, hueco más largo, últimas comprobaciones, botón "Exportar registro" (CSV).

16. **Empleados** — Gestión de cajeros (existe en el código; alta con "Generar código" → QR; lista de empleados con "Ver código" y dar de baja; regenerar código invalida el anterior).

### 2B. App del CAJERO (EMPLEADO / espejo)

Barra inferior de **2 pestañas: "En vivo" y "Ajustes"**. Comparte con el dueño: Intro, Vinculación, Setup y Splash (con textos adaptados al cajero).

1. **Intro / Setup / Vinculación / Splash** — Equivalentes a las del dueño pero con copy propio ("Aquí ves y escuchas cada Yape que cobra tu caja", "Cada cobro, cantado", etc.). El Setup del cajero solo pide el permiso de notificaciones.

2. **En vivo** — El espejo de los cobros según entran. Muestra:
   - Cabecera con badge "CAJERO" (o "DUEÑO") + hero "Cobrado hoy" (monto + nº yapes) + **píldora "EN VIVO" o "SIN SEÑAL"** (distingue "hoy no pagó nadie" de "el celular que captura está caído").
   - Aviso si la fuente está caída ("Sin señal desde hace X"; "no le digas a un cliente que no pagó sin comprobarlo").
   - Lista de pagos en vivo: avatar, nombre (o "No se pudo leer"), hora + código de operación, monto, y badge de estado ("VERIFICADO" / "DESCARTADO" / "NUEVO" / "LIBRE").
   - **Long-press sobre un pago → descartar** (única acción de escritura; diálogo reversible "¿Descartar este cobro?"). Estado vacío: "Todavía no entra ningún yape".
   - **Lectura en voz alta** de cada cobro nuevo (text-to-speech): "Yape recibido de María por 28 soles".

3. **Verificar** — (Pantalla presente en el código pero **retirada de la barra** por decisión de producto: los cobros ya nacen verificados.) Buscador antifraude de solo lectura: se escribe un monto o código de operación y dice si ese pago llegó de verdad al sistema.

4. **Ajustes (cajero)** — Tarjeta de perfil del turno (solo lectura, con "Cobrado hoy" y nº yapes), sección "Cómo me avisa" con toggles "Leer en voz alta" y "Sonido de alerta", botón "Probar cómo suena un yape", tarjeta "Permisos" (subpantalla de permisos del cajero) y "Cerrar mi turno".

---

## 3. Flujo de navegación

### Lógica de arranque (dueño), en orden estricto de decisión:
1. Si **no se ha visto la Intro** → **Intro**.
2. Si **no hay sesión** (no vinculado) → **Vinculación**.
3. Si **no se ha visto el Setup** → **Setup**.
4. Si **falta el permiso de notificaciones** → **Configuración/Permisos**.
5. En cualquier otro caso → **Splash** → **Inicio**.

Regla: Intro una vez (antes de vincular), Setup una vez (después de vincular), Splash en cada arranque ya vinculado. Cada transición limpia la pila de navegación.

### Transiciones por acción (dueño):
- Intro → "Vincular mi celular" → Vinculación.
- Vinculación → canjear código con éxito → (guarda credencial, sincroniza) → Setup.
- Setup → "Comenzar a usar Payku" → Inicio.
- Inicio → "Ver todo" → Historial; tap en un pago → Detalle del pago.
- Historial → tap en un pago → Detalle del pago.
- Ajustes → filas → Perfil / Avisos / Ayuda / Acerca / Configuración / Almacenamiento; "Cerrar sesión" → vuelve a Vinculación.
- Avisos → cada tarjeta salta a donde se arregla (Configuración / Historial / Uptime / Ayuda).
- Todas las subpantallas → flecha atrás → vuelve a la anterior.

### Barra inferior (dueño): Inicio · Historial · Ajustes. Solo visible en esas 3 pantallas raíz.

### Navegación del cajero:
- Misma lógica de arranque (Intro → Vinculación → Setup → Splash → app).
- Barra inferior de 2 pestañas: **En vivo · Ajustes**.
- Salidas de sesión: **401 del servidor** (token revocado por el dueño) → vuelve a Vinculación con aviso "Este celular fue desvinculado"; **"Cerrar mi turno"** voluntario → revoca en servidor y vuelve a Vinculación.

### Efectos de sesión (ambas apps):
- Con la app en primer plano, cada ~20 s se re-consulta la identidad al servidor; un **401** cierra sesión y vuelve a Vinculación.
- Al volver a primer plano (onResume) se refresca el feed/identidad y se arranca el servicio de captura/escucha.

---

## 4. Funcionalidades / features en detalle

### F1. Captura de pagos (solo dueño)
- **Input**: notificaciones del sistema de Yape (package `com.bcp.innovacxion.yapeapp`) y Plin (package `pe.com.interbank.mobilebanking` — Interbank). El servicio recibe TODAS las notificaciones del teléfono y filtra por package.
- **Proceso**: descarta la notificación-resumen de grupo; toma título + cuerpo como "texto crudo"; guarda un registro **antes** de intentar enviarlo. No interpreta el contenido (eso lo hace el backend).
- **Output**: un `EventoPago` en la base local con estado `EN_COLA`, con nombre/monto/código en NULL (los rellena el backend después). Dispara el envío inmediato.
- **iOS**: sin equivalente (ver nota crítica).

### F2. Cola de envío y reintentos (dueño)
- Entrega los pagos pendientes al backend **de uno en uno** (para saber cuál falla). Requiere red.
- Reintentos con espera creciente (backoff exponencial) ante fallos temporales. Si el token fue revocado → borra credencial y pide re-vincular. Si el comercio está inactivo → no reintenta y avisa. Si el servidor rechaza un pago concreto → lo marca "con error" y sigue con los demás.
- **Sincronización instantánea**: al recuperar internet, si el toggle está activo, vacía la cola en el acto (sin esperar la ventana periódica).

### F3. Sincronización / espejo (dueño)
- **Bajada**: pide al backend los pagos del comercio y los guarda localmente, para que la base sea un espejo completo (historial disponible sin internet, sobrevive a reinstalar).
- **Fusión**: cuando un pago que el celular capturó (solo crudo) vuelve parseado del servidor, se "pega" el nombre/monto/código/estado encima de la fila local.
- **Reconciliación**: si el dueño borra pagos desde el panel web, la app los quita también del celular (con salvaguardas para no borrar pagos que aún no llegaron al servidor).

### F4. Caja del día (dueño)
- **Input**: los pagos de hoy en la base local.
- **Cálculo**: suma de montos de hoy (excluyendo descartados), nº de pagos, y variación % vs ayer.
- **Output**: la tarjeta "Cobrado hoy" en Inicio. (Ver sección 6 para reglas.)

### F5. Historial con filtros y exportación (dueño)
- **Input**: texto de búsqueda, filtro de estado, filtro de fecha.
- **Proceso**: consulta paginada (tandas de 50) sobre la base local; agrupa por día; calcula resumen (cuántos, total, enviados).
- **Output**: lista agrupada + resumen + CSV exportable (share sheet).

### F6. Almacenamiento y retención (dueño)
- **Input**: switch de borrado automático + días a conservar (1–90).
- **Proceso**: en segundo plano borra los pagos **ya enviados** más viejos que N días. Nunca borra los que no se han enviado.
- **Output**: espacio liberado + vista previa de cuántos se borrarían.

### F7. Avisos / vigilancia (dueño)
- **Proceso**: un watchdog periódico (cada ~15 min) mide si la captura está viva, manda un "latido" al servidor, y genera avisos si algo va mal. Cura antes de avisar (intenta reconectar el listener).
- **Output**: bandeja de avisos + notificación permanente que refleja el estado real + alertas push cuando la captura cae.

### F8. Visor en vivo + voz (cajero)
- **Input**: sondeo al backend cada 5 s + push (FCM) con la app cerrada.
- **Proceso**: muestra los cobros de la jornada; anuncia en voz alta los nuevos; deduplica para no repetir avisos.
- **Output**: lista en vivo + voz + notificación por cada cobro.

### F9. Verificar / descartar cobros (cajero)
- **Input**: long-press sobre un pago (descartar) o búsqueda por monto/código (verificar).
- **Proceso**: marca el pago como "descartado" o "verificado" en el servidor (operación idempotente, por id).
- **Output**: el pago deja de sumar a la caja (descartado) pero se conserva en el historial.

### F10. Vinculación por QR/código (ambas)
- **Input**: código `PYK-XXXXXX` (escrito, escaneado con cámara, o decodificado de una imagen de galería).
- **Proceso**: se canjea en el backend por un token de dispositivo. El rol lo decide el servidor según qué endpoint acepta el código.
- **Output**: sesión guardada + entrada a la app.

---

## 5. Modelos de datos

### Entidad principal: EventoPago (un cobro capturado) — tabla local `eventos_pago`
| Campo | Tipo | Significado |
|---|---|---|
| id | entero (PK) | Id local autogenerado |
| packageOrigen | texto | App que originó la notificación (ej. Yape) |
| billetera | texto (default "Yape") | "Yape" o "Plin". Se guarda, no se deriva |
| textoCrudo | texto | Texto íntegro de la notificación, sin interpretar (dato sagrado) |
| nombrePagador | texto? | Nombre de quien pagó (nulo hasta que el servidor lo rellena) |
| montoCentimos | entero? | Monto en **céntimos** (nunca decimal). Nulo = aún sin parsear / no reconocido |
| capturadoEn | entero (epoch ms) | Momento de captura |
| codigoSeguridad | texto? | "Cód. de seguridad" de Yape (id de transacción aproximado) |
| hashNotificacion | texto (ÚNICO) | Clave de deduplicación |
| estado | texto | EN_COLA / ENVIADO / FALLIDO / DESCARTADO |
| intentos | entero | Nº de intentos de envío |
| ultimoError | texto? | Último error de envío (diagnóstico) |

**Estados de un cobro:**
- **EN_COLA**: capturado, esperando su primer envío.
- **ENVIADO**: el servidor ya lo recibió.
- **FALLIDO**: no subió aún por falta de red. Es dinero real: **cuenta en la caja** y **se reintenta**.
- **DESCARTADO**: el servidor lo dio por inválido, o el cajero lo marcó como no-venta. **NO cuenta en la caja** y **NO se reintenta**.

**Regla transversal**: todas las sumas/conteos de caja excluyen DESCARTADO; la cola de envío solo toma EN_COLA y FALLIDO.

### Modelos de UI/dominio
- **PagoRecibido**: proyección del EventoPago para la UI (id, nombre, montoCentimos, textoCrudo, código, recibidoEn, estado, billetera, packageOrigen, intentos, ultimoError). Derivado: `seEntendio = monto != null`.
- **Sesion**: token, rol (SENSOR/EMPLEADO), comercio, dispositivo (nombre del celular), urlApi, comercioId, sucursalId? (nulo = ve todo el comercio), sucursalNombre, estado (PENDIENTE/ACTIVO). Derivado: `veTodoElComercio = sucursalId == null`.
- **ResumenHoy**: totalCentimos, cuantos, variacionVsAyer? (nulo si ayer fue 0).
- **ResumenFiltro**: cuantos, totalCentimos, enviados; derivado enCola = cuantos − enviados.
- **UsoAlmacenamiento**: totalPagos, bytes, masAntiguo?, pendientes.
- **Aviso**: id, gravedad (CRITICO/ATENCION/INFO), título, detalle, acción?, ruta?.
- **EstadoFuente** (cajero): minutosSinSenal?, fuente?, comercioInactivo?.
- **Filtros**: FiltroEstado (TODOS/ENVIADO/EN_COLA/FALLIDO/NO_LEIDO — "no leído" = enviado pero sin monto), FiltroFecha (HOY/SIETE_DIAS/MES/TODO/RANGO), FiltroHistorial (texto, fecha, estado, desde?, hasta?).

### Relaciones
Modelo **muy plano**: una sola tabla local (`eventos_pago`), sin claves foráneas. La relación conceptual es entre el cobro **local** (lo que este celular capturó) y el cobro **remoto** (lo que el servidor sabe, ya parseado); se enlazan **por el hash de deduplicación**. El backend organiza jerárquicamente: comercio → sucursal → dispositivo/empleado, pero el celular solo conoce su propio ámbito vía el token.

### Deduplicación
`hash = SHA-256("packageOrigen|minuto|textoCrudo")` (el timestamp reducido a minuto). Índice único → insertar un duplicado es un no-op. Se prefiere un duplicado raro y visible a perder un cobro en silencio.

---

## 6. Lógica de negocio (validaciones, cálculos, reglas)

### Dinero en céntimos
El monto es SIEMPRE un entero de céntimos, nunca decimal (en coma flotante 0.1 + 0.2 ≠ 0.3, y esto es dinero). La conversión soles↔céntimos usa **redondeo**, no truncado (19.99 puede llegar como 19.9899… y truncar robaría un céntimo).

### Búsqueda por monto (lo que el usuario teclea)
Al escribir "25" en el historial se busca el pago de S/ 25.00 (exacto en céntimos), no un LIKE numérico. El separador final es decimal solo si lo siguen 1–2 cifras; con 3 es de millares ("1.250" = 1250 soles), independiente del locale del celular.

### Caja del día
- Se suma en la base de datos (no en memoria sobre la lista pintada, que va limitada).
- Excluye DESCARTADO.
- Ventanas: hoy = [medianoche de hoy, medianoche de mañana); ayer = [medianoche de ayer, medianoche de hoy).
- Variación vs ayer = (totalHoy − totalAyer) / totalAyer. Si ayer fue 0 → nulo (no se divide entre cero; se oculta la comparación).
- **Medianoche siempre en hora de Perú (America/Lima)**, no la del celular (los celulares importados llegan con la zona mal puesta; con la del sistema el corte del día caería mal y la caja no cuadraría).

### Estado "No leído"
Un pago cuenta como "no leído" solo si tiene monto nulo **y** ya fue ENVIADO (el servidor lo recibió pero no supo leer el monto → señal de que Yape cambió el formato). Un pago recién capturado sin monto y sin subir está "procesando", no "no leído".

### Retención automática
- Arranca apagada (no se borra el historial del dueño sin que él lo prenda).
- Días: mínimo 1, máximo 90, default 30.
- Solo borra pagos **ENVIADOS** más viejos que N días. Los EN_COLA/FALLIDO nunca se borran (es dinero que aún no subió).

### Formato de soles y fechas
- Soles: "S/ 1,250.00" con locale fijo (EE.UU. para el formato numérico + prefijo "S/").
- Fechas y horas: locale es-PE, zona America/Lima forzada.

### Nombres visibles
Se limpia un posible prefijo de billetera pegado al nombre (p. ej. "Yape Lucía Fernández" → "Lucía Fernández"). Los nombres llegan parcialmente enmascarados desde Yape ("William Pla\*").

### Estados remotos del cobro (óptica del cajero)
- **LIBRE**: llegó, nadie lo usó.
- **CONSUMIDO / VERIFICADO**: confirmó una venta (antifraude: no se reusa). El cajero lo ve como "VERIFICADO".
- **DESCARTADO**: marcado a mano como no-venta.
Desde 08/2026, los cobros **nacen verificados** (si el sensor lo recibió, entró de verdad); el cajero solo descarta lo que no fue venta o lo deshace. La acción es **idempotente** y va por id (no por monto, para no confundir dos cobros del mismo importe).

### Umbral de "fuente caída" (cajero)
Variable según la hora de Lima: ~45 min en horario de tienda, ~120 min de madrugada (para absorber el modo de ahorro de batería). "Nunca reportó" es un caso distinto de "lleva mucho callado".

---

## 7. Integraciones externas (APIs, backend, bases de datos)

### Backend: Node + Fastify + Prisma (REST)
- URL configurable; en desarrollo `http://10.0.2.2:1337` (localhost del PC desde el emulador Android). En producción, un dominio real.
- (Histórico: hubo un andamiaje anterior contra Supabase, ya retirado. No reconstruir Supabase.)

### Autenticación
- **Token de dispositivo opaco**, en cabecera `Authorization: Bearer <token>`. El servidor lo hashea y de él deriva el comercio y la sucursal. **La app nunca manda esos ids** → un celular no puede pedir datos de otro comercio.
- No hay usuario/contraseña en el celular (eso es del panel web, otra identidad que las rutas del celular rechazan).
- El token se obtiene canjeando el código de vinculación y es **revocable** desde el panel.

### Endpoints (según rol)
**Dueño / sensor:**
- `POST /device/vincular` — canjea código por token.
- `DELETE /device/vincular` — cierra sesión (revoca token).
- `POST /device/ingest` — sube el **texto crudo** de un pago (no el parseado). Los desenlaces "nuevo / duplicado / ignorado / sin parsear" son todos éxito para la cola local.
- `POST /device/heartbeat` — latido (con batería y estado del permiso de notificaciones).
- `GET /device/me` — identidad del dispositivo (comercio, sucursal, estado).
- `GET /device/pagos?desde=<ms>&limit=200` — bajada del espejo (sincronización).

**Cajero / espejo:**
- `POST /espejo/vincular` / `DELETE /espejo/vincular` — vincular / cerrar sesión (además baja el push).
- `GET /espejo/pagos?limit=&cursor=` — feed de cobros (jornada actual sin cursor; días pasados con cursor).
- `GET /espejo/me` — identidad del cajero.
- `POST /espejo/heartbeat` — latido (sin batería).
- `POST /espejo/push-token` / `DELETE /espejo/push-token` — registra/baja el token de push.
- `PATCH /espejo/pagos/:id/estado` — marca "verificado" o "descartado" (idempotente).

**Errores clave** (reacciones opuestas):
- Temporal (sin red, timeout, 5xx, rate-limit) → reintentar con espera creciente.
- 401/403 (token revocado) → parar, borrar credencial, re-vincular.
- 402 (comercio inactivo) → avisar al dueño, no reintentar.
- Otros 4xx → reintentar no cambia nada.

### Contrato de datos
- JSON. Al codificar, **omitir las claves nulas** (el backend valida con esquemas donde "opcional" = clave ausente, no `null`).
- Frontera de unidades: el servidor habla **soles decimales** e **ISO-8601 UTC**; dentro de la app todo es **céntimos enteros** y **epoch ms**. Convertir en la frontera (fecha ilegible → nulo, no 0; monto → redondeo).

### Firebase Cloud Messaging (solo cajero)
- Push "nuevo Yape" con la app cerrada. **Por token de dispositivo**, no por topics: cada cajero registra su token FCM en el backend y el servidor le envía el push directo. (En iOS: APNs con token por dispositivo.)

### Base de datos local
- SQLite (vía Room en Android) con una sola tabla de cobros, **solo en la app del dueño**. El cajero no tiene base local: todo lo lee del backend.

### ntfy.sh (legado, cajero)
- Un servicio de "golpecitos" HTTP en streaming, hoy secundario frente a FCM. En iOS probablemente se omite y se usa solo APNs.

---

## 8. Librerías de terceros usadas (y su equivalente/propósito en iOS)

| Librería (Android) | Para qué sirve | Equivalente iOS sugerido |
|---|---|---|
| Jetpack Compose + Material3 | Toda la UI declarativa | SwiftUI |
| Navigation Compose | Navegación entre pantallas | NavigationStack / router propio |
| Room (SQLite) | Base local de cobros (solo dueño) | GRDB o Core Data / SwiftData |
| WorkManager | Trabajos en segundo plano (envío, vigilancia) | BGTaskScheduler + envío al recuperar red |
| OkHttp | Cliente HTTP REST (real) y streaming | URLSession |
| kotlinx.serialization | JSON | Codable |
| ZXing (zxing-android-embedded) | Escanear y generar el QR de vinculación | AVFoundation (escanear) + CoreImage (generar) |
| Firebase Messaging | Push de "nuevo Yape" (cajero) | APNs / Firebase iOS |
| TextToSpeech (API del SO) | Voz "Yape recibido de María por 28 soles" (cajero) | AVSpeechSynthesizer |
| SharedPreferences / DataStore | Preferencias locales | UserDefaults |
| EncryptedSharedPreferences | (legado; se migró a almacenamiento normal) | Keychain (ver nota en sección 9) |
| Coroutines / Flow | Concurrencia y datos reactivos | async/await + AsyncStream / Combine |
| NotificationListenerService (API del SO) | **Captura de notificaciones** | **Sin equivalente en iOS** |
| Fuentes Space Grotesk + Inter (empaquetadas) | Tipografía | Fuentes embebidas |
| Iconos Lucide (generados como vectores) | Iconografía | SF Symbols o los SVG de Lucide |

(No usa Retrofit efectivamente —hace HTTP manual—, ni Coil/Glide, ni inyección de dependencias con framework: la composición de objetos es manual.)

---

## 9. Manejo de estado (local vs remoto)

### Se guarda LOCALMENTE (en el celular)
- **Cobros** (solo dueño): la tabla `eventos_pago` es a la vez buzón de salida (cola de envío) y espejo de trabajo (historial completo). Se conserva indefinidamente hasta que el dueño borre o la retención automática limpie los enviados viejos. Sobrevive a reinicios y cierres.
- **Credenciales / sesión**: token, rol, comercio, dispositivo, sucursal, URL de la API. **Decisión de producto importante**: en Android se guardó **sin cifrar** a propósito, porque el almacén cifrado (Keystore) se invalidaba tras un force-stop en ciertos móviles y dejaba la sesión ilegible para siempre. La regla resultante es: **la sesión solo se cierra cuando el usuario toca "cerrar sesión" o cuando el servidor responde 401/403; nunca sola.** En iOS el Keychain es más fiable, pero conviene mantener esa política (no cerrar sesión sola ante fallos de almacenamiento). Borrar la credencial **no** borra los cobros.
- **Preferencias**: sincronización instantánea (on por defecto), voz/sonido del cajero (on por defecto), borrado automático (off por defecto) + días, flags de onboarding (intro vista, setup visto), estado del listener, dedup de yapes vistos por el cajero. Estas preferencias **no viajan al servidor** (son de ese celular).

### Se sincroniza REMOTAMENTE
- El **texto crudo** de cada cobro sube al servidor (que lo parsea).
- El servidor es la **fuente de verdad** del comercio entero; el dueño baja ese espejo (nombre, monto, código, estado ya resueltos).
- El **estado** de cada cobro (verificado/descartado) lo escribe el cajero contra el servidor.
- El cajero **no guarda nada localmente**: cada 5 s (+ push) lee el feed del backend.

### Datos reactivos
La UI observa la base local (Flows en Android → en iOS: `@Published` / `AsyncStream` sobre GRDB/Core Data, o un store observable). El cajero mantiene su estado en memoria alimentado por el sondeo + push.

---

## 10. Permisos del dispositivo

### App del dueño (sensor)
- **Acceso a notificaciones** (`BIND_NOTIFICATION_LISTENER_SERVICE`) — el ÚNICO imprescindible; sin él la app no tiene nada que leer. Se concede en ajustes del sistema.
- **Notificaciones (POST_NOTIFICATIONS)** — para la notificación permanente y las alertas.
- **Servicio en primer plano** (tipo "uso especial") — para mantener la captura viva todo el día.
- **Ignorar optimización de batería** — para sobrevivir al modo de ahorro / ROMs agresivas.
- **Arranque al reiniciar** (BOOT_COMPLETED) — rearmar el servicio tras reinicio.
- **Cámara** — solo para escanear el QR de vinculación.
- **Internet / estado de red**.
- **Inicio automático por fabricante** — no es un permiso estándar (no hay API para consultarlo); se guía al usuario a la pantalla propietaria de su marca (Xiaomi/Huawei/Oppo/etc.).

### App del cajero
- **Notificaciones (POST_NOTIFICATIONS)**, **servicio en primer plano**, **ignorar optimización de batería**, **cámara** (QR), **internet**. **No** pide acceso a notificaciones (no lee las de nadie: las recibe del servidor).

### En iOS los permisos relevantes serían
- Notificaciones (para push y alertas locales).
- Cámara (escaneo de QR).
- Background App Refresh (equivalente parcial al trabajo en segundo plano).
- (El acceso a notificaciones de otras apps **no existe** en iOS.)

---

## 11. Elementos de diseño (colores, tipografía, estilo, iconos)

### Identidad de color
Marca **morada/violeta**. Los colores se nombran por **función**, no por tono. Neutros cálidos (no blanco/negro puros). Estilo con **bordes de 1px** para separar tarjetas (no sombras). Cifras tabulares en toda la app (los montos no "bailan" en las listas).

**Colores de marca / estructura (fijos):**
- Marca (primario): `#6C42E6` — botones, elementos activos, foco (modo claro).
- MarcaClara (primario en oscuro): `#8A68EF`.
- Humo (fondo claro): `#F6FAF8`. Niebla (superficie tenue): `#EFF1F0`. Borde: `#ECE8E1`.
- Tinta (texto principal): `#1A1714` (marrón muy oscuro, no negro).

**Colores semánticos (se adaptan a claro/oscuro):**
- MarcaOscura (texto sobre chip morado): `#45259C` / oscuro `#D6C8FC`.
- MarcaTenue (fondo suave de chips/filas/avatar del negocio): `#EFE9FE` / oscuro `#241A3D`.
- TintaSuave (texto secundario): `#6B655D` / oscuro `#7FA294`.
- Éxito: `#1E9E6A` / `#34D399`; fondo `#E3F5EC` / `#102A20`.
- Alerta (ámbar): `#E08600` / `#FBBF24`; fondo `#FFF3DE` / `#2E2410`.
- Error (rojo): `#DC2626` / `#F08A8A`; fondo `#FBE9E9` / `#2C1616`.

**Superficies en modo oscuro:** fondo `#17181A`, superficie `#1F2123`, capa flotante (menús/diálogos) `#26282B` — la flotante es **más clara** que la superficie (en oscuro la separación se hace con luminosidad, no con sombra). El verde ya **no** significa "capturando"; el estado se comunica con un punto + texto en una píldora.

### Tipografía
Dos familias variables, empaquetadas (funcionan sin internet):
- **Space Grotesk** → lo que se MIRA: títulos, cifras, montos, botones (Medium/SemiBold/Bold).
- **Inter** → lo que se LEE: cuerpo y etiquetas (Normal/Medium/SemiBold).
- Cifras tabulares activadas globalmente.

### Formas y radios
Redondeado generoso: controles/campos/chips 12pt, tarjetas 20pt, hojas modales 20pt, píldoras totalmente redondeadas.

### Avatares
Con iniciales (máx. 2 palabras). El avatar del **negocio** va en morado de marca. El avatar del **pagador** usa un color determinista por el hash del nombre (6 tonos suaves: azul, morado, naranja, verde, rosa, cian) — el mismo pagador cae siempre en el mismo color.

### Iconografía
Set de iconos **Lucide** (contorno, trazo 2, esquinas redondeadas), tintados con el color de contenido actual. En iOS, equivalen a SF Symbols o a los mismos SVG de Lucide. Iconos usados: Home, Search, Settings, Bell, Close, Check, CloudUpload/CloudDone, HourglassEmpty, ErrorOutline, Refresh, Shield, Storage, Storefront, Campaign, Sensors, Visibility, QrCodeScanner, Download, FilterList, History, Bolt, TrendingUp/Down, Logout, entre otros (~70).

### Estilo general
Limpio, redondeado, con tarjetas separadas por borde fino, mucho contraste en montos (Space Grotesk grande), y color reservado para el significado (verde = plata confirmada; ámbar = revisar; rojo = error). Textos en español peruano, cercanos y explicativos.

---

## 12. Casos especiales / edge cases importantes

- **Cero pérdida de cobros**: el texto crudo se guarda en disco **antes** de intentar enviarlo; la cola sobrevive a falta de red, cierres y reinicios. Nombre/monto pueden ir nulos para no perder un cobro por no encajar en un patrón.
- **Notificación ilegible**: se guarda igual con su texto crudo; aparece como "No leído" solo tras ser enviada sin monto; el servidor puede re-interpretarla luego.
- **Listener desconectado / reintento de enlace**: el sistema desconecta la escucha al actualizar la app o por presión de memoria; hay que pedir re-enlace y reprocesar las notificaciones activas al reconectar (Android no las reentrega solo).
- **ROMs agresivas** (Xiaomi/Huawei/etc.) matan el proceso de golpe: el estado "captura viva" se decide cruzando tres señales (permiso + bandera de conexión + servicio realmente corriendo); ninguna basta sola. Un vigilante intenta reconectar antes de avisar.
- **Permiso de inicio automático por fabricante**: no consultable; se guía al usuario a la pantalla de su marca y se confía en lo que dice.
- **Token revocado desde el panel → re-vincular**: un 401/403 no se reintenta; se borra la credencial y se pide vincular otra vez. Cerrar sesión revoca el token en el servidor (no basta borrar local).
- **Comercio inactivo/suspendido**: el servidor rechaza envíos; se genera un aviso crítico y los cobros se siguen guardando para subirlos al regularizar.
- **Cruce de medianoche con la app abierta**: la caja del día sigue contando contra el día anterior hasta que se vuelva a entrar (caso menor y asumido).
- **Reloj del celular en el futuro / datos corruptos**: el cursor de sincronización se acota a "ahora" para que un cobro con fecha futura no deje fuera a los cobros reales recientes.
- **Sincronización con solapamiento**: se re-piden las últimas 48 h para rescatar cobros que suben tarde; re-bajar lo ya visto es gratis (deduplicación).
- **Reconciliación segura**: borrar del celular lo que se borró en el panel solo ocurre tras una bajada exitosa, sin topar el límite de página, y solo sobre cobros ya enviados dentro de la ventana.
- **Duplicado en la frontera del minuto**: dos entregas de la misma notificación en el cambio de minuto podrían duplicarse; se prefiere ese duplicado raro y visible a perder un cobro en silencio.
- **DESCARTADO ≠ FALLIDO**: descartado no cuenta en caja ni se reintenta; fallido sí (dinero real esperando red).
- **"SIN SEÑAL" en el cajero**: se distingue "hoy no pagó nadie" de "el celular que captura está caído" para no acusar a un cliente honesto.
- **Deduplicación de avisos en el cajero**: entre el sondeo, el push y el servicio de escucha, se lleva una lista de los últimos ~200 cobros vistos para no cantar el mismo dos veces.
- **La app no avisa de pagos, avisa de problemas**: el dueño ya recibe la notificación de Yape; duplicarla sería ruido. Los avisos son solo para cuando algo va mal.

---

## Resumen de arquitectura para el port

- **Dos apps** sobre un backend común: **Sensor** (captura, tiene base local y cola) y **Espejo/Cajero** (visor en vivo, sin base local).
- **El cliente es "tonto"**: captura y reenvía texto crudo; **el backend parsea** (así un cambio de formato de Yape se arregla en el servidor sin publicar app).
- **Fuente de verdad**: el backend. El celular del dueño mantiene un espejo local para funcionar sin internet.
- **Autenticación por token de dispositivo** revocable; rol decidido por el servidor; vinculación por QR/código, sin contraseñas.
- **El mayor reto del port a iOS es la captura de notificaciones**, que no existe en iOS y debe resolverse por otra vía. El resto es directamente reconstruible en SwiftUI.
