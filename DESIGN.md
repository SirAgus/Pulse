---
name: Pulse
description: A living telemetry ribbon that expands from the Mac notch into focused controls.
colors:
  carbon: "#0E1012"
  raised-carbon: "#171B1E"
  signal: "#54E6C7"
  text-primary: "#FFFFFF"
  text-secondary: "rgba(255,255,255,0.62)"
  divider: "rgba(255,255,255,0.10)"
typography:
  headline:
    fontFamily: "-apple-system, BlinkMacSystemFont, sans-serif"
    fontSize: "18px"
    fontWeight: 600
    lineHeight: 1.2
  body:
    fontFamily: "-apple-system, BlinkMacSystemFont, sans-serif"
    fontSize: "11px"
    fontWeight: 500
    lineHeight: 1.35
  readout:
    fontFamily: "ui-monospace, SFMono-Regular, monospace"
    fontSize: "42px"
    fontWeight: 600
    lineHeight: 1
rounded:
  control: "8px"
  action: "10px"
  island: "24px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "20px"
components:
  button-primary:
    backgroundColor: "{colors.signal}"
    textColor: "{colors.carbon}"
    rounded: "{rounded.action}"
    height: "40px"
  telemetry-row:
    backgroundColor: "{colors.carbon}"
    textColor: "{colors.text-primary}"
    height: "36px"
---

# Design System: Pulse

## Overview

**Creative North Star: "Telemetry Ribbon"**

Pulse behaves like a continuous instrument attached to the physical notch. A thin signal path, precise readouts, and calm tonal fields make compact and expanded states feel like one surface changing resolution—not separate dashboards. The world borrows the discipline of mission telemetry and studio control strips without theatrical science-fiction chrome.

The system is dense but never busy. One dominant reading and one primary action lead each mode; secondary controls align to the same signal path and recede until relevant.

**Key Characteristics:**

- A continuous signal line connects state, navigation, and action.
- Matte carbon surfaces with mineral-white type and one spectral user accent.
- Native macOS typography, symbols, input behavior, and accessibility.
- Tonal grouping replaces stacks of floating cards.
- Motion shows continuity between compact and expanded states.

## Colors

**Strategy: Restrained.** Carbon and Raised Carbon carry the interface; Signal marks live state, progress, focus, and the current action. The user-selected accent replaces Signal when it is not white. Semantic green, amber, and red appear only for system meaning.

**The One Signal Rule.** On each surface, one accent owns the active path; do not scatter unrelated accent colors across neighboring controls.

## Typography

Use the macOS system family throughout. Rounded faces are reserved for timer or media values where their softer cadence communicates ongoing activity; monospaced digits are used for changing measurements.

**The Readout Rule.** Labels describe; numerals report. Labels stay small and quiet, while the value that answers the user's question is the strongest type on the surface.

## Layout

The notch is the origin. Content expands downward in aligned horizontal bands: ambient status, active mode, primary readout or action, then secondary tools. Compact states retain the same left-to-right order as their expanded counterpart.

Spacing follows a tight 4-point rhythm. The expanded dashboard is 520 pt wide; dense groups use tonal fields and alignment rather than individual containers. The interface remains usable on displays without a notch and across every current expanded mode.

## Elevation & Depth

Pulse is materially flat. Depth comes only from black-level separation and a restrained top highlight. The island and its internal content cast no shadows.

**The Single Object Rule.** The island is one shadowless silhouette; content inside it may not pretend to be a collection of separate windows.

## Shapes

The outer island keeps its notch-aware continuous silhouette with a 24 pt expanded radius. Internal controls use 8–10 pt corners, compact capsules only for binary selections, and hairline rails for measurements. Large generic rounded cards are not part of the system.

## Components

### Primary action

A 40 pt-high Signal field with Carbon text and a 10 pt continuous corner. Its label never wraps.

### Telemetry row

A 36 pt aligned band containing a 12 pt symbol, a single-line label, a 2 pt signal rail, and a right-aligned monospaced value. Rows are separated by one low-contrast hairline.

### Navigation

Seven equal-width icon targets sit above a continuous rail. The active mode uses white iconography, a three-point Signal marker, and the matching rail segment; inactive modes recede without receiving individual containers.

### Quick access control

Three columns of compact 38 pt controls use Raised Carbon as a shared tonal field. Icon, label, and optional badge remain on one line.

## Do's and Don'ts

### Do:

- **Do** make the active state readable before exposing secondary controls.
- **Do** use the signal path as a functional carrier for progress, playback, selection, or urgency.
- **Do** preserve familiar macOS symbols and input behavior.
- **Do** let inactive information recede through tone and typography.

### Don't:

- **Don't** place every feature in an equal-weight rounded card.
- **Don't** use glow, glass blur, or gradients as substitutes for hierarchy.
- **Don't** use uppercase tracking on ordinary labels or paragraphs.
- **Don't** animate decoration independently from state.
