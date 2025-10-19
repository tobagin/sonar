/*
 * Widget for displaying individual webhook requests.
 */

using Gtk;
using Adw;
using GLib;

namespace Sonar {
#if DEVELOPMENT
    [GtkTemplate (ui = "/io/github/tobagin/sonar/Devel/request_row.ui")]
#else
    [GtkTemplate (ui = "/io/github/tobagin/sonar/request_row.ui")]
#endif
    public class RequestRow : Adw.ExpanderRow {
        [GtkChild] private unowned Label method_label;
        [GtkChild] private unowned Button star_button;
        [GtkChild] private unowned Button copy_button;
        [GtkChild] private unowned Button copy_headers_button;
        [GtkChild] private unowned Button copy_body_button;
        [GtkChild] private unowned Button copy_curl_button;
        [GtkChild] private unowned Button copy_http_button;
        [GtkChild] private unowned Button replay_button;
        [GtkChild] private unowned Button compare_button;
        [GtkChild] private unowned Button save_template_button;
        [GtkChild] private unowned TextView headers_text;
        [GtkChild] private unowned TextView body_text;
        
        private WebhookRequest request;
        private MainWindow main_window;
        private bool is_history_mode;
        private Button delete_button;
        
        public WebhookRequest get_request() {
            return this.request;
        }
        
        // Template properties
        public string method_path { get; private set; }
        public string timestamp_text { get; private set; }
        public string method { get; private set; }
        public string path { get; private set; }
        public string content_type { get; private set; }
        
        public RequestRow(WebhookRequest request, MainWindow main_window, bool is_history_mode = false) {
            Object();
            
            this.request = request;
            this.main_window = main_window;
            this.is_history_mode = is_history_mode;
            
            // Set template properties
            this.method_path = request.path;
            this.timestamp_text = request.timestamp.format("%H:%M:%S");
            this.method = request.method;
            this.path = request.path;
            this.content_type = request.content_type ?? "text/plain";
            
            this._setup_ui();
            this._populate_data();
        }
        
        private void _setup_ui() {
            // Style the method label with colors
            this.method_label.add_css_class("method-" + request.method.down());
            
            // Add method colors
            switch (request.method.up()) {
                case "GET":
                    this.method_label.add_css_class("success");
                    break;
                case "POST":
                    this.method_label.add_css_class("accent");
                    break;
                case "PUT":
                    this.method_label.add_css_class("warning");
                    break;
                case "DELETE":
                    this.method_label.add_css_class("error");
                    break;
                case "PATCH":
                    this.method_label.add_css_class("accent");
                    break;
                default:
                    this.method_label.add_css_class("neutral");
                    break;
            }
            
            // Connect to expansion changes for accordion behavior
            this.notify["expanded"].connect(() => {
                this.main_window.handle_request_row_expansion(this, this.get_expanded());
            });
            
            // Connect button signals - template buttons are already defined
            this.star_button.clicked.connect(this._on_star_clicked);
            this.copy_button.clicked.connect(this._on_copy_all_clicked);
            this.copy_headers_button.clicked.connect(this._on_copy_headers_clicked);
            this.copy_body_button.clicked.connect(this._on_copy_body_clicked);
            this.copy_curl_button.clicked.connect(this._on_copy_curl_clicked);
            this.copy_http_button.clicked.connect(this._on_copy_http_clicked);
            this.replay_button.clicked.connect(this._on_replay_clicked);
            this.compare_button.clicked.connect(this._on_compare_clicked);
            this.save_template_button.clicked.connect(this._on_save_template_clicked);

            // Set initial star state
            this._update_star_icon();
            
            // Add delete button for history mode
            if (this.is_history_mode) {
                this.delete_button = new Button();
                this.delete_button.set_icon_name("user-trash-symbolic");
                this.delete_button.set_tooltip_text("Delete from History");
                this.delete_button.set_valign(Align.CENTER);
                this.delete_button.add_css_class("flat");
                this.delete_button.add_css_class("destructive-action");
                this.delete_button.clicked.connect(this._on_delete_clicked);
                this.add_suffix(this.delete_button);
            }
        }
        
        private void _populate_data() {
            // Set headers text
            var headers_buffer = this.headers_text.get_buffer();
            headers_buffer.set_text(this.request.get_formatted_headers(), -1);
            
            // Set body text
            var formatted_body = this.request.get_formatted_body();
            if (formatted_body.length == 0) {
                formatted_body = "<empty>";
            }
            var body_buffer = this.body_text.get_buffer();
            body_buffer.set_text(formatted_body, -1);
        }
        
        private void _on_copy_all_clicked() {
            var json_data = this._request_to_json_string();
            this._copy_to_clipboard(json_data);
            this._show_copy_toast("Request data copied");
        }
        
        private void _on_copy_headers_clicked() {
            var headers_text = this.request.get_formatted_headers();
            this._copy_to_clipboard(headers_text);
            this._show_copy_toast("Headers copied");
        }
        
        private void _on_copy_body_clicked() {
            var body_text = this.request.get_formatted_body();
            this._copy_to_clipboard(body_text);
            this._show_copy_toast("Body copied");
        }
        
        private void _on_delete_clicked() {
            this.main_window.delete_from_history(this.request.id);
        }

        private void _on_star_clicked() {
            // Toggle starred state
            this.request.is_starred = !this.request.is_starred;

            // Update icon
            this._update_star_icon();

            // Notify main window to save state
            this.main_window.on_request_starred_changed(this.request);

            // Show feedback
            if (this.request.is_starred) {
                this._show_copy_toast("Request starred");
            } else {
                this._show_copy_toast("Unstarred");
            }
        }

        private void _update_star_icon() {
            if (this.request.is_starred) {
                this.star_button.set_icon_name("starred-symbolic");
                this.star_button.set_tooltip_text(_("Unstar Request"));
                this.star_button.add_css_class("accent");
            } else {
                this.star_button.set_icon_name("non-starred-symbolic");
                this.star_button.set_tooltip_text(_("Star Request"));
                this.star_button.remove_css_class("accent");
            }
        }

        public void update_starred_state() {
            this._update_star_icon();
        }

        private void _on_copy_curl_clicked() {
            var curl_command = this._generate_curl_command();
            this._copy_to_clipboard(curl_command);
            this._show_copy_toast("Copied as cURL command");
        }

        private void _on_copy_http_clicked() {
            var http_request = this._generate_http_request();
            this._copy_to_clipboard(http_request);
            this._show_copy_toast("Copied as HTTP request");
        }

        private string _generate_curl_command() {
            var builder = new StringBuilder();

            // Start with curl command
            builder.append("curl");

            // Add method if not GET
            if (this.request.method != "GET") {
                builder.append_printf(" -X %s", this.request.method);
            }

            // Add headers
            this.request.headers.foreach((key, value) => {
                // Escape special characters in header values
                var escaped_value = value.replace("\"", "\\\"");
                builder.append_printf(" \\\n  -H \"%s: %s\"", key, escaped_value);
            });

            // Add body if present
            if (this.request.body.length > 0) {
                // Escape special characters in body
                var escaped_body = this.request.body
                    .replace("\\", "\\\\")
                    .replace("\"", "\\\"")
                    .replace("$", "\\$")
                    .replace("`", "\\`")
                    .replace("\n", "\\n");
                builder.append_printf(" \\\n  -d \"%s\"", escaped_body);
            }

            // Add URL (use localhost as placeholder since we don't have the original URL)
            var url = "http://localhost:8000" + this.request.path;
            if (this.request.query_params.size() > 0) {
                url += "?";
                bool first = true;
                this.request.query_params.foreach((key, value) => {
                    if (!first) url += "&";
                    url += @"$(Uri.escape_string(key))=$(Uri.escape_string(value))";
                    first = false;
                });
            }
            builder.append_printf(" \\\n  \"%s\"", url);

            return builder.str;
        }

        private string _generate_http_request() {
            var builder = new StringBuilder();

            // Request line
            var path_with_query = this.request.path;
            if (this.request.query_params.size() > 0) {
                path_with_query += "?";
                bool first = true;
                this.request.query_params.foreach((key, value) => {
                    if (!first) path_with_query += "&";
                    path_with_query += @"$(Uri.escape_string(key))=$(Uri.escape_string(value))";
                    first = false;
                });
            }
            builder.append_printf("%s %s HTTP/1.1\n", this.request.method, path_with_query);

            // Headers
            this.request.headers.foreach((key, value) => {
                builder.append_printf("%s: %s\n", key, value);
            });

            // Empty line before body
            builder.append("\n");

            // Body
            if (this.request.body.length > 0) {
                builder.append(this.request.body);
            }

            return builder.str;
        }

        private void _on_replay_clicked() {
            this._show_replay_dialog();
        }

        private void _on_compare_clicked() {
            var comparison_request = this.main_window.get_comparison_request();

            if (comparison_request == null) {
                // This is the first request selected for comparison
                this.main_window.select_for_comparison(this.request);
            } else {
                // Compare with the previously selected request
                this.main_window.compare_with_selected(this.request);
            }
        }

        public void update_compare_button_state(bool has_comparison_selection) {
            if (has_comparison_selection) {
                this.compare_button.set_sensitive(true);
                this.compare_button.set_label(_("Compare with Selected"));
            } else {
                this.compare_button.set_sensitive(true);
                this.compare_button.set_label(_("Select for Comparison"));
            }
        }

        private void _on_save_template_clicked() {
            this._show_save_template_dialog();
        }

        private void _show_save_template_dialog() {
            var dialog = new Adw.AlertDialog(
                _("Save as Template"),
                _("Create a reusable template from this request")
            );

            dialog.add_response("cancel", _("Cancel"));
            dialog.add_response("save", _("Save"));
            dialog.set_response_appearance("save", Adw.ResponseAppearance.SUGGESTED);
            dialog.set_default_response("save");
            dialog.set_close_response("cancel");

            // Create input fields
            var name_entry = new Entry();
            name_entry.set_placeholder_text(_("Template name (e.g., Create User)"));
            name_entry.set_activates_default(true);

            var description_entry = new Entry();
            description_entry.set_placeholder_text(_("Description (optional)"));

            var box = new Box(Orientation.VERTICAL, 12);
            box.append(name_entry);
            box.append(description_entry);

            dialog.set_extra_child(box);

            dialog.response.connect((response) => {
                if (response == "save") {
                    var name = name_entry.get_text().strip();
                    var description = description_entry.get_text().strip();

                    if (name.length == 0) {
                        this._show_copy_toast("Template name cannot be empty");
                        return;
                    }

                    this.main_window.save_request_as_template(this.request, name, description);
                }
            });

            dialog.present(this.main_window);
        }

        private void _show_replay_dialog() {
            var dialog = new Adw.AlertDialog(
                _("Replay Request"),
                _("Enter the URL where you want to resend this request")
            );

            dialog.add_response("cancel", _("Cancel"));
            dialog.add_response("replay", _("Replay"));
            dialog.set_response_appearance("replay", Adw.ResponseAppearance.SUGGESTED);
            dialog.set_default_response("replay");
            dialog.set_close_response("cancel");

            // Create URL entry
            var entry = new Entry();
            entry.set_placeholder_text("https://example.com/webhook");
            entry.set_text("http://localhost:8000" + this.request.path);
            entry.set_activates_default(true);

            // Create extra content box
            var box = new Box(Orientation.VERTICAL, 12);
            box.append(entry);

            dialog.set_extra_child(box);

            dialog.response.connect((response) => {
                if (response == "replay") {
                    var url = entry.get_text().strip();
                    if (url.length > 0) {
                        this._replay_request_async.begin(url);
                    }
                }
            });

            dialog.present(this.main_window);
        }

        private async void _replay_request_async(string url) {
            this._show_copy_toast("Replaying request...");

            try {
                var session = new Soup.Session();
                var message = new Soup.Message(this.request.method, url);

                // Add all headers
                this.request.headers.foreach((key, value) => {
                    message.request_headers.append(key, value);
                });

                // Add body if present
                if (this.request.body.length > 0) {
                    message.set_request_body_from_bytes(
                        this.request.content_type ?? "application/octet-stream",
                        new Bytes(this.request.body.data)
                    );
                }

                // Send request
                var response = yield session.send_async(message, Priority.DEFAULT, null);

                if (message.status_code >= 200 && message.status_code < 300) {
                    this._show_copy_toast(@"Request replayed successfully ($(message.status_code))");
                } else {
                    this._show_copy_toast(@"Request sent, got status $(message.status_code)");
                }

            } catch (Error e) {
                this._show_copy_toast(@"Failed to replay: $(e.message)");
            }
        }

        private string _request_to_json_string() {
            var json_node = this.request.to_json();
            var generator = new Json.Generator();
            generator.set_root(json_node);
            generator.pretty = true;
            generator.indent = 2;
            return generator.to_data(null);
        }
        
        private void _copy_to_clipboard(string text) {
            var window = this.get_root() as Gtk.Window;
            if (window != null) {
                var clipboard = window.get_clipboard();
                clipboard.set_text(text);
            }
        }
        
        private void _show_copy_toast(string message) {
            var toast = new Adw.Toast(message);
            toast.set_timeout(2);
            
            // Find the toast overlay by traversing up the widget hierarchy
            Widget? parent = this.get_parent();
            while (parent != null) {
                if (parent is Adw.ToastOverlay) {
                    var overlay = parent as Adw.ToastOverlay;
                    overlay.add_toast(toast);
                    break;
                }
                parent = parent.get_parent();
            }
        }
    }
}