/*
 * Main application class for Sonar webhook inspector.
 */

using Gtk;
using Adw;
using GLib;

namespace Sonar {
    
    /**
     * The main Sonar application.
     */
    public class Application : Adw.Application {
        private MainWindow? window;
        private RequestStorage storage;
        private WebhookServer server;
        private TunnelManager tunnel_manager;
        private SimpleAction copy_url_action;
        
        public Application() {
            Object(
                application_id: Config.APP_ID,
                flags: ApplicationFlags.DEFAULT_FLAGS
            );
        }
        
        public override void startup() {
            base.startup();

            // Initialize core components
            this.storage = new RequestStorage();
            this.server = new WebhookServer(this.storage);
            this.tunnel_manager = new TunnelManager();

            // Start the webhook server
            try {
                var settings = new GLib.Settings(Config.APP_ID);
                int port = settings.get_int("forwarded-port");
                this.server.start(port, "127.0.0.1");
                info(@"Webhook server started on http://127.0.0.1:$port");
            } catch (Error e) {
                critical("Failed to start webhook server: %s", e.message);
            }

            this._setup_actions();
            this._setup_resources();

            // Connect to tunnel status changes to update copy URL action
            this.tunnel_manager.status_changed.connect(this._on_tunnel_status_changed_for_actions);

            // Set initial state based on current tunnel status
            var initial_status = this.tunnel_manager.get_status();
            this._on_tunnel_status_changed_for_actions(initial_status);
        }
        
        public override void activate() {
            if (this.window == null) {
                this.window = new MainWindow(this, this.storage, this.server, this.tunnel_manager);
            }
            
            this.window.present();
            
            // Check if this is a new version and show release notes automatically
            if (this._should_show_release_notes()) {
                // Small delay to ensure main window is fully presented
                Timeout.add(500, () => {
                    this._show_about_with_release_notes();
                    return false;
                });
            }
        }
        
        public override void shutdown() {
            info("Shutting down application...");
            
            // Stop server and tunnel
            try {
                this.server.stop();
                this.tunnel_manager.stop();
            } catch (Error e) {
                critical("Error during shutdown: %s", e.message);
            }
            
            base.shutdown();
        }
        
        private void _setup_actions() {
            // Quit action
            var quit_action = new SimpleAction("quit", null);
            quit_action.activate.connect(() => {
                this.quit();
            });
            this.add_action(quit_action);
            this.set_accels_for_action("app.quit", {"<primary>q"});
            
            // About action
            var about_action = new SimpleAction("about", null);
            about_action.activate.connect(this._on_about_action);
            this.add_action(about_action);
            
            // Preferences action
            var preferences_action = new SimpleAction("preferences", null);
            preferences_action.activate.connect(this._on_preferences_action);
            this.add_action(preferences_action);
            this.set_accels_for_action("app.preferences", {"<primary>comma"});
            
            // Clear requests action
            var clear_requests_action = new SimpleAction("clear-requests", null);
            clear_requests_action.activate.connect(() => {
                if (this.window != null) {
                    this.window.clear_requests();
                }
            });
            this.add_action(clear_requests_action);
            this.set_accels_for_action("app.clear-requests", {"<primary>l"});
            
            // Copy URL action
            this.copy_url_action = new SimpleAction("copy-url", null);
            this.copy_url_action.activate.connect(() => {
                if (this.window != null) {
                    this.window.copy_tunnel_url();
                }
            });
            this.add_action(this.copy_url_action);
            this.set_accels_for_action("app.copy-url", {"<primary>u"});
            
            // Initially disable copy URL action until tunnel is running
            this.copy_url_action.set_enabled(false);
            
            // Toggle tunnel action
            var toggle_tunnel_action = new SimpleAction("toggle-tunnel", null);
            toggle_tunnel_action.activate.connect(() => {
                if (this.window != null) {
                    this.window.toggle_tunnel();
                }
            });
            this.add_action(toggle_tunnel_action);
            this.set_accels_for_action("app.toggle-tunnel", {"<primary>t"});
            
            // Refresh action
            var refresh_action = new SimpleAction("refresh", null);
            refresh_action.activate.connect(() => {
                if (this.window != null) {
                    this.window.refresh_ui();
                }
            });
            this.add_action(refresh_action);
            this.set_accels_for_action("app.refresh", {"F5"});

            // Mock response action
            var mock_response_action = new SimpleAction("mock-response", null);
            mock_response_action.activate.connect(() => {
                this._on_mock_response_action();
            });
            this.add_action(mock_response_action);
            this.set_accels_for_action("app.mock-response", {"<primary>m"});
            
            // Toggle fullscreen action
            var fullscreen_action = new SimpleAction("toggle-fullscreen", null);
            fullscreen_action.activate.connect(() => {
                if (this.window != null) {
                    this.window.toggle_fullscreen();
                }
            });
            this.add_action(fullscreen_action);
            this.set_accels_for_action("app.toggle-fullscreen", {"F11"});
            
            // View history action
            var view_history_action = new SimpleAction("view-history", null);
            view_history_action.activate.connect(() => {
                if (this.window != null) {
                    this.window.view_history();
                }
            });
            this.add_action(view_history_action);
            this.set_accels_for_action("app.view-history", {"<primary>h"});
            this.set_accels_for_action("app.about", {"F1"});
            
            // Export requests action (window action)
            var export_action = new SimpleAction("export-requests", null);
            export_action.activate.connect(() => {
                if (this.window != null) {
                    this.window.export_requests();
                }
            });
            // Note: This should be a window action, but adding here for simplicity
        }
        
        private void _setup_resources() {
            // Load application resources
            try {
                string[] resource_paths = {
                    "/app/share/sonar/sonar-resources.gresource",
                    "/usr/share/sonar/sonar-resources.gresource",
                    GLib.Path.build_filename(Environment.get_current_dir(), "data", "sonar-resources.gresource")
                };
                
                foreach (var resource_path in resource_paths) {
                    var file = File.new_for_path(resource_path);
                    if (file.query_exists()) {
                        try {
                            var resource = Resource.load(resource_path);
                            resources_register(resource);
                            break;
                        } catch (Error e) {
                            continue;
                        }
                    }
                }
            } catch (Error e) {
                warning("Could not load application resources: %s", e.message);
            }
        }
        
        private bool _should_show_release_notes() {
            var settings = new GLib.Settings(Config.APP_ID);
            string last_version = settings.get_string("last-version-shown");
            string current_version = Config.VERSION;

            // Show if this is the first run (empty last version) or version has changed
            if (last_version == "" || last_version != current_version) {
                settings.set_string("last-version-shown", current_version);
                return true;
            }
            return false;
        }
        
        private void _show_about_with_release_notes() {
            // Open the about dialog first
            this._on_about_action();
            
            // Wait for the dialog to appear, then navigate to release notes
            Timeout.add(300, () => {
                this._simulate_tab_navigation();
                
                // Simulate Enter key press after another delay to open release notes
                Timeout.add(200, () => {
                    this._simulate_enter_activation();
                    return false;
                });
                return false;
            });
        }
        
        private void _simulate_tab_navigation() {
            // Get the focused widget and try to move focus
            if (this.window != null) {
                var focused_widget = this.window.get_focus();
                if (focused_widget != null) {
                    // Try to move focus to the next focusable widget
                    var parent = focused_widget.get_parent();
                    if (parent != null) {
                        // Move focus to the next sibling using tab forward
                        parent.child_focus(Gtk.DirectionType.TAB_FORWARD);
                    }
                }
            }
        }
        
        private void _simulate_enter_activation() {
            // Get the currently focused widget and try to activate it
            if (this.window != null) {
                var focused_widget = this.window.get_focus();
                if (focused_widget != null) {
                    // If it's a button, click it
                    if (focused_widget is Gtk.Button) {
                        ((Gtk.Button)focused_widget).activate();
                    }
                    // For other widgets, try to activate the default action
                    else {
                        focused_widget.activate_default();
                    }
                }
            }
        }
        
        private string _generate_release_notes() {
            var notes = new StringBuilder();
            notes.append("""<p><b>What's New in Version %s</b></p>""".printf(Config.VERSION));
            notes.append("<ul>");
            notes.append("<li><b>Dynamic Status Page:</b> Status messages now change based on your current tunnel state - from setup required to tunnel active</li>");
            notes.append("<li><b>Improved History Management:</b> Automatic history saving, export functionality, and individual delete buttons for better request management</li>");
            notes.append("<li><b>Enhanced Keyboard Shortcuts:</b> Reorganized shortcuts dialog with better categorization and comprehensive coverage of all features</li>");
            notes.append("<li><b>Professional Menu Layout:</b> Reordered main menu items for better user experience and workflow</li>");
            notes.append("<li><b>Better Flatpak Integration:</b> Fixed data persistence issues and improved sandbox compatibility</li>");
            notes.append("<li><b>Real-time Request Statistics:</b> View detailed analytics of your webhook history with method breakdowns and content type analysis</li>");
            notes.append("</ul>");
            notes.append("<p><i>Updates include bug fixes, performance improvements, and enhanced user experience across all features.</i></p>");
            return notes.str;
        }
        
        private void _on_about_action() {
            info("About action activated");
            
            string[] developers = { "Thiago Fernandes" };
            string[] designers = { "Thiago Fernandes" };
            string[] artists = { "Thiago Fernandes", "@oiimrosabel" };
            
            string app_name = "Sonar";
            string comments = "A modern, native GTK4/LibAdwaita webhook inspector for capturing and debugging HTTP requests with comprehensive logging and tunnel management capabilities";
            
            if (Config.APP_ID.contains("Devel")) {
                app_name = "Sonar (Development)";
                comments = "A modern, native GTK4/LibAdwaita webhook inspector for capturing and debugging HTTP requests with comprehensive logging and tunnel management capabilities (Development Version)";
            }

            // Generate release notes for current version
            string release_notes = this._generate_release_notes();
            
            var about = new Adw.AboutDialog() {
                application_name = app_name,
                application_icon = Config.APP_ID,
                developer_name = "The Sonar Team",
                version = Config.VERSION,
                developers = developers,
                designers = designers,
                artists = artists,
                license_type = Gtk.License.GPL_3_0,
                website = "https://tobagin.github.io/apps/sonar",
                issue_url = "https://github.com/tobagin/sonar/issues",
                support_url = "https://github.com/tobagin/sonar/discussions",
                comments = comments,
                release_notes = release_notes
            };

            // Load and set release notes from metainfo
            try {
                string[] possible_paths = {
                    Path.build_filename("/app/share/metainfo", @"$(Config.APP_ID).metainfo.xml"),
                    Path.build_filename("/usr/share/metainfo", @"$(Config.APP_ID).metainfo.xml"),
                    Path.build_filename(Environment.get_user_data_dir(), "metainfo", @"$(Config.APP_ID).metainfo.xml")
                };
                
                foreach (string metainfo_path in possible_paths) {
                    var file = File.new_for_path(metainfo_path);
                    
                    if (file.query_exists()) {
                        uint8[] contents;
                        file.load_contents(null, out contents, null);
                        string xml_content = (string) contents;
                        
                        // Parse the XML to find the release matching Config.VERSION
                        var parser = new Regex("<release version=\"%s\"[^>]*>(.*?)</release>".printf(Regex.escape_string(Config.VERSION)), 
                                               RegexCompileFlags.DOTALL | RegexCompileFlags.MULTILINE);
                        MatchInfo match_info;
                        
                        if (parser.match(xml_content, 0, out match_info)) {
                            string release_section = match_info.fetch(1);
                            
                            // Extract description content
                            var desc_parser = new Regex("<description>(.*?)</description>", 
                                                        RegexCompileFlags.DOTALL | RegexCompileFlags.MULTILINE);
                            MatchInfo desc_match;
                            
                            if (desc_parser.match(release_section, 0, out desc_match)) {
                                string metainfo_notes = desc_match.fetch(1).strip();
                                about.set_release_notes(metainfo_notes);
                                about.set_release_notes_version(Config.VERSION);
                            }
                        }
                        break;
                    }
                }
            } catch (Error e) {
                // If we can't load release notes from metainfo, that's okay
                warning("Could not load release notes from metainfo: %s", e.message);
            }

            // Set copyright
            about.set_copyright("© 2025 Thiago Fernandes");

            // Add acknowledgement section
            about.add_acknowledgement_section(
                "Special Thanks",
                {
                    "The GNOME Project",
                    "The GTK4 Team", 
                    "LibAdwaita Contributors",
                    "Vala Programming Language Team",
                    "Ngrok Team"
                }
            );

            // Set translator credits
            about.set_translator_credits("Thiago Fernandes");
            
            // Add Source link
            about.add_link("Source", "https://github.com/tobagin/sonar");

            if (this.window != null) {
                about.present(this.window);
            }
        }
        
        private void _on_tunnel_status_changed_for_actions(TunnelStatus status) {
            // Update copy URL action enabled state based on tunnel status
            this.copy_url_action.set_enabled(status.active && status.public_url != null);
        }
        
        private void _on_preferences_action() {
            if (this.window != null) {
                var preferences = new PreferencesDialog(this.window, this.tunnel_manager, this.server);
                preferences.present(this.window);
            }
        }

        private void _on_mock_response_action() {
            if (this.window != null) {
                var dialog = new MockResponseDialog(this.window, this.server.mock_manager);
                dialog.present();
            }
        }
    }
    
    /**
     * Main entry point.
     */
    public static int main(string[] args) {
        var app = new Sonar.Application();
        return app.run(args);
    }
}