# App nativa · PanditaCash

App nativa iOS + Android generada con [Capacitor](https://capacitorjs.com/).

- **App ID**: `com.axorsystem.panditacash`
- **App Name**: PanditaCash
- **Modo**: la app carga la web en `https://panditacash.5-78-222-255.sslip.io` — cualquier cambio en la web aparece en la app **sin resubir el APK/IPA**. Es lo mejor de los dos mundos: distribución nativa + actualizaciones instantáneas.

## Requisitos

| Plataforma | Necesitas |
|---|---|
| Android | **JDK 17** (`brew install openjdk@17`) — ya instalado |
| iOS | **Xcode.app** completo (App Store, gratis) + cuenta Apple Developer opcional |

## Comandos comunes

Todos desde `frontend/`:

```bash
# Después de cualquier cambio en el código Vue:
npm run build && npx cap sync

# Android debug APK (para probar/compartir por link):
export JAVA_HOME="/opt/homebrew/opt/openjdk@17"
cd android && ./gradlew assembleDebug
# → android/app/build/outputs/apk/debug/app-debug.apk

# Android release APK (firmado, para stores):
cd android && ./gradlew assembleRelease
# Requiere keystore configurado (ver más abajo)

# Abrir proyecto Android en Android Studio (para debug con emulador):
npx cap open android

# Abrir proyecto iOS en Xcode:
npx cap open ios
```

## Distribución del APK Android sin Play Store

1. Compila el APK debug con los comandos de arriba
2. Súbelo a **panditacash.com/app.apk** (o cualquier URL pública HTTPS)
3. El usuario abre esa URL en su móvil → descarga el archivo
4. Al abrirlo Android pide autorizar "Instalar apps desconocidas" para el navegador → aceptar
5. Se instala como app real con icono PanditaCash

Alternativa: hosting gratis en GitHub Releases o Firebase App Distribution.

## Distribución iOS sin App Store

Apple **bloquea el sideload de IPA** en iPhone estándar. Las únicas vías legales:

- **App Store** — review + $99/año de Apple Developer Program
- **TestFlight** — hasta 10k testers por link, expira 90 días, requiere Developer Program
- **Ad-hoc** — hasta 100 dispositivos registrados manualmente por UDID

Sin Apple Developer Program, iPhone solo puede usar la **PWA** (que también funciona bien: se instala con "Añadir a pantalla de inicio" desde Safari).

## Iconos y splash

Los assets fuente están en `frontend/resources/`:

- `icon.png` — 1024×1024, fondo pastel #FFF5E4
- `splash.png` — 2732×2732, logo centrado sobre fondo pastel

Para regenerarlos después de cambiar el logo:

```bash
rsvg-convert -w 1024 -h 1024 -b '#FFF5E4' branding/logo.svg > resources/icon.png
# splash.png se regenera con el script Python del sync inicial
npx capacitor-assets generate --assetPath resources
npx cap sync
```

## Configurar firma para release

Para APK release (Play Store o distribución firmada):

1. Genera keystore una sola vez:
   ```bash
   keytool -genkey -v -keystore panditacash-release.keystore \
     -alias panditacash -keyalg RSA -keysize 2048 -validity 10000
   ```
2. Guárdalo en `android/app/panditacash-release.keystore` (no lo subas a git — está en `.gitignore`)
3. En `android/gradle.properties`:
   ```
   PANDITACASH_KEYSTORE_PASSWORD=xxxxx
   PANDITACASH_KEY_PASSWORD=xxxxx
   PANDITACASH_KEY_ALIAS=panditacash
   ```
4. Configura `android/app/build.gradle` para usar el keystore (ver docs de Capacitor)

## Publicar en Play Store

1. Crea cuenta Google Play Console — **$25 USD one-time**
2. Sube el APK release
3. Rellena listing, screenshots, política de privacidad
4. Review 1-2 días típicamente

## Publicar en App Store

1. Apple Developer Program — **$99 USD/año**
2. Abre `ios/App/App.xcworkspace` en Xcode
3. Configura signing con tu Team ID
4. Archive → Distribute App → App Store Connect
5. Rellena listing en App Store Connect
6. Review 1-3 días típicamente
