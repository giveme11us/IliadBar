# IliadBar vision

IliadBar is the native macOS control center for iliadbox and compatible
Freebox OS gateways. It keeps the state of the home connection visible,
makes common actions immediate, and exposes advanced controls without forcing
people into a browser-based administration console.

## Product principles

- **Local first.** Box data and credentials stay on the Mac. Network calls go
  directly to the box.
- **Discover, do not assume.** Find boxes through Bonjour, negotiate the API
  version, and support more than one saved box.
- **Status before controls.** Show whether information is live, stale, offline,
  or unavailable because a permission is missing.
- **Safe administration.** Destructive operations require explicit
  confirmation and describe exactly what they remove.
- **Native and compact.** The menu-bar panel is for glanceable state and common
  actions; deeper configuration lives in a proper Settings window.
- **One core, multiple surfaces.** The app, CLI, widgets, and tests use the same
  typed API client and domain models.

## Visual direction

IliadBar should feel like a compact network instrument made for macOS. The
interface uses system typography for familiarity, monospaced digits for live
measurements, restrained iliad red for identity, and semantic system colors
for state. Its signature is a custom box-signal glyph whose segments represent
connectivity and activity at menu-bar scale.

## Definition of 1.0

Version 1.0 is a signed, notarized, updateable app with automatic discovery,
secure credential storage, resilient offline behavior, tested API flows, a
complete dashboard, download and file management, core network controls,
localization, accessibility, CLI parity for essential operations, and a
documented release process.
