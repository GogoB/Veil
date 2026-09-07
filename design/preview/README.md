# Veil — interface study 01

An interactive browser study of Discover and the anonymous composer, created
before the SwiftUI application. This is a visual and interaction prototype.

## Open

From the repository root:

    node design/preview/serve.cjs

Then open http://127.0.0.1:4173. No packages or build step are needed. The server
binds only to the local machine. Set VEIL_PREVIEW_PORT to use another port.

You can also open index.html directly; clipboard support depends on the browser.
On desktop both screens appear together. Below 860px, the screen selector switches
between Discover and Composer. Acid/cyan accents and light/dark appearances can
be compared without changing the composition.

## Try

- Switch Discover/Following and filter by topic. Following excludes anonymous posts.
- Like a post, open replies, and add a demo comment.
- Search public post text/topics/profile names. Thread aliases are not searchable.
- Hide posts or mute topics; reset them from feed preferences.
- Switch Profile/Anonymous and Generated alias/Custom/Sigil only.
- Regenerate an alias/sigil; reserved service names are rejected on posting.
- Add up to four JPEG/PNG/WebP images, remove them, and mark sensitive media.
- Choose an expiration preset, then post into the local Discover feed.
- Open Veiled Activity to see anonymous posts created in this tab.

The Inbox is an empty-state composition. Image processing happens locally and
re-encodes selected files. All changes are held in memory and reset on reload;
there are no API requests, accounts, authentication, messaging, persistent
storage, or real expiration jobs. Expiration is a presentation choice in this
study. The prototype does not implement or prove server-side privacy, encryption,
blocking, recovery, or platform-native accessibility.

The UI supports keyboard focus, labelled controls, modal focus containment,
reduced motion, and increased contrast. Native Dynamic Type, VoiceOver, safe-area
behaviour and Apple material rendering require the eventual SwiftUI/Mac pass.

## Design choices under review

The saved screenshots in `screenshots/` include the desktop dark/light/cyan
comparisons and narrow-screen layouts. The interactions were checked in hidden
Edge on Windows at 1440px, 820px, 390px, and 320px. No page runtime exceptions or
third-party page requests were observed. Native Apple rendering is outstanding.

- Graphite reading surfaces, warm white text, sparse acid-lime accent.
- Cool cyan alternate; darker accessible accent equivalents in light mode.
- System sans-serif body text with brief monospaced metadata.
- Original geometric thread sigils and a provisional monochrome Veil wordmark.
- Fine feed separators; material treatment limited to navigation.
- Explicit identity preview before posting.

The typography uses local system fonts. Windows shows Segoe UI; Apple systems
use their system font. Proportions will need a native review before token values
are treated as final. The original branding files have not been overwritten.

## Image credit

The local demonstration photograph is by **Osman Rana**, from
[Unsplash](https://unsplash.com/photos/grayscale-photo-of-concrete-building-5LED2xbiKvk).
Downloaded as a resized JPEG for this design study. The sample post persona and
copy are fictional and do not identify the photographer as a Veil user.

All other graphics are original code-native SVGs. Reference projects and the
confirmed user direction are recorded in ../../branding/DESIGN_DIRECTION.md
(from the repository root: branding/DESIGN_DIRECTION.md).
