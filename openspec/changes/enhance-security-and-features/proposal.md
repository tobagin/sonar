# Enhance Security and Features

## Overview

This change proposal addresses critical security vulnerabilities, code quality improvements, and missing features identified through comprehensive codebase analysis of the Sonar webhook inspector application.

## Why

During a comprehensive security and code quality audit of Sonar v2.1.0, we discovered several critical issues that require immediate attention:

1. **Security Posture is Inadequate**: Plain-text credential storage, no rate limiting, and SSRF vulnerabilities expose users to significant security risks. As a tool that handles webhook data (which may include sensitive information), Sonar must implement industry-standard security practices.

2. **Code Quality Violations**: MainWindow.vala at 1,164 lines violates the project's 500-line maximum by 232%, making the codebase difficult to maintain and test. This technical debt will compound as features are added.

3. **Incomplete Features**: A TODO comment in production code indicates incomplete filtering functionality, and users have reported missing capabilities like webhook signature validation and advanced export formats that are standard in competing tools.

4. **Performance Issues**: Linear search through requests causes UI lag with large histories (500ms+ for 10k requests), and synchronous disk I/O blocks the UI during saves. These issues create a poor user experience.

5. **Competitive Disadvantage**: Without signature validation, multiple export formats, and robust security, Sonar cannot compete with commercial webhook inspection tools despite having a solid foundation.

**This change is necessary now because**:
- Security vulnerabilities put users at risk and damage project reputation
- Code quality issues will become harder to fix as the codebase grows
- Users are requesting missing features that competitors already have
- Performance problems worsen as usage scales

By addressing these issues comprehensively, we establish a solid foundation for future development and position Sonar as a professional-grade webhook inspection tool.

## Problem Statement

After thorough analysis of the Sonar codebase (v2.1.0), several areas require improvement:

### Security Concerns
1. **Auth Token Storage**: Ngrok auth tokens are stored in GSettings without encryption, exposing credentials in plain text
2. **Request Size Limits**: While basic validation exists, there's no rate limiting to prevent DoS attacks
3. **Subprocess Security**: ngrok subprocess execution lacks proper input validation and error handling
4. **SSRF Vulnerability**: Webhook forwarding feature allows arbitrary URLs without validation
5. **Path Traversal Risk**: No validation on request paths that could exploit file system operations

### Code Quality Issues
1. **Large Files**: MainWindow.vala (1,164 lines) exceeds the 500-line project constraint
2. **Missing Error Recovery**: Tunnel failures don't provide automatic retry mechanisms
3. **No Logging Levels**: All logging uses fixed levels without runtime configurability
4. **Memory Management**: No limits on in-memory request storage before disk persistence
5. **Resource Cleanup**: Some async operations lack proper cancellation handling

### Missing Features
1. **Request Filtering**: Incomplete filter implementation (TODO found in MainWindow.vala:965)
2. **Webhook Authentication**: No support for validating webhook signatures (GitHub, Stripe, etc.)
3. **Custom Headers**: Cannot add custom headers to forwarded requests
4. **Request Mocking**: No ability to mock responses for testing webhook consumers
5. **Export Formats**: Limited export options (only JSON, missing CSV, HAR format)
6. **Dark Mode Assets**: Application theme support incomplete
7. **Internationalization**: No translation support (empty po/ directory)
8. **Performance Monitoring**: No metrics on server performance or response times
9. **Webhook Scheduling**: No ability to schedule or batch replay requests
10. **API Webhooks**: No REST API for programmatic access

### Performance Opportunities
1. **JSON Parsing**: Repeated JSON parsing without caching formatted output
2. **UI Updates**: Request list updates aren't batched, causing UI lag
3. **Disk I/O**: Synchronous file operations block the main thread
4. **Search Performance**: Linear search through requests without indexing

## Scope

This proposal encompasses:

1. **Security Hardening** - Implement encryption, rate limiting, and input validation
2. **Code Refactoring** - Split large files and improve error handling
3. **Feature Completions** - Implement missing filter functionality and webhook authentication
4. **New Capabilities** - Add request mocking, enhanced export, and performance monitoring
5. **Architecture Improvements** - Implement async patterns and resource management

## Success Criteria

- All security vulnerabilities addressed with appropriate mitigations
- No source files exceed 500 lines
- Code coverage >80% for critical security functions
- Performance improvements: <100ms UI updates, <50ms JSON parsing
- All TODO/FIXME comments resolved
- Zero high-severity security issues in audit

## Affected Components

- `src/managers/Server.vala` - Rate limiting, request validation
- `src/managers/Tunnel.vala` - Secure credential storage
- `src/MainWindow.vala` - File splitting, filter completion
- `src/models/Models.vala` - Request indexing, caching
- `src/dialogs/PreferencesDialog.vala` - Security settings
- New files: SecurityManager, RateLimiter, SignatureValidator, MockServer

## Dependencies

- **libsecret** - For secure credential storage (replacing plain GSettings)
- **libsodium** or GLib Crypto - For signature validation
- No breaking changes to existing dependencies

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| libsecret adds Flatpak permission | Low | Required for secure storage, minimal attack surface |
| Refactoring breaks existing functionality | High | Comprehensive testing, incremental refactoring |
| Performance regression from new features | Medium | Benchmarking, profiling, feature flags |
| Breaking changes for users | Low | Backward compatible migrations |

## Timeline Estimate

- Security fixes: 2-3 days
- Code quality improvements: 2-3 days
- Feature completions: 3-4 days
- New capabilities: 5-7 days
- Testing and documentation: 2-3 days
- **Total: 14-20 days**

## Open Questions

1. Should we maintain backward compatibility for plain-text stored tokens, or force re-entry?
2. What should be the default rate limit (requests/second)?
3. Should webhook signature validation be enabled by default or opt-in?
4. Should we implement API webhooks now or defer to future release?
5. What export formats are highest priority (CSV, HAR, others)?

## Related Work

- Previous refactor: `reorganize-codebase-structure` (completed)
- Project specs: `vala-naming`, `directory-structure`, `changelog-format`
- Flatpak security best practices
- OWASP secure coding guidelines
