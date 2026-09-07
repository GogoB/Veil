# Veil visual direction

Researched: 2026-09-07. The first native SwiftUI implementation is ready for its
Mac build and visual review.

## Confirmed preference

The user wants cyberpunk mixed with an Apple-like look and feel, avoiding the
usual generic AI-generated appearance. The exact palette and screen designs are
still proposals. Existing Figma designs have not yet been supplied.

## References and interpretation

- [Apple's Liquid Glass introduction](https://www.apple.com/newsroom/2025/06/apple-introduces-a-delightful-and-elegant-new-software-design/):
  Apple describes content-focused interfaces with fluid, translucent controls and
  navigation. Proposed use in Veil: clear hierarchy, spacious reading surfaces,
  familiar interactions, and selective translucent navigation.
- [Territory Studio's Blade Runner 2049 screen graphics](https://territorystudio.com/project/blade-runner-2049/):
  The studio developed physical and optical textures alongside utilitarian
  interfaces, including minimal geometric monochrome screens for Wallace Corp.
  Proposed use in Veil: precise geometry, restrained colour, and a distinctive
  visual language for aliases and sigils. Film interfaces are atmosphere
  references; mobile reading and touch interactions need their own treatment.
- [Nothing OS 3.0 design preview](https://nothing.community/d/17007-ama-nothing-os-30-with-yuri-software-design-lead):
  The official community introduction describes refined typography and dot-matrix
  animations. Proposed use in Veil: a small, consistent set of original graphic
  details that make the interface recognizable. Build Veil's own symbols.

These are reference projects, not claims about which design style is objectively
best. The choices below are a proposed synthesis for this product.

## Proposed visual system

- Start the first composition in dark mode: near-black graphite, slightly lighter
  surfaces, warm-white body text, and subdued but readable secondary text.
  Establish a matching light appearance before finalizing the system.
- Try acid yellow-green as the main accent, limited to primary actions, selected
  states, and small identity details. Compare icy cyan in the same layout before
  choosing. Reserve warning/error colours for their actual meanings.
- Use native system typography for posts, messages, and controls. Limit monospaced
  typography to brief metadata such as expiration labels. Keep body text readable
  at Dynamic Type sizes.
- Let posts share a continuous reading surface with fine separators and generous
  spacing. Use containers where grouping has a purpose.
- Use translucent material selectively for navigation and overlays; keep text
  backgrounds visually stable. The current iOS 16 target remains in the handoff;
  actual Liquid Glass adoption needs a separate compatibility decision.
- Give anonymous participants original geometric sigils, readable at avatar size.
  Preserve thread/conversation scope: no visual identifier may introduce stable
  public linkage across threads or conversations.
- Express identity changes with the sigil, clear text, and a short transition.
  Use motion to explain a state change; respect reduced-motion preferences.
- Keep standard touch behaviour and accessible labels. Colour alone must not
  distinguish anonymous and attributed identities.

## Specific first-screen ideas

- Discover: a restrained title and feed switch, generous post typography, images
  with room to breathe, thin separators, and compact anonymous identity details.
- Composer: make the attributed/anonymous choice unmistakable before publishing;
  preview the selected alias or sigil beside the identity label.
- Veiled Activity: use the same visual system with a stronger sigil motif and
  clear ownership controls. Treat its private purpose as a useful distinction.
- Messages: prioritize the conversation; make request/accepted state and identity
  explicit with concise labels.

## Patterns to avoid

Avoid default purple-blue gradients, glowing borders around every component,
glass cards behind every post, dashboard-style bento layouts for social feeds,
decorative terminal text, fake telemetry, constant glitch effects, tiny uppercase
body copy, and generic padlock/shield decoration. The provisional violet folder
icon is not a commitment to violet as the app's main colour.

## Proposed next design step

Build one detailed Discover screen and one composer state with realistic content
to assess the balance, spacing, identity cues, and accent colour before spreading
the styling across every screen. Use the existing Figma frames when available.

The first native implementation is now available in [ios](../ios/README.md). It
implements the visual direction in SwiftUI with dark/light/system appearance and
acid/cyan accent choices. The visual direction remains a proposal until the user
has reviewed it on an iPhone simulator or device.

## Reasoning recommendation

High is the proposed default for implementation and design work. Use Extra High,
where available, for privacy boundaries, recovery, E2EE integration, and difficult
cross-system investigations. Medium is sufficient for small specified visual or
copy changes. These are recommendations; no model or reasoning setting changed.

[OpenAI's Codex prompting guide](https://developers.openai.com/cookbook/examples/gpt-5/codex_prompting_guide)
recommends Medium for a general balance of speed and intelligence and High or
Extra High for difficult tasks. Applying the higher settings to Veil's sensitive
architecture is a project-specific judgment. Visual quality also needs concrete
references, rendered comparison, and iteration.
