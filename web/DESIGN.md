# Design System: Scribe Pro Cloud Landing & Billing Portal

## 1. Visual Theme & Atmosphere
A dark, crystal-glass Apple-adjacent aesthetic (`DESIGN_VARIANCE: 7 / MOTION_INTENSITY: 6 / VISUAL_DENSITY: 4`).
Deep obsidian background surface with subtle radial emerald mesh ambient glows, glassmorphic floating cards (`backdrop-filter: blur(24px)`), and crisp high-contrast typography.

## 2. Color Palette & Roles
- **Canvas Obsidian** (`#09090B`) — Base background
- **Glass Surface** (`rgba(255, 255, 255, 0.03)`) — Card background
- **Border Specular** (`rgba(255, 255, 255, 0.08)`) — Subtle 1px inner structural border
- **Pure White Text** (`#FAFAFA`) — Primary headlines
- **Muted Steel** (`#A1A1AA`) — Secondary body copy
- **Electric Emerald Accent** (`#10B981`) — Singular accent color for Pro status, CTAs, and active pricing state

## 3. Typography Rules
- **Display & Headlines:** `Geist Display` / `Cabinet Grotesk` / Sans-serif (`system-ui, -apple-system, sans-serif`) — `letter-spacing: -0.03em`, `line-height: 1.1`.
- **Body Text:** `system-ui` relaxed leading, max 65 characters width.
- **Mono:** `Geist Mono` / `JetBrains Mono` / `ui-monospace` for code, license keys, and API tokens.
- **Banned:** `Inter`, `Times New Roman`, generic purple glows, over-saturated gradient text.

## 4. Component Stylings
- **Buttons:** Tactile `-1px` transform on active. Electric Emerald fill for primary CTA, glass outline for secondary.
- **Cards:** 16px corner radius, subtle inset highlight `shadow-[inset_0_1px_0_rgba(255,255,255,0.1)]`.
- **Pricing Grid:** Asymmetric highlight on Pro tier ($9.99/mo) with active badge.

## 5. Anti-Patterns (Banned)
- No emojis
- No pure black (`#000000`)
- No AI purple gradients
- No equal 3-column generic card layouts
- No fake round numbers (`99.99%`)
