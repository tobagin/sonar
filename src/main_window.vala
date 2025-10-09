/*
 * Main window for the Sonar webhook inspector.
 */

using Gtk;
using Adw;
using GLib;

namespace Sonar {
    
    /**
     * The main application window.
     */
#if DEVELOPMENT
    [GtkTemplate (ui = "/io/github/tobagin/sonar/Devel/main_window.ui")]
#else
    [GtkTemplate (ui = "/io/github/tobagin/sonar/main_window.ui")]
#endif
    public class MainWindow : Adw.ApplicationWindow {
        [GtkChild] private unowned Adw.ToastOverlay toast_overlay;
        [GtkChild] private unowned Adw.HeaderBar header_bar;
        [GtkChild] private unowned Button header_history_button;
        [GtkChild] private unowned Button history_button;
        [GtkChild] private unowned Button stop_tunnel_button;
        [GtkChild] private unowned Button header_stop_button;
        [GtkChild] private unowned MenuButton primary_menu_button;
        [GtkChild] private unowned Adw.Banner status_banner;
        [GtkChild] private unowned Stack main_stack;
        [GtkChild] private unowned StatusPage empty_page;
        [GtkChild] private unowned Box tunnel_controls;
        [GtkChild] private unowned Button setup_token_button;
        [GtkChild] private unowned Box start_tunnel_container;
        [GtkChild] private unowned Button start_tunnel_button;
        [GtkChild] private unowned Gtk.Spinner tunnel_spinner;
        [GtkChild] private unowned Button clear_button;
        // Requests filter UI
        [GtkChild] private unowned Button filter_button;
        [GtkChild] private unowned Revealer filter_revealer;
        [GtkChild] private unowned SearchEntry requests_search_entry;
        [GtkChild] private unowned DropDown requests_method_filter;
        [GtkChild] private unowned DropDown requests_content_type_filter;
        [GtkChild] private unowned DropDown requests_time_filter;
        [GtkChild] private unowned ToggleButton starred_only_toggle;
        [GtkChild] private unowned Button clear_filters_button;
        [GtkChild] private unowned ListBox request_list;
        // History UI
        [GtkChild] private unowned SearchEntry history_search_entry;
        [GtkChild] private unowned DropDown history_method_filter;
        [GtkChild] private unowned Button clear_history_button;
        [GtkChild] private unowned Button history_stats_button;
        [GtkChild] private unowned Button export_history_button;
        [GtkChild] private unowned Button back_to_requests_button;
        [GtkChild] private unowned ListBox history_list;
        
        private RequestStorage storage;
        private WebhookServer server;
        private TunnelManager tunnel_manager;
        private Gee.HashMap<string, RequestRow> request_rows;
        private RequestRow? currently_expanded_row;

        // Filter state
        private string? filter_method = null;
        private string? filter_content_type = null;
        private string? filter_time_range = null;
        private string? filter_search_text = null;

        // Comparison state
        private WebhookRequest? comparison_request = null;
        
        public MainWindow(Adw.Application app, RequestStorage storage, 
                         WebhookServer server, TunnelManager tunnel_manager) {
            Object(application: app);
            
            this.storage = storage;
            this.server = server;
            this.tunnel_manager = tunnel_manager;
            this.request_rows = new Gee.HashMap<string, RequestRow>();
            
            this._setup_ui();
            this._connect_signals();
            this._update_ui_state();
        }
        
        private void _setup_ui() {
            // UI is now loaded from template
            // Just configure what's needed
            this.set_default_size(900, 600);

            // Configure banner signal
            this.status_banner.button_clicked.connect(this._on_banner_button_clicked);

            // Setup filter dropdowns
            this._setup_filter_dropdowns();
        }

        private void _setup_filter_dropdowns() {
            // HTTP Method filter for requests
            var methods = new string[] {"All Methods", "GET", "POST", "PUT", "DELETE", "PATCH", "HEAD", "OPTIONS"};
            this.requests_method_filter.set_model(new StringList(methods));
            this.requests_method_filter.set_selected(0);

            // Content Type filter
            var content_types = new string[] {
                "All Types",
                "application/json",
                "application/x-www-form-urlencoded",
                "multipart/form-data",
                "text/plain",
                "text/html",
                "application/xml"
            };
            this.requests_content_type_filter.set_model(new StringList(content_types));
            this.requests_content_type_filter.set_selected(0);

            // Time filter
            var time_ranges = new string[] {
                "All Time",
                "Last 5 minutes",
                "Last 15 minutes",
                "Last 30 minutes",
                "Last hour",
                "Last 24 hours"
            };
            this.requests_time_filter.set_model(new StringList(time_ranges));
            this.requests_time_filter.set_selected(0);

            // HTTP Method filter for history
            this.history_method_filter.set_model(new StringList(methods));
            this.history_method_filter.set_selected(0);
        }
        
        private void _setup_window_actions() {
            // Export requests action
            var export_action = new SimpleAction("export-requests", null);
            export_action.activate.connect(() => {
                this.export_requests();
            });
            this.add_action(export_action);
            
            // Show help overlay action
            var help_action = new SimpleAction("show-help-overlay", null);
            help_action.activate.connect(() => {
                this._show_keyboard_shortcuts_dialog();
            });
            this.add_action(help_action);
            
            // Set keyboard shortcut for help overlay
            var app = this.get_application() as Gtk.Application;
            if (app != null) {
                app.set_accels_for_action("win.show-help-overlay", {"<primary>question"});
            }
        }
        
        private void _connect_signals() {
            // Button signals
            this.setup_token_button.clicked.connect(this._on_setup_token_clicked);
            this.start_tunnel_button.clicked.connect(this._on_start_tunnel_clicked);
            this.stop_tunnel_button.clicked.connect(this._on_stop_tunnel_clicked);
            this.header_stop_button.clicked.connect(this._on_stop_tunnel_clicked);
            this.clear_button.clicked.connect(this._on_clear_requests_clicked);
            this.header_history_button.clicked.connect(this._on_history_button_clicked);
            this.history_button.clicked.connect(this._on_history_button_clicked);
            this.clear_history_button.clicked.connect(this._on_clear_history_clicked);
            this.history_stats_button.clicked.connect(this._on_history_stats_clicked);

            // Filter signals
            this.filter_button.clicked.connect(this._on_filter_button_clicked);
            this.clear_filters_button.clicked.connect(this._on_clear_filters_clicked);
            this.requests_search_entry.search_changed.connect(this._on_requests_search_changed);
            this.requests_method_filter.notify["selected"].connect(this._on_filter_changed);
            this.requests_content_type_filter.notify["selected"].connect(this._on_filter_changed);
            this.requests_time_filter.notify["selected"].connect(this._on_filter_changed);
            this.starred_only_toggle.toggled.connect(this._on_filter_changed);
            this.export_history_button.clicked.connect(this._on_export_history_clicked);
            this.back_to_requests_button.clicked.connect(this._on_back_to_requests_clicked);
            
            // Search functionality
            this.history_search_entry.search_changed.connect(this._on_search_changed);
            
            // Setup method filter dropdown
            this._setup_method_filter();
            
            // Storage signals
            this.storage.request_added.connect(this._on_request_added);
            this.storage.requests_cleared.connect(this._on_requests_cleared);
            
            // Server signals
            this.server.request_received.connect(this._on_server_request_received);
            
            // Tunnel manager signals
            this.tunnel_manager.status_changed.connect(this._on_tunnel_status_changed);
            
            // Window signals
            this.close_request.connect(this._on_close_request);
            
            // Window actions
            this._setup_window_actions();
        }
        
        private void _update_ui_state() {
            var tunnel_status = this.tunnel_manager.get_status();
            bool tunnel_active = tunnel_status.active;
            bool has_auth_token_error = tunnel_status.error != null && 
                (tunnel_status.error.contains("No NGROK_AUTHTOKEN") || 
                 tunnel_status.error.contains("auth token"));
            
            // Determine if we have requests
            bool has_requests = this.storage.count() > 0;
            
            // Update tunnel controls visibility
            this.tunnel_spinner.set_visible(false);
            
            // Show/hide setup button based on auth token status
            this.setup_token_button.set_visible(has_auth_token_error);
            
            // Show start tunnel container only when no auth error and tunnel is not active
            this.start_tunnel_container.set_visible(!has_auth_token_error && !tunnel_active);
            
            // Main stop button: visible when tunnel is active AND no requests received yet
            this.stop_tunnel_button.set_visible(tunnel_active && !has_requests);
            
            // Header stop button: only visible when tunnel is active AND we have received requests
            this.header_stop_button.set_visible(tunnel_active && has_requests);
            
            // Make sure tunnel_controls container is always visible (it contains our tunnel buttons)
            this.tunnel_controls.set_visible(true);
            
            // Update status banner
            if (tunnel_active && tunnel_status.public_url != null) {
                this.status_banner.set_title("Tunnel Active: " + tunnel_status.public_url);
                this.status_banner.set_button_label("Copy URL");
                this.status_banner.set_revealed(true);
                // this.url_label.set_text(tunnel_status.public_url);
            } else if (has_auth_token_error) {
                this.status_banner.set_title("Setup Required: " + tunnel_status.error);
                this.status_banner.set_button_label("Setup Token");
                this.status_banner.set_revealed(true);
                // this.url_label.set_text("");
            } else if (tunnel_status.error != null) {
                this.status_banner.set_title("Tunnel Error: " + tunnel_status.error);
                this.status_banner.set_button_label("Retry");
                this.status_banner.set_revealed(true);
                // this.url_label.set_text("");
            } else {
                this.status_banner.set_revealed(false);
                // this.url_label.set_text("");
            }
            
            // Update status page content based on current state
            this._update_status_page(tunnel_status, has_auth_token_error);
            
            // Update main stack visibility
            string current_page = this.main_stack.get_visible_child_name() ?? "empty";
            if (current_page != "history") {
                if (this.storage.count() > 0) {
                    this.main_stack.set_visible_child_name("requests");
                } else {
                    this.main_stack.set_visible_child_name("empty");
                }
            }
            
            // Update button sensitivities
            this.clear_button.set_sensitive(this.storage.count() > 0);
            this.clear_history_button.set_sensitive(this.storage.count_history() > 0);
        }
        
        private void _on_start_tunnel_clicked() {
            this._start_tunnel_and_server.begin();
        }
        
        private async void _start_tunnel_and_server() {
            try {
                // Start server first
                if (!this.server.get_is_running()) {
                    this.server.start(8000, "127.0.0.1");
                    
                    // Wait a moment for server to start
                    Timeout.add(500, () => {
                        this._start_tunnel_and_server.callback();
                        return Source.REMOVE;
                    });
                    yield;
                }
                
                // Start tunnel
                var status = yield this.tunnel_manager.start_async(8000, "http");
                this._update_ui_state();
                
                if (!status.active && status.error != null) {
                    this._show_error_dialog("Tunnel Error", status.error);
                }
                
            } catch (Error e) {
                this._show_error_dialog("Error", "Failed to start tunnel: " + e.message);
            }
        }
        
        private void _on_stop_tunnel_clicked() {
            this.tunnel_manager.stop();
            this.server.stop();
            this._update_ui_state();
        }
        
        private void _on_banner_button_clicked() {
            var tunnel_status = this.tunnel_manager.get_status();
            bool has_auth_token_error = tunnel_status.error != null && 
                (tunnel_status.error.contains("No NGROK_AUTHTOKEN") || 
                 tunnel_status.error.contains("auth token"));
            
            if (has_auth_token_error) {
                // Show setup token dialog
                this._on_setup_token_clicked();
            } else if (tunnel_status.active && tunnel_status.public_url != null) {
                // Copy URL
                this._on_copy_url_clicked();
            } else {
                // Retry tunnel start
                this._on_start_tunnel_clicked();
            }
        }
        
        private void _on_copy_url_clicked() {
            var public_url = this.tunnel_manager.get_public_url();
            if (public_url != null) {
                var clipboard = this.get_clipboard();
                clipboard.set_text(public_url);
                
                // Show toast notification
                var toast = new Adw.Toast("URL copied to clipboard");
                toast.set_timeout(2);
                
                // Find the toast overlay (assuming it exists in the UI)
                var overlay = this.get_first_child() as Adw.ToastOverlay;
                if (overlay != null) {
                    overlay.add_toast(toast);
                }
            }
        }
        
        private void _on_setup_token_clicked() {
            var preferences = new PreferencesDialog(this, this.tunnel_manager, this.server);
            preferences.present(this);
        }
        
        private void _on_clear_requests_clicked() {
            this._show_clear_requests_confirmation();
        }
        
        private void _on_history_button_clicked() {
            string current_page = this.main_stack.get_visible_child_name() ?? "empty";
            
            if (current_page == "history") {
                // Go back to requests or empty
                if (this.storage.count() > 0) {
                    this.main_stack.set_visible_child_name("requests");
                } else {
                    this.main_stack.set_visible_child_name("empty");
                }
            } else {
                // Show history
                this._load_history();
                this.main_stack.set_visible_child_name("history");
            }
        }
        
        private void _on_clear_history_clicked() {
            this._show_clear_history_confirmation();
        }
        
        private void _on_back_to_requests_clicked() {
            // Use the same logic as the history toggle to return to the appropriate main view
            if (this.storage.count() > 0) {
                this.main_stack.set_visible_child_name("requests");
            } else {
                this.main_stack.set_visible_child_name("empty");
            }
        }
        
        private void _on_history_stats_clicked() {
            this._show_history_statistics();
        }
        
        private void _on_export_history_clicked() {
            this._export_history();
        }
        
        private void _on_search_changed() {
            string search_text = this.history_search_entry.get_text().strip().down();
            this._filter_history(search_text);
        }
        
        private void _on_request_added(WebhookRequest request) {
            Idle.add(() => {
                var row = new RequestRow(request, this, false); // Not history mode
                this.request_rows[request.id] = row;
                this.request_list.append(row);

                // Apply filters to the new request
                bool should_show = this._request_matches_filters(request);
                row.set_visible(should_show);

                this._update_ui_state();
                return Source.REMOVE;
            });
        }
        
        private void _on_requests_cleared() {
            Idle.add(() => {
                // Remove all rows
                this.request_rows.clear();
                
                Widget? child = this.request_list.get_first_child();
                while (child != null) {
                    var next = child.get_next_sibling();
                    this.request_list.remove(child);
                    child = next;
                }
                
                this._update_ui_state();
                return Source.REMOVE;
            });
        }
        
        private void _on_server_request_received(WebhookRequest request) {
            // Storage will emit request_added signal, which we handle above
        }
        
        private void _on_tunnel_status_changed(TunnelStatus status) {
            Idle.add(() => {
                this._update_ui_state();
                return Source.REMOVE;
            });
        }
        
        private bool _on_close_request() {
            this.application.quit();
            return false;
        }
        
        private void _show_error_dialog(string title, string message) {
            var dialog = new Adw.AlertDialog(title, message);
            dialog.add_response("ok", "OK");
            dialog.present(this);
        }
        
        public void clear_requests() {
            this.storage.clear();
        }
        
        public void copy_tunnel_url() {
            this._on_copy_url_clicked();
        }
        
        public void toggle_tunnel() {
            if (this.tunnel_manager.is_active()) {
                this._on_stop_tunnel_clicked();
            } else {
                this._on_start_tunnel_clicked();
            }
        }
        
        public void refresh_ui() {
            this._update_ui_state();
        }
        
        public void toggle_fullscreen() {
            if (this.is_fullscreen()) {
                this.unfullscreen();
            } else {
                this.fullscreen();
            }
        }
        
        public void view_history() {
            this._on_history_button_clicked();
        }
        
        public void export_requests() {
            if (this.storage.count() == 0) {
                this._show_toast("No requests to export");
                return;
            }
            
            // Simple export as JSON for now
            var json_array = new Json.Array();
            var requests = this.storage.get_requests();
            
            foreach (var request in requests) {
                json_array.add_element(request.to_json());
            }
            
            var generator = new Json.Generator();
            var root_node = new Json.Node(Json.NodeType.ARRAY);
            root_node.set_array(json_array);
            generator.set_root(root_node);
            generator.pretty = true;
            generator.indent = 2;
            
            var json_data = generator.to_data(null);
            
            // Save to file
            var file_dialog = new Gtk.FileDialog();
            file_dialog.set_title("Export Requests");
            file_dialog.set_initial_name("sonar-requests.json");
            
            file_dialog.save.begin(this, null, (obj, res) => {
                try {
                    var file = file_dialog.save.end(res);
                    if (file != null) {
                        file.replace_contents(json_data.data, null, false, 
                                            FileCreateFlags.REPLACE_DESTINATION, null);
                        this._show_toast("Requests exported successfully");
                    }
                } catch (Error e) {
                    this._show_toast("Export failed: " + e.message);
                }
            });
        }
        
        private void _show_toast(string message, int timeout = 3) {
            var toast = new Adw.Toast(message);
            toast.set_timeout(timeout);
            this.toast_overlay.add_toast(toast);
        }
        
        private void _load_history() {
            // Clear existing history items
            Widget? child = this.history_list.get_first_child();
            while (child != null) {
                var next = child.get_next_sibling();
                this.history_list.remove(child);
                child = next;
            }
            
            // Load history requests
            var history = this.storage.get_history();
            foreach (var request in history) {
                var row = new RequestRow(request, this, true); // History mode
                this.history_list.append(row);
            }
        }
        
        private void _filter_history(string search_text) {
            // Get selected method filter
            var methods_model = this.history_method_filter.get_model() as StringList;
            string? selected_method = null;
            if (methods_model != null) {
                uint selected_index = this.history_method_filter.get_selected();
                selected_method = methods_model.get_string(selected_index);
            }
            
            // Filter implementation with both search text and method
            Widget? child = this.history_list.get_first_child();
            while (child != null) {
                if (child is RequestRow) {
                    var row = child as RequestRow;
                    var request = row.get_request();
                    
                    // Check search text match
                    bool text_matches = search_text.length == 0 ||
                                      request.method.down().contains(search_text) ||
                                      request.path.down().contains(search_text) ||
                                      request.body.down().contains(search_text);
                    
                    // Check method filter match
                    bool method_matches = selected_method == null || 
                                        selected_method == "All Methods" ||
                                        request.method == selected_method;
                    
                    // Show row only if both filters match
                    child.set_visible(text_matches && method_matches);
                }
                child = child.get_next_sibling();
            }
        }
        
        public void delete_from_history(string request_id) {
            this._show_delete_history_item_confirmation(request_id);
        }
        
        public void handle_request_row_expansion(RequestRow expanding_row, bool is_expanding) {
            if (is_expanding) {
                // Close currently expanded row if different from the one being expanded
                if (this.currently_expanded_row != null && this.currently_expanded_row != expanding_row) {
                    this.currently_expanded_row.set_expanded(false);
                }
                this.currently_expanded_row = expanding_row;
            } else {
                // Row is being collapsed
                if (this.currently_expanded_row == expanding_row) {
                    this.currently_expanded_row = null;
                }
            }
        }
        
        private void _show_history_statistics() {
            var dialog = new StatisticsDialog(this.storage);
            dialog.present(this);
        }
        
        private void _export_history() {
            var history = this.storage.get_history();
            
            if (history.size == 0) {
                this._show_toast("No history to export");
                return;
            }
            
            // Create file chooser dialog
            var file_dialog = new Gtk.FileDialog();
            file_dialog.set_title("Export History");
            file_dialog.set_initial_name("sonar-history.json");
            
            // Set up file filters
            var json_filter = new Gtk.FileFilter();
            json_filter.add_pattern("*.json");
            json_filter.add_suffix("json");
            
            var all_filter = new Gtk.FileFilter();
            all_filter.add_pattern("*");
            
            var filters = new GLib.ListStore(typeof(Gtk.FileFilter));
            filters.append(json_filter);
            filters.append(all_filter);
            file_dialog.set_filters(filters);
            
            file_dialog.save.begin(this, null, (obj, res) => {
                try {
                    var file = file_dialog.save.end(res);
                    this._save_history_to_file(file);
                } catch (Error e) {
                    // User cancelled or error occurred
                    if (!(e is Gtk.DialogError.CANCELLED)) {
                        this._show_toast("Export cancelled");
                    }
                }
            });
        }
        
        private void _save_history_to_file(File file) {
            try {
                var history = this.storage.get_history();
                
                var builder = new Json.Builder();
                builder.begin_object();
                builder.set_member_name("exported_at");
                builder.add_string_value(new DateTime.now_utc().format_iso8601());
                builder.set_member_name("total_requests");
                builder.add_int_value(history.size);
                builder.set_member_name("requests");
                builder.begin_array();
                
                foreach (var request in history) {
                    builder.add_value(request.to_json());
                }
                
                builder.end_array();
                builder.end_object();
                
                var gen = new Json.Generator();
                gen.set_root(builder.get_root());
                gen.pretty = true;
                gen.indent = 2;
                
                var json_data = gen.to_data(null);
                
                file.replace_contents(json_data.data, null, false, 
                                    FileCreateFlags.REPLACE_DESTINATION, null);
                
                this._show_toast(@"History exported to $(file.get_basename())");
                
            } catch (Error e) {
                this._show_toast(@"Export failed: $(e.message)");
            }
        }
        
        private void _update_status_page(TunnelStatus tunnel_status, bool has_auth_token_error) {
            if (has_auth_token_error) {
                // Need to set up auth token
                this.empty_page.set_icon_name("dialog-warning-symbolic");
                this.empty_page.set_title("Setup Required");
                this.empty_page.set_description("You need to configure your ngrok auth token before you can start receiving webhook requests.");
            } else if (!tunnel_status.active) {
                // Ready to start tunnel
                this.empty_page.set_icon_name("network-wireless-symbolic");
                this.empty_page.set_title("Ready to Start");
                this.empty_page.set_description("Start the tunnel to begin receiving webhook requests. Your public URL will appear once the tunnel is active.");
            } else if (tunnel_status.active && tunnel_status.public_url != null) {
                // Tunnel is active, waiting for requests
                this.empty_page.set_icon_name("network-wireless-acquiring-symbolic");
                this.empty_page.set_title("Tunnel Active - Waiting for Requests");
                this.empty_page.set_description(@"Your tunnel is running! Send webhook requests to your public URL to see them here:\n$(tunnel_status.public_url)");
            } else if (tunnel_status.error != null) {
                // Tunnel error
                this.empty_page.set_icon_name("dialog-error-symbolic");
                this.empty_page.set_title("Tunnel Error");
                this.empty_page.set_description(@"There was an error with the tunnel: $(tunnel_status.error)\n\nTry restarting the tunnel or check your network connection.");
            } else {
                // Fallback state
                this.empty_page.set_icon_name("network-wireless-symbolic");
                this.empty_page.set_title("No Requests Yet");
                this.empty_page.set_description("Start the tunnel and send webhook requests to see them here.");
            }
        }
        
        private void _setup_method_filter() {
            // Create a string list with HTTP methods
            var methods = new StringList(null);
            methods.append("All Methods");
            methods.append("GET");
            methods.append("POST");
            methods.append("PUT");
            methods.append("PATCH");
            methods.append("DELETE");
            methods.append("HEAD");
            methods.append("OPTIONS");
            
            // Set the model for the dropdown
            this.history_method_filter.set_model(methods);
            this.history_method_filter.set_selected(0); // Default to "All Methods"
            
            // Connect the selection change signal
            this.history_method_filter.notify["selected"].connect(this._on_method_filter_changed);
        }
        
        private void _on_method_filter_changed() {
            // Trigger filtering when method selection changes
            string search_text = this.history_search_entry.get_text().strip().down();
            this._filter_history(search_text);
        }
        
        private void _show_keyboard_shortcuts_dialog() {
            var dialog = new ShortcutsDialog();
            dialog.present(this);
        }
        
        private void _show_clear_requests_confirmation() {
            var dialog = new Adw.AlertDialog(
                _("Clear All Requests"),
                _("Are you sure you want to clear all current requests? This action cannot be undone.")
            );
            
            dialog.add_response("cancel", _("Cancel"));
            dialog.add_response("clear", _("Clear"));
            dialog.set_response_appearance("clear", Adw.ResponseAppearance.DESTRUCTIVE);
            dialog.set_default_response("cancel");
            dialog.set_close_response("cancel");
            
            dialog.response.connect((response) => {
                if (response == "clear") {
                    this.storage.clear();
                }
            });
            
            dialog.present(this);
        }
        
        private void _show_clear_history_confirmation() {
            var dialog = new Adw.AlertDialog(
                _("Clear All History"),
                _("Are you sure you want to clear all request history? This action cannot be undone.")
            );
            
            dialog.add_response("cancel", _("Cancel"));
            dialog.add_response("clear", _("Clear History"));
            dialog.set_response_appearance("clear", Adw.ResponseAppearance.DESTRUCTIVE);
            dialog.set_default_response("cancel");
            dialog.set_close_response("cancel");
            
            dialog.response.connect((response) => {
                if (response == "clear") {
                    this.storage.clear_history();
                    this._load_history(); // Refresh the history view
                    this._show_toast("History cleared");
                }
            });
            
            dialog.present(this);
        }
        
        private void _show_delete_history_item_confirmation(string request_id) {
            var dialog = new Adw.AlertDialog(
                _("Delete Request"),
                _("Are you sure you want to delete this request from history? This action cannot be undone.")
            );

            dialog.add_response("cancel", _("Cancel"));
            dialog.add_response("delete", _("Delete"));
            dialog.set_response_appearance("delete", Adw.ResponseAppearance.DESTRUCTIVE);
            dialog.set_default_response("cancel");
            dialog.set_close_response("cancel");

            dialog.response.connect((response) => {
                if (response == "delete") {
                    if (this.storage.remove_from_history(request_id)) {
                        this._load_history(); // Refresh the history view
                        this._show_toast("Request deleted from history");
                    }
                }
            });

            dialog.present(this);
        }

        // Filter functionality
        private void _on_filter_button_clicked() {
            bool current_state = this.filter_revealer.get_reveal_child();
            this.filter_revealer.set_reveal_child(!current_state);
        }

        private void _on_clear_filters_clicked() {
            // Reset all filters
            this.requests_method_filter.set_selected(0);
            this.requests_content_type_filter.set_selected(0);
            this.requests_time_filter.set_selected(0);
            this.requests_search_entry.set_text("");
            this.starred_only_toggle.set_active(false);

            // Clear filter state
            this.filter_method = null;
            this.filter_content_type = null;
            this.filter_time_range = null;
            this.filter_search_text = null;

            // Refresh display
            this._apply_filters();
        }

        private void _on_requests_search_changed() {
            this.filter_search_text = this.requests_search_entry.get_text().strip();
            this._apply_filters();
        }

        private void _on_filter_changed() {
            // Get selected filter values
            var method_idx = this.requests_method_filter.get_selected();
            var content_type_idx = this.requests_content_type_filter.get_selected();
            var time_idx = this.requests_time_filter.get_selected();

            // Update filter state
            this.filter_method = method_idx > 0 ? this._get_method_from_index((int)method_idx) : null;
            this.filter_content_type = content_type_idx > 0 ? this._get_content_type_from_index((int)content_type_idx) : null;
            this.filter_time_range = time_idx > 0 ? this._get_time_range_from_index((int)time_idx) : null;

            // Apply filters
            this._apply_filters();
        }

        private void _apply_filters() {
            // Iterate through all request rows and show/hide based on filters
            var requests = this.storage.get_requests();

            foreach (var request in requests) {
                var row = this.request_rows.get(request.id);
                if (row != null) {
                    bool should_show = this._request_matches_filters(request);
                    row.set_visible(should_show);
                }
            }
        }

        private bool _request_matches_filters(WebhookRequest request) {
            // Starred filter
            if (this.starred_only_toggle.get_active() && !request.is_starred) {
                return false;
            }

            // Method filter
            if (this.filter_method != null && request.method != this.filter_method) {
                return false;
            }

            // Content type filter
            if (this.filter_content_type != null) {
                if (request.content_type == null || !request.content_type.contains(this.filter_content_type)) {
                    return false;
                }
            }

            // Time filter
            if (this.filter_time_range != null) {
                if (!this._is_within_time_range(request.timestamp, this.filter_time_range)) {
                    return false;
                }
            }

            // Search text filter
            if (this.filter_search_text != null && this.filter_search_text.length > 0) {
                string search_lower = this.filter_search_text.down();
                bool matches = request.path.down().contains(search_lower) ||
                              request.body.down().contains(search_lower);
                if (!matches) {
                    return false;
                }
            }

            return true;
        }

        private bool _is_within_time_range(DateTime timestamp, string range) {
            var now = new DateTime.now_local();
            var diff = now.difference(timestamp);

            switch (range) {
                case "Last 5 minutes":
                    return diff <= 5 * TimeSpan.MINUTE;
                case "Last 15 minutes":
                    return diff <= 15 * TimeSpan.MINUTE;
                case "Last 30 minutes":
                    return diff <= 30 * TimeSpan.MINUTE;
                case "Last hour":
                    return diff <= TimeSpan.HOUR;
                case "Last 24 hours":
                    return diff <= 24 * TimeSpan.HOUR;
                default:
                    return true;
            }
        }

        private string? _get_method_from_index(int index) {
            switch (index) {
                case 1: return "GET";
                case 2: return "POST";
                case 3: return "PUT";
                case 4: return "DELETE";
                case 5: return "PATCH";
                case 6: return "HEAD";
                case 7: return "OPTIONS";
                default: return null;
            }
        }

        private string? _get_content_type_from_index(int index) {
            switch (index) {
                case 1: return "application/json";
                case 2: return "application/x-www-form-urlencoded";
                case 3: return "multipart/form-data";
                case 4: return "text/plain";
                case 5: return "text/html";
                case 6: return "application/xml";
                default: return null;
            }
        }

        private string? _get_time_range_from_index(int index) {
            switch (index) {
                case 1: return "Last 5 minutes";
                case 2: return "Last 15 minutes";
                case 3: return "Last 30 minutes";
                case 4: return "Last hour";
                case 5: return "Last 24 hours";
                default: return null;
            }
        }

        // Bookmark/Star functionality
        public void on_request_starred_changed(WebhookRequest request) {
            // The request object is already updated, just trigger a save
            // Storage will automatically save on next export or app close
            // For now, we can just log it
            debug("Request %s starred status changed to: %s", request.id, request.is_starred.to_string());
        }

        public void toggle_starred_filter() {
            // TODO: Implement "show only starred" filter option
        }

        // Template functionality
        public void save_request_as_template(WebhookRequest request, string name, string description) {
            var template = new RequestTemplate.from_request(request, name, description);
            this.storage.add_template(template);
            this._show_toast(@"Template '$(name)' saved successfully");
        }

        // Comparison functionality
        public void select_for_comparison(WebhookRequest request) {
            this.comparison_request = request;

            // Enable compare buttons on all request rows
            this._update_compare_buttons_state();

            this._show_toast(@"Selected request for comparison. Click Compare on another request to see differences.");
        }

        public void compare_with_selected(WebhookRequest request) {
            if (this.comparison_request == null) {
                this._show_toast("Please select a request for comparison first");
                return;
            }

            this._show_comparison_dialog(this.comparison_request, request);
        }

        public WebhookRequest? get_comparison_request() {
            return this.comparison_request;
        }

        private void _update_compare_buttons_state() {
            // Update all request rows to enable/disable compare button
            foreach (var entry in this.request_rows.entries) {
                var row = entry.value;
                row.update_compare_button_state(this.comparison_request != null);
            }
        }

        private void _show_comparison_dialog(WebhookRequest request1, WebhookRequest request2) {
            var dialog = new Adw.Dialog();
            dialog.set_title("Compare Requests");
            dialog.set_content_width(1000);
            dialog.set_content_height(700);

            // Create toolbar with close button
            var toolbar = new Adw.ToolbarView();
            var header = new Adw.HeaderBar();
            toolbar.add_top_bar(header);

            // Create scrolled window for comparison content
            var scrolled = new ScrolledWindow();
            scrolled.set_vexpand(true);

            // Main comparison layout
            var main_box = new Box(Orientation.VERTICAL, 12);
            main_box.set_margin_top(12);
            main_box.set_margin_bottom(12);
            main_box.set_margin_start(12);
            main_box.set_margin_end(12);

            // Request headers
            var header_box = new Box(Orientation.HORIZONTAL, 12);
            header_box.set_homogeneous(true);

            var request1_header = this._create_request_header_box(request1, "Request 1");
            var request2_header = this._create_request_header_box(request2, "Request 2");

            header_box.append(request1_header);
            header_box.append(request2_header);
            main_box.append(header_box);

            // Comparison sections
            main_box.append(this._create_comparison_section("Method",
                request1.method, request2.method, request1.method != request2.method));

            main_box.append(this._create_comparison_section("Path",
                request1.path, request2.path, request1.path != request2.path));

            main_box.append(this._create_comparison_section("Content-Type",
                request1.content_type ?? "N/A",
                request2.content_type ?? "N/A",
                request1.content_type != request2.content_type));

            main_box.append(this._create_comparison_text_section("Headers",
                request1.get_formatted_headers(),
                request2.get_formatted_headers()));

            main_box.append(this._create_comparison_text_section("Body",
                request1.get_formatted_body(),
                request2.get_formatted_body()));

            scrolled.set_child(main_box);
            toolbar.set_content(scrolled);
            dialog.set_child(toolbar);

            dialog.present(this);

            // Clear comparison selection after showing dialog
            this.comparison_request = null;
            this._update_compare_buttons_state();
        }

        private Box _create_request_header_box(WebhookRequest request, string title) {
            var box = new Box(Orientation.VERTICAL, 6);

            var title_label = new Label(title);
            title_label.add_css_class("title-3");
            title_label.set_xalign(0);

            var time_label = new Label(request.timestamp.format("%Y-%m-%d %H:%M:%S"));
            time_label.add_css_class("dim-label");
            time_label.set_xalign(0);

            box.append(title_label);
            box.append(time_label);

            return box;
        }

        private Box _create_comparison_section(string label, string value1, string value2, bool different) {
            var box = new Box(Orientation.VERTICAL, 6);

            var label_widget = new Label(label);
            label_widget.add_css_class("heading");
            label_widget.set_xalign(0);
            box.append(label_widget);

            var values_box = new Box(Orientation.HORIZONTAL, 12);
            values_box.set_homogeneous(true);

            var value1_box = new Box(Orientation.VERTICAL, 0);
            var value1_label = new Label(value1);
            value1_label.set_xalign(0);
            value1_label.set_wrap(true);
            value1_label.set_wrap_mode(Pango.WrapMode.WORD_CHAR);
            if (different) {
                value1_label.add_css_class("warning");
            }
            value1_box.append(value1_label);

            var value2_box = new Box(Orientation.VERTICAL, 0);
            var value2_label = new Label(value2);
            value2_label.set_xalign(0);
            value2_label.set_wrap(true);
            value2_label.set_wrap_mode(Pango.WrapMode.WORD_CHAR);
            if (different) {
                value2_label.add_css_class("warning");
            }
            value2_box.append(value2_label);

            values_box.append(value1_box);
            values_box.append(value2_box);
            box.append(values_box);

            return box;
        }

        private Box _create_comparison_text_section(string label, string text1, string text2) {
            var box = new Box(Orientation.VERTICAL, 6);

            var label_widget = new Label(label);
            label_widget.add_css_class("heading");
            label_widget.set_xalign(0);
            box.append(label_widget);

            var text_box = new Box(Orientation.HORIZONTAL, 12);
            text_box.set_homogeneous(true);

            // Text view 1
            var scrolled1 = new ScrolledWindow();
            scrolled1.set_vexpand(true);
            scrolled1.set_min_content_height(150);
            var text_view1 = new TextView();
            text_view1.set_editable(false);
            text_view1.set_monospace(true);
            text_view1.set_wrap_mode(Gtk.WrapMode.WORD_CHAR);
            text_view1.get_buffer().set_text(text1, -1);
            scrolled1.set_child(text_view1);

            // Text view 2
            var scrolled2 = new ScrolledWindow();
            scrolled2.set_vexpand(true);
            scrolled2.set_min_content_height(150);
            var text_view2 = new TextView();
            text_view2.set_editable(false);
            text_view2.set_monospace(true);
            text_view2.set_wrap_mode(Gtk.WrapMode.WORD_CHAR);
            text_view2.get_buffer().set_text(text2, -1);
            scrolled2.set_child(text_view2);

            text_box.append(scrolled1);
            text_box.append(scrolled2);
            box.append(text_box);

            return box;
        }
    }
}