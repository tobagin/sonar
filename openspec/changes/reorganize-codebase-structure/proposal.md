# Reorganize Codebase Structure

## Why
The codebase has grown to 10+ Vala files using non-standard snake_case naming instead of PascalCase, a flat `src/` structure with no logical grouping, misplaced screenshots at root level, and an empty CHANGELOG.md with no project history documentation. This creates friction for contributors, makes navigation difficult, and violates Vala ecosystem conventions.

## What Changes
- **Rename all Vala files to PascalCase**: `application.vala` → `Application.vala`, `main_window.vala` → `MainWindow.vala`, etc. (10 files total)
- **Reorganize src/ into subdirectories**: Create `dialogs/`, `models/`, `managers/`, `utils/` and move files into logical groups
- **Move screenshots to data/**: Relocate `screenshots/` → `data/screenshots/` to consolidate data assets
- **Populate CHANGELOG.md**: Document complete project history from v1.0.0 to v2.1.0 using Keep a Changelog format
- **Update build system**: Modify `src/meson.build` to reference new file paths
- **Update documentation**: Fix screenshot references in `README.md`

## Impact
- **Affected specs**: `vala-naming`, `directory-structure`, `changelog-format` (all new capabilities)
- **Affected code**:
  - `src/*.vala` (all 10 Vala source files renamed and relocated)
  - `src/meson.build` (file path updates)
  - `README.md` (screenshot path updates)
  - `screenshots/` → `data/screenshots/` (directory relocation)
  - `CHANGELOG.md` (content population)
- **Breaking changes**: None - purely internal reorganization with no API or functionality changes
- **Migration effort**: Build system automatically handles new paths; no user-facing migration needed
