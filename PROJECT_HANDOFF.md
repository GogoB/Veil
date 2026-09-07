# Veil — Complete Project Handoff

Updated: 2026-09-07  
Status: product and technical planning are complete; native SwiftUI implementation has started with a demo-data application shell; backend implementation has not started.

Repository: C:\Users\GorjanB\Gorjan\Desktop\Veil  
Branch: main  
Initial commit: 9e6f614

This document transfers the full product and technical context into a new Codex
conversation rooted at this repository. Read this file and notes.md before changing
anything. Treat decisions marked Confirmed as requirements. Veil is a temporary
working name.

## Original goal

Veil is an anonymous or pseudonymous social network for iOS. It should offer the
normal features expected from social media while collecting as little real-world
identity as possible. The product must be candid that anonymity cannot be
guaranteed: public writing style, relationships, network metadata, screenshots,
server compromise, and legal process can still identify someone.

The app is native Swift and SwiftUI. Most source authoring happens on Windows.
A Mac with Xcode is used for Apple builds, signing, previews, the simulator, and a
physical iPhone. Existing Figma designs exist but their URL has not yet been
provided.

The immediate objective is a local proof of concept. Deployment, App Store release,
and production operations are outside this phase.

## Conversation decisions

### Accounts and recovery

Confirmed:

1. Support both device-only and recoverable accounts.
2. A device-only account uses a device credential. If all enrolled devices are
   lost, the account is permanently inaccessible.
3. A recoverable account requires two independent secrets: a security passphrase
   and a high-entropy recovery code.
4. Both secrets are required to enroll a replacement device or reset credentials.
   Possession of an unlocked device alone must not reset or replace them.
5. Store only secure server-side verifiers, never plaintext passphrases or recovery
   codes.
6. A successful recovery revokes old sessions and generates a replacement recovery
   code.
7. Recovering the social account without an old device does not restore historical
   end-to-end encrypted messages. Old-device key transfer is required.
8. Do not use a MAC address as an identity. iOS does not provide an appropriate
   stable MAC identifier for this purpose.
9. Phone recovery is excluded from the proof of concept.
10. Do not collect phone numbers, email addresses, contact books, legal names,
    birthdates, or age bands.
11. Public usernames are pseudonymous handles. Internally, accounts use random
    identifiers and device credentials.

Earlier discussion considered an optional phone number for transfer, but this is
not selected. It must never bypass the passphrase-plus-recovery-code rule if added
later.

### Age handling

The earlier 16+ age-band design was rejected because even a coarse age range is
personal information.

Confirmed replacement:

- Present a one-time statement: “I confirm that I am 18 or older.”
- Store the accepted flag only in the local iOS Keychain.
- Never transmit this flag to the Veil API.
- Do not call Apple’s Declared Age Range API in the proof of concept.
- Do not add an age, age band, birthdate, eligibility value, or adult-confirmation
  field to shared API models or the server database.
- This is self-attestation and does not reliably prove age.

### Profiles and social graph

Confirmed:

- Public profile fields: unique username, optional avatar, optional bio, follower
  count, following count, and normal attributed posts.
- Exact follower and following lists are private.
- Anonymous posts, comments, and conversations never appear on the public profile.
- Users can follow, block, and mute profiles.
- Search covers public profiles, topics, and public posts. Anonymous aliases and
  sigils are never searchable, followable, or clickable as profiles.

### Posts

Confirmed:

- Text and images in version one.
- Maximum 2,000 characters and four images per post.
- Strip location and other metadata from image uploads.
- Posts can be edited, with a visible Edited label.
- Posts can be deleted.
- Optional expiration presets: 24 hours, 7 days, 30 days, or never.
- Support reposts and quote posts.
- If an original post disappears, a plain repost disappears. A quote post keeps
  the quoting user’s text and displays “Original unavailable”; it does not keep a
  hidden snapshot of the original.
- Topics or hashtags drive Discover and search.

### Anonymous posts

Confirmed public privacy boundary:

- Other users cannot link an anonymous post to its owner.
- The service keeps a tightly protected internal ownership mapping so the owner
  can edit/delete, rate limits can work, blocks can work, and narrow enforcement
  can occur.
- Public API responses, profiles, feeds, search, notifications, errors, and
  moderator views must never serialize the underlying account ID.
- Moderators act through opaque case and enforcement tokens. They do not receive
  the hidden profile mapping directly.
- Do not claim that the service itself has no ownership data. The correct promise
  is anonymous to other users with minimized service-only linkage.

Anonymous presentation is scoped to one post thread. There are no persistent
anonymous personas.

A user chooses one of:

1. A generated one-thread alias.
2. A custom one-thread alias.
3. No name, with only a generated veil sigil.

The sigil distinguishes anonymous participants in the same thread. It remains
stable within that thread and changes across threads. Alias and sigil values are
not searchable, followable, or profile links. Reserve misleading custom names
such as Admin, Moderator, Support, and system labels.

Anonymous posts belong in Discover, topic feeds, direct links, and public reshares.
They must never enter Following because of a hidden owner/follower relationship.

Add a private, app-lockable Veiled Activity area where a user can manage their
anonymous posts, comments, and conversations.

### Co-owned posts

Confirmed:

- Co-owned normal and anonymous posts are supported.
- The creator invites collaborators, who accept before publication.
- The creator controls edits and deletion.
- Collaborators may leave.
- Normal co-owned posts display accepted profile owners.
- Anonymous co-owned posts hide all owner identities and do not reveal the number
  of hidden owners.
- Each hidden owner receives a separate thread-only OP alias or sigil when replying.
- Co-owners can know one another through the invitation flow; the audience cannot.
- “Message Author” on an anonymous co-owned post reaches the creator.
- Messaging a specific OP reply reaches that co-owner.
- Do not create a shared group inbox in version one.

### Comments and likes

Confirmed:

- Users can comment as their profile or anonymously.
- The chosen identity is locked after their first comment in a post thread.
- Hidden owners remain anonymous and receive an OP marker.
- Use two visible reply levels in version one; deeper replies flatten beneath the
  root comment.
- Edited comments display an Edited label.
- Deleted comments become tombstones when replies depend on them.
- Likes show only a public count.
- Do not expose a liker list.
- The server privately stores account-to-content uniqueness to prevent duplicate
  likes.

### Feeds and discovery

Confirmed:

- Two main feeds: Following and Discover.
- Following is chronological and contains only attributed activity from followed
  profiles.
- Discover can contain normal and anonymous posts.
- Discover uses topics, language, recency, engagement, and negative safety signals.
- Do not use hidden ownership relationships or cross-app tracking for ranking.
- Personal mutes and filters apply before content is presented.

### Messaging

Confirmed version-one scope:

- One-to-one text and images.
- Identified profile-to-profile conversations.
- A sender can message a known normal profile while hiding the sender’s identity.
- From an anonymous post, “Message Author” creates a relay where both participants
  use anonymous conversation identities.
- Every anonymous conversation receives a fresh conversation-only alias or sigil.
  It cannot be correlated publicly with post aliases or other conversations.
- The service retains the minimum hidden mapping needed for delivery, abuse
  controls, and blocking.
- Incoming anonymous messages are controlled per profile: allow, filtered, or
  disabled. Default is filtered.
- A filtered requester may send one text-only message and must wait for acceptance.
- Images and clickable links are unavailable until acceptance.
- No online or last-seen status.
- Typing indicators and read receipts are off by default and configurable per
  conversation.
- Support optional disappearing timers and best-effort delete-for-all. Explain that
  screenshots or copies cannot be remotely erased.
- Blocking an anonymous alias must block the underlying account without revealing
  the connection.
- Private messages target end-to-end encryption.
- Use a pinned Matrix Rust SDK Swift package behind a MessagingProvider abstraction.
  The researched current pin was 26.08.11 on 2026-09-07. Re-check before changing.
- Use a self-hosted Matrix Synapse service with federation disabled.
- Matrix user IDs and room IDs are internal implementation details and never appear
  as Veil identities.
- A recovered account without old-device crypto transfer cannot decrypt old
  messages.
- Message reporting is explicit: only messages selected by the reporter are
  decrypted and attached to a moderation case. The rest of the conversation
  remains encrypted.

### User control and narrow service rules

The user rejected broad content moderation and said: “freedom of speech baby. Give
them all control.”

The agreed interpretation is broad user control above a narrow mandatory floor.
Allowing doxxing would contradict the project’s privacy purpose.

User controls:

- Block a profile, thread identity, alias, or conversation.
- Mute profiles, threads, topics, and keywords.
- Blur sensitive media by default, with a user-controlled preference.
- Allow, filter, or disable anonymous message requests.
- Configure read receipts, typing indicators, and disappearing timers.

The service floor is limited to:

- Clearly illegal material.
- Child sexual abuse material.
- Credible threats and criminal solicitation.
- Malware, spam, automation attacks, and service disruption.
- Publishing another person’s private identifying information without consent.

Other lawful adult material is handled with personal filters instead of broad
platform moderation.

Privacy-preserving reports:

- A public-content report stores the content ID, a structured category, and an
  optional explanation. Avoid duplicating the reported content.
- If reported content is deleted before review, move the existing record into
  restricted quarantine.
- The reporter is represented by an opaque case credential.
- Moderator views show content and opaque enforcement tokens, not hidden author or
  reporter profiles.
- Encrypted-message reports contain only messages deliberately selected by the
  reporter.
- Do not send reports or user content to third-party moderation or AI services.
- Optional report text warns users not to add unnecessary personal information.

Current Apple App Review Guideline 1.2 requires distributed social apps to provide
content filtering, reporting, blocking, timely responses, and public developer
contact information. Apple also applies this rule to anonymous chat. The local
proof of concept can demonstrate the selected design, but an App Store submission
requires a separate compliance pass.

### Helpful additions accepted as part of the design

- Private Veiled Activity management screen.
- Topics and topic muting.
- Keyword muting.
- Sensitive-content warnings and blur controls.
- Generic notification text that does not include private-message plaintext.
- Report, block, and mute controls throughout relevant views.

Do not add polls, communities, group chats, voice calls, video calls, federation,
phone recovery, or cloud deployment in this phase.

## Technical architecture

### Visual direction update (2026-09-07)

Confirmed by the user before implementation:

- Combine a cyberpunk-inspired aesthetic with an Apple-like look and feel.
- Avoid the usual generic AI-generated interface appearance.
- Research visual references before implementing the design.

Proposed interpretation and research are in
[branding/DESIGN_DIRECTION.md](branding/DESIGN_DIRECTION.md). Palette, typography
details, visual balance, and individual screen treatments remain proposals until
reviewed. The existing violet folder icon is provisional and does not dictate the
app palette. The Figma URL is still outstanding.

Reasoning recommendation, not a changed application setting: High for normal
implementation and design work; Extra High, where available, for privacy
boundaries, recovery, encrypted messaging, and difficult cross-system debugging.
Medium is sufficient for small, well-specified visual and copy adjustments.

### Native SwiftUI milestone (2026-09-07)

The first attempt incorrectly produced a browser prototype. The user corrected
the scope to SwiftUI. That prototype was removed and replaced with the native
project at `ios/Veil.xcodeproj`.

The SwiftUI application currently includes:

- Local Keychain-backed 18+ confirmation and demo account-mode setup.
- Discover and Following feeds, topics, likes, replies, feed hiding/muting, and
  post detail.
- An attributed/anonymous composer with generated/custom/sigil-only presentation,
  topic, expiration, sensitive-content, and up to four PhotosPicker images.
- Local image pixel checks and re-encoding before a future upload transport.
- Public search that excludes anonymous aliases and sigils.
- Veiled Activity and public-profile separation.
- Demo message requests/conversations behind a MessagingProvider protocol.
- Privacy controls plus dark/light/system and acid/cyan appearance choices.

The app targets iOS 16 and uses demo data without a backend. Open
`ios/Veil.xcodeproj` on the Mac in Xcode 15 or later. Windows does not have the
Apple SDK, so compilation, simulator rendering, Dynamic Type, and VoiceOver still
require the Mac. This milestone does not prove production privacy, authentication,
encryption, upload, or expiration behavior.

On Windows, run `powershell -NoProfile -File scripts/Verify-iOSProject.ps1` to
check Xcode source membership, Info.plist XML, and the local privacy-model guard.

### Repository areas

Implement:

- ios — SwiftUI iOS application.
- Shared — dependency-free Swift package with Codable API contracts.
- Server — Swift/Vapor API using Fluent and PostgreSQL.
- infra — Docker and private Synapse configuration.
- scripts — Windows helpers for local startup and verification.

The SwiftUI app should run in demo-data mode before the backend is available. This
lets the screens and flows be tested on the Mac while backend integration proceeds.

### Local environment facts

Verified on 2026-09-07:

- Docker CLI 28.1.1 is installed.
- Docker Desktop’s Linux engine was stopped during planning.
- A native Windows Swift toolchain was not installed.
- Git is installed.
- The Mac is still required for SwiftUI/Xcode builds.

Recommended workflow:

- Build and run Vapor in a Linux Swift Docker container.
- Run PostgreSQL and Synapse through Docker Compose on Windows.
- Connect the Mac simulator or physical iPhone to the Windows host over the LAN.
- Generate/open the iOS project on the Mac and run Xcode tests there.
- Never attempt to build SwiftUI on Windows.

### Shared public contracts

Required types:

- AccountMode: deviceOnly or recoverable.
- ActorKind: profile, generatedAlias, customAlias, or sigil.
- ActorRole: participant or originalPoster.
- ActorPresentation containing public profile presentation or thread identity.
- PostVisibility: attributed or anonymous.
- AnonymousPresentationMode.
- FeedKind: following or discover.
- ConversationIdentity: identified or anonymous.
- AnonymousRequestPolicy: allow, filtered, or disabled.
- ContentPreferences for mutes and sensitive media.
- Profile, Topic, Post, PostReference, Comment, Conversation, and Message DTOs.
- Account creation, recovery, post creation, comment creation, and report requests.

There must be no age-related property in any shared or server type.

For anonymous ActorPresentation values:

- profile must be absent.
- an alias and/or sigil may be present.
- an opaque enforcement token may be present only where the client needs block or
  report actions.
- the owning account identifier must never be present.

### Server data separation

Public social tables contain displayable content and public presentation fields.

Separate restricted tables hold:

- Content ID to account ownership.
- Conversation identity to account ownership.
- Thread identity to account ownership.
- Opaque enforcement token to enforcement subject.
- Device credentials and session state.
- Recovery verifiers.

Use an application-level ownership key from environment configuration to protect
sensitive mappings at rest. Do not commit a real key.

Store:

- Random account ID.
- Username and optional public profile fields.
- Device public keys or protected session credentials.
- Recovery verifiers only for recoverable accounts.
- Social content and relationships required by features.
- Encrypted Matrix event payloads and necessary delivery metadata.
- Minimal abuse-control state.

Avoid:

- Request-body logging.
- Message plaintext logging.
- Recovery secret logging.
- Raw long-term IP logging.
- Third-party analytics identifiers.
- Contact uploads or precise location.

### Authentication behavior

Proof-of-concept API authentication can use an opaque bearer session bound to a
registered device record, while retaining the device public-key field and a clean
interface for a later signed challenge.

Account creation:

- Validate a normalized unique username.
- Require a device public key.
- For recoverable mode, require a security passphrase.
- Generate a high-entropy recovery code once.
- Hash the passphrase and recovery code independently with an appropriate password
  hashing function.
- Return the recovery code only once.
- Issue an opaque session token; store only its digest.

Recovery:

- Require username, passphrase, recovery code, and replacement device public key.
- Verify both secrets.
- Revoke all prior sessions/devices.
- Enroll the replacement device.
- Rotate the recovery code and return it once.
- Do not restore missing Matrix crypto keys.

### API groups

Implement versioned JSON routes for:

- Health and local readiness.
- Account creation, current session, logout, and recovery.
- Profile lookup/update, follow/unfollow, block, and mute.
- Following and Discover feeds.
- Post create/read/edit/delete, expiration, collaborators, likes, reposts, and
  quotes.
- Comment listing/create/edit/delete and comment likes.
- Topic and public-content search.
- Veiled Activity for the authenticated owner.
- Conversation request/list/accept/block metadata.
- Privacy-preserving reports.
- Matrix account/session provisioning behind an internal adapter.

### SwiftUI application

Minimum screens and flows:

1. Local one-time 18+ confirmation.
2. Account-mode choice and account creation.
3. Following and Discover feeds.
4. Post card and post-detail thread.
5. Composer with attributed/anonymous identity, generated/custom/sigil mode,
   topics, expiration, sensitivity, images, and collaborator invitations.
6. Comments with locked identity and OP presentation.
7. Messages list, request inbox, and conversation.
8. Public profile.
9. Search.
10. Veiled Activity.
11. Privacy controls for blocks, mutes, keywords, sensitive media, receipts,
    typing, and anonymous requests.
12. Recovery and device-management explanations.

Use semantic SwiftUI colors, Dynamic Type, SF Symbols by name, NavigationStack,
TabView, and accessible labels. Do not hardcode the Figma appearance before the
Figma link is supplied.

Store the adult confirmation and device secrets in Keychain. Store non-secret
content preferences locally and synchronize only preferences that require
server-side enforcement.

### Messaging adapter

Define a MessagingProvider protocol so screens and view models do not depend on
Matrix types.

Provide:

- DemoMessagingProvider for previews and immediate UI testing.
- MatrixMessagingProvider using the pinned Matrix Rust SDK.
- Explicit methods for account/session setup, sync, send text, send image, accept
  request, delete-for-all, disappearing timer, block, export old-device keys, and
  import transferred keys.
- A clear selected-message export path for reports.
- No server endpoint accepting normal message plaintext.

The Matrix Swift API is unstable, so isolate every imported Matrix symbol inside
the adapter and pin the package version.

### Image handling

- Accept JPEG, PNG, HEIC, and WebP as appropriate for the client.
- Limit posts to four images.
- Re-encode uploads to remove EXIF and location metadata.
- Enforce size and pixel limits on both client and server.
- Use a local mounted upload directory for the proof of concept.
- Use random object names; never include usernames in storage paths.

### Bot and abuse controls

Do not claim one account per human.

For the proof of concept, provide interfaces and local implementations for:

- Device credential uniqueness.
- Signup, posting, messaging-request, and upload rate limits.
- Upload quotas.
- Progressive account privileges.
- Opaque blocks and enforcement tokens.
- An App Attest adapter with a debug implementation.

If network identifiers are needed for active abuse control, use short-lived,
rotating keyed values and avoid retaining raw addresses.

## Acceptance tests

### Privacy contracts

- Serialize every anonymous public DTO and prove it contains no account ID,
  profile link, age field, recovery material, Matrix ID, or stable cross-thread
  identifier.
- Confirm no API request carries the adult-confirmation flag.
- Confirm moderator DTOs contain only case and enforcement tokens.
- Confirm report DTOs contain no reporter profile.

### Anonymous identity

- The same participant receives the same sigil within a thread.
- The participant receives a different sigil in another thread.
- Thread aliases never appear in search or profile activity.
- Hidden owner relationships never place content in Following.
- Anonymous co-owned posts expose neither owners nor owner count.
- OP reply identities remain distinct for multiple hidden owners.

### Accounts

- Device-only accounts cannot use recovery.
- Recoverable creation requires a passphrase and returns one recovery code.
- Recovery fails if either secret is wrong.
- Successful recovery revokes old sessions and rotates the code.
- No age, phone, email, MAC address, or birthdate field exists in storage.

### Social behavior

- Enforce post text/image limits.
- Test create, edit, delete, and expiration.
- Test collaborator invitation/acceptance/leave and creator-only edit/delete.
- Test comment identity locking and two-level reply flattening.
- Test one-like-per-account while exposing only counts.
- Test repost and quote behavior when the original disappears.
- Verify Following and Discover eligibility rules.
- Verify personal keyword/topic/profile filters.

### Messaging

- Anonymous request policies allow, filter, or reject correctly.
- A filtered request allows one text message and no media/link before acceptance.
- Conversation aliases differ across conversations.
- Anonymous blocking applies to the hidden account without revealing it.
- Vapor, PostgreSQL, and Synapse cannot render E2EE message plaintext.
- Old-device transfer preserves history.
- Recovery without old-device keys leaves old history unavailable.
- Reports include only explicitly selected messages.
- Typing/read receipts default off.
- Disappearing timers and delete-for-all are presented as best effort.

### Local operation

- Docker Compose starts PostgreSQL, Vapor, and non-federated Synapse.
- API health and database readiness succeed.
- Shared Swift package tests pass in Linux Docker.
- Vapor tests pass in Linux Docker.
- Xcode builds the iOS 16 target.
- SwiftUI tests run on a Mac simulator.
- A physical iPhone can connect to the Windows-hosted API over the LAN.

## Implementation order

1. Create Shared contracts and privacy serialization tests.
2. Create the SwiftUI shell with demo data, adult gate, feeds, composer, post
   detail, messages, profiles, search, Veiled Activity, and privacy settings.
3. Create Vapor, PostgreSQL models/migrations, authentication, and social routes.
4. Add internal ownership/enforcement separation and test non-linkability.
5. Add Docker Compose, local uploads, and Synapse with federation disabled.
6. Add the pinned Matrix adapter and E2EE device-transfer flow.
7. Connect the SwiftUI API client to Vapor while keeping demo mode for previews.
8. Run Linux package/server tests on Windows.
9. Generate the Xcode project and run builds/tests on the Mac.
10. Apply the supplied Figma file screen by screen after its URL is available.
11. Update notes.md and commit coherent milestones on main.

## Existing repository state

At handoff creation, the Veil repository contains:

- notes.md with earlier research and decision history.
- branding/veil.svg.
- branding/veil.ico.
- branding/veil-preview.png.
- branding/Build-Icon.ps1.
- .gitignore and .gitattributes.
- Windows desktop.ini folder-icon configuration, intentionally ignored by Git.

No app, server, shared package, Docker, or Matrix implementation files have been
created yet. Earlier temporary staging files in the CMS repository were deleted.
Do not touch the CMS repository.

## Remaining user inputs

These inputs are intentionally deferred and do not block the initial scaffold:

- Figma file URL and target frames.
- Final product name.
- Final app icon derived from the provisional folder branding.
- Production jurisdiction, launch markets, retention periods, and operator contact
  information.
- Git remote and repository visibility.

## Research references

- Swift on Windows: https://www.swift.org/install/windows/
- Vapor: https://github.com/vapor/vapor
- Matrix Rust SDK: https://github.com/matrix-org/matrix-rust-sdk
- Matrix Swift components: https://github.com/matrix-org/matrix-rust-components-swift
- Matrix E2EE guide: https://matrix.org/docs/matrix-concepts/end-to-end-encryption/
- Synapse administration: https://element-hq.github.io/synapse/latest/admin_api/
- Apple Keychain device-only accessibility:
  https://developer.apple.com/documentation/security/ksecattraccessiblewhenpasscodesetthisdeviceonly
- Apple App Review Guidelines:
  https://developer.apple.com/app-store/review/guidelines/
- Apple DeviceCheck and App Attest:
  https://developer.apple.com/documentation/devicecheck
- OWASP authentication:
  https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html
- OWASP password storage:
  https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html

## Instruction for the new Veil-rooted agent

Begin by running:

    Get-Location
    git rev-parse --show-toplevel
    git status --short --branch

Do not proceed unless the repository root is:

    C:\Users\GorjanB\Gorjan\Desktop\Veil

Then read PROJECT_HANDOFF.md and notes.md, implement the local proof of concept in
the order above, run all checks available on Windows, document Mac-only validation,
update notes.md, and commit completed work using the existing Git identity.
