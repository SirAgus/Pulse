# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

Pulse is currently a native macOS 14+ application built with SwiftUI. The schema value `adaptive` records that the interface must adapt between the Mac's notch, menu-bar displays without a notch, compact overlays, and expanded working surfaces; it does not imply support for non-macOS platforms.

## Users

Mac users who want to control music, focus sessions, alarms, notes, clipboard history, connected devices, and system status without leaving their current task.

## Product Purpose

Pulse turns the otherwise passive notch or menu-bar area into a glanceable, interactive control surface. Success means the user can understand state and complete a small action in seconds without opening a separate full-size application.

## Positioning

Unlike a conventional menu-bar utility or dashboard window, Pulse expands directly from the physical notch into contextual controls and collapses back into ambient status.

## Operating Context

Pulse is used while another application remains primary. It appears in compact and expanded states, under varied desktop backgrounds, and often during focused work, media playback, meetings, or timed sessions. Interactions must be fast, reversible, and understandable without onboarding.

## Capabilities and Constraints

- Preserve all current functionality: music and volume control, Pomodoro and timers, alarms, system and connectivity widgets, notes, clipboard history, camera, app shortcuts, and customization.
- Preserve the notch-aware geometry and compact/expanded behavior.
- Existing interface copy may be clarified, shortened, and made more consistent.
- The application targets macOS 14+ and uses native SwiftUI/AppKit.
- Existing permission requirements and integrations remain unchanged.
- The compact state has severe spatial constraints; critical state and the primary action take precedence over decorative content.

## Brand Commitments

- Preserve the product name `PULSE`.
- Preserve the idea of a living, responsive surface attached to the Mac's notch.
- The interface should support sustained work rather than compete with it.

## Evidence on Hand

- Existing implementation in `Sources/DynamicIsland/`.
- Current product and installation documentation in `README.md`.
- Current interface captures in `Resources/screenshots/`.
- Existing logo and application icon in `Resources/`.
- No testimonials, usage benchmarks, customer claims, or commercial proof are available and none should be fabricated.

## Product Principles

1. Glance first: important state must be readable before interaction.
2. One interruption, one clear action: expanded views should lead with the task that caused the user to open them.
3. Context over navigation: show controls relevant to the active mode before the broader widget catalog.
4. Native trust: behavior, accessibility, keyboard support, and system conventions should feel at home on macOS.
5. Calm density: fit meaningful capability into a small surface without turning every item into an equal-weight card.

## Accessibility & Inclusion

Maintain legible contrast across user-selectable backgrounds, support Reduce Motion, preserve keyboard and pointer affordances, avoid relying on color alone for state, and provide descriptive accessibility labels for icon-only controls.
