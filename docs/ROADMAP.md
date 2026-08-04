# Roadmap to 1.0

This roadmap is executable: every checkbox requires implementation plus the
listed evidence. A successful build alone is not evidence for runtime behavior.

## 0.3 — Foundation

- [x] Discover `_fbx-api._tcp` services with Bonjour and expose actionable
  discovery errors.
- [x] Build the API base URL from discovery metadata and negotiate the major API
  version; retain a manual URL fallback.
- [x] Prefer HTTPS when the box advertises it.
- [x] Support multiple saved box profiles and an explicit active box.
- [x] Store app tokens in the private 0600 configuration file and migrate legacy Keychain data once.
- [x] Add a Settings window for boxes, refresh cadence, launch-at-login, and
  notifications.
- [x] Model offline, stale, permission, authentication, and transport failures.
- [x] Add deterministic API, configuration, and formatting tests.

Evidence: unit tests, a clean debug/release build, pairing against a real box,
and successful relaunch after credential migration.

## 0.4 — Dashboard and downloads

- [x] Unified dashboard with connection health, public address, live traffic,
  uptime, temperature, storage summary, and data freshness.
- [x] Complete download list with search, filters, sorting, task details, and
  explicit active/error/completed states.
- [x] Add magnet, remote URL, and local `.torrent` input.
- [x] Pause, resume, retry, remove task, and optionally erase data with safe
  confirmation.
- [x] Expose torrent files, priority, trackers, peers, and pieces when supported.
- [x] Notify on start, completion, and failure without duplicate notifications.

Evidence: mocked state-transition tests and real-box smoke tests.

## 0.5 — Files and storage

- [x] Browse all available storage roots with breadcrumb navigation.
- [x] Upload, download, rename, move, copy, create folders, and delete safely.
- [x] Support multi-selection, progress, cancellation, and collision handling.
- [x] Create and revoke file-sharing links.
- [x] Show disks, partitions, capacity, free space, and health when supported.

Evidence: filesystem contract tests, transfer tests, and destructive-action UI
confirmation tests.

## 0.6 — LAN, DHCP, and Wi-Fi

- [x] List active and known devices with hostname, IP, MAC, interface, reachability,
  and last activity.
- [x] Rename devices and expose useful device details.
- [x] Inspect DHCP configuration and static leases; safely edit supported fields.
- [x] Show Wi-Fi radios, SSIDs, channels, security, and connected stations.
- [x] Toggle Wi-Fi, guest access, and WPS when supported and permitted.
- [x] Generate a scannable guest-network QR code.

Evidence: decoding fixtures for supported firmware variants and real-box smoke
tests for every mutation.

## 0.7 — Network services and advanced modules

- [x] Inspect and manage port forwarding within the assigned IPv4 port range.
- [x] Inspect SMB, FTP, UPnP, remote access, and incoming-port configuration.
- [x] Add VPN client/server views when the box exposes stable endpoints.
- [x] Add parental profiles and access scheduling with permission-aware UI.
- [x] Add calls, contacts, and PVR modules behind capability detection.
- [x] Use WebSocket notifications where supported, with polling fallback.

Evidence: capability matrix, permission tests, and mutation smoke tests.

## 0.8 — Product quality

- [x] Custom app icon and stateful monochrome menu-bar assets.
- [x] WidgetKit widgets for connection and download state.
- [x] Italian and English localization with no user-visible hardcoded strings.
- [x] VoiceOver labels, keyboard navigation, sufficient contrast, reduced-motion
  behavior, and Dynamic Type-compatible layouts where macOS supports it.
- [x] Configurable refresh and notification policies.
- [x] Diagnostics export with secrets redacted.
- [x] CLI parity for discovery, profiles, status, downloads, files, and core network
  inspection; stable JSON output for automation.

Evidence: localization audit, accessibility inspection, widget previews, and CLI
snapshot tests.

## 1.0 — Distribution

- [x] Single-source versioning for app, CLI, Info.plist, and release artifacts.
- [x] Developer ID signing, hardened runtime, notarization, and stapling pipeline.
- [x] Sparkle update feed generation with EdDSA signatures.
- [x] GitHub Actions for format, lint, tests, builds, and release artifacts.
- [x] GitHub Release automation and a generated Homebrew cask.
- [x] Privacy, security, troubleshooting, development, and release documentation.
- [ ] Crash-free clean-install, upgrade, offline, revoked-token, and multi-box tests.

Evidence: CI on a tagged release candidate, Gatekeeper validation on a clean Mac,
Sparkle update from the previous version, and a completed release checklist.

Automated evidence: 30 unit/contract tests plus `Scripts/runtime-smoke.sh`,
which launches the release bundle in isolated clean-install,
legacy-upgrade/offline, revoked-token, and multi-box scenarios. The full suite
passes in CI from a clean commit as of 2026-08-04 (the revoked-token scenario
caught a real Swift 6 actor-isolation crash in the notification-permission
request before ever shipping). The checkbox remains open until the external
release-candidate evidence above is recorded.
