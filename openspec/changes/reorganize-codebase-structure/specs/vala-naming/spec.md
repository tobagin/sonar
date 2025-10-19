# Vala File Naming Conventions

## ADDED Requirements

### Requirement: PascalCase for Vala Source Files
All Vala source files MUST follow PascalCase naming convention to align with Vala ecosystem standards.

#### Scenario: Renaming dialog files
**Given** a Vala file for a dialog component named `statistics_dialog.vala`
**When** applying naming conventions
**Then** it MUST be renamed to `StatisticsDialog.vala`
**And** the class name inside (`StatisticsDialog`) MUST match the filename

#### Scenario: Renaming main application files
**Given** a Vala file for the main window named `main_window.vala`
**When** applying naming conventions
**Then** it MUST be renamed to `MainWindow.vala`
**And** maintain consistency with the `MainWindow` class definition

#### Scenario: Renaming model files
**Given** a Vala file containing data models named `models.vala`
**When** applying naming conventions
**Then** it MUST be renamed to `Models.vala`
**And** preserve all existing model class definitions

### Requirement: Complete File Mapping
The following complete mapping MUST be applied for all Vala source files:

- `application.vala` → `Application.vala`
- `main_window.vala` → `MainWindow.vala`
- `models.vala` → `Models.vala`
- `preferences_dialog.vala` → `PreferencesDialog.vala`
- `request_row.vala` → `RequestRow.vala`
- `server.vala` → `Server.vala`
- `shortcuts_dialog.vala` → `ShortcutsDialog.vala`
- `statistics_dialog.vala` → `StatisticsDialog.vala`
- `tunnel.vala` → `Tunnel.vala`
- `config.vala.in` → `Config.vala.in` (template file)

#### Scenario: Build system references
**Given** Meson build files reference Vala source files
**When** files are renamed to PascalCase
**Then** all references in `src/meson.build` MUST be updated to use new filenames
**And** the build MUST complete successfully without errors

#### Scenario: Git history preservation
**Given** files are being renamed
**When** using version control
**Then** git mv SHOULD be used to preserve file history
**And** commit message MUST reference this change specification

### Requirement: Template File Naming
Template files (`.in` suffix) MUST also follow PascalCase convention.

#### Scenario: Config template naming
**Given** a Vala template file named `config.vala.in`
**When** applying naming conventions
**Then** it MUST be renamed to `Config.vala.in`
**And** Meson configuration MUST reference the correct output filename `Config.vala`
