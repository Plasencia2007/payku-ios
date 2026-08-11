# Payku — proyecto iOS nativo (SwiftUI)

Proyecto **generado en Rork** y extraído aquí archivo por archivo (el plan gratuito de Rork
es de solo lectura, así que se copió el contenido real de cada archivo). Es la reconstrucción
nativa en Swift/SwiftUI de la app Payku (originalmente Android/Kotlin).

## Cómo abrirlo

1. Copia esta carpeta a una **Mac** con **Xcode 16 o superior**.
2. Abre `Payku.xcodeproj`.
3. Selecciona el esquema **Payku**, elige un simulador de iPhone (iOS 18+) y pulsa Run.

No hace falta configurar nada más: el proyecto usa `GENERATE_INFOPLIST_FILE = YES` (no hay
`Info.plist` suelto) y **grupos sincronizados con el sistema de archivos**, así que Xcode
incluye automáticamente cualquier archivo que esté dentro de `Payku/`, `PaykuTests/` y
`PaykuUITests/`.

## Requisitos

- Xcode 16+ (formato de proyecto `objectVersion = 77`).
- Deployment target: **iOS 18.0**.
- Swift 5.

## Estructura

```
Payku-iOS/
├─ Payku.xcodeproj/project.pbxproj      ← proyecto Xcode (grupos sincronizados)
├─ Payku/
│  ├─ PaykuApp.swift                    ← @main + entorno
│  ├─ ContentView.swift                 ← router raíz + TODAS las vistas (~2.300 líneas)
│  ├─ PaykuModels.swift                 ← modelos (Payment, Employee, AlertItem, enums…)
│  ├─ PaykuStore.swift                  ← estado observable + datos de muestra
│  ├─ PaykuTheme.swift                  ← paleta, tarjetas, avatares, componentes
│  └─ Assets.xcassets/                  ← AppIcon + AccentColor (placeholders por defecto)
├─ PaykuTests/PaykuTests.swift
├─ PaykuUITests/PaykuUITests.swift + PaykuUITestsLaunchTests.swift
├─ rork.json                            ← config del generador Rork
└─ .gitignore
```

> **Nota:** Rork puso casi toda la UI (onboarding, vinculación, splash, dueño y cajero) dentro
> de `ContentView.swift`. Si el inge quiere, se puede partir en varios archivos; con los grupos
> sincronizados basta con mover el código a nuevos `.swift` dentro de `Payku/`.

## Antes de compilar / publicar

- **Bundle identifier**: está como `app.rork.ttw2mc8l515rcfbble5ol`. Cámbialo por el tuyo en
  *Target Payku → Signing & Capabilities* (y también en los targets de tests).
- **Firma (Signing)**: asigna tu *Team* de Apple Developer.

## Estado funcional

Esta primera entrega cubre **vinculación, caja del día, historial, visor en vivo, avisos y la
navegación completa**, con **datos de muestra** (ver `PaykuStore.samplePayments()`).

Lo que **no** está (y hay que resolver con backend/otra fuente):

- **Captura de notificaciones de Yape/Plin**: iOS no permite leer notificaciones de otras apps
  (a diferencia de Android). Esa parte necesita otra fuente de datos (un sensor Android dedicado,
  integración por API, o ingreso al backend por otra vía).
- **Conexión al backend real**: hoy todo sale de `PaykuStore` (memoria). Falta cablear las
  llamadas a los endpoints (`/device/*`, `/espejo/*`) que ya usa la app Android.

Ver el documento `especificacion-funcional-payku-swift.md` (en el repo de la app Android) para el
detalle de cada pantalla, regla de negocio y endpoint.
