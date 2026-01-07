/*
 * Preferences dialog for configuring ngrok auth token and other settings.
 */

using Gtk;
using Adw;
using GLib;

namespace Sonar {
    
    /**
     * Dialog for configuring application preferences.
     */
#if DEVELOPMENT
    [GtkTemplate (ui = "/io/github/tobagin/sonar/Devel/preferences.ui")]
#else
    [GtkTemplate (ui = "/io/github/tobagin/sonar/preferences.ui")]
#endif
    public class PreferencesDialog : Adw.PreferencesDialog {
        private TunnelManager tunnel_manager;
        private WebhookServer server;

        [GtkChild] private unowned Entry auth_token_entry;
        [GtkChild] private unowned Button save_token_button;
        [GtkChild] private unowned Button test_token_button;
        [GtkChild] private unowned Label token_status_label;
        [GtkChild] private unowned Label ngrok_version_label;
        [GtkChild] private unowned Adw.ActionRow help_row;

        // Forwarding widgets
        [GtkChild] private unowned Switch enable_forwarding_switch;
        [GtkChild] private unowned TextView forwarding_urls_textview;
        [GtkChild] private unowned Switch preserve_method_switch;
        [GtkChild] private unowned Switch forward_headers_switch;
        [GtkChild] private unowned SpinButton port_spin;

        public PreferencesDialog(Gtk.Window parent, TunnelManager tunnel_manager, WebhookServer server) {
            Object();
            this.tunnel_manager = tunnel_manager;
            this.server = server;

            // Bind settings
            var settings = new GLib.Settings(Config.APP_ID);
            settings.bind("forwarded-port", this.port_spin, "value", SettingsBindFlags.DEFAULT);

            this._setup_signals();
            this._load_current_settings();
        }
        
        private void _setup_signals() {
            // Connect signals for template widgets
            this.auth_token_entry.changed.connect(this._on_token_entry_changed);
            this.save_token_button.clicked.connect(this._on_save_token_clicked);
            this.test_token_button.clicked.connect(this._on_test_token_clicked);

            this.help_row.activated.connect(() => {
                try {
                    AppInfo.launch_default_for_uri("https://ngrok.com/signup", null);
                } catch (Error e) {
                    warning("Failed to open URL: %s", e.message);
                }
            });

            // Forwarding signals
            this.enable_forwarding_switch.notify["active"].connect(this._on_forwarding_settings_changed);
            this.preserve_method_switch.notify["active"].connect(this._on_forwarding_settings_changed);
            this.forward_headers_switch.notify["active"].connect(this._on_forwarding_settings_changed);
            this.forwarding_urls_textview.get_buffer().changed.connect(this._on_forwarding_urls_changed);
        }
        
        private void _load_current_settings() {
            var tunnel_status = this.tunnel_manager.get_status();

            if (tunnel_status.error == null || !tunnel_status.error.contains("No NGROK_AUTHTOKEN")) {
                this.token_status_label.set_text("Token configured");
                this.token_status_label.add_css_class("success");
                this.test_token_button.set_sensitive(true);
            } else {
                this.token_status_label.set_text("No token configured");
                this.token_status_label.remove_css_class("success");
                this.token_status_label.add_css_class("error");
            }

            // Set ngrok version
            var version = TunnelManager.get_version();
            this.ngrok_version_label.set_text(version ?? "Not installed");

            // Load forwarding settings
            this.enable_forwarding_switch.set_active(this.server.is_forwarding_enabled());
            this.preserve_method_switch.set_active(this.server.get_preserve_method());
            this.forward_headers_switch.set_active(this.server.get_forward_headers());

            var urls = this.server.get_forward_urls();
            if (urls.size > 0) {
                var buffer = this.forwarding_urls_textview.get_buffer();
                buffer.set_text(string.joinv("\n", urls.to_array()), -1);
            }
        }
        
        private void _on_token_entry_changed() {
            string token = this.auth_token_entry.get_text().strip();
            bool has_token = token.length > 0;
            
            this.save_token_button.set_sensitive(has_token);
            this.test_token_button.set_sensitive(false);
        }
        
        private void _on_save_token_clicked() {
            string token = this.auth_token_entry.get_text().strip();

            // Smart cleanup for "ngrok config add-authtoken <token>" paste
            if (token.has_prefix("ngrok config add-authtoken ")) {
                token = token.replace("ngrok config add-authtoken ", "").strip();
                // Update UI to show what we are actually saving
                this.auth_token_entry.set_text(token);
            }
            
            if (token.length == 0) {
                this._show_error("Please enter a valid auth token");
                return;
            }
            
            bool success = this.tunnel_manager.set_auth_token(token);
            
            if (success) {
                this.token_status_label.set_text("Token saved successfully");
                this.token_status_label.remove_css_class("error");
                this.token_status_label.add_css_class("success");
                this.test_token_button.set_sensitive(true);
                
                // Clear the entry for security
                this.auth_token_entry.set_text("");
                this.save_token_button.set_sensitive(false);
                
                this._show_success("Auth token saved successfully");
            } else {
                var status = this.tunnel_manager.get_status();
                string error_msg = status.error ?? "Failed to save auth token";
                this.token_status_label.set_text(error_msg);
                this.token_status_label.remove_css_class("success");
                this.token_status_label.add_css_class("error");
                this._show_error(error_msg);
            }
        }
        
        private void _on_test_token_clicked() {
            this.test_token_button.set_sensitive(false);
            this.test_token_button.set_label("Testing...");

            // Refresh token status (now async)
            this.tunnel_manager.refresh_auth_token();

            // Wait a bit for the async refresh to complete, then check status
            Timeout.add(2000, () => {
                this.test_token_button.set_label("Test Connection");
                this.test_token_button.set_sensitive(true);

                var status = this.tunnel_manager.get_status();
                if (status.error == null || !status.error.contains("No NGROK_AUTHTOKEN")) {
                    this._show_success("Connection test successful");
                    this.token_status_label.set_text("Token is valid");
                    this.token_status_label.remove_css_class("error");
                    this.token_status_label.add_css_class("success");
                } else {
                    this._show_error("Connection test failed: " + status.error);
                    this.token_status_label.set_text(status.error);
                    this.token_status_label.remove_css_class("success");
                    this.token_status_label.add_css_class("error");
                }

                return Source.REMOVE;
            });
        }
        
        private void _show_success(string message) {
            // For now, just show a simple dialog
            var dialog = new Adw.AlertDialog("Success", message);
            dialog.add_response("ok", "OK");
            dialog.present(this);
        }
        
        private void _show_error(string message) {
            var dialog = new Adw.AlertDialog("Error", message);
            dialog.add_response("ok", "OK");
            dialog.present(this);
        }

        private void _on_forwarding_settings_changed() {
            this.server.set_forwarding_enabled(this.enable_forwarding_switch.get_active());
            this.server.set_preserve_method(this.preserve_method_switch.get_active());
            this.server.set_forward_headers(this.forward_headers_switch.get_active());
        }

        private void _on_forwarding_urls_changed() {
            var buffer = this.forwarding_urls_textview.get_buffer();
            TextIter start, end;
            buffer.get_bounds(out start, out end);
            string text = buffer.get_text(start, end, false);

            var urls = new Gee.ArrayList<string>();
            foreach (var line in text.split("\n")) {
                var url = line.strip();
                if (url.length > 0 && (url.has_prefix("http://") || url.has_prefix("https://"))) {
                    urls.add(url);
                }
            }

            this.server.set_forward_urls(urls);
        }
    }
}