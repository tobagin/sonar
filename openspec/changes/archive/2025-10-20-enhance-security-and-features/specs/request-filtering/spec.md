# Request Filtering Completion

This spec completes the incomplete request filtering implementation identified in MainWindow.vala:965.

## MODIFIED Requirements

### Requirement: Complete Request Filtering Implementation
The request filtering feature MUST be fully implemented with all planned filter criteria working correctly.

**Rationale**: The current implementation has a TODO comment indicating incomplete "show only starred" filter functionality.

**Priority**: MEDIUM

**Related**: MainWindow.vala line 965 TODO comment

#### Scenario: Filter by starred status
- **Given** the user has starred some webhook requests
- **When** the "Show Only Starred" toggle is activated
- **Then** only starred requests MUST be displayed in the list
- **And** the filter MUST work in combination with other active filters
- **And** the count of filtered requests MUST be shown

#### Scenario: Combine multiple filter criteria
- **Given** the user sets multiple filters (method=POST, starred=true, time=last hour)
- **When** the filters are applied
- **Then** only requests matching ALL criteria MUST be displayed
- **And** the filter logic MUST use AND operations (not OR)
- **And** the UI MUST clearly indicate which filters are active

#### Scenario: Persist filter state across sessions
- **Given** the user has configured specific filters
- **When** the application is closed and reopened
- **Then** the filter state MUST be restored from GSettings
- **And** the filters MUST be re-applied to the current request list
- **And** the UI controls MUST reflect the saved state

---

### Requirement: Advanced Search Capabilities
Request search MUST support advanced query syntax for power users.

**Rationale**: Current search only does basic text matching; advanced syntax enables more powerful filtering.

**Priority**: LOW

#### Scenario: Search with field-specific queries
- **Given** the user enters a search query with field prefix (e.g., "path:/api/webhook")
- **When** the search is executed
- **Then** only requests matching the field-specific criteria MUST be shown
- **And** supported fields MUST include: path, method, body, header
- **And** syntax examples MUST be shown in placeholder text

#### Scenario: Search with regular expressions
- **Given** the user enters a regex pattern (e.g., "/user/[0-9]+/webhook")
- **When** regex mode is enabled
- **Then** requests matching the regex pattern MUST be displayed
- **And** invalid regex patterns MUST show an error message
- **And** regex must be case-insensitive by default

#### Scenario: Full-text search across all fields
- **Given** the user enters a search term without field prefix
- **When** the search is executed
- **Then** all requests with the term in path, body, or headers MUST match
- **And** search results MUST be ranked by relevance
- **And** matched text MUST be highlighted in the detail view

## ADDED Requirements

### Requirement: Filter Performance Optimization
Request filtering MUST complete in <100ms for lists of up to 10,000 requests.

**Rationale**: Large request histories can cause slow filter application, degrading user experience.

**Priority**: MEDIUM

**Related**: specs/performance-optimization

#### Scenario: Fast filtering with indexes
- **Given** the user has 10,000 requests in history
- **When** a filter is changed (e.g., method=POST)
- **Then** the filter MUST complete in <100ms
- **And** the UI MUST remain responsive during filtering
- **And** indexes on method, content_type, and timestamp MUST be used

#### Scenario: Incremental filter updates
- **Given** filters are currently applied
- **When** a new request arrives
- **Then** only the new request MUST be evaluated against filters
- **And** the full list MUST NOT be re-filtered
- **And** the UI update MUST be batched

---

### Requirement: Saved Filter Presets
Users MUST be able to save and recall commonly used filter combinations.

**Rationale**: Users often use the same filter combinations repeatedly; presets improve workflow efficiency.

**Priority**: LOW

#### Scenario: Save current filter as preset
- **Given** the user has configured multiple active filters
- **When** the user clicks "Save as Preset"
- **Then** a dialog MUST prompt for a preset name
- **And** the current filter state MUST be saved to user data
- **And** the preset MUST appear in a quick-access menu

#### Scenario: Apply saved filter preset
- **Given** the user has saved filter presets
- **When** the user selects a preset from the menu
- **Then** all filter controls MUST be updated to match the preset
- **And** the filter MUST be applied to the request list
- **And** the preset name MUST be shown in the UI

#### Scenario: Manage saved presets
- **Given** the user has multiple saved presets
- **When** the user opens the preset manager
- **Then** all presets MUST be listed
- **And** the user MUST be able to rename, edit, or delete presets
- **And** a default preset MUST be settable

## REMOVED Requirements

None - This completes existing partial functionality.
