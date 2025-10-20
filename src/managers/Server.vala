/*
 * libsoup HTTP server for receiving webhook requests.
 */

using Soup;
using GLib;

namespace Sonar {
    
    /**
     * HTTP server for receiving webhook requests using libsoup.
     */
    public class WebhookServer : Object {
        private Soup.Server server;
        private RequestStorage storage;
        private RateLimiter rate_limiter;
        private int port;
        private string host;
        private bool is_running;
        private uint server_source_id;

        // Forwarding settings
        private bool forwarding_enabled = false;
        private Gee.ArrayList<string> forward_urls;
        private bool preserve_method = true;
        private bool forward_headers = true;

        public signal void request_received(WebhookRequest request);

        public WebhookServer(RequestStorage request_storage) {
            this.storage = request_storage;
            this.rate_limiter = new RateLimiter(100, 200, 1000); // 100 req/s, burst 200, track 1000 sources
            this.port = 8000;
            this.host = "127.0.0.1";
            this.is_running = false;
            this.server_source_id = 0;
            this.forward_urls = new Gee.ArrayList<string>();

            this.server = new Soup.Server("server-header", @"Sonar-Vala/$(Config.VERSION)");
            this._setup_routes();
        }
        
        private void _setup_routes() {
            // Health check endpoint
            this.server.add_handler("/health", (server, msg, path, query) => {
                var response_data = """{"status": "healthy"}""";
                msg.set_status(200, null);
                msg.set_response("application/json", Soup.MemoryUse.COPY, response_data.data);
            });
            
            // Root endpoint
            this.server.add_handler("/", (server, msg, path, query) => {
                // Skip if not exactly root path to avoid conflicts
                if (path != "/") {
                    return;
                }
                
                var response_data = """{
    "message": "Sonar Webhook Server (Vala)",
    "version": "%s",
    "info": "Accepts requests on any endpoint path",
    "supported_methods": ["GET", "POST", "PUT", "DELETE", "PATCH", "HEAD", "OPTIONS"],
    "examples": ["/webhook", "/api/events", "/stripe-webhook", "/github-webhook"]
}""".printf(Config.VERSION);
                msg.set_status(200, null);
                msg.set_response("application/json", Soup.MemoryUse.COPY, response_data.data);
            });
            
            // Catch-all handler for webhook endpoints
            this.server.add_handler(null, (server, msg, path, query) => {
                this._handle_webhook_request(msg, path, query);
            });
        }
        
        private void _handle_webhook_request(Soup.ServerMessage msg, string path, HashTable<string, string>? query) {
            try {
                // Skip root path (handled by specific handler)
                if (path == "/" || path == "/health") {
                    return;
                }

                // Rate limiting check (use path as identifier for per-endpoint limiting)
                if (!this.rate_limiter.check_rate_limit(path)) {
                    var error_response = """{
    "status": "error",
    "message": "Rate limit exceeded",
    "retry_after": 1
}""";
                    msg.set_status(429, null);
                    msg.set_response("application/json", Soup.MemoryUse.COPY, error_response.data);
                    return;
                }

                var method = msg.get_method();
                var headers = new HashTable<string, string>(str_hash, str_equal);
                var query_params = new HashTable<string, string>(str_hash, str_equal);
                
                // Extract headers
                msg.get_request_headers().foreach((name, value) => {
                    headers.set(name, value);
                });
                
                // Extract query parameters
                if (query != null) {
                    query.foreach((key, val) => {
                        query_params.set(key, val);
                    });
                }
                
                // Get request body
                var body_bytes = msg.get_request_body();
                string body = "";
                if (body_bytes != null && body_bytes.length > 0) {
                    body = (string) body_bytes.data;
                }
                
                // Get content type and length directly from LibSoup headers
                var request_headers = msg.get_request_headers();
                string? content_type = request_headers.get_content_type(null);
                int64 content_length = request_headers.get_content_length();
                
                
                // Validate and sanitize input data
                bool is_valid;
                string[] warnings;
                HashTable<string, Value?> sanitized_data;
                
                this._sanitize_webhook_data(method, path, headers, body, 
                                          query_params, content_type, content_length,
                                          out is_valid, out sanitized_data, out warnings);
                
                // Log warnings if any
                if (warnings.length > 0) {
                    warning("Webhook validation warnings: %s", string.joinv(", ", warnings));
                }
                
                // Reject invalid requests
                if (!is_valid) {
                    var error_response = """{
    "status": "error",
    "message": "Invalid request data",
    "errors": ["%s"]
}""".printf(string.joinv("\", \"", warnings));
                    
                    msg.set_status(400, null);
                    msg.set_response("application/json", Soup.MemoryUse.COPY, error_response.data);
                    return;
                }
                
                // Extract sanitized data properly
                var clean_headers = new HashTable<string, string>(str_hash, str_equal);
                var clean_query_params = new HashTable<string, string>(str_hash, str_equal);
                
                // Get headers safely
                var headers_value = sanitized_data.lookup("headers");
                if (headers_value != null) {
                    var headers_variant = headers_value.get_variant();
                    if (headers_variant.get_type_string() == "a{ss}") {
                        var headers_iter = headers_variant.iterator();
                        string key, value;
                        while (headers_iter.next("{ss}", out key, out value)) {
                            clean_headers.set(key, value);
                        }
                    }
                }
                
                // Get query params safely 
                var query_value = sanitized_data.lookup("query_params");
                if (query_value != null) {
                    var query_variant = query_value.get_variant();
                    if (query_variant.get_type_string() == "a{ss}") {
                        var query_iter = query_variant.iterator();
                        string key, value;
                        while (query_iter.next("{ss}", out key, out value)) {
                            clean_query_params.set(key, value);
                        }
                    }
                }
                
                // Create webhook request with properly extracted data
                var webhook_request = new WebhookRequest.full(
                    sanitized_data.lookup("method").get_string(),
                    sanitized_data.lookup("path").get_string(),
                    clean_headers,
                    sanitized_data.lookup("body").get_string(),
                    clean_query_params,
                    sanitized_data.lookup("content_type") != null ? 
                        sanitized_data.lookup("content_type").get_string() : null,
                    sanitized_data.lookup("content_length") != null ? 
                        sanitized_data.lookup("content_length").get_int64() : -1
                );
                
                // Store request
                this.storage.add_request(webhook_request);

                // Forward webhook if enabled
                if (this.forwarding_enabled && this.forward_urls.size > 0) {
                    this._forward_webhook_async.begin(webhook_request);
                }

                // Emit signal
                this.request_received(webhook_request);

                info("Received %s request to %s", method, webhook_request.path);
                
                // Return success response
                var success_response = """{
    "status": "received",
    "message": "Webhook received successfully",
    "request_id": "%s",
    "timestamp": "%s"
}""".printf(webhook_request.id, webhook_request.timestamp.format_iso8601());
                
                if (warnings.length > 0) {
                    success_response = """{
    "status": "received",
    "message": "Webhook received successfully",
    "request_id": "%s",
    "timestamp": "%s",
    "warnings": ["%s"]
}""".printf(webhook_request.id, webhook_request.timestamp.format_iso8601(),
            string.joinv("\", \"", warnings));
                }
                
                msg.set_status(200, null);
                msg.set_response("application/json", Soup.MemoryUse.COPY, success_response.data);
                
            } catch (Error e) {
                critical("Error processing webhook: %s", e.message);
                var error_response = """{
    "status": "error",
    "message": "Internal server error while processing webhook"
}""";
                
                msg.set_status(500, null);
                msg.set_response("application/json", Soup.MemoryUse.COPY, error_response.data);
            }
        }
        
        private void _sanitize_webhook_data(string method, string path,
                                          HashTable<string, string> headers,
                                          string body,
                                          HashTable<string, string> query_params,
                                          string? content_type,
                                          int64 content_length,
                                          out bool is_valid,
                                          out HashTable<string, Value?> sanitized_data,
                                          out string[] warnings) {

            is_valid = true;
            var warnings_list = new Gee.ArrayList<string>();
            sanitized_data = new HashTable<string, Value?>(str_hash, str_equal);

            // Initialize ValidationUtils
            ValidationUtils.initialize();

            // Validate and sanitize method
            string clean_method;
            string? method_error;
            bool method_valid = ValidationUtils.validate_method(method, out clean_method, out method_error);
            if (!method_valid) {
                if (method_error != null) {
                    warnings_list.add(method_error);
                }
                if (clean_method.length == 0) {
                    is_valid = false;
                }
            }
            sanitized_data.set("method", clean_method);

            // Validate and sanitize path
            string clean_path;
            string? path_error;
            bool path_valid = ValidationUtils.validate_path(path, out clean_path, out path_error);
            if (!path_valid) {
                if (path_error != null) {
                    warnings_list.add(path_error);
                    // Path traversal attempts are critical - reject the request
                    if (path_error.contains("path traversal") || path_error.contains("dangerous characters")) {
                        is_valid = false;
                    }
                }
            }
            sanitized_data.set("path", clean_path);

            // Validate and sanitize headers
            HashTable<string, string> clean_headers;
            string[] header_warnings;
            ValidationUtils.validate_headers(headers, out clean_headers, out header_warnings);
            foreach (var warning in header_warnings) {
                warnings_list.add(warning);
            }
            // Convert HashTable to Variant
            var headers_variant_builder = new VariantBuilder(new VariantType("a{ss}"));
            clean_headers.foreach((key, val) => {
                headers_variant_builder.add("{ss}", key, val);
            });
            sanitized_data.set("headers", headers_variant_builder.end());

            // Validate and sanitize body
            string clean_body;
            string? body_warning;
            int64 max_body_size = 10485760; // 10MB default
            ValidationUtils.validate_body_size(body, max_body_size, out clean_body, out body_warning);
            if (body_warning != null) {
                warnings_list.add(body_warning);
            }
            sanitized_data.set("body", clean_body);

            // Validate and sanitize query params
            HashTable<string, string> clean_query_params;
            string[] query_warnings;
            ValidationUtils.validate_query_params(query_params, out clean_query_params, out query_warnings);
            foreach (var warning in query_warnings) {
                warnings_list.add(warning);
            }
            // Convert HashTable to Variant
            var query_variant_builder = new VariantBuilder(new VariantType("a{ss}"));
            clean_query_params.foreach((key, val) => {
                query_variant_builder.add("{ss}", key, val);
            });
            sanitized_data.set("query_params", query_variant_builder.end());

            // Validate and sanitize content type
            string? clean_content_type;
            bool content_type_valid = ValidationUtils.validate_content_type(content_type, out clean_content_type);
            if (!content_type_valid && content_type != null) {
                warnings_list.add("Invalid or too long content type");
            }
            if (clean_content_type != null) {
                sanitized_data.set("content_type", clean_content_type);
            }

            // Validate content length
            if (content_length >= 0) {
                var security_mgr = SecurityManager.get_default();
                if (!security_mgr.validate_body_size(content_length, max_body_size)) {
                    warnings_list.add(@"Content-Length header indicates size exceeds limit: $(content_length) bytes");
                    // Don't reject, as we already truncated the body
                }
                sanitized_data.set("content_length", content_length);
            }

            // Convert warnings list to array
            warnings = warnings_list.to_array();
        }
        
        public void start(int port = 8000, string host = "127.0.0.1") throws Error {
            if (this.is_running) {
                warning("Server is already running");
                return;
            }
            
            this.port = port;
            this.host = host;
            
            var address = new InetSocketAddress.from_string(host, (uint16) port);
            this.server.listen(address, 0);
            
            this.is_running = true;
            info("Webhook server starting on %s:%d", this.host, this.port);
        }
        
        public void stop() {
            if (!this.is_running) {
                return;
            }
            
            info("Stopping webhook server...");
            this.server.disconnect();
            this.is_running = false;
            info("Webhook server stopped");
        }
        
        public string get_url() {
            return @"http://$(this.host):$(this.port)";
        }

        public bool get_is_running() {
            return this.is_running;
        }

        // Forwarding API
        public void set_forwarding_enabled(bool enabled) {
            this.forwarding_enabled = enabled;
            debug("Forwarding %s", enabled ? "enabled" : "disabled");
        }

        public bool is_forwarding_enabled() {
            return this.forwarding_enabled;
        }

        public void set_forward_urls(Gee.ArrayList<string> urls) {
            // Validate all URLs before setting
            var validated_urls = new Gee.ArrayList<string>();
            foreach (var url in urls) {
                string? error;
                // Allow private IPs by default for development, but log warning
                bool is_valid = ValidationUtils.validate_forward_url(url, true, out error);
                if (is_valid) {
                    validated_urls.add(url);
                } else {
                    warning("Skipping invalid forward URL '%s': %s", url, error ?? "Unknown error");
                }
            }

            this.forward_urls = validated_urls;
            debug("Set %d forward URLs (%d validated)", urls.size, validated_urls.size);
        }

        public Gee.ArrayList<string> get_forward_urls() {
            return this.forward_urls;
        }

        public void set_preserve_method(bool preserve) {
            this.preserve_method = preserve;
        }

        public bool get_preserve_method() {
            return this.preserve_method;
        }

        public void set_forward_headers(bool forward) {
            this.forward_headers = forward;
        }

        public bool get_forward_headers() {
            return this.forward_headers;
        }

        private async void _forward_webhook_async(WebhookRequest request) {
            var session = new Soup.Session();

            foreach (var url in this.forward_urls) {
                try {
                    var method = this.preserve_method ? request.method : "POST";
                    var message = new Soup.Message(method, url);

                    // Add headers if enabled
                    if (this.forward_headers) {
                        request.headers.foreach((key, value) => {
                            message.request_headers.append(key, value);
                        });
                    }

                    // Add body
                    if (request.body.length > 0) {
                        message.set_request_body_from_bytes(
                            request.content_type ?? "application/octet-stream",
                            new Bytes(request.body.data)
                        );
                    }

                    // Send async
                    yield session.send_async(message, Priority.DEFAULT, null);

                    info("Forwarded %s request to %s (status: %u)", method, url, message.status_code);
                } catch (Error e) {
                    warning("Failed to forward to %s: %s", url, e.message);
                }
            }
        }

        // Rate Limiter API
        public void set_rate_limiting_enabled(bool enabled) {
            this.rate_limiter.set_enabled(enabled);
        }

        public bool is_rate_limiting_enabled() {
            return this.rate_limiter.is_enabled();
        }

        public void configure_rate_limit(int requests_per_second, int burst_size) {
            this.rate_limiter.configure(requests_per_second, burst_size);
        }

        public RateLimiter get_rate_limiter() {
            return this.rate_limiter;
        }
    }
}