# Design System: ScribeWeb

## 1. Visual Theme & Atmosphere
A restrained, gallery-airy interface with confident asymmetric layouts and fluid spring-physics motion. The atmosphere is clinical yet warm — reflecting a premium macOS native application aesthetic, utilizing an iridescent, organically shifting background to create depth without neon slop. Density is balanced (5), Variance is offset (6), and Motion is fluid CSS choreography (7).

## 2. Color Palette & Roles
- **Canvas White** (#FAFAFA) — Primary background surface
- **Pure Surface** (#FFFFFF) — Card and container fill
- **Deep Charcoal** (#111111) — Primary text, deep depth
- **Muted Steel** (#666666) — Secondary text, metadata
- **Whisper Border** (rgba(0,0,0,0.06)) — Card borders, 1px structural lines
- **Iridescent Mesh** (Subtle pastels: #fdfbfb, #ebedee, #e0c3fc, #8ec5fc) — Used exclusively for the shifting background mesh to create premium uniqueness.
(No pure black. No AI Purple/Blue neon. No oversaturated gradients.)

## 3. Typography Rules
- **Display:** `ui-rounded, 'SF Pro Rounded', system-ui, sans-serif` for heavy logos (SCRIBE SYSTEM). `system-ui, -apple-system, sans-serif` for all main headlines. Track-tight (-2px), controlled scale, weight-driven hierarchy.
- **Body:** `system-ui, -apple-system, sans-serif` — Relaxed leading, 65ch max-width.
- **Mono:** `ui-monospace, SFMono-Regular` — For code, metadata, typing demo.
- **Banned:** `Inter` (banned for premium display contexts), generic serif fonts, oversized gradients.

## 4. Component Stylings
* **Buttons:** Flat, tactile translate on active/hover. No outer glow. 
* **Cards (Bento):** Generously rounded corners (24px). Diffused whisper shadow (0 12px 32px rgba(0,0,0,0.08)).
* **Settings Window Wrapper:** Replicates native macOS window. 12px border radius, thin border, shadow for elevation. Includes native traffic lights.
* **Hero Background:** Slow-moving `meshShift` keyframe animation covering the hero viewport.

## 5. Layout Principles
Grid-first architecture. Asymmetric splits for sections. Max-width 1200px containment. Clean spatial separation always. No flexbox percentage math hacks.

## 6. Motion & Interaction
- **Spring Physics:** `cubic-bezier(0.16, 1, 0.3, 1)` for all reveals and translates.
- **Background Loop:** Perpetual micro-loop (15s duration) on the iridescent background.
- **Staggered Orchestration:** Cascade delays for the hero waterfall reveal.

## 7. Anti-Patterns (Banned)
- No emojis anywhere (unless explicitly demonstrating a feature).
- No pure black (`#000000`).
- No neon/outer glow shadows.
- No 3-column equal card layouts (use asymmetric bento).
- No generic AI copywriting clichés.
- No broken image links.
- No generic Bootstrap margins/paddings.
