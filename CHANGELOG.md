# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.2.1] - 2025-10-20

### Fixed
- Fixed screenshot URLs in metainfo after directory reorganization (screenshots moved to data/screenshots)

## [2.2.0] - 2025-10-20

### Added
- **Security Hardening**: Secure credential storage using libsecret (GNOME Keyring)
- **Security**: DoS protection with configurable rate limiting (100 req/s, burst 200)
- **Security**: SSRF prevention with URL validation and private IP filtering
- **Security**: Comprehensive input validation for all webhook data
- **Security**: Webhook signature validation for GitHub, Stripe, and custom HMAC
- **Performance**: O(1) request indexing for instant lookups
- **Performance**: Batched UI updates (100ms intervals) for smooth 60fps rendering
- **Performance**: JSON parsing cache to avoid redundant parsing
- **Performance**: Async disk I/O to prevent UI freezing
- **Export**: HAR (HTTP Archive) format export
- **Export**: CSV export with customizable fields
- **Export**: Enhanced cURL export with proper authentication headers
- **Export**: Selective export (export specific requests)
- **Feature**: Request filtering by method, content-type, time, and starred status
- **Feature**: Request comparison to see differences between webhooks
- **Reliability**: Exponential backoff retry for tunnel connection (3 attempts)
- **Testing**: Comprehensive test suite with 4 automated test scripts
- **Testing**: Security testing suite for validation and rate limiting
- **Testing**: Performance benchmarking tools
- **Documentation**: Complete testing guide (TESTING_GUIDE.md)
- **Documentation**: Quick start testing guide (QUICK_START_TESTING.md)

### Changed
- Webhook server now starts automatically on application launch
- Improved memory management with LRU eviction strategies
- Enhanced error handling with detailed validation messages
- Better tunnel status UI with retry feedback

### Fixed
- Subprocess assertion error when checking ngrok process status
- Path validation false positives from buggy null byte detection
- GLib-GIO-CRITICAL warnings in tunnel management
- Circular reference crash in component initialization

### Security
- Migrated from plaintext credential storage to encrypted GNOME Keyring
- Added rate limiting to prevent DoS attacks
- Implemented SSRF protection for webhook forwarding
- Added timing-safe signature comparison to prevent timing attacks
- URL-encoded control character validation

## [2.1.0] - 2025-10-09

### Added
- Advanced filtering by HTTP method (GET, POST, PUT, DELETE, etc.)
- Filter by content-type (JSON, XML, form-data, etc.)
- Filter by time range (5min, 15min, 30min, 1hr, 24hr)
- Full-text search in request path and body
- Request bookmarking/starring functionality
- Filter view to show only starred requests
- Request replay capability to resend webhooks to custom URLs
- Side-by-side request comparison feature
- Request templates for saving and reusing webhook patterns
- Automatic webhook forwarding to multiple URLs
- Enhanced export as cURL command with proper escaping
- Export as raw HTTP request format

### Changed
- Improved request inspection UI with bookmarking controls
- Enhanced copy functionality with multiple format support

## [2.0.3] - 2025-10-08

### Changed
- Redesigned keyboard shortcuts dialog with cleaner, more organized layout
- Improved shortcuts presentation using native Libadwaita components
- Reorganized main menu for better user experience
- Grouped related actions together logically
- Moved frequently used actions to the top

### Fixed
- Simplified shortcuts dialog implementation
- Reduced code complexity and improved maintainability
- Better resource management and performance

## [2.0.2] - 2025-09-18

### Fixed
- Fixed metainfo validation error causing build failures
- Removed template release entry that caused ordering issues
- Better appstream compliance
- Enhanced build process reliability

## [2.0.1] - 2025-09-18

### Changed
- Updated runtime version to 49 for improved compatibility
- Enhanced metainfo with additional configuration items
- Better system integration
- Enhanced stability
- Improved runtime performance

## [2.0.0] - 2025-08-25

### Changed
- **BREAKING:** Complete rewrite from Python to Vala
- Dramatically improved performance and startup times
- Eliminated Python runtime dependency - now a truly native GTK4 application
- Reduced memory footprint and system resource usage
- Enhanced stability and reliability through compile-time type checking
- Migrated to Meson build system for better performance and maintainability

### Added
- Comprehensive preferences dialog with advanced configuration options
- Keyboard shortcuts dialog with customizable key bindings
- Detailed request statistics and analytics dashboard
- Enhanced main window with improved layout and responsiveness
- Better integration with GNOME desktop environment
- Proper GSettings integration for persistent configuration
- Improved error handling and user feedback mechanisms
- Enhanced request processing and display performance
- Automated Flatpak packaging with GitHub Actions
- Real-time performance metrics and monitoring
- Enhanced request history with filtering and search capabilities
- Improved data visualization and reporting

### Removed
- Python runtime dependency
- Python-based implementation

### Security
- Compile-time type checking provides better safety guarantees

## [1.0.8] - 2025-07-21

### Changed
- Migrated authentication token storage to GSettings
- Better configuration management
- Improved version handling

## [1.0.7] - 2025-07-18

### Fixed
- Python version installation path issues
- Internationalization (i18n) configuration
- Appdata processing and validation
- Version management and build-time generation

### Changed
- Improved Flatpak manifest management
- Better version synchronization across build files

## [1.0.6] - 2025-07-18

### Changed
- Centralized version management with meson.build as source of truth
- Improved build-time version generation

### Fixed
- Template processing for appdata.xml.in

## [1.0.5] - 2025-07-15

### Changed
- Replaced filesystem=home permission with portal permissions for better security
- Improved sandboxing and security posture

### Fixed
- Replaced unavailable chart-line-symbolic icon with standard dialog-information-symbolic
- File picker now uses Flatpak portal for exports

## [1.0.0] - 2025-07-15

### Added
- Initial release of Sonar
- Native GTK4 application for webhook inspection
- Integration with ngrok for public URL tunneling
- Real-time webhook capture and inspection
- Detailed view of HTTP headers, body content, and metadata
- Quick copy functionality for request data
- Libadwaita interface with GNOME design patterns
- Persistent request history with JSON storage
- Support for multiple content types (JSON, XML, form-data)

[2.2.1]: https://github.com/tobagin/sonar/compare/v2.2.0...v2.2.1
[2.2.0]: https://github.com/tobagin/sonar/compare/v2.1.0...v2.2.0
[2.1.0]: https://github.com/tobagin/sonar/compare/v2.0.3...v2.1.0
[2.0.3]: https://github.com/tobagin/sonar/compare/v2.0.2...v2.0.3
[2.0.2]: https://github.com/tobagin/sonar/compare/v2.0.1...v2.0.2
[2.0.1]: https://github.com/tobagin/sonar/compare/v2.0.0...v2.0.1
[2.0.0]: https://github.com/tobagin/sonar/compare/v1.0.8...v2.0.0
[1.0.8]: https://github.com/tobagin/sonar/compare/v1.0.7...v1.0.8
[1.0.7]: https://github.com/tobagin/sonar/compare/v1.0.6...v1.0.7
[1.0.6]: https://github.com/tobagin/sonar/compare/v1.0.5...v1.0.6
[1.0.5]: https://github.com/tobagin/sonar/compare/v1.0.0...v1.0.5
[1.0.0]: https://github.com/tobagin/sonar/releases/tag/v1.0.0
