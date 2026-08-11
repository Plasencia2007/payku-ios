# Prompt maestro: Payku iOS como DOS apps (Dueño + Cajero), igual que Android

Pega todo lo de abajo (desde "CONTEXTO") en Rork / Cursor / Claude. Este prompt va DESPUÉS
(o junto) al de conexión con la API (`PROMPT-conectar-api.md`).

---

## CONTEXTO

Tengo el proyecto **Payku** en Swift/SwiftUI. Está construido como **una sola app** que cambia
entre `OwnerAppView` y `CashierAppView` según un rol que **el usuario elige con un Picker** en la
pantalla de vinculación. Eso está MAL. En la versión original de Android son **DOS apps
separadas** y el rol NO lo elige el usuario: lo decide el backend.

Quiero reestructurarlo para que sea **igual que Android: dos aplicaciones distintas**, cada una
con su rol fijo, compartiendo el máximo de código.

## DIAGNÓSTICO (arréglalo)

1. **Quita el selector de rol** (`Picker "Rol"` con `selectedRole` en `LinkingView`). El rol no
   se elige a mano.
2. Hoy es un solo target. Debe haber **dos apps**.
3. El rol debe venir del backend: cada app canjea el código SOLO en el endpoint de su rol y
   rechaza el código del otro rol.

## ARQUITECTURA OBJETIVO

Crea **dos targets** (dos apps, dos esquemas, dos bundle ids) en el MISMO proyecto Xcode,
compartiendo el código común. Es el equivalente iOS del "módulo núcleo + dos apps" de Android.

- **App 1 — "Payku Dueño"** — bundle id `com.tunegocio.payku.dueno`. Rol fijo `.owner`.
- **App 2 — "Payku Cajero"** — bundle id `com.tunegocio.payku.cajero`. Rol fijo `.cashier`.
- Define el rol **en tiempo de compilación** por target (p. ej. una constante `AppRole.current`
  inyectada por un flag de compilación `OWNER_APP` / `CASHIER_APP`, o un archivo de config por target).
  La app NUNCA muestra ni permite cambiar el rol.
- **Código compartido** entre ambas (en el/los targets comunes o con "Target Membership" en ambos):
  modelos (`PaykuModels`), tema y componentes (`PaykuTheme`), la capa de red (`PaykuAPI`),
  `KeychainStore`, y la lógica de `PaykuStore` que sea común.
- Cada app tiene su propio `@main` (`PaykuDuenoApp`, `PaykuCajeroApp`) y su router raíz, pero
  reutilizan las mismas vistas comunes (onboarding, vinculación, splash).
- La vinculación: la app Dueño canjea en `POST /device/vincular`; la app Cajero en
  `POST /espejo/vincular`. Si metes un código del otro rol, el backend responde 404 → muestra
  "Ese código no es para esta app".

> Si Rork no soporta dos targets fácilmente, hazlo como **dos proyectos Xcode** que comparten
> una carpeta de código común (`PaykuShared/`). Pero lo preferible es un proyecto con dos targets.

---

## APP DUEÑO (owner) — funcionalidades y pantallas

Es la app del dueño del negocio: ve su **caja del día**, el **historial** completo y los **avisos**.
(En Android además captura las notificaciones; en iOS eso NO existe, así que aquí el dueño solo
**consume** del backend lo que el sensor externo subió.)

**Arranque / onboarding** (una vez): Intro (carrusel explicando qué hace Payku) → Vinculación
(canjear código, SIN elegir rol) → Setup → Splash (saludo por hora) → app.

**Barra inferior: Inicio · Historial · Ajustes.**

1. **Inicio (caja del día)**:
   - Cabecera: nombre del comercio + sucursal + badge "DUEÑO".
   - Tarjeta "Cobrado hoy": total del día (en soles), nº de yapes, variación vs ayer (▲/▼ %).
   - Métricas: "Capturados" (pagos de hoy) y "En cola" (pendientes de subir).
   - Banner "N cobros sin enviar · reintentar" si hay pendientes.
   - Lista "Últimos yapes" con avatar, nombre, hora, monto e ícono de estado (enviado/en cola/error).
2. **Historial**: buscador (nombre o monto), chips de estado (Todos/Enviados/En cola/Con error/No leídos),
   filtro por fecha (Hoy/7 días/Mes/Todo/rango), lista agrupada por día con subtotal, exportar CSV.
3. **Detalle de un pago**: monto, "{nombre} te envió un pago", estado, billetera, fecha completa,
   código de seguridad (copiar), intentos, y el **texto crudo** original (copiar). Solo lectura.
4. **Ajustes**: permisos, avisos (con contador), toggle "Sincronización instantánea", perfil,
   almacenamiento, ayuda, acerca, cerrar sesión.
5. **Avisos**: bandeja de PROBLEMAS (no de pagos): captura caída, permiso faltante, "no leídos"
   (Yape cambió de formato), cola sin enviar, comercio inactivo. Cada uno con gravedad y acción.
6. **Almacenamiento**: tamaño en disco, borrado automático (retención 1–90 días, solo enviados),
   borrado manual (enviados / >90 días / todo).
7. **Perfil** (solo lectura), **Acerca**, **Ayuda** (FAQs + WhatsApp/correo), **Empleados**
   (dar de alta cajeros → genera código/QR; dar de baja; regenerar código).

**Estado de un pago (dueño):** EN_COLA (sin subir), ENVIADO (en el servidor), FALLIDO (no subió por
red; cuenta en caja y se reintenta), DESCARTADO (inválido; NO cuenta y NO se reintenta).

## APP CAJERO (cashier) — funcionalidades y pantallas

Es la app del empleado del mostrador. **No captura nada**: es un visor en vivo de los cobros que el
sensor detecta. Sirve para verificar cobros y evitar fraudes con capturas falsas.

**Arranque / onboarding**: igual (Intro con copy de cajero → Vinculación → Setup → Splash).

**Barra inferior: En vivo · Ajustes.**

1. **En vivo**:
   - Cabecera con badge "CAJERO" + hero "Cobrado hoy" (total + nº) + **píldora "EN VIVO" o "SIN SEÑAL"**
     (distingue "hoy no pagó nadie" de "el sensor está caído" — clave para no acusar a un cliente).
   - Aviso si la fuente está caída ("Sin señal desde hace X").
   - Lista de cobros en vivo: avatar, nombre (o "No se pudo leer"), hora + código de operación,
     monto, y badge de estado (**VERIFICADO** / **DESCARTADO** / **NUEVO** / **LIBRE**).
   - **Long-press sobre un cobro → descartar** (única acción; diálogo reversible "¿Descartar este cobro?").
   - **Lectura en voz alta** de cada cobro nuevo (text-to-speech con `AVSpeechSynthesizer`):
     "Yape recibido de María por 28 soles". Idioma es-PE.
   - Sondeo del feed cada 5 s + push (para avisar con la app cerrada).
2. **Ajustes (cajero)**: perfil del turno (solo lectura), toggles "Leer en voz alta" y "Sonido de
   alerta", botón "Probar cómo suena", permisos, cerrar turno.

**Estados del cobro (cajero):** LIBRE (llegó, nadie lo usó), VERIFICADO/CONSUMIDO (confirmó una venta),
DESCARTADO (marcado como no-venta). Desde el diseño actual, los cobros **nacen verificados**; el cajero
solo descarta lo que no fue venta (o lo deshace). La acción va por `PATCH /espejo/pagos/:id/estado`
(idempotente, por id).

---

## CÓDIGO COMPARTIDO (no lo dupliques)

- `PaykuModels` (Payment, Employee, AlertItem, enums).
- `PaykuTheme` + componentes (Avatar, tarjetas, píldoras, MetricTile, etc.).
- `PaykuAPI` (protocolo + Live + Fake) y `KeychainStore` (ver el prompt de la API).
- Vistas comunes: `IntroView`, `LinkingView` (sin picker), `SetupView`, `SplashView`, `PaymentRow`.
- La diferencia entre apps es solo: el `AppRole` fijo, el `@main`, qué endpoints de vinculación usa,
  y qué pantallas monta (OwnerAppView vs CashierAppView).

## ARREGLOS DE UI/UX (aplícalos)

1. **Quitar el Picker de rol** y el texto que cambia según `selectedRole`.
2. **Splash**: el saludo por hora debe usar la hora de **America/Lima**, no la del dispositivo.
3. **Montos**: formatéalos SIEMPRE "S/ 1,250.00" (separador de miles fijo), con cifras
   tabulares (`.monospacedDigit()`), para que no "bailen" en las listas.
4. **Modo oscuro**: revisa que todos los colores del tema tengan variante clara/oscura (hoy el
   tema parece fijo en claro). El fondo, superficies y textos deben adaptarse.
5. **Estados de carga y vacío** en Inicio, Historial y En vivo (spinner, "Aún no entra ningún
   yape", "No hay pagos en este periodo").
6. **Errores de red**: si una llamada falla, muestra un aviso con "Reintentar", no una pantalla en blanco.
7. **Banner "comercio inactivo"** (402) por encima del contenido, en ambas apps.
8. **Pull-to-refresh** en Inicio e Historial (dueño) y refresco al volver a primer plano.
9. **Accesibilidad**: labels en avatares, botones e íconos; respeta Dynamic Type.
10. **Cerrar sesión**: que revoque el token en el servidor y limpie el Keychain, no solo el estado en memoria.

## REGLAS DE NEGOCIO A RESPETAR

- Dinero en **céntimos Int** dentro de la app; medianoche **America/Lima** para la caja del día;
  excluir DESCARTADO del total; "No leído" = enviado sin monto; descartar es reversible y no borra.
- El rol lo fija el target (compilación) y lo confirma el backend; el usuario nunca lo elige.

## RESTRICCIONES

- No rompas el diseño ni las pantallas actuales; reutiliza los componentes que ya existen.
- Mantén `@Observable` + `@MainActor` + async/await.
- No implementes captura de notificaciones (imposible en iOS).
- Deja un `FakePaykuAPI` activable por flag para seguir viendo la demo sin backend.

Cuando termines, dime: qué targets/apps creaste, qué código quedó compartido, y qué falta para
producción (APNs/push, escaneo real de QR, y la URL definitiva del backend).
