# AstroCam

AstroCam is a SwiftUI + AVFoundation camera app inspired by ProCam, focused on manual control for astrophotography.

## Features
- Full-screen live preview
- Manual controls: ISO, shutter (0.1–30s), focus (0–1 + INF button), WB auto + Kelvin (3200–5000)
- AE/AF lock toggles
- RAW capture when supported, otherwise HEIF
- Intervalometer (N shots, interval, countdown, stop)
- Saves into custom album "AstroCam"
- Presets: Stelle, Via Lattea urbano (stacking), Via Lattea buio

## Requirements
- Xcode 15+
- iOS 16+
- Physical device (camera APIs are not available in the simulator)

## Build & Run
1. Open `AstroCam.xcodeproj` in Xcode.
2. Select a real iOS device as the run target.
3. In the target settings, set your Signing Team and Bundle Identifier.
4. Build and run.

## Build con Codemagic (senza Mac)
Questa e' la via consigliata se non hai un Mac. Per pubblicare su TestFlight serve **Apple Developer Program**.

### 1) Collega la repo a Codemagic
1. Vai su Codemagic -> Add application.
2. Seleziona GitHub e autorizza l'accesso.
3. Scegli la repo `Giuseppe575/astrocam-ios`.
4. Seleziona il workflow `astrocam_release` del file `codemagic.yaml`.

### 2) Crea l'app su App Store Connect
1. App Store Connect -> My Apps -> New App.
2. Platform: iOS, Name: AstroCam, Bundle ID: `com.giuseppe.astrocam`.
3. Salva e crea la scheda app.

### 3) Certificati e provisioning (TestFlight)
Per TestFlight servono:
- Apple Distribution Certificate
- App Store provisioning profile per `com.giuseppe.astrocam`

Con Codemagic puoi automatizzare usando **App Store Connect API key**:
1. App Store Connect -> Users and Access -> Keys -> App Store Connect API.
2. Crea una API key e scarica il file `.p8`.
3. Annota:
   - Issuer ID
   - Key ID

### 4) Environment variables in Codemagic
Vai su Codemagic -> App settings -> Environment variables e aggiungi:
- `APP_STORE_CONNECT_ISSUER_ID` = Issuer ID
- `APP_STORE_CONNECT_KEY_ID` = Key ID
- `APP_STORE_CONNECT_API_KEY` = contenuto del file `.p8` (testo completo)

In `codemagic.yaml` sono gia' configurate:
- `BUNDLE_ID` = `com.giuseppe.astrocam`
- `XCODE_PROJECT` = `AstroCam.xcodeproj`
- `XCODE_SCHEME` = `AstroCam`

### 5) Code signing in Codemagic (dove caricare)
Nel file `codemagic.yaml` usiamo `codemagic-cli-tools` per:
- creare/inizializzare il keychain
- scaricare certificati e profili da App Store Connect

Non devi caricare manualmente i profili se usi la API key. Se preferisci manuale:
1. Codemagic -> App settings -> Code signing.
2. Carica:
   - Apple Distribution Certificate (.p12 + password)
   - App Store provisioning profile (.mobileprovision)

### 6) Pubblicazione su TestFlight
Il workflow usa `publishing -> app_store_connect` con:
- `submit_to_testflight: true`
Questo carica automaticamente la build su TestFlight.

### 7) Opzione Ad Hoc (se serve)
Richiede:
- Lista UDID device
- Ad Hoc provisioning profile
Poi sostituisci nel workflow il tipo profilo in `app-store-connect fetch-signing-files` con `IOS_APP_ADHOC`.

### Problemi comuni
- **Errore signing**: mancano Issuer ID/Key ID/API key oppure non esiste l'app in App Store Connect con bundle id `com.giuseppe.astrocam`.
- **Provisioning assente**: non hai un certificato Apple Distribution valido o il profilo non e' creato.
- **Build fallisce**: controlla i log `xcodebuild.log` negli artifacts.

## Permissions
AstroCam needs:
- Camera access for live preview and captures.
- Photo Library add access to save shots in the "AstroCam" album.

## Notes
- Long shutter speeds require a steady mount.
- RAW output depends on device support.

## Structure
- `AstroCam/` SwiftUI views and camera logic
- `AstroCam.xcodeproj/` Xcode project

