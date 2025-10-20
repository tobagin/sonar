/*
 * Validation utilities for input sanitization and security checks.
 */

using GLib;

namespace Sonar {

    /**
     * Utility class for input validation and sanitization.
     */
    public class ValidationUtils : Object {
        private static SecurityManager? security_manager = null;

        /**
         * Initialize validation utils with SecurityManager instance.
         */
        public static void initialize() {
            if (security_manager == null) {
                security_manager = SecurityManager.get_default();
            }
        }

        /**
         * Validate and sanitize an HTTP method.
         *
         * @param method The HTTP method to validate
         * @param out_method Output parameter for the sanitized method
         * @param out_error Output parameter for error message if invalid
         * @return true if valid, false otherwise
         */
        public static bool validate_method(string method, out string out_method, out string? out_error) {
            out_error = null;
            string clean = method.up().strip();

            if (clean.length == 0) {
                out_error = "Empty HTTP method";
                out_method = "";
                return false;
            }

            if (clean.length > 10) {
                out_error = "HTTP method too long";
                out_method = clean.substring(0, 10);
                return false;
            }

            // Whitelist of allowed methods
            string[] allowed_methods = {
                "GET", "POST", "PUT", "DELETE", "PATCH",
                "HEAD", "OPTIONS", "TRACE", "CONNECT"
            };

            bool is_allowed = false;
            foreach (var allowed in allowed_methods) {
                if (clean == allowed) {
                    is_allowed = true;
                    break;
                }
            }

            if (!is_allowed) {
                out_error = @"Unknown HTTP method: $clean";
                out_method = clean;
                return false;
            }

            out_method = clean;
            return true;
        }

        /**
         * Validate and sanitize a request path.
         *
         * @param path The path to validate
         * @param out_path Output parameter for the sanitized path
         * @param out_error Output parameter for error message if invalid
         * @return true if valid, false otherwise
         */
        public static bool validate_path(string path, out string out_path, out string? out_error) {
            initialize();
            out_error = null;
            string clean = path.strip();

            info("validate_path called with: '%s' (cleaned: '%s')", path, clean);
            info("security_manager is null: %s", (security_manager == null).to_string());

            if (clean.length == 0) {
                out_path = "/";
                return true;
            }

            if (clean.length > 2048) {
                out_error = "Path exceeds maximum length (2048 characters)";
                out_path = clean.substring(0, 2048);
                return false;
            }

            // Use SecurityManager path validation
            if (security_manager != null) {
                bool result = security_manager.validate_path(clean);
                info("SecurityManager.validate_path('%s') returned: %s", clean, result.to_string());
                if (!result) {
                    warning("Path validation failed for: %s", clean);
                    out_error = "Path contains invalid or dangerous characters (path traversal attempt)";
                    out_path = "/";
                    return false;
                }
            }

            // Ensure path starts with /
            if (!clean.has_prefix("/")) {
                clean = "/" + clean;
            }

            // Check for encoded null bytes and control characters
            if (clean.contains("%00") || clean.contains("%0a") || clean.contains("%0d")) {
                out_error = "Path contains encoded null bytes or control characters";
                out_path = "/";
                return false;
            }

            out_path = clean;
            return true;
        }

        /**
         * Validate and sanitize HTTP headers.
         *
         * @param headers Input headers
         * @param out_headers Output parameter for sanitized headers
         * @param out_warnings Output parameter for warnings
         */
        public static void validate_headers(
            HashTable<string, string> headers,
            out HashTable<string, string> out_headers,
            out string[] out_warnings
        ) {
            initialize();
            var clean_headers = new HashTable<string, string>(str_hash, str_equal);
            var warnings = new Gee.ArrayList<string>();

            headers.foreach((key, value) => {
                string clean_key = key.strip().down();
                string clean_value = value;

                // Validate key length
                if (clean_key.length == 0) {
                    warnings.add("Empty header name skipped");
                    return;
                }

                if (clean_key.length > 128) {
                    warnings.add(@"Header key '$clean_key' too long, skipped");
                    return;
                }

                // Validate value length
                if (clean_value.length > 8192) {
                    warnings.add(@"Header '$clean_key' value too long, truncated");
                    clean_value = clean_value.substring(0, 8192);
                }

                // Sanitize the value to remove control characters
                if (security_manager != null) {
                    clean_value = security_manager.sanitize_string(clean_value, 8192);
                }

                clean_headers.set(clean_key, clean_value);
            });

            out_headers = clean_headers;
            out_warnings = warnings.to_array();
        }

        /**
         * Validate request body size.
         *
         * @param body The request body
         * @param max_size Maximum allowed size in bytes
         * @param out_body Output parameter for the body (potentially truncated)
         * @param out_warning Output parameter for warning if truncated
         * @return true if size is acceptable, false if truncated
         */
        public static bool validate_body_size(
            string body,
            int64 max_size,
            out string out_body,
            out string? out_warning
        ) {
            initialize();
            out_warning = null;

            if (body.length <= max_size) {
                out_body = body;
                return true;
            }

            out_body = body.substring(0, (long) max_size);
            out_warning = @"Request body too large ($(body.length) bytes), truncated to $(max_size) bytes";
            return false;
        }

        /**
         * Validate and sanitize query parameters.
         *
         * @param query_params Input query parameters
         * @param out_params Output parameter for sanitized parameters
         * @param out_warnings Output parameter for warnings
         */
        public static void validate_query_params(
            HashTable<string, string> query_params,
            out HashTable<string, string> out_params,
            out string[] out_warnings
        ) {
            initialize();
            var clean_params = new HashTable<string, string>(str_hash, str_equal);
            var warnings = new Gee.ArrayList<string>();

            query_params.foreach((key, value) => {
                string clean_key = key.strip();
                string clean_value = value;

                // Validate key
                if (clean_key.length == 0) {
                    warnings.add("Empty query parameter key skipped");
                    return;
                }

                if (clean_key.length > 128) {
                    warnings.add(@"Query parameter key '$clean_key' too long, skipped");
                    return;
                }

                // Validate value
                if (clean_value.length > 2048) {
                    warnings.add(@"Query parameter '$clean_key' value too long, truncated");
                    clean_value = clean_value.substring(0, 2048);
                }

                // Sanitize strings
                if (security_manager != null) {
                    clean_key = security_manager.sanitize_string(clean_key, 128);
                    clean_value = security_manager.sanitize_string(clean_value, 2048);
                }

                clean_params.set(clean_key, clean_value);
            });

            out_params = clean_params;
            out_warnings = warnings.to_array();
        }

        /**
         * Validate content type string.
         *
         * @param content_type The content type to validate
         * @param out_content_type Output parameter for sanitized content type
         * @return true if valid, false if truncated or invalid
         */
        public static bool validate_content_type(string? content_type, out string? out_content_type) {
            if (content_type == null || content_type.length == 0) {
                out_content_type = null;
                return true;
            }

            string clean = content_type.strip();

            if (clean.length > 256) {
                out_content_type = clean.substring(0, 256);
                return false;
            }

            // Basic validation: should contain /
            if (!clean.contains("/")) {
                out_content_type = null;
                return false;
            }

            out_content_type = clean;
            return true;
        }

        /**
         * Validate a forward URL for SSRF prevention.
         *
         * @param url The URL to validate
         * @param allow_private Whether to allow private IPs (for development)
         * @param out_error Output parameter for error message if invalid
         * @return true if URL is safe, false otherwise
         */
        public static bool validate_forward_url(string url, bool allow_private, out string? out_error) {
            initialize();
            out_error = null;

            if (security_manager == null) {
                out_error = "Security manager not initialized";
                return false;
            }

            // Use SecurityManager's URL validation
            string error_msg;
            bool is_valid = security_manager.validate_url(url, out error_msg);

            if (!is_valid) {
                if (allow_private && error_msg.contains("Private or local IP")) {
                    // Allow if explicitly enabled
                    return true;
                }
                out_error = error_msg;
                return false;
            }

            return true;
        }

        /**
         * Check if a string contains only safe, printable characters.
         *
         * @param input The string to check
         * @return true if safe, false if contains dangerous characters
         */
        public static bool is_safe_string(string input) {
            for (int i = 0; i < input.length; i++) {
                unichar c = input.get_char(i);

                // Allow common whitespace
                if (c == ' ' || c == '\t' || c == '\n' || c == '\r') {
                    continue;
                }

                // Allow printable ASCII and UTF-8
                if ((c >= 0x20 && c <= 0x7E) || c >= 0x80) {
                    continue;
                }

                // Reject control characters
                return false;
            }

            return true;
        }
    }
}
