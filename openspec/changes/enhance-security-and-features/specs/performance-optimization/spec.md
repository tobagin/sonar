# Performance Optimization

This spec defines performance improvements for JSON parsing, UI updates, search, and disk I/O.

## ADDED Requirements

### Requirement: Request Indexing for Fast Search
The application MUST implement indexing for common search fields to achieve O(1) or O(log n) lookup performance.

**Rationale**: Linear search through large request histories causes UI lag; indexing provides fast filtering.

**Priority**: MEDIUM

#### Scenario: Index requests by method
- **Given** requests are being stored
- **When** a new request is added
- **Then** the request MUST be added to a method index (hash map)
- **And** filtering by method MUST use the index (O(1) lookup)
- **And** index updates MUST happen asynchronously to avoid blocking UI

#### Scenario: Index requests by content type
- **Given** requests have various content types
- **When** filtering by content type
- **Then** an index on content_type field MUST be used
- **And** lookup MUST complete in <10ms for 10,000 requests
- **And** null or missing content types MUST be handled correctly

#### Scenario: Index requests by timestamp for time range queries
- **Given** requests have timestamps
- **When** filtering by time range (last 5 min, last hour, etc.)
- **Then** a sorted timestamp index MUST enable binary search
- **And** range queries MUST complete in O(log n) time
- **And** index MUST be updated incrementally as requests arrive

---

### Requirement: Batched UI Updates
UI updates for incoming requests MUST be batched to prevent excessive redraws and maintain responsiveness.

**Rationale**: Updating the UI for every incoming request causes performance issues during high-volume periods.

**Priority**: HIGH

#### Scenario: Batch multiple rapid requests
- **Given** multiple webhook requests arrive within 100ms
- **When** requests are being displayed
- **Then** UI updates MUST be batched and applied once every 100ms
- **And** all pending requests MUST be added in a single UI transaction
- **And** the UI MUST remain responsive (<16ms frame time for 60fps)

#### Scenario: Prevent UI freezing during bulk operations
- **Given** 1000 requests are being loaded from history
- **When** displaying in the UI
- **Then** requests MUST be added in chunks of 50
- **And** a GLib.idle callback MUST be used between chunks
- **And** a loading indicator MUST be shown during processing

---

### Requirement: JSON Parsing Cache
Formatted JSON output MUST be cached to avoid repeated parsing of the same request body.

**Rationale**: Pretty-printing JSON is expensive; caching eliminates redundant work when viewing the same request multiple times.

**Priority**: LOW

#### Scenario: Cache formatted JSON body
- **Given** a request has a JSON body
- **When** the formatted body is requested for the first time
- **Then** the body MUST be parsed and pretty-printed
- **And** the formatted result MUST be cached in the WebhookRequest object
- **And** subsequent requests for formatted body MUST return the cached value

#### Scenario: Invalidate cache on body modification
- **Given** a formatted JSON body is cached
- **When** the request body is modified (unlikely but possible)
- **Then** the cache MUST be invalidated
- **And** the next format request MUST re-parse and re-cache

---

### Requirement: Async Disk I/O Performance
All disk I/O operations MUST complete without blocking the UI thread and optimize for write throughput.

**Rationale**: Synchronous disk writes cause UI freezes; async I/O maintains responsiveness.

**Priority**: HIGH

**Related**: specs/code-quality (Async Disk I/O requirement)

#### Scenario: Asynchronous history save with write coalescing
- **Given** multiple requests arrive in quick succession
- **When** history saves are triggered
- **Then** save operations MUST be coalesced (only one save pending at a time)
- **And** the most recent state MUST be saved
- **And** the UI MUST never block waiting for disk writes

#### Scenario: Atomic file writes for data integrity
- **Given** history is being saved to disk
- **When** the save operation executes
- **Then** data MUST be written to a temporary file first
- **And** the temporary file MUST be atomically renamed to replace the target
- **And** failures MUST not corrupt existing data

---

### Requirement: Memory Usage Optimization
The application MUST limit memory usage to <100MB for typical use cases (up to 1,000 active requests).

**Rationale**: Unbounded memory growth can cause system performance issues and crashes.

**Priority**: MEDIUM

#### Scenario: Limit active requests in memory
- **Given** the application is receiving many requests
- **When** active request count exceeds 1,000
- **Then** older requests MUST be archived to disk-only storage
- **And** only recent requests MUST remain fully in memory
- **And** memory usage MUST stay under 100MB

#### Scenario: Lazy load historical requests
- **Given** the user opens the history view with 10,000 stored requests
- **When** the view is displayed
- **Then** only the first 100 requests MUST be loaded into memory
- **And** additional requests MUST be loaded on scroll (pagination)
- **And** memory usage MUST not exceed 150MB even with large histories

## MODIFIED Requirements

None - These are new performance optimizations.

## REMOVED Requirements

None - No existing functionality is being removed.
