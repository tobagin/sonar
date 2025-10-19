# Changelog Format and Content

## ADDED Requirements

### Requirement: Keep a Changelog Format
The CHANGELOG.md file MUST follow the "Keep a Changelog" format (https://keepachangelog.com/en/1.0.0/).

#### Scenario: Changelog structure
**Given** a CHANGELOG.md file exists
**When** documenting project history
**Then** it MUST include these sections in order:
  - Header with title "# Changelog"
  - Preamble explaining the format
  - Release entries in reverse chronological order (newest first)
**And** each release entry MUST follow the format:
  ```
  ## [Version] - YYYY-MM-DD

  ### Added
  - New features

  ### Changed
  - Changes to existing functionality

  ### Deprecated
  - Soon-to-be removed features

  ### Removed
  - Removed features

  ### Fixed
  - Bug fixes

  ### Security
  - Security fixes
  ```

#### Scenario: Version formatting
**Given** a release version to document
**When** creating a release entry
**Then** the version MUST be formatted as `[X.Y.Z]` (e.g., `[2.1.0]`)
**And** the date MUST use ISO 8601 format `YYYY-MM-DD`
**And** versions MUST be listed in reverse chronological order

### Requirement: Complete Version History
The CHANGELOG.md MUST document all releases from v1.0.0 to current (v2.1.0).

#### Scenario: Version 2.1.0 entry
**Given** the v2.1.0 release on 2025-10-09
**When** documenting the changelog
**Then** it MUST include an entry for version 2.1.0
**And** the entry MUST document:
  - Advanced filtering features (method, content-type, time range, search)
  - Request bookmarking/starring functionality
  - Request replay capability
  - Request comparison features
  - Request templates
  - Webhook forwarding functionality
  - Enhanced export options (cURL, HTTP format)

#### Scenario: Version 2.0.x entries
**Given** releases v2.0.0, v2.0.1, v2.0.2, and v2.0.3
**When** documenting the changelog
**Then** each version MUST have a separate entry
**And** v2.0.0 MUST be documented as a BREAKING CHANGE with complete Python-to-Vala rewrite
**And** v2.0.1, v2.0.2, v2.0.3 MUST document their respective bug fixes and improvements

#### Scenario: Version 1.x entries
**Given** Python-based releases from v1.0.0 to v1.0.8
**When** documenting the changelog
**Then** major version 1.x releases SHOULD be summarized
**And** entries SHOULD focus on significant features and changes
**And** entries MAY aggregate minor patch releases for brevity

### Requirement: Content Alignment with Metainfo
Changelog entries MUST align with release descriptions in the metainfo file where available.

#### Scenario: Metainfo cross-reference
**Given** a release documented in `data/io.github.tobagin.sonar.metainfo.xml.in`
**When** creating the corresponding changelog entry
**Then** the changelog MUST include the same key features and changes
**And** the changelog MAY use more concise formatting than metainfo
**And** both MUST use the same release date

#### Scenario: Feature categorization
**Given** features from metainfo release descriptions
**When** organizing in the changelog
**Then** new capabilities MUST be listed under "### Added"
**And** improvements to existing features MUST be listed under "### Changed"
**And** bug fixes MUST be listed under "### Fixed"
**And** security-related changes MUST be listed under "### Security"

### Requirement: Changelog Maintenance
The changelog MUST be updated as part of the release process.

#### Scenario: Future release workflow
**Given** a new version is being prepared for release
**When** creating release artifacts
**Then** CHANGELOG.md MUST be updated before the release is tagged
**And** the new version entry MUST be added at the top (below the header)
**And** the entry MUST include all notable changes since the last release
**And** the version and date MUST match the values in meson.build and metainfo

### Requirement: Unreleased Section
The changelog MUST support tracking unreleased changes via an optional `## [Unreleased]` section.

#### Scenario: Work-in-progress tracking
**Given** development work between releases
**When** documenting ongoing changes
**Then** an `## [Unreleased]` section MAY be present at the top
**And** it SHOULD list changes not yet part of a tagged release
**And** it MUST be removed or renamed when creating a new release

## MODIFIED Requirements

None - CHANGELOG.md is currently empty, so no existing requirements are modified.

## REMOVED Requirements

None - no existing changelog requirements exist to remove.
