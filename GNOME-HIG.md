GNOME Human Interface Guidelines Review – Sonar

Summary

- Overall: Solid baseline with GTK4/Libadwaita and Blueprint; many good patterns (HeaderBar, Banner, Toasts, PreferencesPage/Group, boxed lists, About, actions/accels). A few concrete tweaks will align the app more closely with GNOME HIG around language (sentence case), button semantics, preferences rows, and the shortcuts window.
- Scope reviewed: data/ui/*.blp, src/*_dialog.vala, src/main_window.vala, src/application.vala.

What’s Compliant

- Framework: GTK4 + Libadwaita + Blueprint used consistently.
- Windows: `Adw.ApplicationWindow` + `Adw.HeaderBar` with a single primary menu.
- Feedback: `Adw.ToastOverlay` for transient feedback; `Adw.Banner` for state.
- Lists: `Gtk.ListBox` with `boxed-list`/`separators` for requests/history.
- Preferences: Built with `Adw.PreferencesDialog`, `Adw.PreferencesPage` and `Adw.PreferencesGroup`.
- About & Help: `Adw.AboutDialog`; keyboard accelerators are set on actions.
- Destructive flows: Confirmation dialogs use destructive appearance on the affirmative action.

Key Gaps vs HIG (and Recommendations)

1) Text style: Prefer sentence case

- Guidance: GNOME uses sentence case for titles, buttons, menu items, and labels.
- Examples to adjust (not exhaustive):
  - `data/ui/main_window.blp:15`: “Webhook Inspector” → “Webhook inspector”
  - `data/ui/main_window.blp:21`: “View History” → “View history”
  - `data/ui/main_window.blp:28`: “Stop Tunnel” → “Stop tunnel”
  - `data/ui/main_window.blp:38`: “Main Menu” → “Main menu”
  - `data/ui/main_window.blp:57`: “No Requests Yet” → “No requests yet”
  - `data/ui/main_window.blp:80`: “Setup Ngrok Token” → “Set up ngrok token” (and prefer “ngrok” casing)
  - `data/ui/main_window.blp:92`: “Start Tunnel” → “Start tunnel”
  - `data/ui/main_window.blp:111`: “Stop Tunnel” → “Stop tunnel”
  - `data/ui/main_window.blp:123`: “Requests” → “Requests” (ok if visible as a section title; otherwise sentence case)
  - `data/ui/main_window.blp:143`: “Received Requests” → “Received requests”
  - `data/ui/main_window.blp:188`: “History” → “History” (ok as section name)
  - `data/ui/main_window.blp:208`: “Request History” → “Request history”
  - `data/ui/main_window.blp:221`: “Show Statistics” → “Show statistics”
  - `data/ui/main_window.blp:228`: “Export History” → “Export history…” (ellipses since it opens a file dialog)
  - `data/ui/main_window.blp:242`: “Clear All History” → “Clear all history”
  - `data/ui/preferences.blp:12`: “Ngrok Configuration” → “ngrok configuration”
  - `data/ui/preferences.blp:16`: “Auth Token” → “Auth token” (or “Authentication token”)
  - `data/ui/preferences.blp:36`: “Save Token” → “Save token” (see Prefs section below to possibly remove)
  - `data/ui/preferences.blp:46`: “Test Connection” → “Test connection”
  - `data/ui/preferences.blp:54`: “Status” → “Status” (ok)
  - `data/ui/preferences.blp:68`: “Ngrok Version” → “ngrok version”
  - `data/ui/shortcuts_dialog.blp:5,13`: “Keyboard Shortcuts” → “Keyboard shortcuts”
  - `data/ui/statistics_dialog.blp:5,13`: “Request Statistics” → “Request statistics”
  - `data/ui/statistics_dialog.blp:39`: “Total Requests” → “Total requests”
  - `data/ui/statistics_dialog.blp:58`: “Unique Endpoints” → “Unique endpoints”
  - `data/ui/statistics_dialog.blp:77`: “Avg. Request Size” → “Average request size”
  - `data/ui/statistics_dialog.blp:97`: “HTTP Methods Distribution” → “HTTP methods distribution”
  - `data/ui/statistics_dialog.blp:108`: “Content Types Distribution” → “Content types distribution”
  - `data/ui/statistics_dialog.blp:119`: “Most Active Endpoints” → “Most active endpoints”
  - `data/ui/request_row.blp:28`: “Method” → “Method” (ok) | `:39` “Path” (ok) | `:50` “Content Type” → “Content type” | `:61` “Headers” (ok) | `:97` “Body” (ok)
  - Menu items (`data/ui/main_window.blp:285–327`): change to sentence case where applicable, e.g., “_View History” → “_View history”, “_Toggle Tunnel” → “_Toggle tunnel”, “_Keyboard Shortcuts” → “_Keyboard shortcuts”.

2) Destructive styling: Reserve for destructive actions only

- Guidance: Use `destructive-action` for irreversible operations (delete, clear).
- Issues:
  - Stop tunnel buttons use destructive styling:
    - `data/ui/main_window.blp:31` and `:114` – “Stop Tunnel/Stop tunnel” are not destructive.
- Recommendation:
  - Remove `destructive-action` from the stop buttons; keep them default (or `flat` when in header) and rely on text/icon to convey meaning.
  - Keep destructive styling on “Clear history” and delete actions, which already prompt for confirmation.

3) Preferences patterns: Use Preferences rows and avoid modal success popups

- Guidance: Use `Adw.EntryRow`/`Adw.PasswordEntryRow` inside `Adw.PreferencesGroup`. Save changes immediately or with an explicit row-level Apply pattern; avoid “Save” buttons for simple fields. Provide success feedback via non-blocking toasts.
- Issues:
  - A raw `Entry` is embedded as a suffix in an `Adw.ActionRow` (token), plus separate “Save Token” and “Test Connection” buttons (`data/ui/preferences.blp:15–50`).
  - Success feedback uses `Adw.AlertDialog` (`src/preferences_dialog.vala:106–114`).
- Recommendations:
  - Replace the `Entry` with `Adw.PasswordEntryRow` (Blueprint: `PasswordEntryRow`) with `show-apply` and `apply` signal if you prefer explicit commit, or save-on-change otherwise.
  - Remove the dedicated “Save token” button. If validation is needed, keep “Test connection” as a distinct row with a suffix button.
  - Replace modal success dialogs with `Adw.Toast` (keep modal alerts for errors only).
  - Use brand casing “ngrok” consistently in titles/descriptions.

4) Keyboard shortcuts window: Prefer Gtk.ShortcutsWindow

- Guidance: GNOME recommends `Gtk.ShortcutsWindow` for the shortcuts overlay (`win.show-help-overlay`).
- Issue:
  - A custom `Adw.Dialog` is used (`data/ui/shortcuts_dialog.blp`, `src/shortcuts_dialog.vala`).
- Recommendation:
  - Replace with `Gtk.ShortcutsWindow` organized by sections and groups; keep the accelerator “Ctrl + ?” wired to `win.show-help-overlay`.

5) Button styling: Avoid decorative “pill” outside of specific patterns

- Guidance: Prefer default button shapes; use `suggested-action` for primary actions. Reserve “pill” forms for specific patterns (e.g., segmented controls) and sparingly.
- Issues:
  - Several content-area buttons use `styles ["pill", ...]` (`data/ui/main_window.blp:83, 94, 107, 114`).
- Recommendation:
  - Drop the `pill` style in content areas; keep `suggested-action` on primary actions like “Start tunnel”.

6) Typography classes: Use semantic widgets where possible

- Guidance: Avoid heavy reliance on heading size classes (e.g., `title-2`, `title-3`) to style arbitrary labels. Prefer semantic widgets (`Adw.ActionRow` titles, group titles) or document headers.
- Findings:
  - `title-2` is applied to URL and numeric labels (`data/ui/main_window.blp:71`, `data/ui/statistics_dialog.blp:51, 70, 89`), `title-3` in stats suffix (`src/statistics_dialog.vala:233`).
- Recommendation:
  - Keep where it reads like a section heading; otherwise use default label typography to avoid visual hierarchy inflation.

7) Icon-only buttons: Add accessible names

- Guidance: Icon-only buttons should have accessible names for screen readers (tooltips are not sufficient for a11y).
- Candidates:
  - History, clear, stats, export, back, delete, copy buttons across pages (`data/ui/main_window.blp:154–245`, `data/ui/request_row.blp:19–25, 70–76, 106–112`).
- Recommendation:
  - Set `accessible-name` on these buttons (and keep tooltips). In code, ensure labels are translatable.

8) Ellipses: Use on actions that open a chooser or require input

- Guidance: Add an ellipsis (…) to labels that open a dialog requiring further user input before the action can complete.
- Example:
  - `data/ui/main_window.blp:228` “Export History” → “Export history…” (file dialog follows).

9) Request row tag sizing and wrapping

- Guidance: Avoid fixed-width tag labels unless necessary; ensure body/header content wraps sensibly.
- Findings:
  - `width-chars`/`max-width-chars` on method tag (`data/ui/request_row.blp:11–12`).
  - `wrap-mode: word` on `Gtk.TextView` for headers/body; JSON often benefits from `word-char` and monospace, with horizontal scrolling minimized.
- Recommendation:
  - Let the tag size naturally; consider `word-char` wrapping for code-like content.

10) History filtering control styling

- Guidance: In content areas, keep inputs with their default styling. Use “flat” primarily in header/toolbars.
- Finding:
  - `Gtk.DropDown` uses `flat` in the content area (`data/ui/main_window.blp:263`).
- Recommendation:
  - Remove `flat` from the dropdown in the content area to match default Adwaita visuals.

11) Dialog sizing

- Guidance: Prefer content-driven sizing with clamps rather than hard `content-width`/`content-height`.
- Finding:
  - Shortcuts and statistics dialogs set fixed sizes (`data/ui/shortcuts_dialog.blp:6–7`, `data/ui/statistics_dialog.blp:6–7`).
- Recommendation:
  - Consider relying on `Adw.Clamp` and minimum sizes, letting the dialog grow with content.

Menu Review

- Primary menu structure is sensible: Preferences; app actions (history, copy URL, toggle tunnel, clear); help/about; quit.
- Minor language/casing adjustments recommended (see 1). Add ellipsis to “Export history…”.
- Keep only broadly useful items in the primary menu; if history/view toggles become core to navigation, consider an `Adw.ViewSwitcher` in the header bar.

Optional, Higher-Impact Improvements

- Navigation & view switching: If “Requests” vs “History” are coequal top-level views, consider `Adw.ViewStack` + `Adw.ViewSwitcherTitle` for consistent navigation. Otherwise, current Stack + toggle is acceptable.
- Preferences window: If you prefer non-modal preferences, migrate to `Adw.PreferencesWindow` (non-blocking), otherwise `Adw.PreferencesDialog` is fine.

Quick Fix Checklist

- Text to sentence case throughout (see file refs above).
- Remove `destructive-action` from “Stop tunnel” buttons.
- Switch preferences token field to `Adw.PasswordEntryRow`; save on change or via row Apply.
- Replace custom shortcuts dialog with `Gtk.ShortcutsWindow`.
- Drop `pill` styling from content-area buttons.
- Add `accessible-name` to icon-only buttons.
- Add ellipsis to “Export history…”.
- Let dialogs size to content via `Adw.Clamp` instead of fixed content sizes.

Notes on Color and Contrast

- The app adds CSS classes like `success`, `warning`, `error`, `accent` to labels and progress bars in code. Ensure these classes are either meaningful under Adwaita (not all apply to all widgets) or backed by an app stylesheet. Avoid relying on color alone to convey meaning; the current UI also uses text labels (e.g., HTTP methods), which is good for accessibility.

Files Reviewed

- UI: `data/ui/main_window.blp`, `data/ui/request_row.blp`, `data/ui/preferences.blp`, `data/ui/shortcuts_dialog.blp`, `data/ui/statistics_dialog.blp`
- Code: `src/main_window.vala`, `src/request_row.vala`, `src/preferences_dialog.vala`, `src/shortcuts_dialog.vala`, `src/statistics_dialog.vala`, `src/application.vala`

