# Sonar - Feature Roadmap & TODO

This document tracks potential features and enhancements for the Sonar webhook inspector application.

**Last Updated**: 2025-10-20
**Current Version**: 2.2.0

---

## 🎯 Top Priority Features (v2.3.0)

### 1. Response Configuration System 🏆 HIGH VALUE
**Status**: Not Started
**Complexity**: Medium
**Impact**: Critical for proper webhook testing

Currently, Sonar always returns `200 OK` to all webhook requests. Real webhook testing requires testing how providers handle different response codes.

**Features to Implement**:
- [ ] Configure custom response status codes (200, 201, 202, 400, 500, 503, etc.)
- [ ] Custom response headers configuration
- [ ] Custom response body templates
- [ ] Conditional responses based on request patterns (path, method, headers)
- [ ] Response delay simulation (test timeout handling)
- [ ] Response templates for common scenarios
- [ ] Per-path response configuration
- [ ] Default response policy settings

**Use Cases**:
- Test retry logic (return 500, verify provider retries)
- Test accepted response handling (return 202 Accepted)
- Test error handling (return 400 with error body)
- Test timeout scenarios (add artificial delays)

**Technical Notes**:
- Extend `WebhookServer` in [src/managers/Server.vala](src/managers/Server.vala)
- Add UI in preferences dialog for response configuration
- Store response rules in RequestStorage model
- Match requests against rules and return configured responses

---

### 2. CLI Tool for Automation 🤖 HIGH VALUE
**Status**: Not Started
**Complexity**: High
**Impact**: Opens CI/CD and automation use cases

Create a command-line interface for Sonar that enables scripting, automation, and CI/CD integration.

**Features to Implement**:
- [ ] Basic CLI framework (`sonar-cli` binary)
- [ ] Capture mode: `sonar capture --duration 30s --export results.json`
- [ ] Assert mode: `sonar assert --file captured.json --schema expected.json`
- [ ] Export commands: `sonar export --format har --output webhooks.har`
- [ ] Server control: `sonar start`, `sonar stop`, `sonar status`
- [ ] Headless mode for CI environments
- [ ] JSON output for machine parsing
- [ ] Exit codes for success/failure
- [ ] Configuration via env vars or config file

**Use Cases**:
- Integration into GitHub Actions/GitLab CI
- Automated webhook testing in pipelines
- Scripted testing workflows
- Headless webhook capture in containers
- Batch processing of webhook data

**Technical Notes**:
- Create new `src/cli/` directory with CLI application
- Share core logic with GUI app (managers, models, utils)
- Use libsoup for server without GTK dependency
- Consider using `glib-2.0` GOptionContext for argument parsing
- Package as separate binary `sonar-cli` alongside GUI `sonar`

---

### 3. Mock Server Mode 🎭 HIGH VALUE
**Status**: Not Started
**Complexity**: Medium
**Impact**: Enables offline testing and simulation

Allow Sonar to act as a mock webhook server that simulates provider behavior without requiring actual third-party services.

**Features to Implement**:
- [ ] Mock mode toggle in preferences
- [ ] Pre-configured response templates (success, failure, timeout)
- [ ] Rule-based responses (if path matches X, return Y)
- [ ] Delay simulation with configurable ranges
- [ ] Failure injection (random or deterministic errors)
- [ ] Load testing mode (send burst of requests)
- [ ] Mock data generation (realistic webhook payloads)
- [ ] Import mock definitions from templates

**Use Cases**:
- Offline development without internet connectivity
- Test webhook integrations without provider access
- Simulate error scenarios (500 errors, timeouts)
- Development environment setup without API keys
- Integration testing without external dependencies

**Technical Notes**:
- Add mock mode flag to `WebhookServer`
- Create `MockResponseEngine` class to handle rule matching
- Store mock rules in templates or separate config
- UI toggle in preferences to enable/disable mock mode
- Consider template variables for dynamic data ({{timestamp}}, {{uuid}})

---

### 4. Request Editor with Enhanced Replay 📝 HIGH VALUE
**Status**: Not Started
**Complexity**: Medium
**Impact**: Significantly improves testing flexibility

Currently, replay sends the exact captured request. Add ability to modify requests before replaying.

**Features to Implement**:
- [ ] Visual request editor dialog
- [ ] Edit HTTP method before replay
- [ ] Edit headers (add, remove, modify)
- [ ] Edit body content with syntax highlighting
- [ ] Edit query parameters
- [ ] Variable substitution ({{timestamp}}, {{uuid}}, {{random}})
- [ ] Bulk replay (multiple requests in sequence)
- [ ] Replay with delays between requests
- [ ] Save edited requests as new templates
- [ ] Request chaining (use response from one in next request)

**Use Cases**:
- Test edge cases by modifying captured data
- Test authentication with different tokens
- Test validation by sending invalid data
- Create test scenarios from real examples
- Fuzzing by generating request variations

**Technical Notes**:
- Create new `RequestEditorDialog` in [src/dialogs/](src/dialogs/)
- Add Blueprint UI definition in [data/ui/](data/ui/)
- Use GtkSourceView for syntax-highlighted editing
- Implement template variable parser/replacer
- Extend replay functionality in MainWindow

---

## 🚀 High-Value Features (v2.4.0)

### 5. Multi-Tunnel & Port Management 🌐 MEDIUM VALUE
**Status**: Not Started
**Complexity**: High
**Impact**: Expands testing to multiple services

**Features**:
- [ ] Run multiple ngrok tunnels simultaneously
- [ ] Configure custom local server ports (not just 8000)
- [ ] Port forwarding rules (route paths to different ports)
- [ ] Custom ngrok subdomains (paid plan feature)
- [ ] Multi-service routing (different webhooks to different services)
- [ ] Tunnel profiles (save/load tunnel configurations)
- [ ] Visual tunnel management UI

**Technical Notes**:
- Refactor `TunnelManager` to support multiple instances
- Array/HashMap of active tunnels
- UI list showing all active tunnels with start/stop controls
- Port conflict detection and handling

---

### 6. Webhook Security Testing Tools 🔒 HIGH VALUE
**Status**: Not Started
**Complexity**: Medium
**Impact**: Unique differentiator, security focus

**Features**:
- [ ] Signature testing tool (test with different HMAC keys)
- [ ] Security headers analyzer (flag missing headers)
- [ ] Payload sanitization testing (send malicious payloads)
- [ ] Replay attack detection testing
- [ ] CORS configuration testing
- [ ] Rate limit testing (verify limits work correctly)
- [ ] SSRF vulnerability testing (attempt private IPs)
- [ ] Security report generation

**Technical Notes**:
- Create new `SecurityTestingDialog`
- Extend `SignatureValidator` with testing mode
- Add malicious payload templates (XSS, SQLi, path traversal)
- Generate security audit reports

---

### 7. Schema Inference & Documentation 📚 MEDIUM VALUE
**Status**: Not Started
**Complexity**: Medium
**Impact**: Helps understand and document webhook APIs

**Features**:
- [ ] Automatically infer JSON schema from captured webhooks
- [ ] Track schema evolution over time
- [ ] Generate OpenAPI/Swagger documentation
- [ ] Export as Postman collection
- [ ] Generate integration guide markdown
- [ ] Schema validation against new requests
- [ ] Detect schema breaking changes
- [ ] Visual schema viewer

**Technical Notes**:
- Implement JSON schema inference algorithm
- Store inferred schemas in RequestStorage
- Create schema comparison logic
- Generate OpenAPI 3.0 spec from schemas
- Add export options in ExportUtils

---

### 8. Request Collections & Organization 📦 MEDIUM VALUE
**Status**: Not Started
**Complexity**: Low-Medium
**Impact**: Better organization for complex projects

**Features**:
- [ ] Create named collections of related requests
- [ ] Move requests between collections
- [ ] Collection-level filters and search
- [ ] Export/import collections
- [ ] Collection descriptions and metadata
- [ ] Nested collections (hierarchical organization)
- [ ] Collection sharing (export as bundle)
- [ ] Default collection for new requests

**Technical Notes**:
- Add `RequestCollection` model to Models.vala
- Extend RequestStorage with collection management
- UI for collection creation/management
- Sidebar or dropdown for collection navigation

---

## 🎨 UI/UX Enhancements (Ongoing)

### 9. Enhanced UI Features 🖼️ LOW-MEDIUM VALUE
**Status**: Not Started
**Complexity**: Low-Medium

**Features**:
- [ ] Manual dark/light theme toggle (beyond system preference)
- [ ] Request pinning (pin to top of list)
- [ ] Custom tags/labels with colors
- [ ] Batch operations (select multiple requests for bulk actions)
- [ ] Quick filters bar (one-click common filters)
- [ ] Split view (view two requests side-by-side)
- [ ] Request grouping (by date, method, content-type)
- [ ] Collapsible sections (independently collapse headers, body)
- [ ] Customizable columns in list view
- [ ] Drag-and-drop request reordering

**Technical Notes**:
- Add tag system to WebhookRequest model
- Implement multi-selection in request ListBox
- Create quick filter widgets in header bar
- Add split view mode to MainWindow

---

## 🤝 Collaboration Features (v3.0.0 - Future)

### 10. Team Collaboration & Sharing 👥 HIGH VALUE
**Status**: Not Started (Future)
**Complexity**: Very High
**Impact**: Opens enterprise market

**Features**:
- [ ] Export/import requests with shareable files
- [ ] Team workspaces (shared webhook collections)
- [ ] Cloud sync (optional, sync across devices)
- [ ] Collaborative annotations (comments on requests)
- [ ] Shared template library
- [ ] Team member permissions
- [ ] Activity feed (who viewed/edited what)
- [ ] Request sharing via URL

**Technical Notes**:
- Requires backend service for cloud features
- Consider E2E encryption for privacy
- Export format for sharing (ZIP with metadata)
- Authentication/authorization system

---

## 🔧 Technical Enhancements

### 11. Protocol Support Extensions 🌐 MEDIUM VALUE
**Status**: Not Started
**Complexity**: High

**Features**:
- [ ] WebSocket support (capture and inspect WebSocket connections)
- [ ] GraphQL support (special handling for GraphQL payloads)
- [ ] gRPC support (capture and decode gRPC requests)
- [ ] MQTT support (listen for MQTT messages)
- [ ] Server-Sent Events (SSE) support
- [ ] Custom protocol plugin system

**Technical Notes**:
- WebSocket: Use libsoup WebSocket API
- GraphQL: Parse introspection queries, show schema
- gRPC: Requires protobuf parsing
- Plugin system: Consider GModule for dynamic loading

---

### 12. Advanced Filtering & Search 🔍 LOW VALUE
**Status**: Not Started
**Complexity**: Medium

**Features**:
- [ ] JSONPath queries (filter by JSON field values)
- [ ] Regular expression search
- [ ] Saved filter presets
- [ ] Smart filters (auto-suggest based on patterns)
- [ ] Header-specific search
- [ ] Query parameter filtering
- [ ] Size-based filtering
- [ ] Custom filter expressions

**Technical Notes**:
- Implement JSONPath parser or use library
- Add regex support to FilterManager
- Store saved filters in GSettings
- Create filter expression DSL

---

### 13. Privacy & Data Management 🔐 MEDIUM VALUE
**Status**: Not Started
**Complexity**: Medium

**Features**:
- [ ] Auto-expiry (delete requests older than X days)
- [ ] Sensitive data redaction (auto-detect/mask PII)
- [ ] Request size limits (reject or truncate large requests)
- [ ] Selective persistence (choose what to save)
- [ ] Request history encryption at rest
- [ ] GDPR compliance mode (auto-redact personal data)
- [ ] Request retention policies
- [ ] Secure delete (overwrite before deleting)

**Technical Notes**:
- Implement PII detection (regex for emails, tokens, IPs)
- Add encryption layer for history.json
- Create retention policy settings in preferences
- Auto-cleanup job on app start

---

### 14. Performance & Monitoring 📊 LOW VALUE
**Status**: Not Started
**Complexity**: Low-Medium

**Features**:
- [ ] Real-time metrics dashboard (request rate, sizes)
- [ ] Performance graphs (request volume over time)
- [ ] Memory usage monitor
- [ ] Request size distribution histogram
- [ ] Export analytics as CSV/JSON
- [ ] Webhook latency tracking
- [ ] System resource usage graphs
- [ ] Performance alerts (when metrics exceed thresholds)

**Technical Notes**:
- Extend StatisticsDialog with real-time charts
- Use Cairo for custom graphs or consider libgchart
- Track metrics in-memory with rolling windows
- Add metrics export to ExportUtils

---

### 15. Request Transformation Pipeline 🔄 LOW VALUE
**Status**: Not Started
**Complexity**: High

**Features**:
- [ ] Transform requests before forwarding
- [ ] Format conversion (JSON ↔ XML ↔ form-data)
- [ ] Field mapping/renaming
- [ ] Request enrichment (add fields)
- [ ] Validation pipeline (schema validation)
- [ ] Custom transformation scripts
- [ ] Transformation templates
- [ ] Visual transformation builder

**Technical Notes**:
- Create TransformationEngine class
- Support JavaScript or Vala-based transforms
- Store transformation rules in templates
- Apply transformations in forwarding pipeline

---

## 📋 Completed Features (v2.2.0 and earlier)

✅ **Core webhook capture and inspection**
✅ **ngrok integration with public URLs**
✅ **Request history with persistent storage**
✅ **Advanced filtering (method, content-type, time, search)**
✅ **Request bookmarking/starring**
✅ **Request comparison (side-by-side diff)**
✅ **Request replay to custom URLs**
✅ **Request templates**
✅ **Webhook forwarding to multiple URLs**
✅ **Export formats (HAR, CSV, cURL, JSON)**
✅ **Security hardening (encrypted credentials, rate limiting)**
✅ **SSRF prevention**
✅ **Webhook signature validation (GitHub, Stripe, HMAC)**
✅ **Performance optimization (O(1) indexing, batched UI)**
✅ **Statistics dashboard**
✅ **Keyboard shortcuts**

---

## 🏆 Competitive Feature Comparison

| Feature | Sonar | RequestBin | Webhook.site | Beeceptor | ngrok |
|---------|-------|------------|--------------|-----------|-------|
| Native Desktop App | ✅ | ❌ | ❌ | ❌ | ✅ |
| Real-time Capture | ✅ | ✅ | ✅ | ✅ | ✅ |
| Request Filtering | ✅ | ⚠️ | ✅ | ✅ | ✅ |
| Request Comparison | ✅ | ❌ | ❌ | ❌ | ❌ |
| Request Templates | ✅ | ❌ | ❌ | ✅ | ❌ |
| Webhook Forwarding | ✅ | ❌ | ✅ | ✅ | ✅ |
| Export (HAR, CSV, cURL) | ✅ | ⚠️ | ⚠️ | ❌ | ⚠️ |
| Encrypted Credentials | ✅ | N/A | N/A | N/A | ⚠️ |
| Rate Limiting | ✅ | ❌ | ⚠️ | ✅ | ✅ |
| Signature Validation | ✅ | ❌ | ✅ | ❌ | ❌ |
| **Custom Responses** | ❌ | ✅ | ✅ | ✅ | ❌ |
| **Mock Server Mode** | ❌ | ❌ | ❌ | ✅ | ❌ |
| **CLI Tool** | ❌ | ⚠️ | ⚠️ | ❌ | ✅ |
| **Team Collaboration** | ❌ | ✅ | ✅ | ✅ | ✅ |
| **Multi-Tunnel** | ❌ | N/A | N/A | N/A | ✅ |
| **Request Editor** | ❌ | ❌ | ⚠️ | ⚠️ | ❌ |

**Legend**: ✅ Full Support | ⚠️ Partial Support | ❌ Not Available | N/A Not Applicable

---

## 📝 Implementation Notes

### Development Guidelines
- Follow existing architecture patterns (managers, models, components, utils)
- Keep files under 500 lines (refactor if approaching limit)
- Add Vala unit tests for new functionality
- Update CHANGELOG.md with all user-facing changes
- Use Blueprint for UI definitions
- Follow GNOME HIG (Human Interface Guidelines)
- Maintain security-first approach for all features

### Code Organization
```
src/
├── managers/      # Backend logic (Server, Tunnel, Security, etc.)
├── models/        # Data models (WebhookRequest, Templates, etc.)
├── components/    # Reusable UI components
├── dialogs/       # Dialog windows (Preferences, Statistics, etc.)
├── utils/         # Utility classes (Export, Validation, etc.)
└── cli/           # CLI tool (future)
```

### Testing Requirements
- Add test cases to `tests/` directory
- Security features require security tests
- Performance features require benchmarks
- UI features require manual testing checklist

---

## 🗺️ Roadmap Summary

**v2.3.0** (Q4 2025) - **Testing & Automation**
- Response Configuration System
- CLI Tool for Automation
- Mock Server Mode
- Request Editor with Enhanced Replay

**v2.4.0** (Q1 2026) - **Advanced Features**
- Multi-Tunnel Support
- Webhook Security Testing Tools
- Schema Inference & Documentation
- Request Collections

**v3.0.0** (2026) - **Collaboration & Enterprise**
- Team Collaboration Features
- Cloud Sync (optional)
- Advanced Protocol Support
- Enterprise Security Features

---

## 💬 Contributing

See feature requests and contribute ideas at:
- GitHub Issues: https://github.com/tobagin/sonar/issues
- GitHub Discussions: https://github.com/tobagin/sonar/discussions

---

**Last Updated**: 2025-10-20
**Maintainer**: @tobagin
