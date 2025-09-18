Sonar Refactor and Improvement Plan (CODEX)

Overview

- Goal: Improve maintainability, reduce duplication, and prepare the app for future features while keeping the current UX intact.
- Scope: Architecture, UI structure, code quality, deprecations, packaging/CI, and a phased roadmap with low‑risk “quick wins”.

Current Architecture Snapshot

- App type: GTK4/Libadwaita Vala application (Meson build, Flatpak packaging).
- Key modules:
  - `src/application.vala`: App lifecycle, actions, About dialog, manual resource registration.
  - `src/main_window.vala`: Primary UI, tunnel controls, status banner, requests + history, export, filtering, toasts.
  - `src/server.vala`: Libsoup 3 HTTP server, request intake + sanitization.
  - `src/tunnel.vala`: Ngrok process + API management, token handling via GSettings.
  - `src/models.vala`: WebhookRequest, TunnelStatus, RequestStorage with JSON persistence.
  - `src/*_dialog.vala`: Preferences, Shortcuts, Statistics dialogs.
  - UI: Blueprint files under `data/ui/*.blp` compiled into gresources.

Key Findings

- Large files that over‑accumulate responsibilities:
  - `src/main_window.vala` (740 LOC): UI state machine, event wiring, history filtering/export, toasts, tunnel banner and actions.
  - `src/tunnel.vala` (447 LOC): Auth token IO, ngrok process lifecycle, API polling, settings, synchronization.
  - `src/models.vala` (428 LOC): Multiple models and persistence.
  - `src/application.vala` (397 LOC): Actions plus About/Release notes generation and manual resource handling.
  - `src/server.vala` (348 LOC): Routing + sanitization + response composition.

- Duplication and missing single source of truth:
  - HTTP method → CSS color mapping duplicated:
    - `src/request_row.vala:62` and `src/statistics_dialog.vala:243`.
  - Clipboard/toast helpers duplicated:
    - Copy URL + toast in `src/main_window.vala:263` vs. request copy helpers in `src/request_row.vala:151` and toast at `src/request_row.vala:159`.
  - JSON export logic appears in both requests and history paths:
    - Requests export `src/main_window.vala:416` onwards; history export builder `src/main_window.vala:574` onwards.

- Redundant or brittle patterns:
  - Manual resource loading despite static gresource linking.
    - `src/application.vala:172-196` loads `.gresource` from the filesystem. Resources are already compiled in via `data/ui/meson.build` and `src/meson.build`. This is redundant and can be dropped.
  - About/Release notes UI automation simulating focus/enter presses is brittle (`src/application.vala:211-258`). Consider explicit navigation instead of synthetic key flow.
  - Unused UI remnants in Blueprint:
    - `data/ui/main_window.blp` still defines `url_label` and `copy_url_button` not bound/used (commented out in `src/main_window.vala`), increasing mental overhead.
  - Global “kill all ngrok” (`src/tunnel.vala:332-358`) uses `pkill`, which may not be desirable or available in sandboxed contexts.

- Deprecations and API posture:
  - Using GTK4, Libadwaita 1.4, Libsoup 3: No obvious deprecations found in code or Blueprints during scan.
  - Blueprint syntax and Adwaita widgets look up to date.

Refactor Targets

1) Split oversized files by responsibility

- `src/main_window.vala` → split into focused components:
  - `src/ui/RequestsPage.vala`: Manages current requests list, clear/export, expansion coordination.
  - `src/ui/HistoryPage.vala`: Manages history view, search + method filter, export, delete, stats dialog.
  - `src/ui/TunnelBannerController.vala`: Encapsulates banner state and actions (copy URL, retry, setup token).
  - `src/ui/Toasts.vala` (or a generic `UiUtils.vala`): One place for adding toasts via `Adw.ToastOverlay`.
  - `MainWindow` stays a light container wiring these subcomponents.

- `src/tunnel.vala` → separate domain concerns:
  - `src/tunnel/TunnelManager.vala`: Public API and state machine only.
  - `src/tunnel/NgrokProcess.vala`: Start/stop ngrok, lifecycle, exit monitoring.
  - `src/tunnel/NgrokApiClient.vala`: HTTP polling against 127.0.0.1:4040, response parsing.
  - `src/tunnel/AuthStore.vala`: Token load/save with GSettings and environment; validation.

- `src/models.vala` → one class per file under `src/models/`:
  - `WebhookRequest.vala`, `RequestStorage.vala`, `TunnelStatus.vala`.
  - Add a small `JsonUtils.vala` if helpful (formatters, pretty JSON, safe parsing).

- `src/server.vala`
  - Extract sanitization into `src/server/WebhookSanitizer.vala` for isolated testing and reuse.

- `src/application.vala`
  - Extract About dialog construction into `src/ui/AboutController.vala` (and avoid synthetic key navigation).
  - Remove `_setup_resources()`; rely on statically linked resources.

2) Introduce single sources of truth

- `src/utils/HttpStyle.vala`:
  - `static string method_css(string method)` used by both RequestRow and StatisticsDialog.
  - `static StringList methods()` to feed the history filter and any future menus.

- `src/utils/Clipboard.vala` and `src/utils/Toasts.vala`:
  - Shared helpers to copy text and show toasts consistently.

- `src/services/ExportService.vala`:
  - `export_requests(...)` and `export_history(...)` implemented once and reused.

3) Remove redundancy and dead code

- Drop manual resource loading (keep gresource static linking): `src/application.vala:172-196`.
- Prune unused Blueprint nodes (or wire them properly): `data/ui/main_window.blp` URL label and `copy_url_button`.
- Replace `kill_all()` with process‑scoped termination or hide behind a debug flag.

4) Improve composability and testability

- Emit signals instead of passing `MainWindow` into `RequestRow` where possible; have parent subscribe to row signals (e.g., `delete_clicked(request_id)`, `expanded_changed(self, expanded)`), reducing coupling.
- Isolate JSON persistence and file IO behind small interfaces to enable headless tests for `RequestStorage` and `ExportService`.
- Consider converting some functions to pure methods with inputs/outputs to simplify unit tests (e.g., filtering logic from `src/main_window.vala:520-540`).

5) UX/Behavior improvements (optional, low‑risk)

- Replace custom Shortcuts dialog with `Gtk.ShortcutsWindow` (if desired) to align with GNOME conventions and reduce manual upkeep.
- Preferences: expose server port/host in a “Developer” group; today port is hardcoded across `MainWindow` and `TunnelManager`.
- History: add import + selective export (time range, method) via `ExportService`.

Packaging, Build, CI

- Meson
  - Increase warnings during development builds (`warning_level=2 or 3`, keep `werror=false` unless CI is green).
  - Keep `--define=DEVELOPMENT` switch; ensure code paths behave without manual resource registration.

- Flatpak
  - Current manifest bundles ngrok. Review license and update cadence. Consider a “system ngrok” fallback via portals if feasible.
  - Runtime: `org.gnome.Platform 48` looks current for 2025; keep in sync with Flathub updates.

- GitHub Actions
  - The `Update Flathub on Tag` workflow is clear and targeted. Consider adding a lint/build workflow (meson compile + unit tests) on PRs.

Concrete File Notes

- MainWindow
  - Size and responsibilities: `src/main_window.vala:1`.
  - Copy URL + toast UI: `src/main_window.vala:263`.
  - History filter loop: `src/main_window.vala:520`.
  - Export requests: `src/main_window.vala:416`.
  - Export history builder: `src/main_window.vala:574`.

- RequestRow
  - Method color styling duplicated: `src/request_row.vala:62`.
  - Clipboard and toast helpers: `src/request_row.vala:151` and `src/request_row.vala:159`.

- StatisticsDialog
  - Method color mapping duplicated: `src/statistics_dialog.vala:243`.

- Application
  - Manual resource loading (redundant): `src/application.vala:172-196`.
  - Synthetic navigation to show release notes (fragile): `src/application.vala:211-258`.

- Server
  - Sanitization tightly coupled in handler; candidate for extraction: `src/server.vala:240-540`.

Proposed Module Layout (incremental)

- `src/ui/`
  - `MainWindow.vala` (thin)
  - `RequestsPage.vala`
  - `HistoryPage.vala`
  - `TunnelBannerController.vala`
  - `AboutController.vala`
  - `Toasts.vala` (or `UiUtils.vala`)

- `src/services/`
  - `ExportService.vala`

- `src/utils/`
  - `HttpStyle.vala`
  - `Clipboard.vala`
  - `JsonUtils.vala` (optional)

- `src/tunnel/`
  - `TunnelManager.vala`
  - `NgrokProcess.vala`
  - `NgrokApiClient.vala`
  - `AuthStore.vala`

- `src/models/`
  - `WebhookRequest.vala`
  - `RequestStorage.vala`
  - `TunnelStatus.vala`

- `src/server/`
  - `WebhookServer.vala`
  - `WebhookSanitizer.vala`

Phased Roadmap

Phase 0 – Quick Wins (low risk)

- Remove manual resource loading: delete `Application._setup_resources()` calls and method; rely on statically linked resources.
- Extract method → CSS color map to `utils/HttpStyle.vala`; update RequestRow and StatisticsDialog to use it.
- Introduce `utils/Clipboard` and `ui/Toasts` helpers; update both MainWindow and RequestRow.
- Prune unused Blueprint nodes (`url_label`, `copy_url_button`) or rewire them intentionally.

Phase 1 – Split models and add services

- Move `WebhookRequest`, `TunnelStatus`, `RequestStorage` into separate files under `src/models/`.
- Create `services/ExportService.vala` for requests/history export. Replace inline export logic in MainWindow.
- Extract `WebhookSanitizer` from `server.vala` for testability.

Phase 2 – UI composition refactor

- Introduce `RequestsPage` and `HistoryPage`. Migrate code from `MainWindow` while keeping the UI XML unchanged initially (controllers operate on injected widgets).
- Add `TunnelBannerController` to encapsulate banner state and actions.
- Convert `RequestRow` → emit signals rather than call `MainWindow` directly.

Phase 3 – Tunnel subsystem cleanup

- Split `TunnelManager` into `NgrokProcess`, `NgrokApiClient`, and `AuthStore` (GSettings + env). Keep `TunnelManager` API stable.
- Replace `kill_all()` with scoped termination and optionally hide the action behind development builds.

Phase 4 – Quality, tests, and CI

- Add unit tests (GLib testing) for:
  - `RequestStorage` persistence (load/save/limits).
  - `WebhookSanitizer` edge cases (size limits, headers, query params).
  - `ExportService` JSON shape.
- Add a Meson test target and a GitHub Action workflow to run tests on PRs.

Acceptance Criteria & Risks

- No regression in current UX: requests capture, tunnel start/stop, history, export, stats, preferences.
- Lower coupling: clear ownership boundaries, fewer cross‑class calls into UI containers.
- Risks: Module splitting can ripple imports and resources; mitigate with incremental PRs that move code but preserve behavior.

Sizing & Priority

- P0 (quick wins, 1–2 days): resource loader removal, method color/clipboard/toasts helpers, Blueprint pruning.
- P1 (models/services split, 2–3 days): move models, add `ExportService`, extract `WebhookSanitizer`.
- P2 (UI composition, 3–5 days): introduce `RequestsPage`, `HistoryPage`, `TunnelBannerController`; adjust signals.
- P3 (tunnel cleanup, 3–4 days): split tunnel pieces; stabilize API.
- P4 (tests + CI, 1–2 days): unit tests and workflow.

Notes & Nice‑to‑haves

- Consider `Gtk.ShortcutsWindow` to replace the manual Shortcuts dialog for long‑term consistency.
- Add a Preferences “Advanced” group for server host/port and history limits.
- Consider raising Meson warning level during development.

