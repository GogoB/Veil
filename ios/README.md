# Veil native iOS app

Veil is implemented as a native SwiftUI application in `Veil.xcodeproj`. It
targets iOS 16, links the local `Shared` contracts package, and pins
`MatrixRustSDK` to exact version `26.08.11` behind `MessagingProvider`.

Open the project on a Mac with Xcode, select the `Veil` scheme, and run an iOS
16+ simulator or device. The app offers two startup paths:

- **Local server** creates or recovers a real local account and connects to the
  Vapor API, PostgreSQL, and private Synapse services.
- **Demo data** opens the full native interface without a running backend.

The app includes the Keychain-only adult confirmation, device-only and
recoverable accounts, Discover and Following, attributed and anonymous posts,
sanitized image uploads, topics, expiration, collaborators, reposts and quotes,
comments, likes, public profiles, follow actions, search, Veiled Activity,
privacy controls, encrypted message requests, text and image messages,
delete-for-all, selected-message reports, timers, and message-key transfer.

Start the local services and run the API smoke test from the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\Start-Local.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\Smoke-Test-API.ps1
```

For an iPhone or a Mac on another machine, initialize with the Windows host LAN
address and set the same API address in the app's Privacy Controls:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\Start-Local.ps1 -PublicHost 192.168.1.50
```

Validate source membership and privacy guards on Windows with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\Verify-iOSProject.ps1
```

Windows can parse the Swift source through the Linux toolchain, but it cannot
compile SwiftUI or the Apple-only Matrix XCFramework. Run the final build,
simulator, Dynamic Type, and VoiceOver checks in Xcode. See the repository
`README.md` for full local-stack instructions.
