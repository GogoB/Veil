# Veil local proof of concept

Veil is a native SwiftUI social app where each post, comment, or conversation can
use a public profile or a scope-specific anonymous identity. This repository
contains the iOS app, shared Swift contracts, a Vapor/PostgreSQL API, and a
private Synapse homeserver for end-to-end encrypted direct messages.

The proof of concept collects no email address, phone number, contact book,
birthdate, age band, or legal name. The one-time “18 or older” confirmation stays
in the iOS Keychain and is never sent to the API. Public anonymity is not a
guarantee against writing-style analysis, screenshots, network observation,
server compromise, or lawful process.

## Run the local stack on Windows

Requirements: Docker Desktop with Linux containers and PowerShell 5.1 or later.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\Start-Local.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\Smoke-Test-API.ps1
```

The first build compiles Vapor in a Swift 6.1 container and can take several
minutes. Later builds use Docker’s cache. The services are:

- Veil API: `http://127.0.0.1:8080`
- Synapse client API: `http://127.0.0.1:8008`
- PostgreSQL: `127.0.0.1:5432`

Generated secrets live in ignored `.env` and `.local` paths. Stop the services
without deleting their data:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\Stop-Local.ps1
```

For a physical iPhone or a simulator on another computer, use the Windows host’s
LAN address when initializing the stack:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\Start-Local.ps1 -PublicHost 192.168.1.50
```

Set the iOS app’s API address to `http://192.168.1.50:8080` in Privacy Controls,
then restart the app. The host firewall must allow local TCP ports 8080 and 8008.

## Run the native iOS app

Open `ios/Veil.xcodeproj` on a Mac with Xcode. The project targets iOS 16, links
the local `Shared` package, and pins `MatrixRustSDK` to exact version `26.08.11`.
Select **Local server** during account setup to use Vapor and Synapse, or **Demo
data** to explore the screens without any services.

The Windows source check validates Xcode source membership, the property list,
and the age-data privacy guard:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\Verify-iOSProject.ps1
```

An actual SwiftUI build, simulator run, Dynamic Type review, and VoiceOver review
require Xcode and Apple’s SDK. They cannot be completed on Windows.

## Repository layout

- `ios/Veil` — SwiftUI screens, local Keychain state, API client, and Matrix adapter.
- `Shared` — dependency-free Codable contracts and privacy tests.
- `Server` — Vapor routes, Fluent models/migrations, privacy boundaries, and tests.
- `infra` — Docker Compose, PostgreSQL initialization, and non-federated Synapse configuration.
- `scripts` — setup, startup, shutdown, smoke-test, and iOS project checks.
- `branding` — provisional local artwork and design direction.

Normal message plaintext is sent through Matrix encryption. Vapor stores opaque
event IDs and delivery metadata. Plaintext reaches Vapor only when a user
explicitly selects individual decrypted messages for a report.
