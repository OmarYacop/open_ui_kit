---
name: Open UI Kit
description: Neutral, token-driven Flutter components for coherent adaptive interfaces.
colors:
  light-background: "#FFFFFF"
  light-surface: "#FFFFFF"
  light-surface-muted: "#F5F5F5"
  light-surface-inverse: "#0A0A0A"
  light-border: "#E5E5E5"
  light-input: "#E5E5E5"
  light-border-strong: "#D4D4D4"
  light-text-primary: "#0A0A0A"
  light-text-muted: "#737373"
  light-text-inverse: "#FAFAFA"
  light-primary: "#0A0A0A"
  light-on-primary: "#FAFAFA"
  light-secondary: "#F5F5F5"
  light-on-secondary: "#0A0A0A"
  light-danger: "#DC2626"
  light-on-danger: "#FFFFFF"
  light-success: "#16A34A"
  light-warning: "#D97706"
  light-focus-ring: "#A1A1A1"
  light-overlay: "rgba(0, 0, 0, 0.6)"
  dark-background: "#0A0A0A"
  dark-surface: "#171717"
  dark-surface-muted: "#262626"
  dark-surface-inverse: "#FAFAFA"
  dark-border: "#262626"
  dark-input: "rgba(255, 255, 255, 0.1490196078)"
  dark-border-strong: "#404040"
  dark-text-primary: "#FAFAFA"
  dark-text-muted: "#A3A3A3"
  dark-text-inverse: "#0A0A0A"
  dark-primary: "#FAFAFA"
  dark-on-primary: "#0A0A0A"
  dark-secondary: "#262626"
  dark-on-secondary: "#FAFAFA"
  dark-danger: "#EF4444"
  dark-on-danger: "#FAFAFA"
  dark-success: "#22C55E"
  dark-warning: "#F59E0B"
  dark-focus-ring: "#737373"
  dark-overlay: "rgba(0, 0, 0, 0.7019607843)"
typography:
  display-xl:
    fontFamily: "system-ui, sans-serif"
    fontSize: "34px"
    fontWeight: 700
    lineHeight: 1.15
    letterSpacing: "-0.4px"
  display-lg:
    fontFamily: "system-ui, sans-serif"
    fontSize: "32px"
    fontWeight: 700
    lineHeight: 1.15
    letterSpacing: "-0.5px"
  display-md:
    fontFamily: "system-ui, sans-serif"
    fontSize: "28px"
    fontWeight: 700
    lineHeight: 1.2
    letterSpacing: "-0.3px"
  title:
    fontFamily: "system-ui, sans-serif"
    fontSize: "24px"
    fontWeight: 700
    lineHeight: 1.2
    letterSpacing: "-0.2px"
  heading:
    fontFamily: "system-ui, sans-serif"
    fontSize: "20px"
    fontWeight: 600
    lineHeight: 1.25
  subheading:
    fontFamily: "system-ui, sans-serif"
    fontSize: "17px"
    fontWeight: 600
    lineHeight: 1.3
  body-lg:
    fontFamily: "system-ui, sans-serif"
    fontSize: "17px"
    fontWeight: 400
    lineHeight: 1.5
  body:
    fontFamily: "system-ui, sans-serif"
    fontSize: "16px"
    fontWeight: 400
    lineHeight: 1.45
  body-sm:
    fontFamily: "system-ui, sans-serif"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.4
  label:
    fontFamily: "system-ui, sans-serif"
    fontSize: "14px"
    fontWeight: 500
    lineHeight: 1.3
  label-sm:
    fontFamily: "system-ui, sans-serif"
    fontSize: "13px"
    fontWeight: 500
    lineHeight: 1.3
  caption:
    fontFamily: "system-ui, sans-serif"
    fontSize: "13px"
    fontWeight: 400
    lineHeight: 1.3
    letterSpacing: "0.1px"
  micro:
    fontFamily: "system-ui, sans-serif"
    fontSize: "12px"
    fontWeight: 500
    lineHeight: 1.25
    letterSpacing: "0.1px"
  mono:
    fontFamily: "Menlo, Courier, monospace"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.4
rounded:
  none: "0px"
  xs: "6px"
  sm: "10px"
  md: "12px"
  lg: "16px"
  xl: "24px"
  pill: "999px"
spacing:
  x0: "0px"
  x1: "4px"
  x2: "8px"
  x3: "12px"
  x4: "16px"
  x5: "20px"
  x6: "24px"
  x8: "32px"
  x10: "40px"
  x12: "48px"
  x16: "64px"
components:
  button-primary:
    backgroundColor: "{colors.light-primary}"
    textColor: "{colors.light-on-primary}"
    typography: "{typography.label}"
    rounded: "{rounded.md}"
    padding: "0 16px"
    height: "36px"
  button-neutral:
    backgroundColor: "{colors.light-surface}"
    textColor: "{colors.light-text-primary}"
    typography: "{typography.label}"
    rounded: "{rounded.md}"
    padding: "0 16px"
    height: "36px"
  input-standard:
    backgroundColor: "{colors.light-surface}"
    textColor: "{colors.light-text-primary}"
    typography: "{typography.body}"
    rounded: "{rounded.md}"
    padding: "0 16px"
    height: "40px"
  filter-chip-selected:
    backgroundColor: "{colors.light-primary}"
    textColor: "{colors.light-on-primary}"
    typography: "{typography.label}"
    rounded: "{rounded.pill}"
    padding: "8px 12px"
  badge-neutral:
    backgroundColor: "{colors.light-surface}"
    textColor: "{colors.light-text-primary}"
    typography: "{typography.caption}"
    rounded: "{rounded.pill}"
    padding: "4px 8px"
  card-standard:
    backgroundColor: "{colors.light-surface}"
    textColor: "{colors.light-text-primary}"
    rounded: "{rounded.xl}"
    padding: "24px"
  card-elevated:
    backgroundColor: "{colors.light-surface}"
    textColor: "{colors.light-text-primary}"
    rounded: "{rounded.xl}"
    padding: "24px"
  alert-success:
    backgroundColor: "rgba(22, 163, 74, 0.10)"
    textColor: "{colors.light-success}"
    rounded: "{rounded.lg}"
    padding: "16px 20px"
  page-navigation:
    backgroundColor: "{colors.light-surface}"
    textColor: "{colors.light-text-primary}"
    padding: "12px 16px"
  data-table:
    backgroundColor: "{colors.light-surface}"
    textColor: "{colors.light-text-primary}"
    rounded: "{rounded.lg}"
    padding: "1px"
---

# Design System: Open UI Kit

## Overview

**Creative North Star: "The Release Workbench"**

Open UI Kit feels like a well-kept technical workbench: calm enough to disappear during focused work, precise enough that every boundary and state is legible, and flexible enough to reorganize around the available viewport. The visual system is composition-first. Real controls cooperate inside believable application surfaces instead of presenting themselves as decorative specimens.

The identity is intentionally neutral and framework-independent. Platform system typography, near-black and near-white contrast, quiet filled controls, exact one-pixel borders, and restrained elevation form the base. Semantic intent colors appear only when status or consequence needs a distinct voice; motion confirms state and continuity without becoming spectacle.

**Key Characteristics:**

- Neutral light and dark schemes with semantic role parity.
- A compact semantic type scale rendered in the platform system sans.
- A 4-point spatial rhythm with comfortable 44px interaction targets.
- Precise borders and tonal fills before shadows.
- Rounded, contained geometry that remains crisp rather than soft or ornamental.
- Adaptive composition with accessible semantics, RTL-safe directionality, and reduced-motion support.

## Colors

The palette is a neutral ladder anchored by Quiet Ink and Paper White, with green, red, and amber reserved for semantic feedback.

### Primary

- **Quiet Ink / Paper White:** The primary role is near-black in light appearance and near-white in dark appearance. Use it for the clearest action, selected controls, and high-contrast interactive emphasis.
- **Opposing Canvas:** The on-primary role always flips to the opposite end of the neutral range so filled controls remain direct and legible.

### Secondary

- **Soft Neutral:** Secondary surfaces use the muted neutral fill with primary text. They identify lower-emphasis controls and statuses without introducing another brand hue.

### Tertiary

- **Check Green:** Success is the sole non-neutral accent in the release showcase. Use it for completed, healthy, or confirmed states—not decoration.
- **Action Red:** Danger identifies errors and destructive consequences. Components normally apply it as a soft wash with red foreground rather than a solid red block.
- **Caution Amber:** Warning identifies states that need attention without implying failure.

### Neutral

- **Canvas:** Background provides the page field; it is pure white in light appearance and near-black in dark appearance.
- **Calm Surface:** Surface holds cards, fields, menus, and popovers. Dark appearance lifts it one neutral step above the page.
- **Inset Neutral:** Surface-muted groups secondary information, hover states, schedule summaries, and disabled fields.
- **Hairline:** Border and input roles provide the default one-pixel structure. Border-strong is reserved for stronger separation and today/focus-adjacent markers.
- **Working Text:** Text-primary carries essential content; text-muted carries helpers, metadata, dates, and supporting explanations.
- **Focus Gray:** Focus-ring is deliberately neutral so keyboard focus stays visible without competing with semantic status colors.

### Named Rules

**The Semantic Color Rule.** Green, red, and amber communicate status or consequence; they are not general decoration.

**The Scheme Parity Rule.** Preserve semantic roles when changing appearance. Dark mode is a composed token set, not an inversion filter.

## Typography

**Display Font:** Platform system sans (resolved by Flutter from an unset token font family)

**Body Font:** Platform system sans (resolved by Flutter from an unset token font family)

**Label/Mono Font:** Platform system sans for labels; Menlo, Courier, then monospace for code and commands

**Character:** Compact, direct, and practical. Weight and a small amount of negative tracking establish hierarchy; muted color separates supporting copy without shrinking it into illegibility.

### Hierarchy

- **Display XL** (700, 34px, 1.15): Highest-level product or screen identity.
- **Display LG** (700, 32px, 1.15): Prominent showcase and page titles.
- **Display MD** (700, 28px, 1.2): Compact display moments on smaller surfaces.
- **Title** (700, 24px, 1.2): Major section titles below display level.
- **Heading** (600, 20px, 1.25): Page chrome and strong section headings.
- **Subheading** (600, 17px, 1.3): Card titles and compact surface headings.
- **Body Large** (400, 17px, 1.5): Lead copy and roomy descriptive text.
- **Body** (400, 16px, 1.45): Default reading and control-adjacent text.
- **Body Small** (400, 14px, 1.4): Compact content and table values.
- **Label** (500, 14px, 1.3): Form labels, buttons, selected dates, and emphasized metadata.
- **Label Small** (500, 13px, 1.3): Dense control labels.
- **Caption** (400, 13px, 1.3): Helpers, subtitles, table headers, and dates.
- **Micro** (500, 12px, 1.25): The smallest supported utility role.
- **Mono** (400, 14px, 1.4): Installation commands and technical literals.

### Named Rules

**The Semantic Type Rule.** Choose the nearest existing text role before applying a local style override; components inherit the scale through `UiText`.

## Layout

The canonical adaptive classifier treats widths below 600 logical pixels as phone, 600–899 as tablet, and 900 or more as desktop. Page patterns switch compact filters and secondary content into a vertical order on phones, then arrange them as fixed side panes around a flexible body on tablet and desktop. Safe-area ownership stays with page patterns and scaffolds.

Spacing follows a 4-point base from 0 through 64px. Common control gaps are 4–12px; card chrome uses 16px vertically and 24px horizontally; default card content uses 24px. The showcase is constrained to a 1240px content width, uses 20px horizontal page padding below 720px and 48px at larger sizes, and switches its asymmetric 6:5 workspace from two columns to one below 980px. Its data table hides secondary columns below 640px rather than forcing horizontal overflow.

**The Adaptive Hierarchy Rule.** Preserve information order while changing composition: primary work first, supporting work second, structured results last.

## Elevation & Depth

The system uses a hybrid of tonal layering, borders, and restrained shadows. Standard, outlined, and muted cards rely on surface color plus a one-pixel border. The elevated card adds only the small ambient shadow; medium and large shadows are reserved for overlays or genuinely floating layers.

### Shadow Vocabulary

- **None** (`[]`): Default for inline surfaces and containers.
- **Ambient Small** (`0 1px 2px rgba(0, 0, 0, 0.051)`): Slight lift for the primary work area and low floating surfaces.
- **Overlay Medium** (`0 4px 6px rgba(0, 0, 0, 0.102), 0 2px 2px rgba(0, 0, 0, 0.059)`): Menus, selection toolbars, and mid-level overlays.
- **Overlay Large** (`0 10px 16px rgba(0, 0, 0, 0.102), 0 4px 6px rgba(0, 0, 0, 0.059)`): High floating layers that need clear separation.

### Named Rules

**The Border-Before-Shadow Rule.** Use a one-pixel semantic border and tonal separation for structure; add shadow only when a surface is actually elevated.

## Shapes

Open UI Kit uses a stepped rounded vocabulary: 6px for compact details, 10px for small controls and calendar affordances, 12px for buttons and fields, 16px for alerts, tables, and date-picker chrome, 24px for cards, and a 999px pill for badges, chips, switches, and fully rounded indicators. The result is friendly but engineered: shapes are consistent, borders stay crisp, and rounded clipping belongs to the component that owns the surface.

**The Owned Chrome Rule.** When a picker or field is embedded in an already framed card, sheet, or drawer, remove its duplicate border and padding rather than nesting visible containers.

## Components

Components feel quietly tactile and composition-first. Their public state APIs drive color, opacity, focus, and semantics instead of wrapper-level interaction hacks.

### Buttons

- **Shape:** Gently rounded rectangular controls (12px radius) with a 44px minimum tap target around visual heights of 32px, 36px, or 40px.
- **Primary:** Near-black on light and near-white on dark, with the opposing on-primary text color. Medium buttons use 16px horizontal padding; small use 12px and large use 24px.
- **Hover / Focus:** Filled buttons darken on hover and press; transparent intents receive a muted tonal fill. Press scales to 97%. Focus uses a crisp 2px neutral ring offset 2px from the shape. Disabled and loading states reduce the complete control to 50% opacity; loading replaces content with a spinner.
- **Neutral / Secondary:** Bordered by default. Neutral uses the surface color and restrained foreground; secondary uses the muted fill. Remove the border only when an already elevated or framed parent owns the boundary.
- **Ghost / Link:** Transparent at rest. Ghost gains a muted hover wash; link underlines on hover or press.

### Chips

- **Style:** Filter chips are interactive pill controls with a one-pixel border and 8px by 12px medium padding. Selected chips use primary/on-primary; unselected chips use surface/text-primary.
- **State:** Hover and press darken the relevant fill, press scales to 97%, focus uses the shared ring, and disabled chips use 50% opacity. Selection is exposed explicitly to semantics.
- **Badges:** Passive status badges use tighter 4px by 8px small padding, caption type at medium weight, and a pill silhouette. Outlined badges remain transparent with an intent-colored border.

### Cards / Containers

- **Corner Style:** Broad but controlled rounding (24px radius).
- **Background:** Standard and elevated cards use the semantic card surface; muted cards use the muted surface; outlined cards are transparent.
- **Shadow Strategy:** Only the elevated variant adds Ambient Small.
- **Border:** Every card variant carries a one-pixel semantic border.
- **Internal Padding:** Card content defaults to 24px. Header and footer chrome use 24px horizontal and 16px vertical padding, separated from content by dividers.
- **Interaction:** Optional pressable cards darken by 1.5% on hover and 3% on press without losing their header, body, or footer slots.

### Inputs / Fields

- **Style:** A surface-filled field with a one-pixel input border, 12px radius, body type, and a 40px default visual height. Large fields use 16px horizontal padding; smaller fields use 12px.
- **Focus:** The border switches to the ring color and a separate 3px ring appears 3px outside the control over 150ms with standard easing.
- **Error / Disabled:** Error uses the destructive border plus a translucent outer ring and a live-region caption. Disabled fields use muted fill and foreground and suppress editing; read-only fields remain focusable for selection and copying.
- **Embedded:** Removes the field surface, border, and focus ring so a compound parent can own the complete chrome.

### Navigation

- **Style:** Generated page chrome uses the surface color, 16px horizontal and 12px vertical padding, semantic heading/body-small type, and optional one-pixel dividers. Directional back and forward icons resolve from reading direction.
- **Adaptive behavior:** Navigation and side surfaces switch by canonical phone, tablet, and desktop form factors; system back, safe insets, and platform expectations remain intact.

### Alerts

- **Style:** Inline notices use a 16px radius, 20px horizontal and 16px vertical padding, an 18px intent-colored icon, and a one-pixel border.
- **Intent:** Success, warning, and destructive alerts use 8–10% tinted fills and 35% tinted borders. Neutral and informational alerts use the muted surface and semantic border.
- **Semantics:** Warning and destructive alerts publish live regions; all titled alerts expose a concise combined label.

### Data Tables and Pickers

- **Data tables:** Use a surface background, one-pixel border, 16px outer radius, muted caption headers, 12px horizontal cell padding, and 44px default row extent. Selected rows receive an 8% primary tint; interactive hover uses the muted surface.
- **Date pickers:** Use 16px outer chrome, compact 10px header affordances, tokenized selected-day fills, and directional navigation. Set `showBorder: false` and zero chrome padding when the picker sits inside another surface.

### Motion and State

- **Durations:** Instant 0ms, faster 20ms, fast 120ms, standard 200ms, slow 320ms, and extra-slow 500ms.
- **Easing:** Ease-out cubic is standard; ease-out back is reserved for emphasized motion; linear is available for continuous progress.
- **Reduced motion:** All non-instant duration tokens collapse to zero and emphasized/standard easing resolves to linear.

## Do's and Don'ts

### Do:

- **Do** resolve visual values through `UiThemeTokens` so light, dark, custom brand, and reduced-motion behavior stay coherent.
- **Do** use semantic typography, color, intent, and form-factor roles before local overrides.
- **Do** preserve a minimum 44px interaction target even when the painted control is visually compact.
- **Do** let page patterns own spacing, safe insets, and responsive rearrangement.
- **Do** use semantic labels, visible focus, RTL-safe directional icons, and state properties supplied by the public component API.

### Don't:

- **Don't** introduce Material or Cupertino styling inside the kit; platform integration belongs at the boundary.
- **Don't** stack cards, borders, or picker chrome when the parent surface already provides containment.
- **Don't** use success, warning, or danger colors as general-purpose decoration.
- **Don't** force desktop columns into compact viewports; reorder or omit secondary information deliberately.
- **Don't** bypass disabled, loading, selection, or focus semantics with `IgnorePointer` or ad hoc gesture wrappers.
