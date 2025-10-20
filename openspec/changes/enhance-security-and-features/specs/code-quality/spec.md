# Code Quality Improvements

This spec defines code quality improvements including file size limits, error handling, and maintainability enhancements.

## MODIFIED Requirements

### Requirement: Source File Size Limit Enforcement
All source files MUST adhere to the 500-line maximum constraint defined in project conventions.

**Rationale**: The project explicitly limits files to 500 lines for maintainability, but MainWindow.vala currently violates this at 1,164 lines.

**Priority**: HIGH

**Related**: openspec/specs/vala-naming

#### Scenario: Split MainWindow into focused components
- **Given** MainWindow.vala exceeds 500 lines (currently 1,164 lines)
- **When** the refactoring is complete
- **Then** MainWindow.vala MUST be ≤500 lines
- **And** new view classes (RequestsView, HistoryView, TunnelControls, FilterPanel) MUST each be ≤500 lines
- **And** all functionality MUST be preserved
- **And** the public API MUST remain backward compatible

#### Scenario: Maintain UI template structure
- **Given** Blueprint UI templates reference MainWindow widgets
- **When** MainWindow is split into components
- **Then** Blueprint files MUST be updated to match new structure
- **And** all GtkTemplate bindings MUST work correctly
- **And** no visual regressions MUST occur

---

### Requirement: Comprehensive Error Recovery
The application MUST implement robust error handling with automatic recovery mechanisms for transient failures.

**Rationale**: Current implementation lacks retry logic for tunnel failures, causing poor user experience when transient network issues occur.

**Priority**: MEDIUM

#### Scenario: Retry tunnel connection on transient failures
- **Given** the user attempts to start a tunnel
- **When** the initial connection fails with a transient error (network timeout, DNS failure)
- **Then** the application MUST automatically retry up to 3 times
- **And** exponential backoff MUST be used between retries (1s, 2s, 4s)
- **And** the user MUST see a loading indicator with retry status
- **And** permanent failures MUST show an error dialog after all retries exhausted

#### Scenario: Cancel long-running operations gracefully
- **Given** an async operation is in progress
- **When** the user closes the window or cancels the operation
- **Then** the operation MUST be cancelled via Cancellable
- **And** resources MUST be cleaned up properly
- **And** no partial state MUST be left

#### Scenario: Display actionable error messages
- **Given** an error occurs in the application
- **When** the error is presented to the user
- **Then** the message MUST explain what went wrong in user-friendly terms
- **And** the message MUST suggest actionable steps to resolve the issue
- **And** technical details MUST be available via "Show Details" button

## ADDED Requirements

### Requirement: Async Disk I/O
All disk I/O operations MUST use async patterns to prevent blocking the UI thread.

**Rationale**: Synchronous file operations in RequestStorage cause UI freezes when saving large histories.

**Priority**: MEDIUM

#### Scenario: Save request history asynchronously
- **Given** new webhook requests are being added frequently
- **When** the history is saved to disk
- **Then** the save operation MUST use async I/O (File.replace_contents_async)
- **And** the UI MUST remain responsive during the save
- **And** errors MUST be handled without data loss

#### Scenario: Load history on startup without blocking
- **Given** the application is starting
- **When** the history file is being loaded
- **Then** the main window MUST display immediately
- **And** history loading MUST happen asynchronously
- **And** a loading indicator MUST show progress
- **And** errors MUST fall back gracefully

---

### Requirement: Memory Management for Request Storage
Request storage MUST implement bounds on in-memory data to prevent unbounded memory growth.

**Rationale**: Current implementation loads all history into memory, which can cause issues with large histories.

**Priority**: MEDIUM

#### Scenario: Limit in-memory active requests
- **Given** the webhook server is receiving many requests
- **When** the active request count exceeds 1,000
- **Then** the oldest requests MUST be moved to history storage
- **And** only the most recent 1,000 MUST remain in the active list
- **And** the UI MUST reflect the current active requests

#### Scenario: Implement lazy loading for history
- **Given** the user has thousands of historical requests
- **When** the history view is opened
- **Then** only the most recent 100 requests MUST be loaded initially
- **And** older requests MUST be loaded on-demand (pagination or infinite scroll)
- **And** memory usage MUST not exceed reasonable bounds (~100MB)

## REMOVED Requirements

None - These are improvements to existing functionality.
