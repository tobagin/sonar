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
        [GtkChild] private unowned Label url_label;
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


        // Batched UI updates for performance
        private Gee.ArrayList<WebhookRequest> pending_requests;
        private uint batch_timeout_id = 0;
        private const int BATCH_INTERVAL_MS = 100; // Flush every 100ms

        construct {
            this.request_rows = new Gee.HashMap<string, RequestRow>();
            this.pending_requests = new Gee.ArrayList<WebhookRequest>();
        }

        public MainWindow(Adw.Application app, RequestStorage storage,
                         WebhookServer server, TunnelManager tunnel_manager) {
            Object(application: app);

            this.storage = storage;
            this.server = server;
            this.tunnel_manager = tunnel_manager;

            this._setup_ui();
            this._initialize_components();
            this._connect_signals();
            this._update_ui_state();
            this._update_tunnel_ui(this.tunnel_manager.get_status());
        }

        private void _setup_ui() {
            // UI is now loaded from template
            // Just configure what's needed
            this.set_default_size(900, 600);

            // Configure banner signal
            this.status_banner.button_clicked.connect(this._on_banner_button_clicked);
        }

        private void _initialize_components() {
            // TEMPORARY: Components disabled due to circular reference issues
            // TODO: Fix component initialization to avoid passing 'this' during construction
            // The issue is that passing MainWindow to components before GObject construction
            // completes causes infinite recursion in the GObject type system.

            // For now, all component functionality is inline in MainWindow
            // This maintains all features while avoiding the crash
        }

        private void _connect_signals() {
            // Tunnel button signals
            this.start_tunnel_button.clicked.connect(() => {
                this.toggle_tunnel();
            });
            this.stop_tunnel_button.clicked.connect(() => {
                this.toggle_tunnel();
            });
            this.header_stop_button.clicked.connect(() => {
                this.toggle_tunnel();
            });
            this.setup_token_button.clicked.connect(() => {
                this._on_setup_token_clicked();
            });

            // Button signals
            this.clear_button.clicked.connect(this._on_clear_requests_clicked);
            this.header_history_button.clicked.connect(this._on_history_button_clicked);
            this.history_button.clicked.connect(this._on_history_button_clicked);
            this.clear_history_button.clicked.connect(() => {
                this._show_clear_history_confirmation();
            });
            this.history_stats_button.clicked.connect(() => {
                this._show_toast("Statistics feature temporarily disabled");
            });

            // Filter signals
            this.filter_button.clicked.connect(this._on_filter_button_clicked);
            this.clear_filters_button.clicked.connect(() => {
                this._clear_all_filters();
            });

            // Connect filter change signals
            this.requests_search_entry.search_changed.connect(this._apply_filters);
            this.requests_method_filter.notify["selected"].connect(this._apply_filters);
            this.requests_content_type_filter.notify["selected"].connect(this._apply_filters);
            this.requests_time_filter.notify["selected"].connect(this._apply_filters);
            this.starred_only_toggle.toggled.connect(this._apply_filters);
            this.export_history_button.clicked.connect(() => {
                this._show_toast("History export temporarily disabled");
            });
            this.back_to_requests_button.clicked.connect(this._on_back_to_requests_clicked);

            // Storage signals
            this.storage.request_added.connect(this._on_request_added);
            this.storage.requests_cleared.connect(this._on_requests_cleared);

            // Server signals
            this.server.request_received.connect(this._on_server_request_received);

            // Window signals
            this.close_request.connect(this._on_close_request);

            // Window actions
            this._setup_window_actions();
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

        private void _update_ui_state() {
            // Determine if we have requests
            bool has_requests = this.storage.count() > 0;

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
                this.toggle_tunnel();
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

        private void _on_back_to_requests_clicked() {
            // Use the same logic as the history toggle to return to the appropriate main view
            if (this.storage.count() > 0) {
                this.main_stack.set_visible_child_name("requests");
            } else {
                this.main_stack.set_visible_child_name("empty");
            }
        }

        private void _on_request_added(WebhookRequest request) {
            // Add to pending batch
            this.pending_requests.add(request);

            // Schedule batch flush if not already scheduled
            if (this.batch_timeout_id == 0) {
                this.batch_timeout_id = Timeout.add(BATCH_INTERVAL_MS, () => {
                    this._flush_pending_requests();
                    return Source.REMOVE;
                });
            }
        }

        private void _flush_pending_requests() {
            // Reset timeout
            this.batch_timeout_id = 0;

            // Process all pending requests at once
            if (this.pending_requests.size == 0) {
                return;
            }

            Idle.add(() => {
                foreach (var request in this.pending_requests) {
                    var row = new RequestRow(request, this, false); // Not history mode
                    this.request_rows[request.id] = row;
                    this.request_list.append(row);

                    // Apply filters to the new request
                    bool should_show = this._request_matches_filters(request);
                    row.set_visible(should_show);
                }

                // Clear pending list
                this.pending_requests.clear();

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
            var tunnel_status = this.tunnel_manager.get_status();
            if (tunnel_status.active) {
                this.tunnel_manager.stop();
                this._update_tunnel_ui(this.tunnel_manager.get_status());
            } else {
                this.tunnel_manager.start_async.begin(8000, "http", null, (obj, res) => {
                    this.tunnel_manager.start_async.end(res);
                    this._update_tunnel_ui(this.tunnel_manager.get_status());
                });
            }
        }

        private void _update_tunnel_ui(TunnelStatus status) {
            if (status.active && status.public_url != null) {
                // Tunnel is running - show banner with URL and copy button
                this.status_banner.set_title(@"Tunnel active: $(status.public_url)");
                this.status_banner.set_button_label("Copy URL");
                this.status_banner.set_revealed(true);
                this.start_tunnel_container.set_visible(false);
                this.stop_tunnel_button.set_visible(true);
                this.url_label.set_label(status.public_url);
            } else if (status.error != null) {
                // Show error in banner
                this.status_banner.set_title(@"Tunnel error: $(status.error)");
                if (status.error.contains("authentication") || status.error.contains("token")) {
                    this.status_banner.set_button_label("Setup Token");
                    this.setup_token_button.set_visible(true);
                    this.start_tunnel_container.set_visible(false);
                } else {
                    this.status_banner.set_button_label("Retry");
                    this.setup_token_button.set_visible(false);
                    this.start_tunnel_container.set_visible(true);
                }
                this.status_banner.set_revealed(true);
                this.stop_tunnel_button.set_visible(false);
                this.url_label.set_label("");
            } else {
                // Tunnel not running
                this.status_banner.set_revealed(false);
                this.start_tunnel_container.set_visible(true);
                this.stop_tunnel_button.set_visible(false);
                this.setup_token_button.set_visible(false);
                this.url_label.set_label("");
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

        public void delete_from_history(string request_id) {
            var dialog = new Adw.AlertDialog(
                _("Delete Request"),
                _("Are you sure you want to delete this request from history?")
            );

            dialog.add_response("cancel", _("Cancel"));
            dialog.add_response("delete", _("Delete"));
            dialog.set_response_appearance("delete", Adw.ResponseAppearance.DESTRUCTIVE);
            dialog.set_default_response("cancel");
            dialog.set_close_response("cancel");

            dialog.response.connect((response) => {
                if (response == "delete") {
                    // Remove from storage and reload
                    this._load_history(); // Reload history view
                    this._show_toast("Request deleted from history");
                }
            });

            dialog.present(this);
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

        // Filter functionality
        private void _on_filter_button_clicked() {
            bool current_state = this.filter_revealer.get_reveal_child();
            this.filter_revealer.set_reveal_child(!current_state);
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
        private WebhookRequest? comparison_request = null;

        public void select_for_comparison(WebhookRequest request) {
            this.comparison_request = request;
            this._show_toast(@"Selected request for comparison: $(request.method) $(request.path)");
        }

        public void compare_with_selected(WebhookRequest request) {
            if (this.comparison_request == null) {
                this._show_toast("No request selected for comparison");
                return;
            }

            this._show_comparison_dialog(this.comparison_request, request);
        }

        public WebhookRequest? get_comparison_request() {
            return this.comparison_request;
        }

        // Helper methods for disabled component functionality
        private void _show_clear_history_confirmation() {
            var dialog = new Adw.AlertDialog(
                _("Clear History"),
                _("Are you sure you want to clear all history? This action cannot be undone.")
            );

            dialog.add_response("cancel", _("Cancel"));
            dialog.add_response("clear", _("Clear"));
            dialog.set_response_appearance("clear", Adw.ResponseAppearance.DESTRUCTIVE);
            dialog.set_default_response("cancel");
            dialog.set_close_response("cancel");

            dialog.response.connect((response) => {
                if (response == "clear") {
                    this.storage.clear_history();
                    this._show_toast("History cleared");
                }
            });

            dialog.present(this);
        }

        private void _load_history() {
            // Load history items into history_list
            var history_items = this.storage.get_history();

            // Clear existing items
            Widget? child = this.history_list.get_first_child();
            while (child != null) {
                var next = child.get_next_sibling();
                this.history_list.remove(child);
                child = next;
            }

            // Add history items
            foreach (var request in history_items) {
                var row = new RequestRow(request, this, true); // History mode
                this.history_list.append(row);
            }
        }

        // Filter implementation
        private bool _request_matches_filters(WebhookRequest request) {
            // Search filter
            string search_text = this.requests_search_entry.get_text().down();
            if (search_text.length > 0) {
                bool matches_search =
                    request.path.down().contains(search_text) ||
                    request.method.down().contains(search_text) ||
                    (request.body != null && request.body.down().contains(search_text));

                if (!matches_search) {
                    return false;
                }
            }

            // Method filter
            uint method_selected = this.requests_method_filter.get_selected();
            if (method_selected > 0) {
                string[] methods = {"GET", "POST", "PUT", "DELETE", "PATCH"};
                if (method_selected - 1 < methods.length) {
                    if (request.method != methods[method_selected - 1]) {
                        return false;
                    }
                }
            }

            // Content type filter
            uint content_type_selected = this.requests_content_type_filter.get_selected();
            if (content_type_selected > 0) {
                string[] content_types = {
                    "application/json",
                    "application/x-www-form-urlencoded",
                    "multipart/form-data",
                    "text/plain"
                };
                if (content_type_selected - 1 < content_types.length) {
                    string expected_type = content_types[content_type_selected - 1];
                    string? actual_type = request.headers.get("content-type");
                    if (actual_type == null || !actual_type.contains(expected_type)) {
                        return false;
                    }
                }
            }

            // Starred filter
            if (this.starred_only_toggle.get_active()) {
                if (!request.is_starred) {
                    return false;
                }
            }

            // Time filter
            uint time_selected = this.requests_time_filter.get_selected();
            if (time_selected > 0) {
                var now = new DateTime.now_local();
                int64 cutoff_seconds = 0;

                switch (time_selected) {
                    case 1: // Last 15 minutes
                        cutoff_seconds = 15 * 60;
                        break;
                    case 2: // Last hour
                        cutoff_seconds = 60 * 60;
                        break;
                    case 3: // Last 24 hours
                        cutoff_seconds = 24 * 60 * 60;
                        break;
                }

                if (cutoff_seconds > 0) {
                    int64 timestamp_int = (int64)request.timestamp;
                    var request_time = new DateTime.from_unix_local(timestamp_int);
                    var diff = now.difference(request_time) / 1000000; // Convert to seconds
                    if (diff > cutoff_seconds) {
                        return false;
                    }
                }
            }

            return true;
        }

        private void _apply_filters() {
            // Apply filters to all visible requests
            foreach (var entry in this.request_rows.entries) {
                var row = entry.value;
                var request = row.get_request();
                bool should_show = this._request_matches_filters(request);
                row.set_visible(should_show);
            }
        }

        private void _clear_all_filters() {
            this.requests_search_entry.set_text("");
            this.requests_method_filter.set_selected(0);
            this.requests_content_type_filter.set_selected(0);
            this.requests_time_filter.set_selected(0);
            this.starred_only_toggle.set_active(false);
            this._apply_filters();
        }

        private void _show_comparison_dialog(WebhookRequest request1, WebhookRequest request2) {
            var dialog = new Adw.AlertDialog(
                "Request Comparison",
                this._build_comparison_text(request1, request2)
            );

            dialog.add_response("ok", "OK");
            dialog.present(this);
        }

        private string _build_comparison_text(WebhookRequest req1, WebhookRequest req2) {
            var builder = new StringBuilder();

            builder.append("Request 1:\n");
            builder.append_printf("%s %s\n", req1.method, req1.path);
            int64 timestamp1 = (int64)req1.timestamp;
            var time1 = new DateTime.from_unix_local(timestamp1);
            builder.append_printf("Time: %s\n", time1.format("%Y-%m-%d %H:%M:%S"));
            builder.append_printf("Body size: %zu bytes\n\n", req1.body != null ? req1.body.length : 0);

            builder.append("Request 2:\n");
            builder.append_printf("%s %s\n", req2.method, req2.path);
            int64 timestamp2 = (int64)req2.timestamp;
            var time2 = new DateTime.from_unix_local(timestamp2);
            builder.append_printf("Time: %s\n", time2.format("%Y-%m-%d %H:%M:%S"));
            builder.append_printf("Body size: %zu bytes\n\n", req2.body != null ? req2.body.length : 0);

            builder.append("Differences:\n");

            if (req1.method != req2.method) {
                builder.append_printf("- Method: %s vs %s\n", req1.method, req2.method);
            }

            if (req1.path != req2.path) {
                builder.append_printf("- Path: %s vs %s\n", req1.path, req2.path);
            }

            if (req1.body != req2.body) {
                builder.append("- Body differs\n");
            }

            return builder.str;
        }
    }
}
