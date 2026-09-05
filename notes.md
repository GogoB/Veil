# Veil - Project Notes

Working name: **Veil**. Final product name and branding remain open.
Status: idea and planning; documentation and branding only.
Started: 2026-09-05.

This file is the continuing project record. Update it after meaningful discussions
or changes. Label decisions as **Confirmed**, **Proposed**, or **Open** so that
suggestions do not silently become requirements. Never record passwords, recovery
codes, signing keys, or other live credentials here.

## Product concept

An anonymous/pseudonymous social network with posting, profiles, comments, and
private messaging. Familiar social features such as following and blocking are
part of the intended direction; the exact first-release scope is not decided.

The aim is to avoid collecting real-world identity and minimize retained data.
A persistent username still links activity together. No guarantee of
untraceability: public content, relationships, network metadata, and user choices
can reveal identity. No promise of zero personal data or universal legal immunity.

## Confirmed direction

- Native iOS application using Swift and SwiftUI.
- Frontend Figma designs already exist; the file URL has not been supplied here.
- Development can happen on Windows. Use the Mac with Xcode for Apple-framework
  builds, previews, simulator/physical-iPhone testing, and signing. Validate on
  the Mac throughout development.
- Anonymous/pseudonymous use and data minimization are core product goals.
- Credential resets require **both a separate security passphrase and a recovery
  code**. The user selected a passphrase rather than a second generated key or a
  physical security key.
- Possessing an existing device/session alone must not enable a credential reset
  or replacement of the required recovery secrets.
- Global availability is the ambition. Company jurisdiction and launch countries
  are currently undecided.
- Create a separate Desktop project, custom folder icon, local Git repository,
  and this notes file. App implementation comes later.

## Account and recovery design - proposed, not a completed specification

### Device access and account modes

- Ordinary access uses a device credential; app locking protects local access.
- A strict device-only mode could keep a credential that does not migrate or
  synchronize to another device. Permanent loss of that credential loses access.
- Recovery-enabled accounts could recover using the passphrase and recovery code,
  without providing a phone number. Requiring both takes precedence over the
  earlier suggestion that a recovery code alone would suffice.
- Optional phone recovery was discussed as a convenience, but its exact role is
  unresolved. Phone verification must not become a bypass for the confirmed
  passphrase-plus-code rule.
- App deletion, backup restoration, device erasure, passcode changes, repair, and
  resale need explicit behavior before implementation.
- Device credentials and account IDs are separate. A MAC address is not the
  proposed identity mechanism.
- Recovery configuration must be completed and confirmed by the user before the
  account can claim recovery support.

### Sensitive actions and recovery protections

- Proposed: adding a device, changing the passphrase or recovery configuration,
  and deleting an account require both secrets, with fresh server-side checks.
  Confirm the precise action list and friction before implementation.
- Do not retain the passphrase in app storage. The user should store the recovery
  code separately from the everyday device.
- Store only appropriately protected verification material, never plaintext
  secrets or credentials in logs. Cryptographic protocol and parameters are open.
- Proposed: consume a recovery code when used and issue a replacement through a
  flow that confirms the user has saved it.
- Proposed: successful account recovery revokes old device credentials/sessions.
- Phone verification, an active session, and support-assisted recovery must not
  silently replace the two-secret requirement.
- If either required secret is lost, recovery becomes unavailable under this
  design. Existing device access might continue. Communicate that consequence
  clearly and decide whether any additional, explicitly enrolled recovery
  mechanism should exist.
- Requiring two secrets does not automatically make this phishing-resistant MFA.
- A person with an unlocked app could still read accessible messages or post.
  App locking, session management, and limits on destructive actions remain needed.
- Losing account access does not automatically delete public posts, other users'
  copies, or server records. Account expiration/deletion is a separate policy.
- Account recovery and encrypted message-history recovery are separate features.
  A recovered account does not by itself recover missing decryption keys.

## Privacy and operations - proposals

- Retain only data justified by a feature, abuse prevention, or an applicable
  legal duty. Set specific retention/deletion periods before launch.
- Candidate account data: random account ID, username, authentication public keys
  or protected verifiers, and limited abuse-control state.
- Social features require content and relationships such as posts, comments,
  follows, and blocks. These are linkable account data.
- End-to-end encryption for private messages is proposed, not selected or
  implemented. Evaluate an established, reviewed protocol rather than inventing
  cryptography. Delivery metadata, multi-device access, backups, and reporting
  need separate decisions.
- Optional push notifications need Apple push tokens. Prefer generic payloads
  without message plaintext, and review token retention.
- Minimize IP and request logging across the application, hosting, CDN, monitoring,
  backups, and other providers. Processing a network connection differs from
  retaining its IP address.
- Optional phone enrollment creates a link to the account and its earlier history.
  SMS providers receive the phone number. Encoding or encryption is not anonymity;
  plain phone-number hashes are enumerable. A keyed fingerprint can reduce some
  exposure but remains linkable and is not a complete recovery architecture.
- Avoid unnecessary analytics identifiers, contact uploads, precise location, and
  personal profile fields. Strip location metadata from uploaded images.
- Define reporting, blocking, filtering, moderation access, and evidence retention
  for public content and user-submitted reports. E2EE does not prevent a recipient
  from reporting or sharing content they can read.

## Bot and server abuse controls - proposals

- Evaluate Apple App Attest and DeviceCheck for app integrity and limited device
  abuse signals. They do not prove humanity or one account per human.
- Device counts and phone counts cannot guarantee person-level uniqueness.
- Layer signup/request rate limits, upload quotas, gradual account privileges,
  abuse reports, and infrastructure DDoS protection.
- Consider an invite-only pilot and challenges when suspicious activity occurs.
- Control infrastructure spending as well as requests. Attackers can hit public
  endpoints without creating accounts.
- Decide behavior for unsupported attestation, legitimate reinstall/transfer,
  shared or resold devices, and false positives. Do not treat device flags as a
  permanent identity record or a universal ban decision.

## Legal and distribution - open

- There is no single set of global social-media rules. Company establishment,
  target markets, service behavior, and providers affect applicable obligations.
- No universal minimum police-disclosure dataset has been established for this
  project. Obtain jurisdiction-specific advice before setting launch claims,
  retention periods, reporting processes, or preservation exceptions.
- Minimize collection from the outset while respecting applicable binding
  disclosure, retention, preservation, and reporting obligations.
- EU DSA Article 10 and Article 18 were discussed as examples, not as a complete
  global compliance assessment.
- Apple App Review guideline 1.2 requires UGC controls and specifically addresses
  services primarily used for random or anonymous chat. A pseudonymous feed does
  not guarantee App Store acceptance.
- Company location, initial countries, audience ages, age assurance, moderation
  staffing, and the privacy/disclosure policy all remain open.
- The Git remote is not configured. This is currently a local repository; review
  Git author metadata and repository visibility before publishing.

## Open decisions

1. Final product name and brand direction.
2. Figma URL, design inventory, and minimum supported iOS version.
3. First-release features: post/media types, feed ordering, follows, comments,
   profiles, private/group messaging, notifications, and search.
4. Audience age range and moderation model.
5. Strict device-only versus recovery-enabled account choices.
6. Precise phone-recovery role without weakening the two-secret requirement.
7. Sensitive-action authorization, recovery enrollment, rotation, and lost-secret
   behavior; account deletion versus permanent loss of access.
8. Bot controls and whether duplicate accounts are merely discouraged or restricted.
9. E2EE protocol, key verification, device linking, history transfer, and backups.
10. Backend stack, hosting, data model, delivery queues, and operating budget.
11. Data inventory, provider selection, retention/deletion, and legal review.
12. Company jurisdiction and staged launch markets.
13. Mac build workflow and eventual Git remote/repository visibility.

## Next steps

- Open this folder as a separate local project and read this file when resuming.
- Obtain the Figma link and inventory the existing screens.
- Agree a small first-release feature set.
- Write the account/recovery flows and threat model, including an unlocked stolen
  phone and a lost device.
- Choose the backend and privacy/abuse-control architecture.
- Then scaffold the iOS project and establish regular Mac builds.

## Decision log

| Date | Status | Decision or discussion |
| --- | --- | --- |
| 2026-09-05 | Confirmed | Native iOS with Swift/SwiftUI; develop on Windows and build/test on Mac. |
| 2026-09-05 | Confirmed | Aim for minimal identity collection; acknowledge pseudonymity and tracking limits. |
| 2026-09-05 | Proposed | Device-only accounts, optional recovery, and optional phone enrollment were discussed. |
| 2026-09-05 | Confirmed | Require a separate security passphrase plus a recovery code for credential resets. |
| 2026-09-05 | Proposed | Extend both-secret checks to device enrollment, recovery changes, and account deletion. |
| 2026-09-05 | Open | Bot strategy, E2EE implementation, backend, age range, jurisdiction, and launch markets. |
| 2026-09-05 | Confirmed | Initialize the Desktop workspace and local Git repository under the working name Veil. |

## Workspace and artwork

Project folder: C:/Users/GorjanB/Gorjan/Desktop/Veil

- branding/veil.svg: editable vector artwork.
- branding/veil.ico: Windows folder icon with 16, 24, 32, 48, 64, 128, and 256px images.
- branding/veil-preview.png: 512px preview.
- branding/Build-Icon.ps1: shared vector geometry and Windows rendering/export script.
  Run from the repository root with: powershell -NoProfile -File branding/Build-Icon.ps1
  This rebuilds the SVG, ICO, and preview, so edit the script geometry as well as
  the SVG if the design is changed in a vector editor.
- desktop.ini: local, hidden Windows folder configuration; ignored by Git.

The artwork is a violet speech bubble folded like a veil against midnight blue.
It is provisional project branding, not a finalized iOS app icon.

A command's working directory does not automatically change the selected project
in the desktop app. Add this folder as a separate local project there.

## Research links

Reference material consulted during planning on 2026-09-05. Re-check current
platform behavior and laws before implementation or launch.

- [Swift getting started and platform workflow](https://www.swift.org/getting-started/)
- [Apple App Attest and DeviceCheck](https://developer.apple.com/documentation/devicecheck)
- [Apple fraud risk assessment](https://developer.apple.com/documentation/devicecheck/assessing-fraud-risk)
- [Device-only Keychain accessibility](https://developer.apple.com/documentation/security/ksecattraccessiblewhenpasscodesetthisdeviceonly)
- [Apple push notification registration](https://developer.apple.com/documentation/usernotifications/registering-your-app-with-apns)
- [Apple privacy and device-fingerprinting rules](https://developer.apple.com/app-store/user-privacy-and-data-use/)
- [Apple App Review guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [OWASP authentication and sensitive-action reauthentication](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html)
- [OWASP recovery guidance](https://cheatsheetseries.owasp.org/cheatsheets/Forgot_Password_Cheat_Sheet.html)
- [OWASP password storage](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html)
- [OWASP unrestricted resource consumption](https://owasp.org/API-Security/editions/2023/en/0xa4-unrestricted-resource-consumption/)
- [Signal on the limits of hashing phone numbers](https://signal.org/blog/contact-discovery/)
- [Telegram encryption and account FAQ](https://telegram.org/faq)
- [Telegram privacy and authority-disclosure policy](https://telegram.org/privacy)
- [Signal's published 2021 subpoena response: an example, not a legal minimum](https://signal.org/bigbrother/cd-california-grand-jury/)
- [EU GDPR, including territorial scope](https://eur-lex.europa.eu/eli/reg/2016/679/oj/eng)
- [EU Digital Services Act](https://eur-lex.europa.eu/eli/reg/2022/2065/oj/eng)
- [Windows custom folder icons](https://learn.microsoft.com/en-us/windows/win32/shell/how-to-customize-folders-with-desktop-ini)
- [Desktop app local-project setup](https://learn.chatgpt.com/docs/projects#use-local-projects-for-folders-and-codebases)
