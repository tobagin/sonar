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
        [GtkChild] private unowned Button copy_button;
        [GtkChild] private unowned Button copy_headers_button;
        [GtkChild] private unowned Button copy_body_button;
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
            this.copy_button.clicked.connect(this._on_copy_all_clicked);
            this.copy_headers_button.clicked.connect(this._on_copy_headers_clicked);
            this.copy_body_button.clicked.connect(this._on_copy_body_clicked);
            
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