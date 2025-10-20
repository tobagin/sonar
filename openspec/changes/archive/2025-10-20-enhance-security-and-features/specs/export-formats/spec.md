# Enhanced Export Formats

This spec adds additional export formats beyond JSON, including CSV, HAR, and cURL scripts.

## ADDED Requirements

### Requirement: Multiple Export Format Support
The application MUST support exporting webhook requests in multiple industry-standard formats.

**Rationale**: Different use cases require different formats; HAR for browser tools, CSV for spreadsheets, cURL for replay.

**Priority**: MEDIUM

#### Scenario: Export as HAR (HTTP Archive Format)
- **Given** the user has captured webhook requests
- **When** the user selects "Export as HAR"
- **Then** a valid HAR 1.2 format file MUST be generated
- **And** all request details (headers, body, timing) MUST be included
- **And** the file MUST be importable into Chrome DevTools, Charles, and other HAR viewers

#### Scenario: Export as CSV
- **Given** the user wants to analyze requests in a spreadsheet
- **When** the user selects "Export as CSV"
- **Then** a CSV file MUST be generated with columns: Timestamp, Method, Path, Status, Content-Type, Body Preview
- **And** headers MUST be escaped properly for CSV format
- **And** multiline body content MUST be quoted correctly

#### Scenario: Export as cURL commands
- **Given** the user wants to replay requests via command line
- **When** the user selects "Export as cURL"
- **Then** a shell script with cURL commands MUST be generated
- **And** each request MUST be a separate cURL command
- **And** headers MUST be included with -H flags
- **And** POST body MUST be included with --data or --data-binary

---

### Requirement: Selective Export
Users MUST be able to export a subset of requests based on selection or filters.

**Rationale**: Large request histories make exporting all data impractical; selective export improves usability.

**Priority**: MEDIUM

#### Scenario: Export filtered requests only
- **Given** the user has active filters applied
- **When** the user exports requests
- **Then** only visible (filtered) requests MUST be exported
- **And** a confirmation dialog MUST show the count of requests to export
- **And** an option to "Export All" (ignoring filters) MUST be available

#### Scenario: Export selected requests
- **Given** the user has selected specific requests (multi-select)
- **When** the user exports
- **Then** only the selected requests MUST be exported
- **And** the selection count MUST be shown in the export dialog
- **And** export formats MUST respect the selection

#### Scenario: Export single request
- **Given** the user right-clicks a single request
- **When** selecting "Export This Request"
- **Then** only that request MUST be exported
- **And** format options MUST be available in a submenu
- **And** the export MUST complete immediately without additional dialogs

---

### Requirement: Export Format Extensibility
The export system MUST be designed to easily add new export formats in the future.

**Rationale**: Users may request additional formats; a plugin-based architecture enables easy extension.

**Priority**: LOW

#### Scenario: Register custom export formatter
- **Given** a developer implements an ExportFormatter interface
- **When** the formatter is registered with ExportManager
- **Then** the format MUST appear in export format selections
- **And** the formatter MUST be called when selected
- **And** errors MUST be handled gracefully

#### Scenario: Export format with custom options
- **Given** an export format has configurable options
- **When** the user selects that format
- **Then** an options dialog MUST be shown
- **And** the user MUST be able to configure format-specific settings
- **And** settings MUST be saved for future exports

## MODIFIED Requirements

### Requirement: JSON Export Enhancement
The existing JSON export MUST be enhanced with formatting options and metadata.

**Rationale**: Current JSON export is basic; adding options improves usability for different scenarios.

**Priority**: LOW

#### Scenario: Export JSON with formatting options
- **Given** the user selects JSON export
- **When** configuring export options
- **Then** the user MUST be able to choose pretty-printed or compact
- **And** the user MUST be able to include/exclude metadata (request IDs, timestamps)
- **And** the user MUST be able to merge requests into single array or separate files

#### Scenario: Export JSON with schema version
- **Given** JSON is exported
- **When** the file is generated
- **Then** a schema version field MUST be included at the root
- **And** the version MUST follow semantic versioning
- **And** documentation MUST define the schema format

## REMOVED Requirements

None - This extends existing export functionality.
