# directory-structure Specification

## Purpose
TBD - created by archiving change reorganize-codebase-structure. Update Purpose after archive.
## Requirements
### Requirement: Source Code Subdirectory Organization
Source files MUST be organized into logical subdirectories based on their role and responsibility.

#### Scenario: Dialog files organization
**Given** multiple dialog Vala files in `src/` directory
**When** organizing by component type
**Then** all dialog files MUST be moved to `src/dialogs/` subdirectory
**And** the following files MUST be in `src/dialogs/`:
  - `PreferencesDialog.vala`
  - `ShortcutsDialog.vala`
  - `StatisticsDialog.vala`

#### Scenario: Model files organization
**Given** a models file containing data structures
**When** organizing by component type
**Then** model files MUST be moved to `src/models/` subdirectory
**And** `Models.vala` MUST be in `src/models/`

#### Scenario: Manager files organization
**Given** files that manage resources and services
**When** organizing by component type
**Then** manager files MUST be moved to `src/managers/` subdirectory
**And** the following files MUST be in `src/managers/`:
  - `Server.vala` (manages webhook server)
  - `Tunnel.vala` (manages ngrok tunnel)

#### Scenario: Utility files organization
**Given** widget and utility component files
**When** organizing by component type
**Then** utility files MUST be moved to `src/utils/` subdirectory
**And** `RequestRow.vala` MUST be in `src/utils/` (custom widget component)

#### Scenario: Root-level application files
**Given** core application and window files
**When** organizing the source tree
**Then** root application files MUST remain in `src/` directory
**And** the following files MUST stay in `src/`:
  - `Application.vala` (application entry point)
  - `MainWindow.vala` (main window UI)
  - `Config.vala.in` (build-time configuration template)

### Requirement: Complete Directory Structure
The final `src/` directory structure MUST match the following organization:

```
src/
├── Application.vala
├── MainWindow.vala
├── Config.vala.in
├── meson.build
├── dialogs/
│   ├── PreferencesDialog.vala
│   ├── ShortcutsDialog.vala
│   └── StatisticsDialog.vala
├── models/
│   └── Models.vala
├── managers/
│   ├── Server.vala
│   └── Tunnel.vala
└── utils/
    └── RequestRow.vala
```

#### Scenario: Build system integration
**Given** source files organized in subdirectories
**When** configuring the Meson build
**Then** `src/meson.build` MUST include all source files with correct relative paths
**And** subdirectory paths MUST use forward slashes (e.g., `dialogs/PreferencesDialog.vala`)
**And** the build MUST produce identical binary output as before reorganization

### Requirement: Screenshots Directory Relocation
Screenshot assets MUST be relocated to the data directory for better asset organization.

#### Scenario: Moving screenshots directory
**Given** a `screenshots/` directory at the project root
**When** organizing data assets
**Then** the directory MUST be moved to `data/screenshots/`
**And** all screenshot files MUST be preserved:
  - `about.png`
  - `history.png`
  - `keyboard-shortcuts.png`
  - `main-window-start-tunnel.png`
  - `main-window-tunnel-started.png`
  - `main-window.png`
  - `preferences.png`
  - `received-requests.png`
  - `request-statistics.png`

#### Scenario: Documentation references update
**Given** documentation and metainfo files reference screenshot paths
**When** screenshots are relocated
**Then** all references in `README.md` MUST be updated to use `data/screenshots/` paths
**And** all references in `data/io.github.tobagin.sonar.metainfo.xml.in` MUST remain unchanged
  (they use GitHub raw URLs, not local paths)

#### Scenario: Git repository cleanup
**Given** the screenshots directory is moved
**When** committing the change
**Then** the old `screenshots/` directory MUST be removed from version control
**And** the new `data/screenshots/` directory MUST be tracked
**And** git history SHOULD be preserved using `git mv`

### Requirement: Meson Build File Organization
The build system MUST support organized source files with flexible build configuration approaches.

#### Scenario: Centralized vs distributed build files
**Given** source files organized in subdirectories
**When** configuring the build system
**Then** the build configuration MAY use either:
  - Centralized: Single `src/meson.build` listing all files with paths
  - Distributed: Subdirectory-specific meson.build files included by main build
**And** the chosen approach MUST maintain build reproducibility
**And** the centralized approach is RECOMMENDED for simpler maintenance initially

