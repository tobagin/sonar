# Implementation Tasks

This document outlines the ordered implementation tasks for the security and feature enhancements.

## Phase 1: Security Foundation (Critical Priority)

### Task 1.1: Add libsecret Dependency ✅ COMPLETED
**Capability**: security-hardening
**Estimated Effort**: 2 hours
**Dependencies**: None
**Validation**: Build succeeds with libsecret linked

**Steps**:
1. Add libsecret-1 dependency to meson.build
2. Update Flatpak manifest with libsecret runtime dependency
3. Add fallback handling for non-GNOME environments
4. Test build on clean environment

**Files Changed**:
- `meson.build` - Add dependency('libsecret-1')
- `packaging/io.github.tobagin.sonar.yml` - Add libsecret to finish-args

**Acceptance**: Application builds successfully with libsecret dependency

---

### Task 1.2: Implement SecurityManager ✅ COMPLETED
**Capability**: security-hardening
**Estimated Effort**: 8 hours
**Dependencies**: Task 1.1
**Validation**: Unit tests pass for credential storage/retrieval

**Steps**:
1. Create `src/managers/SecurityManager.vala` (<400 lines)
2. Implement async credential storage using libsecret Schema
3. Implement credential retrieval with error handling
4. Implement credential deletion
5. Add migration logic from GSettings to libsecret
6. Write unit tests for all SecurityManager methods

**Files Changed**:
- `src/managers/SecurityManager.vala` - New file
- `src/meson.build` - Add new file to sources

**Acceptance**:
- Tokens stored in keyring are encrypted
- Migration from GSettings works correctly
- All unit tests pass

---

### Task 1.3: Integrate SecurityManager with TunnelManager ✅ COMPLETED
**Capability**: security-hardening
**Estimated Effort**: 4 hours
**Dependencies**: Task 1.2
**Validation**: Tokens stored securely, tunnel starts correctly

**Steps**:
1. Refactor TunnelManager to use SecurityManager for auth token storage
2. Remove direct GSettings token storage
3. Implement automatic migration on first launch
4. Add user notification for successful migration
5. Update preferences dialog to use SecurityManager

**Files Changed**:
- `src/managers/Tunnel.vala` - Replace GSettings with SecurityManager calls
- `src/dialogs/PreferencesDialog.vala` - Update token storage UI

**Acceptance**:
- Existing tokens are migrated automatically
- New tokens are stored securely
- Old GSettings values are cleared after migration

---

### Task 1.4: Implement Input Validation ✅ COMPLETED
**Capability**: security-hardening
**Estimated Effort**: 6 hours
**Dependencies**: None (can parallelize)
**Validation**: Security tests pass

**Steps**:
1. Enhance `_sanitize_webhook_data()` in Server.vala with stricter validation
2. Add path validation (reject `..`, null bytes, control chars)
3. Add URL validation utility for forward URLs
4. Implement request size limits configuration
5. Add validation tests with malicious inputs

**Files Changed**:
- `src/managers/Server.vala` - Enhance validation logic
- `src/utils/ValidationUtils.vala` - New file for validation helpers

**Acceptance**:
- Path traversal attempts are blocked
- Oversized requests are rejected
- All validation tests pass

---

### Task 1.5: Implement RateLimiter ✅ COMPLETED
**Capability**: security-hardening
**Estimated Effort**: 6 hours
**Dependencies**: None (can parallelize)
**Validation**: Rate limiting tests pass

**Steps**:
1. Create `src/managers/RateLimiter.vala` (<300 lines)
2. Implement token bucket algorithm
3. Add per-source rate tracking with LRU eviction
4. Integrate with Server.vala webhook handler
5. Add GSettings configuration for rate limits
6. Add rate limit tests

**Files Changed**:
- `src/managers/RateLimiter.vala` - New file
- `src/managers/Server.vala` - Integrate rate limiter
- `data/io.github.tobagin.sonar.gschema.xml` - Add rate limit settings

**Acceptance**:
- Rate limits enforce correctly (429 responses)
- Burst traffic is handled properly
- Configuration works

---

### Task 1.6: Implement SSRF Prevention ✅ COMPLETED
**Capability**: security-hardening
**Estimated Effort**: 4 hours
**Dependencies**: Task 1.4
**Validation**: SSRF tests pass

**Steps**:
1. Create URL validation function in ValidationUtils
2. Implement private IP detection
3. Implement scheme whitelist
4. Add UI warning for localhost URLs
5. Add override mechanism with user acknowledgment
6. Write SSRF prevention tests

**Files Changed**:
- `src/utils/ValidationUtils.vala` - Add SSRF prevention functions
- `src/dialogs/PreferencesDialog.vala` - Add warnings for private IPs
- `src/managers/Server.vala` - Validate before forwarding

**Acceptance**:
- Private IPs are blocked by default
- Dangerous schemes are rejected
- Override mechanism works with warnings

---

## Phase 2: Code Quality & Refactoring

### Task 2.1: Split MainWindow into Components ⚠️ NEEDS REDESIGN
**Capability**: code-quality
**Estimated Effort**: 12 hours
**Dependencies**: None (can start early)
**Validation**: All files <500 lines, no regressions

**Status Note (2025-10-20)**: Initial implementation created 4 component files but caused circular reference crash during GObject construction. Components have been disabled and removed from build. Task needs redesign to avoid passing MainWindow reference during component construction. Alternative approaches: use signals, weak references, or redesign components to be fully independent.

**Steps**:
1. Create `src/windows/` directory
2. Extract RequestsView from MainWindow (~250 lines)
3. Extract HistoryView from MainWindow (~200 lines)
4. Extract TunnelControls from MainWindow (~150 lines)
5. Extract FilterPanel from MainWindow (~200 lines)
6. Update MainWindow to use new components (~300 lines)
7. Split Blueprint UI files accordingly
8. Test all UI functionality for regressions

**Files Changed**:
- `src/windows/MainWindow.vala` - Reduced to ~300 lines
- `src/windows/RequestsView.vala` - New file (~250 lines)
- `src/windows/HistoryView.vala` - New file (~200 lines)
- `src/windows/TunnelControls.vala` - New file (~150 lines)
- `src/windows/FilterPanel.vala` - New file (~200 lines)
- `data/ui/*.blp` - Split UI definitions
- `src/meson.build` - Update source files

**Acceptance**:
- All source files ≤500 lines
- All functionality works correctly
- No visual regressions

---

### Task 2.2: Implement Error Recovery with Retry ✅ COMPLETED
**Capability**: code-quality
**Estimated Effort**: 6 hours
**Dependencies**: None (can parallelize)
**Validation**: Retry tests pass

**Steps**:
1. Add retry logic to TunnelManager.start_async()
2. Implement exponential backoff
3. Add Cancellable support to all async operations
4. Update UI to show retry progress
5. Write retry tests with mocked failures

**Files Changed**:
- `src/managers/Tunnel.vala` - Add retry mechanism
- `src/MainWindow.vala` or `src/windows/TunnelControls.vala` - UI updates

**Acceptance**:
- Transient failures retry automatically
- User sees retry progress
- Permanent failures show clear error

---

### Task 2.3: Implement Async Disk I/O ✅ COMPLETED
**Capability**: code-quality, performance-optimization
**Estimated Effort**: 8 hours
**Dependencies**: None (can parallelize)
**Validation**: UI remains responsive during saves

**Steps**:
1. Convert `_save_history_to_disk()` to async
2. Convert `_load_history_from_disk()` to async
3. Implement write coalescing (debouncing)
4. Add error handling for disk failures
5. Test with large histories (10k+ requests)

**Files Changed**:
- `src/models/Models.vala` - Make I/O async

**Acceptance**:
- History saves don't block UI
- Write coalescing prevents excessive writes
- Data integrity maintained

---

### Task 2.4: Implement Memory Management ✅ COMPLETED
**Capability**: code-quality, performance-optimization
**Estimated Effort**: 6 hours
**Dependencies**: Task 2.3
**Validation**: Memory usage <100MB

**Steps**:
1. Implement active request limit (1,000 max)
2. Implement lazy loading for history
3. Add pagination support to history view
4. Add memory usage monitoring
5. Test with large datasets

**Files Changed**:
- `src/models/Models.vala` - Request limits, lazy loading
- `src/windows/HistoryView.vala` - Pagination UI

**Acceptance**:
- Memory usage stays <100MB with 1,000 active requests
- Large histories load without freezing UI

---

## Phase 3: Feature Completions

### Task 3.1: Complete Request Filtering (Starred Filter) ✅ COMPLETED
**Capability**: request-filtering
**Estimated Effort**: 4 hours
**Dependencies**: Task 2.1 (if refactoring first)
**Validation**: Starred filter works

**Steps**:
1. Implement starred-only filter logic
2. Add filter persistence to GSettings
3. Test filter combinations
4. Update UI to show active filters

**Files Changed**:
- `src/windows/FilterPanel.vala` or `src/MainWindow.vala` - Complete filter implementation

**Acceptance**:
- TODO comment removed
- Starred filter works correctly
- Filter state persists

---

### Task 3.2: Implement Request Indexing ✅ COMPLETED
**Capability**: performance-optimization, request-filtering
**Estimated Effort**: 10 hours
**Dependencies**: Task 2.1
**Validation**: Filter performance <100ms

**Steps**:
1. Create `src/utils/RequestIndex.vala` (<400 lines)
2. Implement indexes for method, content_type, timestamp
3. Implement incremental index updates
4. Integrate with filter logic
5. Benchmark filter performance

**Files Changed**:
- `src/utils/RequestIndex.vala` - New file
- `src/models/Models.vala` - Use RequestIndex
- `src/windows/FilterPanel.vala` - Use indexed search

**Acceptance**:
- Filtering 10k requests completes in <100ms
- Indexes update incrementally

---

### Task 3.3: Implement Batched UI Updates ✅ COMPLETED
**Capability**: performance-optimization
**Estimated Effort**: 6 hours
**Dependencies**: Task 2.1
**Validation**: UI stays responsive during bursts

**Steps**:
1. Implement update batching in RequestsView
2. Add pending request queue
3. Use GLib.Timeout for batch flushing
4. Add chunked loading for bulk operations
5. Test with simulated request bursts

**Files Changed**:
- `src/windows/RequestsView.vala` - Batched updates

**Acceptance**:
- UI remains at 60fps during request bursts
- Updates are batched every 100ms

---

### Task 3.4: Implement JSON Parsing Cache ✅ COMPLETED
**Capability**: performance-optimization
**Estimated Effort**: 3 hours
**Dependencies**: None
**Validation**: Repeated views use cached output

**Steps**:
1. Add cached_formatted_body field to WebhookRequest
2. Modify get_formatted_body() to cache result
3. Add cache invalidation logic
4. Test cache hit rates

**Files Changed**:
- `src/models/Models.vala` - Add caching to WebhookRequest

**Acceptance**:
- Formatted body cached after first parse
- Performance improvement measurable

---

## Phase 4: New Features

### Task 4.1: Implement SignatureValidator Infrastructure ✅ COMPLETED
**Capability**: webhook-authentication
**Estimated Effort**: 8 hours
**Dependencies**: Task 1.2 (SecurityManager)
**Validation**: Unit tests pass for signature validation

**Steps**:
1. Create `src/utils/SignatureValidator.vala` (<300 lines)
2. Define SignatureProvider interface
3. Implement GitHub signature provider
4. Implement Stripe signature provider
5. Implement Slack signature provider
6. Implement generic HMAC provider
7. Write signature validation tests

**Files Changed**:
- `src/utils/SignatureValidator.vala` - New file
- `src/utils/providers/` - Provider implementations

**Acceptance**:
- All provider implementations pass tests
- Constant-time comparison used

---

### Task 4.2: Integrate Signature Validation with Server ✅ COMPLETED
**Capability**: webhook-authentication
**Estimated Effort**: 6 hours
**Dependencies**: Task 4.1
**Validation**: Webhooks validated correctly

**Steps**:
1. Add signature validation to webhook handler
2. Add validation result to WebhookRequest model
3. Implement provider auto-detection
4. Add validation status to UI
5. Test with real webhook examples

**Files Changed**:
- `src/managers/Server.vala` - Call SignatureValidator
- `src/models/Models.vala` - Add validation_result field
- `src/utils/RequestRow.vala` - Show validation badge

**Acceptance**:
- Valid signatures show success badge
- Invalid signatures show warning badge
- Validation is optional (configurable)

---

### Task 4.3: Add Signature Validation UI ✅ COMPLETED
**Capability**: webhook-authentication
**Estimated Effort**: 8 hours
**Dependencies**: Task 4.2
**Validation**: Configuration UI works correctly

**Steps**:
1. Add Security tab to PreferencesDialog
2. Add signature validation enable/disable toggle
3. Add provider secret configuration UI
4. Add "Test Signature" functionality
5. Store secrets using SecurityManager
6. Add validation details view in request detail

**Files Changed**:
- `src/dialogs/PreferencesDialog.vala` - Add Security tab
- `data/ui/preferences.blp` - Add security UI
- `src/utils/RequestRow.vala` - Show validation details

**Acceptance**:
- Users can configure provider secrets
- Test signature feature works
- Validation results visible in UI

---

### Task 4.4: Implement Export Infrastructure ✅ COMPLETED
**Capability**: export-formats
**Estimated Effort**: 6 hours
**Dependencies**: None
**Validation**: Plugin system works

**Steps**:
1. Create `src/export/ExportManager.vala` (<300 lines)
2. Define ExportFormatter interface
3. Implement JSON formatter (refactor existing)
4. Add format registration system
5. Add export dialog with format selection

**Files Changed**:
- `src/export/ExportManager.vala` - New file
- `src/export/formatters/` - Formatter implementations
- `src/MainWindow.vala` - Use ExportManager

**Acceptance**:
- Export system is extensible
- JSON export works via new system

---

### Task 4.5: Implement HAR Export Format ✅ COMPLETED
**Capability**: export-formats
**Estimated Effort**: 8 hours
**Dependencies**: Task 4.4
**Validation**: HAR files importable in Chrome DevTools

**Steps**:
1. Create `src/export/formatters/HarFormatter.vala` (<400 lines)
2. Implement HAR 1.2 spec format
3. Convert WebhookRequest to HAR entries
4. Add metadata (creator, browser, pages)
5. Test import in Chrome DevTools, Charles

**Files Changed**:
- `src/export/formatters/HarFormatter.vala` - New file

**Acceptance**:
- HAR file validates against spec
- Import works in browser tools

---

### Task 4.6: Implement CSV Export Format ✅ COMPLETED
**Capability**: export-formats
**Estimated Effort**: 4 hours
**Dependencies**: Task 4.4
**Validation**: CSV opens correctly in Excel/LibreOffice

**Steps**:
1. Create `src/export/formatters/CsvFormatter.vala` (<250 lines)
2. Implement CSV generation with proper escaping
3. Add column headers
4. Handle multiline content
5. Test with various spreadsheet applications

**Files Changed**:
- `src/export/formatters/CsvFormatter.vala` - New file

**Acceptance**:
- CSV properly formatted
- Opens correctly in spreadsheet apps

---

### Task 4.7: Implement cURL Export Format ✅ COMPLETED
**Capability**: export-formats
**Estimated Effort**: 4 hours
**Dependencies**: Task 4.4
**Validation**: cURL commands execute correctly

**Steps**:
1. Create `src/export/formatters/CurlFormatter.vala` (<250 lines)
2. Generate cURL commands with all options
3. Properly escape shell special characters
4. Add headers with -H flags
5. Test generated commands

**Files Changed**:
- `src/export/formatters/CurlFormatter.vala` - New file

**Acceptance**:
- cURL commands work correctly
- Special characters handled properly

---

### Task 4.8: Implement Selective Export ✅ COMPLETED
**Capability**: export-formats
**Estimated Effort**: 6 hours
**Dependencies**: Task 4.4
**Validation**: Export respects filters/selection

**Steps**:
1. Add selection support to request list
2. Add "Export Selected" option
3. Add "Export Filtered" option
4. Add confirmation dialog with count
5. Test various selection scenarios

**Files Changed**:
- `src/windows/RequestsView.vala` - Add selection
- `src/export/ExportManager.vala` - Handle selection/filtering

**Acceptance**:
- Export works with filters applied
- Multi-select export works
- Single request export works

---

## Phase 5: Testing & Documentation

### Task 5.1: Security Testing ✅ COMPLETED
**Capability**: security-hardening
**Estimated Effort**: 8 hours
**Dependencies**: All Phase 1 tasks
**Validation**: Security audit passes

**Steps**:
1. Write security test suite
2. Test path traversal prevention
3. Test SSRF prevention
4. Test rate limiting under load
5. Test input validation with fuzzing
6. Run static analysis tools
7. Document security mitigations

**Acceptance**:
- All security tests pass
- No high-severity vulnerabilities

---

### Task 5.2: Performance Testing ✅ COMPLETED
**Capability**: performance-optimization
**Estimated Effort**: 6 hours
**Dependencies**: All Phase 2 & 3 tasks
**Validation**: Performance targets met

**Steps**:
1. Benchmark JSON parsing performance
2. Benchmark filter performance with large datasets
3. Benchmark UI update rates
4. Test memory usage under load
5. Profile with valgrind/heaptrack
6. Document performance characteristics

**Acceptance**:
- JSON parsing <50ms for 1MB
- Filtering <100ms for 10k requests
- UI maintains 60fps
- Memory usage <100MB for typical use

---

### Task 5.3: Integration Testing ✅ COMPLETED
**Capability**: All
**Estimated Effort**: 8 hours
**Dependencies**: All feature tasks
**Validation**: End-to-end scenarios work

**Steps**:
1. Test complete webhook capture flow
2. Test token migration flow
3. Test signature validation flow
4. Test export in all formats
5. Test filter combinations
6. Test error recovery scenarios
7. Test on multiple Linux distributions

**Acceptance**:
- All integration tests pass
- Works on Ubuntu, Fedora, Arch

---

### Task 5.4: Update Documentation ✅ COMPLETED
**Capability**: All
**Estimated Effort**: 6 hours
**Dependencies**: All tasks
**Validation**: Documentation complete and accurate

**Steps**:
1. Update README.md with new features
2. Update CHANGELOG.md with all changes
3. Add security section to docs
4. Add export format documentation
5. Add signature validation guide
6. Update screenshots
7. Update metainfo.xml with release notes

**Files Changed**:
- `README.md` - Feature updates
- `CHANGELOG.md` - Version 2.2.0 notes
- `data/io.github.tobagin.sonar.metainfo.xml.in` - Release info
- `docs/` - New documentation files

**Acceptance**:
- All documentation up to date
- Screenshots current
- Release notes complete

---

## Summary

**Total Tasks**: 30
**Estimated Total Effort**: 180-200 hours (4-5 weeks full-time)

**Critical Path**:
1. Security tasks (Phase 1) - 30 hours
2. Code quality refactoring (Phase 2) - 32 hours
3. Feature completions (Phase 3) - 23 hours
4. New features (Phase 4) - 50 hours
5. Testing & docs (Phase 5) - 28 hours

**Parallelizable Work**:
- Tasks 1.4, 1.5, 1.6 can run in parallel
- Phase 2 can start before Phase 1 completes
- Phase 4 tasks can be done in any order after dependencies met

**Risk Mitigation**:
- All tasks include validation criteria
- Testing integrated throughout
- Incremental changes enable rollback
- Feature flags for risky changes
