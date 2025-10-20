# Security Hardening

This spec defines security improvements for credential storage, request validation, rate limiting, and SSRF prevention.

## ADDED Requirements

### Requirement: Secure Credential Storage
The application MUST store sensitive credentials (ngrok auth tokens, webhook secrets) using encrypted storage provided by libsecret instead of plain-text GSettings.

**Rationale**: Plain-text credential storage exposes users to credential theft if their system is compromised.

**Priority**: CRITICAL

#### Scenario: Store ngrok auth token securely
- **Given** the user enters a valid ngrok auth token
- **When** the token is saved
- **Then** the token MUST be stored in the system keyring via libsecret
- **And** the token MUST NOT appear in plain text in any configuration file
- **And** the old GSettings value MUST be cleared after migration

#### Scenario: Retrieve credential from secure storage
- **Given** a credential has been stored in the keyring
- **When** the application needs to retrieve the credential
- **Then** the credential MUST be retrieved from libsecret
- **And** the credential MUST be kept in memory only as long as needed
- **And** retrieval failures MUST be handled gracefully

#### Scenario: Migrate existing plain-text credentials
- **Given** the user has an existing plain-text token in GSettings
- **When** the application launches with the new version
- **Then** the token MUST be automatically migrated to secure storage
- **And** the user MUST be notified of the migration
- **And** the plain-text value MUST be cleared from GSettings

---

### Requirement: Request Rate Limiting
The webhook server MUST implement rate limiting to prevent denial-of-service attacks from excessive requests.

**Rationale**: Without rate limiting, malicious actors can overwhelm the server with requests, causing performance degradation or crashes.

**Priority**: HIGH

#### Scenario: Enforce rate limit on webhook requests
- **Given** rate limiting is enabled with a limit of 100 requests/second
- **When** more than 100 requests arrive from the same source within one second
- **Then** excess requests MUST be rejected with HTTP 429 (Too Many Requests)
- **And** the response MUST include a Retry-After header
- **And** the rate limit status MUST be logged

#### Scenario: Allow burst traffic within limits
- **Given** rate limiting uses a token bucket algorithm
- **When** a burst of requests arrives after a quiet period
- **Then** the burst MUST be allowed up to the burst size limit
- **And** subsequent requests MUST be rate-limited normally
- **And** the average rate MUST not exceed the configured limit

#### Scenario: Configure rate limit settings
- **Given** the user opens application preferences
- **When** navigating to the Security tab
- **Then** the user MUST be able to enable/disable rate limiting
- **And** the user MUST be able to set requests per second limit
- **And** the user MUST be able to set burst size
- **And** changes MUST take effect immediately without restart

---

### Requirement: Input Validation and Sanitization
All webhook request inputs MUST be validated and sanitized to prevent injection attacks and malformed data processing.

**Rationale**: Insufficient input validation can lead to security vulnerabilities including path traversal, XSS, and buffer overflow attacks.

**Priority**: CRITICAL

#### Scenario: Validate request path for safety
- **Given** a webhook request is received
- **When** the request path contains `..`, null bytes, or control characters
- **Then** the path MUST be rejected or sanitized
- **And** the request MUST be logged as suspicious
- **And** a 400 Bad Request response MUST be returned

#### Scenario: Enforce request body size limits
- **Given** the webhook server is configured with a 10MB body limit
- **When** a request arrives with a body larger than 10MB
- **Then** the request MUST be rejected with HTTP 413 (Payload Too Large)
- **And** the connection MUST be closed
- **And** no partial data MUST be processed

#### Scenario: Sanitize header values
- **Given** a webhook request contains headers
- **When** header values contain control characters or exceed length limits
- **Then** control characters MUST be stripped or escaped
- **And** values exceeding 8192 characters MUST be truncated
- **And** a warning MUST be logged for sanitized values

---

### Requirement: SSRF Prevention in Webhook Forwarding
Webhook forwarding MUST prevent Server-Side Request Forgery by validating and restricting target URLs.

**Rationale**: Unrestricted URL forwarding allows attackers to probe internal networks and access restricted resources.

**Priority**: HIGH

#### Scenario: Block forwarding to private IP ranges
- **Given** webhook forwarding is enabled
- **When** the user attempts to add a forward URL pointing to a private IP (127.0.0.1, 10.0.0.0/8, 192.168.0.0/16, 169.254.0.0/16)
- **Then** the URL MUST be rejected by default
- **And** a warning message MUST explain the security risk
- **And** an override option MUST be available with explicit acknowledgment

#### Scenario: Block dangerous URL schemes
- **Given** a user attempts to add a forward URL
- **When** the URL uses a dangerous scheme (file://, ftp://, gopher://)
- **Then** the URL MUST be rejected
- **And** an error message MUST indicate only http:// and https:// are allowed
- **And** no override option MUST be provided

#### Scenario: Validate URL format before forwarding
- **Given** a forward URL is configured
- **When** a webhook is being forwarded
- **Then** the URL MUST be re-validated before sending
- **And** DNS resolution MUST be checked for private IPs
- **And** connection timeouts MUST be enforced (5 seconds max)

## MODIFIED Requirements

None - This is a new security capability.

## REMOVED Requirements

None - No existing functionality is being removed.
