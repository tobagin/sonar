# Project Context

## Purpose
Sonar is a modern desktop webhook inspector for developers. It provides a native GTK4 application with a beautiful, intuitive interface for capturing and inspecting webhook requests during development. The application creates public URLs via ngrok integration, captures incoming webhooks in real-time, and provides detailed inspection tools for headers, body content, and metadata.

**Key Goals:**
- Simplify webhook debugging and testing during development
- Provide instant public URLs for webhook testing without complex setup
- Offer real-time webhook capture with detailed inspection capabilities
- Deliver a native GNOME experience with modern GTK4 and Libadwaita
- Support advanced features like request replay, comparison, filtering, and forwarding

## Tech Stack

**Core Technologies:**
- **Vala** - Primary programming language for the application
- **GTK4 4.8+** - UI toolkit for building the native desktop interface
- **Libadwaita 1.4+** - GNOME design patterns and modern UI components
- **Blueprint** - Modern UI definition language (compiles to GTK XML)
- **Meson** - Build system (>= 1.0.0)

**Key Libraries:**
- **libsoup 3.0+** - HTTP server and client library for webhook handling
- **json-glib 1.6+** - JSON parsing and serialization
- **libgee 0.8+** - Collection library for data structures
- **GIO 2.0** - Input/output and application framework

**Distribution:**
- **Flatpak** - Primary distribution method (sandboxed via Flathub)
- **GNOME Platform 49** - Runtime environment
- **ngrok** - Bundled for tunnel creation

## Project Conventions

### Code Style
- **File Size Limit**: No file should exceed 500 lines of code
- **Modular Organization**: Code organized by feature/responsibility in separate files:
  - `application.vala` - Application entry point
  - `main_window.vala` - Main window implementation
  - `server.vala` - Webhook server (libsoup)
  - `tunnel.vala` - Ngrok tunnel management
  - `models.vala` - Data models
  - `request_row.vala` - Request list item widget
  - `preferences_dialog.vala` - Settings dialog
  - `statistics_dialog.vala` - Analytics dashboard
  - `shortcuts_dialog.vala` - Keyboard shortcuts window
- **Naming**: Follow Vala/GObject naming conventions (snake_case for methods, PascalCase for classes)
- **Documentation**: All public methods and classes should have doc comments
- **UI Files**: Use Blueprint (.blp) files for UI definitions, not hand-written XML

### Architecture Patterns
- **GNOME Application Pattern**: Follows GtkApplication and Adwaita best practices
- **Model-View Separation**: Data models separated from UI components
- **Signal-Based Communication**: GTK signals for component communication
- **Persistent Storage**: JSON file-based storage for request history and templates
- **Async Operations**: Non-blocking I/O for network operations using GLib async patterns
- **Sandboxed Design**: Flatpak-compatible with minimal required permissions
- **Configuration Management**: GSettings/GSchema for user preferences

**Key Components:**
- **Server** (libsoup): Runs local HTTP server to receive webhooks
- **Tunnel** (ngrok): Manages public URL tunneling
- **Request Storage**: Persistent JSON-based history
- **UI Components**: Accordion-style request list with detailed inspection views

### Testing Strategy
- **Unit Tests**: Use Pytest for testing new features and logic
- **Test Coverage Requirements**:
  - At least 1 test for expected use case
  - 1 edge case test
  - 1 failure case test
- **Test Organization**: Tests in `/tests` folder mirroring main app structure
- **Manual Testing**: Test on multiple Linux distributions before release
- **Integration Testing**: Verify ngrok integration and webhook capture flows

### Git Workflow
- **Main Branch**: `main` (stable releases)
- **Development Profile**: Build with `--dev` flag for development builds (app ID: `io.github.tobagin.sonar.Devel`)
- **Version**: Currently v2.1.0 (tracked in meson.build)
- **Build Scripts**: Use `./scripts/build.sh` for production and `./scripts/build.sh --dev` for development
- **Commit Conventions**: Descriptive commits with context (see recent history for examples)
- **Release Process**: Tag releases, update metainfo, build Flatpak manifest

## Domain Context

**Webhook Development Workflow:**
- Developers need public URLs to test webhooks from external services (GitHub, Stripe, etc.)
- ngrok provides temporary public URLs that tunnel to local servers
- Webhooks arrive as HTTP POST/GET/etc. requests with various content types (JSON, XML, form data)
- Common testing scenarios include comparing webhook payloads, replaying requests, and forwarding to multiple endpoints

**Desktop Linux Environment:**
- GNOME desktop environment with Wayland/X11 support
- Flatpak sandbox requires network access permission
- Native integration with GNOME design (dark mode, keyboard shortcuts, etc.)
- ngrok binary bundled in Flatpak for seamless experience

**Request Inspection Needs:**
- View full HTTP request (method, path, headers, body, query params)
- Copy data in multiple formats (JSON, cURL, HTTP)
- Filter and search through request history
- Compare differences between webhook payloads
- Export requests for documentation or debugging

## Important Constraints

**Technical Constraints:**
- **File Size**: No source file should exceed 500 lines
- **GTK/Vala Ecosystem**: Must use GObject patterns and GTK conventions
- **Flatpak Sandboxing**: Limited filesystem access, must request permissions
- **ngrok Dependency**: Requires ngrok binary and valid auth token
- **GNOME Runtime**: Tied to GNOME Platform release cycle (currently 49)
- **Network Access**: Requires network permission for server and ngrok

**Design Constraints:**
- Must follow Libadwaita design patterns and Human Interface Guidelines
- Accordion UI: Only one request expanded at a time for focus
- Keyboard shortcut support required for power users
- Responsive to both mouse and keyboard-driven workflows

**License:**
- GPL-3.0-or-later - Must maintain open source compatibility

## External Dependencies

**Critical External Services:**
- **ngrok** (https://ngrok.com)
  - Purpose: Creates secure public tunnels to local webhook server
  - Integration: Bundled in Flatpak, managed via CLI spawning
  - Requirement: Users must obtain free auth token from ngrok.com
  - Version: v3 stable (Linux AMD64)

**Build-Time Dependencies:**
- Vala compiler (valac)
- Meson build system (>= 1.0.0)
- Blueprint compiler (for .blp UI files)
- GTK4, Libadwaita, libsoup, json-glib, libgee development headers

**Runtime Dependencies:**
- GNOME Platform 49 (via Flatpak)
- ngrok binary (bundled in Flatpak package)

**Development Tools:**
- Git for version control
- GitHub for repository hosting and issue tracking
- Flatpak Builder for packaging
- GNOME Builder (optional, for integrated development)
