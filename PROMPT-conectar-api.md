# Prompt para conectar Payku iOS al backend real

Copia todo lo de abajo (desde "CONTEXTO") y pégalo en Rork / Cursor / Claude.

---

## CONTEXTO

Este es el proyecto **Payku** en Swift/SwiftUI (iOS 18, Xcode 16). Hoy funciona solo con
**datos de muestra** en `PaykuStore` (ver `PaykuStore.samplePayments()`), la vinculación es
falsa (`link(code:role:)` no llama a ningún servidor) y no hay persistencia de sesión ni
sondeo en vivo. Quiero convertirlo en una app **conectada a un backend REST real**, sin
romper el diseño ni las pantallas que ya existen.

Es un sistema de **dos roles** en la misma app:
- **Dueño (owner)**: ve la caja del día, el historial y los avisos de su negocio.
- **Cajero (cashier)**: ve en vivo los cobros que entran y puede verificarlos/descartarlos.

> IMPORTANTE (limitación de Apple): iOS **no puede leer notificaciones de otras apps**, así
> que la app NO captura los Yape/Plin por sí misma (eso lo hace un sensor externo Android).
> En iOS **todo se lee del backend**: el dueño baja su espejo de pagos, el cajero sondea el
> feed. NO implementes captura de notificaciones.

## OBJETIVO

1. Crear una **capa de red** (`PaykuAPI`) con un protocolo + una implementación real (URLSession)
   + un "fake" para las previews.
2. Cablear `PaykuStore` a esa capa: reemplazar los datos de muestra por llamadas reales.
3. Persistir la **sesión/token** en **Keychain** (no en memoria).
4. Implementar los flujos reales: vinculación por código, carga de datos del dueño,
   feed en vivo del cajero con sondeo, verificar/descartar, cerrar sesión.
5. Manejar errores y estados (offline, token revocado, comercio inactivo).

Mantén el estilo del código actual (`@Observable`, `@MainActor`, async/await, SwiftUI).

---

## CONTRATO DEL BACKEND (respétalo al pie de la letra)

**Base URL:** configúrala en un solo lugar (`AppConfig.baseURL`). Usa un placeholder
`https://TU-BACKEND` y déjalo fácil de cambiar. (Si es http en desarrollo, añade la excepción
de ATS en Info.plist con `NSAllowsArbitraryLoads` solo para debug.)

**Autenticación:** token de dispositivo opaco en la cabecera `Authorization: Bearer <token>`.
El servidor deduce el comercio y la sucursal del token; **la app nunca manda esos ids**.
No hay usuario/contraseña en la app. El token se obtiene al vincular y es revocable.

**Formato JSON:**
- Al codificar, **omite las claves nulas** (el backend valida con esquemas donde "opcional"
  = clave ausente, no `null`). En el `JSONEncoder`, no emitas `null`.
- Ignora claves desconocidas al decodificar.
- Peticiones GET/DELETE y POST sin cuerpo: **no pongas `Content-Type: application/json`**
  (un body vacío con ese header da error 400 en el backend).

**Unidades (frontera de conversión):** dentro de la app el dinero es **céntimos enteros (Int)**
y el tiempo es **Date**. El servidor habla **soles decimales (Double)** e **ISO-8601 UTC**.
Convierte SOLO en la capa de red:
- `soles -> céntimos`: `Int((soles * 100).rounded())` (redondeo, no truncar).
- `iso -> Date`: si no se puede parsear, devuelve `nil` (NO uses fecha 0/1970).
- La caja del día corta a **medianoche hora de Perú (America/Lima)**, no la del dispositivo.

### Endpoints del DUEÑO (owner)

- `POST /device/vincular` — canjea el código `PYK-XXXXXX` por un token.
  Body: `{ codigo, modeloCelular?, versionApp? }`.
  Respuesta: `{ token, dispositivo: { id, nombre, comercioId, comercioNombre, sucursalId?, sucursalNombre?, estado } }`.
  (SIN Authorization; este endpoint es el que da el token.)
- `DELETE /device/vincular` — cierra sesión / revoca el token. (Con Authorization.)
- `GET /device/me` — identidad del dispositivo (para refrescar nombre/sucursal):
  `{ id, nombre, comercioId, comercioNombre, sucursalId?, sucursalNombre?, estado }`.
- `GET /device/pagos?desde=<epochMs>&limit=200` — **espejo de pagos** del comercio (lo que el
  dueño ve como caja/historial). Devuelve una lista de:
  `{ id, monto: Double?, nombrePagador?, referencia?, billetera: "yape"|"plin",
     estado: "libre"|"verificado"|"consumido"|"descartado", sinParsear: Bool,
     rawText, packageOrigen?, hashDedup, fechaHoraCaptura?(ISO), creadoEn?(ISO) }`.
- `POST /device/heartbeat` — latido opcional del dueño: `{ bateria?, permisoNotificaciones? }`.

### Endpoints del CAJERO (cashier)

- `POST /espejo/vincular` — canjea el código por token (igual que el del dueño pero para cajero).
  Respuesta: `{ token, empleado: { id, nombre, comercioId, comercioNombre, sucursalId?, sucursalNombre? } }`.
- `DELETE /espejo/vincular` — cierra sesión / revoca token.
- `GET /espejo/me` — identidad del cajero.
- `GET /espejo/pagos?limit=100&cursor=<id?>` — feed del espejo. Sin `cursor`: la jornada actual
  (corta a las 5am hora Perú). Con `cursor`: los anteriores a ese id (scroll a días pasados).
  Respuesta: `{ pagos: [ ...igual que device/pagos... ], hayMas: Bool, siguienteCursor: String? }`.
- `PATCH /espejo/pagos/:id/estado` — **única escritura del cajero**. Body: `{ estado: "verificado" | "descartado" }`.
  Es **idempotente** (mismo estado dos veces = 200). Va por id, no por monto. Devuelve el pago actualizado.
- `POST /espejo/heartbeat` — latido del cajero: `{}`.
- `POST /espejo/push-token` — registra el token de push: `{ fcmToken }` (o el token APNs).
- `DELETE /espejo/push-token` — baja el push al cerrar sesión.

### Errores (reacciones OPUESTAS — impleméntalas)

Mapea el status HTTP a un enum `PaykuError`:
- **temporal** (sin red, timeout, 429, 5xx) → reintentar con espera creciente (backoff). No es fallo del usuario.
- **noAutorizado** (401/403) → el token fue revocado: **borra la credencial y vuelve a la pantalla de vinculación** con el aviso "Este dispositivo fue desvinculado". NO reintentar.
- **comercioInactivo** (402) → muestra un banner "Comercio inactivo" y no reintentes; el dueño lo regulariza.
- **rechazado** (otros 4xx) → error concreto; no reintentar.

---

## QUÉ CONSTRUIR (paso a paso)

1. **`AppConfig`**: `baseURL` y un flag `useFakeBackend` (para previews/demos).

2. **`KeychainStore`**: guardar/leer/borrar la `Session` (token, rol, comercio, dispositivo,
   sucursal) en Keychain. Regla de producto: **la sesión SOLO se cierra cuando el usuario
   toca "Cerrar sesión" o cuando el servidor responde 401/403**; nunca sola.

3. **`PaykuAPI` (protocolo)** con métodos async: `linkOwner(code:)`, `linkCashier(code:)`,
   `logout()`, `me()`, `ownerPayments(since:)`, `cashierFeed(cursor:)`, `setPaymentState(id:state:)`,
   `heartbeat()`, `registerPush(token:)`. Devuelven modelos de dominio (no DTOs).
   - `LivePaykuAPI`: implementación con URLSession, cabecera Bearer, (de)serialización, mapeo de
     errores y de unidades (soles↔céntimos, ISO↔Date).
   - `FakePaykuAPI`: devuelve los datos de muestra actuales (para previews y modo demo).

4. **Cablear `PaykuStore`**: quitar `samplePayments()` del arranque (déjalo solo para el fake).
   - Al arrancar: leer la sesión del Keychain → si existe, `isLinked = true`, cargar datos.
   - `link(code:role:)` real: llama `linkOwner`/`linkCashier`, guarda la sesión en Keychain.
   - `logout()`: llama `logout()` en el server (con tope de 3s; si falla por red, borra local igual),
     borra Keychain, vuelve a vinculación.
   - **Dueño**: `refresh()` llama `ownerPayments(since:)` y actualiza `payments`. Sincronización
     incremental (guarda el más reciente, pide con un solape de ~48h). Refresca al abrir la app
     y con pull-to-refresh.
   - **Cajero**: sondeo cada **5 segundos** a `cashierFeed()` mientras la vista está visible;
     paginación por cursor al hacer scroll; comprobación de "fuente viva" (si el sensor no
     reporta, muestra "SIN SEÑAL"). Al descartar/verificar, llama `setPaymentState` y refresca.

5. **Vinculación real** (`LinkingView`): que el botón "Entrar" canjee el código de verdad
   (con spinner y manejo de error). El escaneo de QR puede quedar para después; por ahora al
   menos el código escrito debe funcionar contra el backend.

6. **Manejo de estados en la UI**: loading, vacío, error de red (con reintentar), banner de
   comercio inactivo, y el "SIN SEÑAL" del cajero.

## REGLAS DE NEGOCIO A RESPETAR

- Dinero SIEMPRE en céntimos (Int); formatear a "S/ 1,250.00" con separador fijo.
- Caja del día y "hoy": medianoche **America/Lima**.
- Excluir los **descartados** del total de caja.
- "No leído" = pago enviado por el servidor pero **sin monto** (formato no reconocido).
- Descartar es **reversible** y no borra el pago (solo deja de sumar).
- El rol lo decide el backend (qué endpoint acepta el código); no dejes que el usuario lo elija a mano.

## RESTRICCIONES

- No rompas las pantallas ni el diseño actuales; solo reemplaza la fuente de datos y agrega la capa de red.
- Mantén `@Observable` + async/await.
- No implementes captura de notificaciones (imposible en iOS).
- Deja `FakePaykuAPI` activable con un flag para poder seguir viendo la demo sin backend.

Cuando termines, dime qué archivos creaste/cambiaste y qué falta para producción (push/APNs,
escaneo real de QR, y la URL definitiva del backend).
