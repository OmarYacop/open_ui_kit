# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Users

Flutter developers and product teams evaluating or building application interfaces with a reusable, framework-neutral component kit.

## Product Purpose

Open UI Kit provides token-driven Flutter primitives, components, and page patterns so applications can ship coherent interfaces without coupling their visual system to Material or Cupertino styling. Success means developers can understand the kit quickly, select an existing component confidently, and compose accessible interfaces without recreating common UI behavior.

## Positioning

The package combines shadcn-inspired composability with Flutter widgets-layer implementation, adaptive behavior, shared design tokens, and reusable motion primitives.

## Operating Context

Developers discover the package through GitHub and pub.dev, evaluate it through repository documentation and the example app, then integrate it through the public `package:open_ui_kit/open_ui_kit.dart` barrel. Contributors validate behavior with focused widget tests and deterministic visual goldens.

## Capabilities and Constraints

- The public library includes foundation tokens, forms, feedback, navigation, overlays, pickers, data display, chat, schedule, and responsive page patterns.
- Components must remain independent of Material and Cupertino styling inside the package.
- Visual values should resolve through `UiThemeTokens` rather than hard-coded application styling.
- Public surfaces must preserve accessibility, RTL behavior, responsive layout, reduced motion, and disabled/loading semantics.
- Existing golden baselines are test artifacts and are not suitable as public showcase images because deterministic test typography obscures real copy.

## Brand Commitments

The product name is Open UI Kit. Its documented voice is direct, technical, and practical. Its visual language uses neutral defaults, selective brand color, calm surfaces, precise borders, restrained elevation, and purposeful motion.

## Evidence on Hand

- The implementation and public API under `lib/` are the source of truth for component appearance and behavior.
- `example/` contains runnable compositions using the real package.
- `test/goldens/goldens/` and `example/test/goldens/` provide regression evidence but are not public marketing assets.
- No testimonials, customer logos, adoption metrics, or commercial claims are available and none should be fabricated.

## Product Principles

- Show real widgets doing recognizable work before explaining their APIs.
- Prefer existing kit components and tokens over showcase-only imitations.
- Make visual documentation reproducible so it stays aligned with the package.
- Keep examples useful as both evaluation surfaces and implementation references.
- Treat accessibility and adaptive behavior as product features, not footnotes.

## Accessibility & Inclusion

Public examples must retain semantic labels, readable contrast, keyboard and focus behavior, RTL-safe directional icons, responsive layouts, and reduced-motion support already expected by the package.
