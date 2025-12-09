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
                
                var response_data = """<!DOCTYPE html>
<html>
<head>
    <title>Sonar is Ready</title>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        :root {
            --bg-color: #fafafa;
            --text-color: #2e3436;
            --card-bg: #ffffff;
            --accent: #1f7bdc;
        }
        @media (prefers-color-scheme: dark) {
            :root {
                --bg-color: #242424;
                --text-color: #eeeeec;
                --card-bg: #303030;
                --accent: #3584e4;
            }
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            background-color: var(--bg-color);
            color: var(--text-color);
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            height: 100vh;
            margin: 0;
            line-height: 1.6;
        }
        .card {
            background: var(--card-bg);
            padding: 2rem 3rem;
            border-radius: 12px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            text-align: center;
            max-width: 500px;
            width: 90%;
        }
        .logo {
            width: 128px;
            height: 128px;
            margin-bottom: 1.5rem;
        }
        h1 {
            margin: 0 0 0.5rem 0;
            font-size: 1.5rem;
        }
        p {
            margin: 0;
            opacity: 0.8;
        }
        .version {
            margin-top: 1.5rem;
            font-size: 0.85rem;
            opacity: 0.5;
        }
    </style>
</head>
<body>
    <div class="card">
        <div class="logo">
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 267 267">
              <path d="M47.127,214.218c-20.167,-21.287 -32.544,-50.028 -32.544,-81.638c0,-65.539 53.21,-118.75 118.75,-118.75c65.54,0 118.75,53.211 118.75,118.75c0,65.54 -53.21,118.75 -118.75,118.75c-23.816,0 -46.004,-7.026 -64.603,-19.117c-0.481,-0.313 -0.812,-0.811 -0.914,-1.376c-0.103,-0.565 0.033,-1.147 0.374,-1.609c1.443,-1.952 2.296,-4.365 2.296,-6.976c-0,-6.488 -5.268,-11.755 -11.756,-11.755c-3.379,-0 -6.426,1.429 -8.571,3.714c-0.393,0.418 -0.941,0.656 -1.515,0.658c-0.573,0.001 -1.122,-0.234 -1.517,-0.651Z" style="fill:#17353b"></path>
              <path d="M110.441,52.877c7.273,-2.088 14.953,-3.207 22.892,-3.207c31.87,0 59.564,18.02 73.439,44.418c0.262,0.498 0.311,1.08 0.137,1.614c-0.174,0.535 -0.556,0.976 -1.061,1.225l-69.219,34.07l37.561,71.405c0.528,1.004 0.157,2.245 -0.836,2.793c-11.868,6.56 -25.512,10.296 -40.021,10.296c-45.759,-0 -82.91,-37.151 -82.91,-82.911c0,-27.486 13.403,-51.866 34.026,-66.954c0.471,-0.345 1.065,-0.476 1.638,-0.362c0.572,0.114 1.071,0.464 1.373,0.963c2.119,3.493 5.958,5.829 10.338,5.829c6.668,0 12.081,-5.413 12.081,-12.08c-0,-1.532 -0.285,-2.997 -0.806,-4.346c-0.211,-0.546 -0.183,-1.154 0.078,-1.678c0.26,-0.524 0.728,-0.914 1.29,-1.075Zm3.192,3.448c0.27,1.174 0.413,2.396 0.413,3.651c-0,8.967 -7.281,16.247 -16.248,16.247c-5.067,0 -9.596,-2.324 -12.577,-5.965c-18.627,14.408 -30.631,36.974 -30.631,62.322c-0,43.46 35.284,78.744 78.743,78.744c13.051,-0 25.365,-3.182 36.207,-8.812l-37.595,-71.469c-0.262,-0.498 -0.311,-1.08 -0.137,-1.615c0.174,-0.534 0.556,-0.976 1.061,-1.224c-0,-0 69.193,-34.058 69.194,-34.058c-13.486,-24.044 -39.223,-40.309 -68.73,-40.309c-6.801,0 -13.403,0.864 -19.7,2.488Z" style="fill:#fcbf0e"></path>
              <path d="M100.893,160.785c-6.572,-7.552 -10.553,-17.417 -10.553,-28.205c-0,-23.728 19.264,-42.993 42.993,-42.993c16.147,-0 30.227,8.919 37.575,22.096c0.278,0.499 0.34,1.09 0.17,1.635c-0.17,0.545 -0.557,0.997 -1.069,1.249c-0,0 -33.38,16.43 -33.38,16.43l18.97,36.063c0.521,0.99 0.167,2.214 -0.802,2.774c-6.318,3.65 -13.648,5.74 -21.464,5.74c-2.988,0 -5.906,-0.306 -8.723,-0.887c-0.6,-0.124 -1.114,-0.505 -1.408,-1.043c-0.293,-0.537 -0.335,-1.176 -0.115,-1.747c0.481,-1.246 0.744,-2.599 0.744,-4.014c-0,-6.165 -5.006,-11.17 -11.171,-11.17c-3.454,-0 -6.543,1.571 -8.593,4.036c-0.391,0.47 -0.968,0.745 -1.579,0.751c-0.61,0.007 -1.193,-0.254 -1.595,-0.715Zm1.712,-4.48c2.693,-2.341 6.21,-3.759 10.055,-3.759c8.465,-0 15.337,6.872 15.337,15.337c0,1.067 -0.109,2.109 -0.317,3.115c1.845,0.27 3.733,0.41 5.653,0.41c6.343,-0 12.333,-1.524 17.622,-4.226l-19.01,-36.139c-0.262,-0.498 -0.311,-1.08 -0.137,-1.615c0.174,-0.534 0.556,-0.976 1.061,-1.224c-0,-0 33.276,-16.379 33.276,-16.379c-6.887,-10.858 -19.013,-18.072 -32.812,-18.072c-21.429,0 -38.827,17.398 -38.827,38.827c0,8.932 3.022,17.162 8.099,23.725Z" style="fill:#fcbf0e"></path>
              <path d="M187.191,236.067l-55.246,-105.024c-0.262,-0.498 -0.311,-1.08 -0.137,-1.615c0.174,-0.534 0.556,-0.976 1.061,-1.224l103.305,-50.848c1.019,-0.502 2.251,-0.095 2.772,0.914c8.395,16.28 13.137,34.746 13.137,54.31c0,45.013 -25.097,84.21 -62.051,104.347c-0.49,0.267 -1.066,0.326 -1.6,0.164c-0.534,-0.161 -0.981,-0.53 -1.241,-1.024Z" style="fill:#1f7bdc"></path>
              <path d="M58.73,206.33c8.788,-0 15.922,7.134 15.922,15.922c0,8.788 -7.134,15.922 -15.922,15.922c-8.787,0 -15.922,-7.134 -15.922,-15.922c-0,-8.788 7.135,-15.922 15.922,-15.922Zm39.068,-162.602c8.967,0 16.248,7.28 16.248,16.248c-0,8.967 -7.281,16.247 -16.248,16.247c-8.967,0 -16.247,-7.28 -16.247,-16.247c-0,-8.968 7.28,-16.248 16.247,-16.248Zm14.862,108.818c8.465,-0 15.337,6.872 15.337,15.337c0,8.465 -6.872,15.338 -15.337,15.338c-8.465,-0 -15.337,-6.873 -15.337,-15.338c-0,-8.465 6.872,-15.337 15.337,-15.337Z" style="fill:#fcbf0e"></path>
              <path d="M244.472,174.47c-10.1,26.753 -29.589,48.915 -54.44,62.457c-0.49,0.267 -1.066,0.326 -1.6,0.164c-0.534,-0.161 -0.981,-0.53 -1.241,-1.024l-55.246,-105.024c-0.262,-0.498 -0.311,-1.08 -0.137,-1.615c0.036,-0.111 0.081,-0.218 0.135,-0.32l112.529,45.362Z" style="fill:#1f4fdc"></path>
            </svg>
        </div>
        <h1>Sonar is ready and listening</h1>
        <p>Your webhook inspector is active.</p>
        <div class="version">Version %s</div>
    </div>
</body>
</html>""";
                response_data = response_data.replace("%s", Config.VERSION);
                msg.set_status(200, null);
                msg.set_response("text/html", Soup.MemoryUse.COPY, response_data.data);
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