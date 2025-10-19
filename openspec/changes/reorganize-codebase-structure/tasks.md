# Implementation Tasks

## Phase 1: Vala File Renaming (REQ-VN-001, REQ-VN-002, REQ-VN-003)

### Task 1.1: Rename Vala files to PascalCase
**Objective**: Rename all Vala source files from snake_case to PascalCase using git mv for history preservation.

**Steps**:
1. Run `cd src`
2. Execute git mv for each file:
   - `git mv application.vala Application.vala`
   - `git mv main_window.vala MainWindow.vala`
   - `git mv models.vala Models.vala`
   - `git mv preferences_dialog.vala PreferencesDialog.vala`
   - `git mv request_row.vala RequestRow.vala`
   - `git mv server.vala Server.vala`
   - `git mv shortcuts_dialog.vala ShortcutsDialog.vala`
   - `git mv statistics_dialog.vala StatisticsDialog.vala`
   - `git mv tunnel.vala Tunnel.vala`
   - `git mv config.vala.in Config.vala.in`
3. Return to project root: `cd ..`

**Validation**:
- Verify all 10 files renamed: `ls src/*.vala src/*.in`
- Confirm git tracked renames: `git status`

**Dependencies**: None

**Estimated time**: 5 minutes

---

### Task 1.2: Update src/meson.build references
**Objective**: Update Meson build file to reference renamed Vala files.

**Steps**:
1. Open `src/meson.build`
2. Update all source file references to use PascalCase filenames
3. Verify the `config_vala` configure_file references correct input/output
4. Save the file

**Validation**:
- Run `meson setup build --wipe` to reconfigure
- Run `meson compile -C build` to verify build succeeds
- Check build log for correct file references

**Dependencies**: Task 1.1 must be completed

**Estimated time**: 10 minutes

---

## Phase 2: Directory Reorganization (REQ-DS-001, REQ-DS-002, REQ-DS-003)

### Task 2.1: Create source subdirectories
**Objective**: Create new subdirectory structure in src/.

**Steps**:
1. Create subdirectories:
   - `mkdir -p src/dialogs`
   - `mkdir -p src/models`
   - `mkdir -p src/managers`
   - `mkdir -p src/utils`

**Validation**:
- Verify directories exist: `ls -d src/*/`
- Confirm 4 new subdirectories created

**Dependencies**: Phase 1 completed

**Estimated time**: 2 minutes

---

### Task 2.2: Move files to appropriate subdirectories
**Objective**: Organize Vala files into logical subdirectories using git mv.

**Steps**:
1. Move dialog files:
   - `git mv src/PreferencesDialog.vala src/dialogs/`
   - `git mv src/ShortcutsDialog.vala src/dialogs/`
   - `git mv src/StatisticsDialog.vala src/dialogs/`
2. Move model files:
   - `git mv src/Models.vala src/models/`
3. Move manager files:
   - `git mv src/Server.vala src/managers/`
   - `git mv src/Tunnel.vala src/managers/`
4. Move utility files:
   - `git mv src/RequestRow.vala src/utils/`

**Validation**:
- Verify root src/ only contains: `Application.vala`, `MainWindow.vala`, `Config.vala.in`, `meson.build`
- Verify subdirectories contain correct files: `tree src/` or `find src -name "*.vala"`
- Confirm git tracked moves: `git status`

**Dependencies**: Task 2.1 must be completed

**Estimated time**: 5 minutes

---

### Task 2.3: Update src/meson.build with subdirectory paths
**Objective**: Update Meson build to reference files in subdirectories.

**Steps**:
1. Open `src/meson.build`
2. Update source file list to include subdirectory paths:
   - `dialogs/PreferencesDialog.vala`
   - `dialogs/ShortcutsDialog.vala`
   - `dialogs/StatisticsDialog.vala`
   - `models/Models.vala`
   - `managers/Server.vala`
   - `managers/Tunnel.vala`
   - `utils/RequestRow.vala`
3. Keep root-level files without paths:
   - `Application.vala`
   - `MainWindow.vala`
   - `config_vala` (generated file)
4. Save the file

**Validation**:
- Run `meson setup build --wipe --buildtype=release` to reconfigure
- Run `meson compile -C build` to verify build succeeds
- Compare resulting binary size/functionality with previous build
- Run `./build/src/sonar --version` to verify application runs

**Dependencies**: Task 2.2 must be completed

**Estimated time**: 10 minutes

---

### Task 2.4: Move screenshots directory to data/
**Objective**: Relocate screenshots from project root to data/ directory.

**Steps**:
1. Move directory: `git mv screenshots data/screenshots`
2. Verify all 9 PNG files preserved

**Validation**:
- Verify directory moved: `ls data/screenshots/`
- Confirm 9 PNG files present
- Confirm old `screenshots/` directory no longer exists: `ls screenshots/` should fail
- Verify git tracked move: `git status`

**Dependencies**: None (can run in parallel with Phase 2)

**Estimated time**: 2 minutes

---

### Task 2.5: Update README.md screenshot references
**Objective**: Update documentation to reflect new screenshot paths.

**Steps**:
1. Open `README.md`
2. Find all references to `screenshots/` paths
3. Replace with `data/screenshots/` paths
4. Save the file

**Validation**:
- Search for old paths: `grep -n "screenshots/" README.md` should find none
- Verify new paths: `grep -n "data/screenshots/" README.md` should find all references
- Manually review README rendering (if using preview)

**Dependencies**: Task 2.4 must be completed

**Estimated time**: 5 minutes

---

## Phase 3: Changelog Creation (REQ-CL-001, REQ-CL-002, REQ-CL-003, REQ-CL-004)

### Task 3.1: Populate CHANGELOG.md with complete history
**Objective**: Create proper changelog documenting all releases from v1.0.0 to v2.1.0.

**Steps**:
1. Open `CHANGELOG.md` (currently empty)
2. Add Keep a Changelog header and preamble
3. Add release entries in reverse chronological order:
   - v2.1.0 (2025-10-09) - Advanced webhook tools
   - v2.0.3 (2025-10-08) - UX enhancements
   - v2.0.2 (2025-09-18) - Metainfo fixes
   - v2.0.1 (2025-09-18) - Runtime updates
   - v2.0.0 (2025-08-25) - Complete Vala rewrite [BREAKING]
   - v1.0.8 (2025-07-21) - GSettings migration
   - v1.0.7 through v1.0.0 - Summarize key changes
4. Cross-reference `data/io.github.tobagin.sonar.metainfo.xml.in` for release descriptions
5. Categorize changes appropriately (Added, Changed, Fixed, etc.)
6. Save the file

**Validation**:
- Verify all versions from v1.0.0 to v2.1.0 are documented
- Check chronological order (newest first)
- Verify date format (YYYY-MM-DD)
- Compare with metainfo for consistency
- Lint with `markdownlint CHANGELOG.md` if available

**Dependencies**: None (can run in parallel)

**Estimated time**: 30 minutes

---

## Phase 4: Testing and Validation

### Task 4.1: Build validation
**Objective**: Ensure all build configurations work correctly.

**Steps**:
1. Clean previous builds: `rm -rf build`
2. Test development build: `./scripts/build.sh --dev`
3. Verify dev build runs: `flatpak run io.github.tobagin.sonar.Devel`
4. Clean: `rm -rf build`
5. Test production build: `./scripts/build.sh`
6. Verify prod build runs: `flatpak run io.github.tobagin.sonar`

**Validation**:
- Both builds complete without errors
- Both applications launch successfully
- Application version displays correctly
- All UI elements render properly
- Webhook capture functionality works

**Dependencies**: All Phase 1 and Phase 2 tasks completed

**Estimated time**: 15 minutes

---

### Task 4.2: Documentation review
**Objective**: Verify all documentation is updated and accurate.

**Steps**:
1. Review README.md for screenshot path accuracy
2. Review CHANGELOG.md for completeness and format
3. Check no broken references exist
4. Verify project.md doesn't need updates (file organization is documented in specs)

**Validation**:
- All documentation renders correctly
- No broken links or file references
- Changelog follows Keep a Changelog format
- README screenshots display properly (if preview available)

**Dependencies**: All previous phases completed

**Estimated time**: 10 minutes

---

### Task 4.3: Git commit and verification
**Objective**: Create clean commit for the reorganization.

**Steps**:
1. Review all changes: `git status`
2. Verify no untracked files from refactoring: `git clean -n`
3. Stage all changes: `git add -A`
4. Create commit with reference to OpenSpec change:
   ```
   refactor: Reorganize codebase structure

   - Rename all Vala files to PascalCase (REQ-VN-001, REQ-VN-002)
   - Organize src/ into subdirectories (REQ-DS-001, REQ-DS-002)
   - Move screenshots to data/ directory (REQ-DS-003)
   - Populate CHANGELOG.md with complete history (REQ-CL-001, REQ-CL-002)

   Implements: openspec/changes/reorganize-codebase-structure
   ```
5. Push changes (if appropriate)

**Validation**:
- Verify commit includes all file renames and moves
- Check git log shows proper file history preservation
- Confirm no lost changes or files

**Dependencies**: All validation tasks completed successfully

**Estimated time**: 5 minutes

---

## Summary

**Total estimated time**: ~2 hours
**Phases**: 4
**Total tasks**: 11
**Parallelizable tasks**: Task 2.4, Task 3.1 (can run while Phase 2 work is in progress)

**Critical path**:
1. Phase 1 (15 min) → Task 2.1 (2 min) → Task 2.2 (5 min) → Task 2.3 (10 min) → Task 4.1 (15 min) → Task 4.2 (10 min) → Task 4.3 (5 min)
2. Task 2.4 (2 min) → Task 2.5 (5 min) can overlap with Phase 2
3. Task 3.1 (30 min) can overlap with all other work

**Rollback plan**: If any task fails validation, use `git reset --hard` to restore previous state before reattempting.
