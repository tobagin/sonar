# Design Document: Enhance Security and Features

## Architecture Overview

This design addresses security vulnerabilities, code quality, and feature gaps through a multi-layered approach that maintains backward compatibility while introducing significant improvements.

## Component Architecture

### 1. Security Layer

#### SecurityManager (New)
**Location**: `src/managers/SecurityManager.vala`

**Purpose**: Centralized security operations for credential management, encryption, and validation.

**Key Responsibilities**:
- Secure credential storage using libsecret
- Migration from plain-text GSettings to encrypted storage
- Input validation and sanitization
- Security policy enforcement

**Design Decisions**:
- Use libsecret (GNOME Keyring) for secure storage instead of plain GSettings
  - **Why**: libsecret provides OS-level encryption and secure storage
  - **Trade-off**: Adds dependency and Flatpak permission, but essential for security
- Implement graceful migration from existing plain-text tokens
  - **Why**: Avoid forcing all users to re-enter credentials
  - **Approach**: On first run, detect old token, migrate to secure storage, clear old value

**API Design**:
```vala
public class SecurityManager : Object {
    public async bool store_credential(string key, string value) throws Error;
    public async string? retrieve_credential(string key) throws Error;
    public async bool delete_credential(string key) throws Error;
    public bool validate_url(string url, out string error_message);
    public bool validate_path(string path);
}
```

#### RateLimiter (New)
**Location**: `src/managers/RateLimiter.vala`

**Purpose**: Protect against DoS attacks through request rate limiting.

**Design Decisions**:
- Token bucket algorithm for flexible rate limiting
  - **Why**: Allows burst traffic while maintaining average rate limits
  - **Config**: 100 requests/second default, configurable via GSettings
- Per-endpoint rate limiting
  - **Why**: Prevent single endpoint from monopolizing resources
- Memory-efficient: Only track active sources (LRU eviction)

**Implementation**:
```vala
public class RateLimiter : Object {
    private HashTable<string, TokenBucket> buckets;
    private int max_requests_per_second;
    private int burst_size;

    public bool check_rate_limit(string identifier) {
        // Returns true if allowed, false if rate limited
    }

    public void reset(string identifier) {
        // Clear rate limit for identifier
    }
}
```

#### SignatureValidator (New)
**Location**: `src/utils/SignatureValidator.vala`

**Purpose**: Validate webhook signatures from popular providers.

**Supported Providers**:
- GitHub (HMAC-SHA256)
- Stripe (HMAC-SHA256)
- Slack (HMAC-SHA256)
- Generic HMAC-SHA256, HMAC-SHA1

**Design Decisions**:
- Plugin-based architecture for easy provider additions
- Constant-time comparison to prevent timing attacks
- Support for multiple signature headers

**API**:
```vala
public interface SignatureProvider : Object {
    public abstract bool validate(
        string payload,
        HashTable<string, string> headers,
        string secret
    );
}

public class SignatureValidator : Object {
    public void register_provider(string name, SignatureProvider provider);
    public bool validate(string provider, string payload,
                        HashTable<string, string> headers, string secret);
}
```

### 2. Code Quality Improvements

#### MainWindow Refactoring
**Problem**: MainWindow.vala is 1,164 lines (exceeds 500-line limit)

**Solution**: Split into focused components

**New Structure**:
```
src/windows/
  ├── MainWindow.vala (300 lines) - Core window, state management
  ├── RequestsView.vala (250 lines) - Request list, filtering
  ├── HistoryView.vala (200 lines) - History management
  ├── TunnelControls.vala (150 lines) - Tunnel control UI
  └── FilterPanel.vala (200 lines) - Filter UI and logic
```

**Design Decisions**:
- Use composition over inheritance
- Each view is self-contained with signals for communication
- Shared state through RequestStorage model
- Blueprint files split accordingly

#### Error Handling Improvements

**Current Issues**:
- Tunnel failures don't retry
- Async operations lack cancellation
- Errors not always surfaced to users

**Solutions**:
1. **Retry Mechanism** for tunnel connections
   ```vala
   private async TunnelStatus start_with_retry(int max_attempts = 3) {
       for (int attempt = 1; attempt <= max_attempts; attempt++) {
           var status = yield start_async();
           if (status.active) return status;
           yield wait_exponential_backoff(attempt);
       }
       return new TunnelStatus.with_error("Failed after retries");
   }
   ```

2. **Cancellable Operations**: All async operations accept Cancellable parameter

3. **User Feedback**: All errors shown via toast notifications with actionable messages

### 3. New Features

#### Request Mocking System
**Location**: `src/managers/MockServer.vala`

**Purpose**: Allow users to define custom responses for testing webhook consumers.

**Design**:
- Define mock responses per endpoint pattern (glob/regex)
- Support dynamic responses (templates, scripts)
- Response delays and error simulation
- UI for managing mocks in preferences dialog

**Use Case**:
- User wants to test how their app handles 429 rate limit from Stripe
- Create mock rule: `/stripe-webhook` → 429 with retry-after header
- Test consumer behavior without hitting actual Stripe API

#### Enhanced Export Formats

**Current**: Only JSON export
**Adding**: CSV, HAR (HTTP Archive), cURL scripts, HTTP raw

**Design**:
```vala
public interface ExportFormatter : Object {
    public abstract string get_name();
    public abstract string get_extension();
    public abstract string format(Gee.List<WebhookRequest> requests) throws Error;
}

public class ExportManager : Object {
    private HashTable<string, ExportFormatter> formatters;

    public void register_formatter(ExportFormatter formatter);
    public string export(Gee.List<WebhookRequest> requests, string format);
}
```

**HAR Format Benefits**:
- Industry standard for HTTP traffic
- Import into Chrome DevTools, Charles, etc.
- Great for sharing with team

#### Webhook Signature Validation UI

**Location**: `src/dialogs/PreferencesDialog.vala` (Security tab)

**Features**:
- Enable/disable signature validation
- Configure secrets per provider
- Test signature validation with sample payloads
- Warning indicators when signatures fail

**UX Flow**:
1. User receives webhook from GitHub
2. If signature validation enabled and secret configured, validate
3. Show badge on request row (✓ Valid / ⚠ Invalid / – Not Validated)
4. In request detail, show validation result

### 4. Performance Optimizations

#### Request Indexing
**Problem**: Linear search through requests O(n)
**Solution**: Build indexes on common search fields

```vala
public class RequestIndex : Object {
    private HashTable<string, Gee.List<WebhookRequest>> by_method;
    private HashTable<string, Gee.List<WebhookRequest>> by_content_type;
    private HashTable<string, Gee.List<WebhookRequest>> by_path_prefix;

    public void add_request(WebhookRequest request);
    public Gee.List<WebhookRequest> search(SearchCriteria criteria);
}
```

**Benefits**:
- O(1) lookup by method, content type
- O(log n) for path prefix searches with trie structure
- Rebuild index in background thread on changes

#### Batched UI Updates

**Problem**: Each request triggers immediate UI update
**Solution**: Batch updates every 100ms

```vala
private uint update_timeout_id = 0;
private Gee.Queue<WebhookRequest> pending_requests;

private void on_request_added(WebhookRequest request) {
    pending_requests.offer(request);

    if (update_timeout_id == 0) {
        update_timeout_id = Timeout.add(100, () => {
            flush_pending_requests();
            update_timeout_id = 0;
            return Source.REMOVE;
        });
    }
}
```

#### Async Disk I/O

**Problem**: Sync file operations block main thread
**Solution**: Use GLib async I/O for all disk operations

```vala
private async void save_history_async() {
    var json_data = serialize_history();

    var temp_file = get_temp_file();
    yield temp_file.replace_contents_async(
        json_data.data,
        null,
        false,
        FileCreateFlags.REPLACE_DESTINATION,
        null
    );

    yield temp_file.move_async(history_file, FileCopyFlags.OVERWRITE);
}
```

### 5. Security Hardening

#### Input Validation Matrix

| Input | Validation | Limit | Sanitization |
|-------|-----------|-------|--------------|
| Request Path | Reject `..`, null bytes | 2048 chars | URL decode, normalize |
| Request Body | Check size | 10 MB | None (preserve original) |
| Headers | Key/value length | 128/8192 chars | Strip control chars |
| Forward URL | Valid URL, no file:// | 2048 chars | Parse and reconstruct |
| Method | Whitelist | 10 chars | Uppercase |
| Query Params | Key/value length | 128/2048 chars | URL decode |

#### SSRF Prevention (Webhook Forwarding)

**Vulnerability**: Users can forward to internal IPs (localhost, 169.254.0.0/16)

**Mitigation**:
```vala
public bool validate_forward_url(string url) {
    var uri = Uri.parse(url, UriFlags.NONE);

    // Block dangerous schemes
    if (uri.get_scheme() in ["file", "ftp", "gopher"]) {
        return false;
    }

    // Block private IP ranges
    var host = uri.get_host();
    if (is_private_ip(host) || is_link_local(host)) {
        return false;
    }

    return true;
}
```

**User Experience**:
- Show warning when adding localhost URLs
- Allow override with "I understand the risks" checkbox
- Disable by default in production

## Data Flow

### Secure Credential Flow
```
User enters token → SecurityManager.store_credential()
                 → libsecret stores in keyring
                 → Old GSettings value cleared

App needs token → SecurityManager.retrieve_credential()
                → libsecret retrieves from keyring
                → Returned to caller
```

### Request Processing with Security
```
HTTP Request → RateLimiter.check_rate_limit()
            → Input validation (path, headers, body)
            → SignatureValidator.validate() (if enabled)
            → WebhookServer._handle_webhook_request()
            → RequestStorage.add_request()
            → Forward (if enabled, with URL validation)
            → UI Update (batched)
```

### Filter Implementation Flow
```
User changes filter → FilterPanel emits filter_changed signal
                   → RequestsView updates filter_criteria
                   → RequestIndex.search(criteria) (fast lookup)
                   → RequestList updates visible items
                   → Batched render
```

## Migration Strategy

### Phase 1: Security (Non-Breaking)
1. Add SecurityManager, integrate libsecret
2. Migrate tokens on first launch
3. Add rate limiting (disabled by default)
4. Add input validation
5. Release as minor version bump (2.2.0)

### Phase 2: Refactoring (Internal)
1. Split MainWindow into views
2. Implement async I/O
3. Add request indexing
4. Performance optimizations
5. Release as patch (2.2.1)

### Phase 3: New Features
1. Request mocking system
2. Signature validation
3. Enhanced export formats
4. Complete filter implementation
5. Release as minor version (2.3.0)

## Testing Strategy

### Security Tests
- Unit tests for input validation
- Fuzzing test for path traversal
- SSRF prevention tests
- Rate limiter stress tests
- Signature validation test vectors

### Performance Tests
- Benchmark JSON parsing (target: <50ms for 1MB)
- UI responsiveness (target: <100ms for 100 requests)
- Memory usage (target: <100MB for 1000 requests)
- Disk I/O latency

### Integration Tests
- Token migration flow
- End-to-end webhook capture
- Filter functionality
- Export all formats

## Configuration

New GSettings keys:
```xml
<key name="rate-limit-enabled" type="b">
  <default>false</default>
</key>

<key name="rate-limit-per-second" type="i">
  <default>100</default>
</key>

<key name="signature-validation-enabled" type="b">
  <default>false</default>
</key>

<key name="max-request-body-size" type="i">
  <default>10485760</default> <!-- 10 MB -->
</key>

<key name="ssrf-protection-enabled" type="b">
  <default>true</default>
</key>
```

## Rollback Plan

If critical issues discovered:
1. Revert to v2.1.0 Flatpak
2. Security fixes can be cherry-picked as hotfix
3. Token migration is reversible (keep old value until confirmed working)
4. All features behind feature flags for easy disable
