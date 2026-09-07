# Veil iOS proof of concept

This is the native SwiftUI implementation. Open `Veil.xcodeproj` on a Mac with
Xcode 15 or later, choose an iOS 16+ simulator, and run the `Veil` scheme.

For a command-line simulator build on the Mac:

    xcodebuild -project ios/Veil.xcodeproj -scheme Veil \
      -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build

On Windows, validate the project structure from the repository root with:

    powershell -NoProfile -File scripts/Verify-iOSProject.ps1

No package installation, backend, or network connection is required. The app runs
with local demo data. The first launch presents the local 18+ confirmation and
account-mode setup. Choose a three-character-or-longer demo username; recoverable
mode additionally asks for a 12-character passphrase but does not store it.

Implemented in this milestone:

- Keychain-only adult confirmation, never represented in an API model.
- Device-only/recoverable account-mode demonstration.
- Discover and Following feeds; anonymous posts cannot enter Following.
- Topics, likes, thread replies, hiding, and topic muting.
- Anonymous/profile composer with generated alias, validated custom alias, or
  sigil-only presentation.
- Four-image picker, local pixel limits, and JPEG re-encoding to discard source
  image metadata before a future upload.
- Expiration and sensitive-content choices with a blurred-media reveal.
- Public search that deliberately excludes anonymous aliases and sigils.
- Veiled Activity and public profile separation.
- Demo message requests and conversations behind `MessagingProvider`.
- Appearance, accent, content, and messaging preferences.

The Matrix adapter, Vapor API, persistence beyond a few local preferences, real
account credentials, collaborator invitations, upload transport, expiration jobs,
and server-enforced blocks are not implemented yet. Windows cannot compile
SwiftUI; the first build and visual/accessibility check must be run on the Mac.

The provisional bundle identifier is `com.veil.poc`. Select your development team
in Xcode only when running on a physical device.
