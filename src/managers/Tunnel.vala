/*
 * Ngrok tunnel manager for creating public URLs.
 */

using GLib;
using Json;

namespace Sonar {
    
    /**
     * Manages ngrok tunnels for the webhook server using subprocess and REST API.
     */
    public class TunnelManager : GLib.Object {
        private Subprocess? ngrok_process;
        private TunnelStatus _status;
        private Mutex status_lock;
        private Settings settings;
        private bool auth_token_set;
        private Cancellable? api_cancellable;
        
        public signal void status_changed(TunnelStatus status);
        
        public TunnelManager() {
            this._status = new TunnelStatus();
            this.status_lock = Mutex();
            this.ngrok_process = null;
            this.auth_token_set = false;
            this.api_cancellable = new Cancellable();
            
            // Initialize GSettings
            try {
                this.settings = new Settings(Config.APP_ID);
            } catch (Error e) {
                warning("Failed to initialize GSettings: %s", e.message);
            }
            
            // Check if ngrok is available
            if (!this._check_ngrok_installation()) {
                this._status = new TunnelStatus.with_error(
                    "Ngrok is not available. Please install ngrok to enable tunnel features."
                );
                return;
            }
            
            // Configure ngrok auth token
            var auth_token = this._load_auth_token();
            if (auth_token != null) {
                this._set_auth_token_internal(auth_token);
            } else {
                this._status = new TunnelStatus.with_error(
                    "No NGROK_AUTHTOKEN found. Set NGROK_AUTHTOKEN to use tunnel features."
                );
            }
        }
        
        private bool _check_ngrok_installation() {
            try {
                var process = new Subprocess(SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_SILENCE,
                                           "ngrok", "version");
                process.wait();
                return process.get_exit_status() == 0;
            } catch (Error e) {
                return false;
            }
        }
        
        private string? _load_auth_token() {
            // First try environment variable
            string? auth_token = Environment.get_variable("NGROK_AUTHTOKEN");
            if (auth_token != null && auth_token.length > 0) {
                return auth_token;
            }
            
            // Then try GSettings
            try {
                if (this.settings != null) {
                    auth_token = this.settings.get_string("ngrok-auth-token");
                    if (auth_token != null && auth_token.length > 0) {
                        Environment.set_variable("NGROK_AUTHTOKEN", auth_token, true);
                        return auth_token;
                    }
                }
            } catch (Error e) {
                warning("Failed to load auth token from GSettings: %s", e.message);
            }
            
            return null;
        }
        
        public bool set_auth_token(string token) {
            this.status_lock.lock();
            
            try {
                // Validate token format (basic validation)
                if (token.length < 10) {
                    this._status = new TunnelStatus.with_error("Invalid auth token: too short");
                    this.status_lock.unlock();
                    this.status_changed(this._status);
                    return false;
                }
                
                bool success = this._set_auth_token_internal(token);
                if (success) {
                    // Save to GSettings for persistence
                    if (this.settings != null) {
                        this.settings.set_string("ngrok-auth-token", token);
                    }
                    
                    // Set environment variable
                    Environment.set_variable("NGROK_AUTHTOKEN", token, true);
                    
                    // Reset status to clear any previous errors
                    this._status = new TunnelStatus();
                    info("Ngrok auth token set successfully");
                } else {
                    this._status = new TunnelStatus.with_error("Failed to set ngrok auth token");
                }
                
                this.status_lock.unlock();
                this.status_changed(this._status);
                return success;
                
            } catch (Error e) {
                this._status = new TunnelStatus.with_error(@"Failed to set ngrok auth token: $(e.message)");
                this.status_lock.unlock();
                this.status_changed(this._status);
                return false;
            }
        }
        
        private bool _set_auth_token_internal(string token) {
            try {
                // Use ngrok config command to set auth token
                var process = new Subprocess(SubprocessFlags.STDOUT_SILENCE | SubprocessFlags.STDERR_PIPE,
                                           "ngrok", "config", "add-authtoken", token);
                process.wait();
                
                if (process.get_exit_status() == 0) {
                    this.auth_token_set = true;
                    return true;
                } else {
                    return false;
                }
            } catch (Error e) {
                warning("Failed to set ngrok auth token: %s", e.message);
                return false;
            }
        }
        
        public TunnelStatus refresh_auth_token() {
            this.status_lock.lock();
            
            // Reset auth token flag first
            this.auth_token_set = false;
            
            // Try to load auth token again
            var auth_token = this._load_auth_token();
            if (auth_token != null) {
                bool success = this._set_auth_token_internal(auth_token);
                if (success) {
                    info("Ngrok auth token refreshed successfully");
                    this._status = new TunnelStatus();
                } else {
                    this._status = new TunnelStatus.with_error("Failed to refresh ngrok auth token");
                }
            } else {
                this._status = new TunnelStatus.with_error(
                    "No NGROK_AUTHTOKEN found. Set NGROK_AUTHTOKEN to use tunnel features."
                );
            }
            
            this.status_lock.unlock();
            this.status_changed(this._status);
            return this._status;
        }
        
        public async TunnelStatus start_async(int port = 8000, string protocol = "http") {
            this.status_lock.lock();
            
            if (this._status.active) {
                warning("Tunnel is already active");
                this.status_lock.unlock();
                return this._status;
            }
            
            // Validate port
            if (port < 1 || port > 65535) {
                this._status = new TunnelStatus.with_error(@"Invalid port: $(port)");
                this.status_lock.unlock();
                this.status_changed(this._status);
                return this._status;
            }
            
            // Check if auth token is set
            if (!this.auth_token_set) {
                this._status = new TunnelStatus.with_error(
                    "Cannot start tunnel without auth token"
                );
                this.status_lock.unlock();
                this.status_changed(this._status);
                return this._status;
            }
            
            try {
                info("Starting ngrok tunnel on port %d...", port);
                
                // Start ngrok process with proper flags
                this.ngrok_process = new Subprocess(
                    SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE,
                    "ngrok", protocol, port.to_string(), "--log=stdout"
                );
                
                this.status_lock.unlock();
                
                // Wait for ngrok to be ready by checking API availability
                var public_url = yield this._wait_for_ngrok_ready_async();
                
                // If we still don't have a URL, try the API directly one more time
                if (public_url == null) {
                    public_url = yield this._get_tunnel_url_async();
                }
                
                this.status_lock.lock();
                
                if (public_url != null) {
                    this._status = new TunnelStatus.with_url(public_url);
                    info("Ngrok tunnel started: %s", public_url);
                } else {
                    this._status = new TunnelStatus.with_error("Failed to get tunnel URL from ngrok API");
                    this._stop_process();
                }
                
                this.status_lock.unlock();
                this.status_changed(this._status);
                return this._status;
                
            } catch (Error e) {
                this.status_lock.lock();
                critical("Failed to start ngrok tunnel: %s", e.message);
                this._status = new TunnelStatus.with_error(@"Failed to start tunnel: $(e.message)");
                this._stop_process();
                this.status_lock.unlock();
                this.status_changed(this._status);
                return this._status;
            }
        }
        
        public void stop() {
            this.status_lock.lock();
            
            if (!this._status.active && this.ngrok_process == null) {
                info("Tunnel is not active");
                this.status_lock.unlock();
                return;
            }
            
            try {
                info("Stopping ngrok tunnel...");
                this._stop_process();
                
                this._status = new TunnelStatus();
                info("Ngrok tunnel stopped successfully");
                
            } catch (Error e) {
                warning("Error stopping tunnel: %s", e.message);
                this._status = new TunnelStatus.with_error(@"Error stopping tunnel: $(e.message)");
            }
            
            this.status_lock.unlock();
            this.status_changed(this._status);
        }
        
        private void _stop_process() {
            if (this.ngrok_process != null) {
                try {
                    this.ngrok_process.force_exit();
                } catch (Error e) {
                    warning("Error terminating ngrok process: %s", e.message);
                }
                this.ngrok_process = null;
            }
        }
        
        private async string? _get_tunnel_url_async() {
            try {
                var session = new Soup.Session();
                var message = new Soup.Message("GET", "http://127.0.0.1:4040/api/tunnels");
                
                var response = yield session.send_async(message, Priority.DEFAULT, this.api_cancellable);
                
                if (message.status_code != 200) {
                    warning("Ngrok API returned status code: %u", message.status_code);
                    return null;
                }
                
                // Read the entire response body
                var input_stream = response as InputStream;
                var data_stream = new DataInputStream(input_stream);
                
                // Read all data from the stream
                var response_data = new StringBuilder();
                string? line;
                while ((line = yield data_stream.read_line_async(Priority.DEFAULT, this.api_cancellable)) != null) {
                    response_data.append(line);
                }
                
                var json_response = response_data.str;
                if (json_response.length == 0) {
                    warning("Empty response from ngrok API");
                    return null;
                }
                
                // Parse JSON response
                var parser = new Json.Parser();
                parser.load_from_data(json_response);
                
                var root = parser.get_root().get_object();
                var tunnels = root.get_array_member("tunnels");
                
                if (tunnels.get_length() > 0) {
                    var tunnel = tunnels.get_object_element(0);
                    var public_url = tunnel.get_string_member("public_url");
                    info("Found ngrok tunnel URL: %s", public_url);
                    return public_url;
                }
                
                info("No tunnels found in ngrok API response");
                return null;
                
            } catch (Error e) {
                warning("Failed to get tunnel URL from API: %s", e.message);
                return null;
            }
        }
        
        private async void _wait_async(int milliseconds) {
            Timeout.add(milliseconds, () => {
                this._wait_async.callback();
                return Source.REMOVE;
            });
            yield;
        }
        
        private async string? _wait_for_ngrok_ready_async() {
            bool process_checked = false;
            
            // Wait up to 10 seconds for ngrok to be ready
            for (int i = 0; i < 20; i++) {
                yield this._wait_async(500); // Wait 500ms between checks
                
                // Check if the process has exited (only once to avoid assertion errors)
                if (this.ngrok_process != null && !process_checked) {
                    try {
                        if (this.ngrok_process.get_if_exited()) {
                            int exit_code = this.ngrok_process.get_exit_status();
                            warning("Ngrok process exited with code: %d", exit_code);
                            process_checked = true;
                            return null;
                        }
                    } catch (Error e) {
                        // Process might still be running, continue
                    }
                    process_checked = true;
                }
                
                // Try to get tunnel URL from API
                var url = yield this._get_tunnel_url_async();
                if (url != null) {
                    info("Ngrok API ready after %d checks", i + 1);
                    return url;
                }
            }
            
            warning("Ngrok API not ready after 10 seconds");
            return null;
        }
        
        public TunnelStatus get_status() {
            this.status_lock.lock();
            var status_copy = this._status;
            this.status_lock.unlock();
            return status_copy;
        }
        
        public string? get_public_url() {
            this.status_lock.lock();
            string? url = this._status.active ? this._status.public_url : null;
            this.status_lock.unlock();
            return url;
        }
        
        public bool is_active() {
            this.status_lock.lock();
            bool active = this._status.active;
            this.status_lock.unlock();
            return active;
        }
        
        public void kill_all() {
            try {
                info("Killing all ngrok processes...");
                var process = new Subprocess(SubprocessFlags.STDOUT_SILENCE | SubprocessFlags.STDERR_SILENCE,
                                           "pkill", "-f", "ngrok");
                process.wait();
                
                this.status_lock.lock();
                this._status = new TunnelStatus();
                this.ngrok_process = null;
                this.status_lock.unlock();
                
                info("All ngrok processes killed");
                this.status_changed(this._status);
                
            } catch (Error e) {
                warning("Error killing ngrok processes: %s", e.message);
            }
        }
        
        public static string? get_version() {
            try {
                var process = new Subprocess(SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_SILENCE,
                                           "ngrok", "version");
                
                var stdout_pipe = process.get_stdout_pipe();
                var data_stream = new DataInputStream(stdout_pipe);
                var version_output = data_stream.read_line();
                
                process.wait();
                
                if (process.get_exit_status() == 0 && version_output != null) {
                    return version_output.strip();
                }
                
            } catch (Error e) {
                warning("Error getting ngrok version: %s", e.message);
            }
            
            return null;
        }
        
        ~TunnelManager() {
            this.api_cancellable.cancel();
            if (this._status.active) {
                this.stop();
            }
        }
    }
}