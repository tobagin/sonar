/*
 * Tunnel controller component for managing tunnel state and UI.
 */

using Gtk;
using Adw;
using GLib;

namespace Sonar {

    /**
     * Controls tunnel starting/stopping and status display.
     */
    public class TunnelController : GLib.Object {
        // UI widgets
        private Banner status_banner;
        private StatusPage empty_page;
        private Button setup_token_button;
        private Box start_tunnel_container;
        private Button start_tunnel_button;
        private Gtk.Spinner tunnel_spinner;
        private Button stop_tunnel_button;
        private Button header_stop_button;
        private Box tunnel_controls;
        private MainWindow parent_window;

        // References
        private TunnelManager tunnel_manager;
        private WebhookServer server;
        private RequestStorage storage;

        public signal void show_error_dialog(string title, string message);
        public signal void copy_url_clicked();
        public signal void show_preferences_dialog();
        public signal void ui_state_changed();

        public TunnelController(Banner status_banner,
                               StatusPage empty_page,
                               Button setup_token_button,
                               Box start_tunnel_container,
                               Button start_tunnel_button,
                               Gtk.Spinner tunnel_spinner,
                               Button stop_tunnel_button,
                               Button header_stop_button,
                               Box tunnel_controls,
                               MainWindow parent_window,
                               TunnelManager tunnel_manager,
                               WebhookServer server,
                               RequestStorage storage) {
            this.status_banner = status_banner;
            this.empty_page = empty_page;
            this.setup_token_button = setup_token_button;
            this.start_tunnel_container = start_tunnel_container;
            this.start_tunnel_button = start_tunnel_button;
            this.tunnel_spinner = tunnel_spinner;
            this.stop_tunnel_button = stop_tunnel_button;
            this.header_stop_button = header_stop_button;
            this.tunnel_controls = tunnel_controls;
            this.parent_window = parent_window;
            this.tunnel_manager = tunnel_manager;
            this.server = server;
            this.storage = storage;

            this._connect_signals();
        }

        private void _connect_signals() {
            this.setup_token_button.clicked.connect(this._on_setup_token_clicked);
            this.start_tunnel_button.clicked.connect(this._on_start_tunnel_clicked);
            this.stop_tunnel_button.clicked.connect(this._on_stop_tunnel_clicked);
            this.header_stop_button.clicked.connect(this._on_stop_tunnel_clicked);
            this.status_banner.button_clicked.connect(this._on_banner_button_clicked);
            this.tunnel_manager.status_changed.connect(this._on_tunnel_status_changed);
            this.tunnel_manager.retry_progress.connect(this._on_retry_progress);
        }

        private void _on_retry_progress(int attempt, int max_attempts, int delay_ms) {
            Idle.add(() => {
                // Update status banner to show retry progress
                this.status_banner.set_title(@"Retrying tunnel start (attempt $attempt/$max_attempts)...");
                this.status_banner.set_revealed(true);
                return Source.REMOVE;
            });
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
                this.update_ui_state();

                if (!status.active && status.error != null) {
                    show_error_dialog("Tunnel Error", status.error);
                }

            } catch (Error e) {
                show_error_dialog("Error", "Failed to start tunnel: " + e.message);
            }
        }

        private void _on_stop_tunnel_clicked() {
            this.tunnel_manager.stop();
            this.server.stop();
            this.update_ui_state();
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
                copy_url_clicked();
            } else {
                // Retry tunnel start
                this._on_start_tunnel_clicked();
            }
        }

        private void _on_setup_token_clicked() {
            show_preferences_dialog();
        }

        private void _on_tunnel_status_changed(TunnelStatus status) {
            Idle.add(() => {
                this.update_ui_state();
                return Source.REMOVE;
            });
        }

        public void update_ui_state() {
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
            } else if (has_auth_token_error) {
                this.status_banner.set_title("Setup Required: " + tunnel_status.error);
                this.status_banner.set_button_label("Setup Token");
                this.status_banner.set_revealed(true);
            } else if (tunnel_status.error != null) {
                this.status_banner.set_title("Tunnel Error: " + tunnel_status.error);
                this.status_banner.set_button_label("Retry");
                this.status_banner.set_revealed(true);
            } else {
                this.status_banner.set_revealed(false);
            }

            // Update status page content based on current state
            this._update_status_page(tunnel_status, has_auth_token_error);

            ui_state_changed();
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

        public void toggle_tunnel() {
            if (this.tunnel_manager.is_active()) {
                this._on_stop_tunnel_clicked();
            } else {
                this._on_start_tunnel_clicked();
            }
        }
    }
}
