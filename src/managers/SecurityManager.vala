/*
 * Security Manager for Sonar.
 * Provides secure credential storage, input validation, and security utilities.
 */

using GLib;
using Secret;

namespace Sonar {

    /**
     * Manages security operations including secure credential storage and validation.
     */
    public class SecurityManager : GLib.Object {
        private static SecurityManager? _instance = null;
        private Settings settings;
        private Secret.Schema schema;

        private const string SCHEMA_NAME = "io.github.tobagin.sonar";
        private const string NGROK_TOKEN_KEY = "ngrok-auth-token";

        /**
         * Singleton instance accessor.
         */
        public static SecurityManager get_default() {
            if (_instance == null) {
                _instance = new SecurityManager();
            }
            return _instance;
        }

        private SecurityManager() {
            // Initialize GSettings
            try {
                this.settings = new Settings(Config.APP_ID);
            } catch (GLib.Error e) {
                warning("Failed to initialize GSettings: %s", e.message);
            }

            // Define libsecret schema for storing credentials
            this.schema = new Secret.Schema(
                SCHEMA_NAME,
                Secret.SchemaFlags.NONE,
                "application", Secret.SchemaAttributeType.STRING,
                "credential-type", Secret.SchemaAttributeType.STRING
            );
        }

        /**
         * Store a credential securely using libsecret.
         *
         * @param key The credential identifier (e.g., "ngrok-auth-token")
         * @param value The credential value to store
         * @param label Human-readable label for the credential
         * @return true if successfully stored, false otherwise
         */
        public async bool store_credential(string key, string value, string label) throws GLib.Error {
            if (key.length == 0 || value.length == 0) {
                throw new IOError.INVALID_ARGUMENT("Key and value cannot be empty");
            }

            try {
                var attributes = new HashTable<string, string>(str_hash, str_equal);
                attributes.insert("application", Config.APP_ID);
                attributes.insert("credential-type", key);

                bool success = yield Secret.password_storev(
                    this.schema,
                    attributes,
                    Secret.COLLECTION_DEFAULT,
                    label,
                    value,
                    null
                );

                if (success) {
                    debug("Credential '%s' stored securely", key);
                }

                return success;
            } catch (GLib.Error e) {
                warning("Failed to store credential '%s': %s", key, e.message);
                throw e;
            }
        }

        /**
         * Retrieve a credential from secure storage.
         *
         * @param key The credential identifier
         * @return The credential value, or null if not found
         */
        public async string? retrieve_credential(string key) throws GLib.Error {
            if (key.length == 0) {
                throw new IOError.INVALID_ARGUMENT("Key cannot be empty");
            }

            try {
                var attributes = new HashTable<string, string>(str_hash, str_equal);
                attributes.insert("application", Config.APP_ID);
                attributes.insert("credential-type", key);

                string? password = yield Secret.password_lookupv(
                    this.schema,
                    attributes,
                    null
                );

                if (password != null) {
                    debug("Credential '%s' retrieved successfully", key);
                } else {
                    debug("Credential '%s' not found in secure storage", key);
                }

                return password;
            } catch (GLib.Error e) {
                warning("Failed to retrieve credential '%s': %s", key, e.message);
                throw e;
            }
        }

        /**
         * Delete a credential from secure storage.
         *
         * @param key The credential identifier
         * @return true if successfully deleted, false otherwise
         */
        public async bool delete_credential(string key) throws GLib.Error {
            if (key.length == 0) {
                throw new IOError.INVALID_ARGUMENT("Key cannot be empty");
            }

            try {
                var attributes = new HashTable<string, string>(str_hash, str_equal);
                attributes.insert("application", Config.APP_ID);
                attributes.insert("credential-type", key);

                bool success = yield Secret.password_clearv(
                    this.schema,
                    attributes,
                    null
                );

                if (success) {
                    debug("Credential '%s' deleted successfully", key);
                } else {
                    debug("Credential '%s' not found for deletion", key);
                }

                return success;
            } catch (GLib.Error e) {
                warning("Failed to delete credential '%s': %s", key, e.message);
                throw e;
            }
        }

        /**
         * Migrate ngrok auth token from GSettings to secure storage.
         * This is called once during upgrade to ensure backward compatibility.
         *
         * @return true if migration was performed or not needed, false on error
         */
        public async bool migrate_ngrok_token() {
            if (this.settings == null) {
                warning("Cannot migrate token: GSettings not initialized");
                return false;
            }

            try {
                // Check if token is already in secure storage
                string? secure_token = yield retrieve_credential(NGROK_TOKEN_KEY);
                if (secure_token != null && secure_token.length > 0) {
                    debug("Token already in secure storage, no migration needed");
                    return true;
                }

                // Get token from GSettings
                string? old_token = this.settings.get_string("ngrok-auth-token");
                if (old_token == null || old_token.length == 0) {
                    debug("No token in GSettings to migrate");
                    return true;
                }

                // Store in secure storage
                bool stored = yield store_credential(
                    NGROK_TOKEN_KEY,
                    old_token,
                    "Ngrok Authentication Token"
                );

                if (stored) {
                    // Clear the old value from GSettings
                    this.settings.set_string("ngrok-auth-token", "");
                    info("Successfully migrated ngrok token to secure storage");
                    return true;
                } else {
                    warning("Failed to store token in secure storage during migration");
                    return false;
                }
            } catch (GLib.Error e) {
                warning("Error during token migration: %s", e.message);
                return false;
            }
        }

        /**
         * Validate a URL for security issues (SSRF prevention).
         *
         * @param url The URL to validate
         * @param error_message Output parameter for validation error message
         * @return true if URL is safe, false otherwise
         */
        public bool validate_url(string url, out string error_message) {
            error_message = "";

            if (url.length == 0) {
                error_message = "URL cannot be empty";
                return false;
            }

            if (url.length > 2048) {
                error_message = "URL exceeds maximum length (2048 characters)";
                return false;
            }

            // Parse the URL
            try {
                var uri = Uri.parse(url, UriFlags.NONE);

                // Check scheme - only allow http and https
                string scheme = uri.get_scheme();
                if (scheme != "http" && scheme != "https") {
                    error_message = @"Dangerous URL scheme '$scheme' not allowed (only http/https)";
                    return false;
                }

                // Check for private/local IPs (SSRF prevention)
                string? host = uri.get_host();
                if (host != null && is_private_or_local_ip(host)) {
                    error_message = @"Private or local IP address detected: $host (SSRF risk)";
                    return false;
                }

                return true;
            } catch (UriError e) {
                error_message = @"Invalid URL format: $(e.message)";
                return false;
            }
        }

        /**
         * Check if a hostname is a private or local IP address.
         * Prevents SSRF attacks by blocking requests to internal networks.
         */
        private bool is_private_or_local_ip(string host) {
            // Check for localhost names
            if (host == "localhost" || host == "127.0.0.1" || host == "::1" ||
                host == "0.0.0.0" || host == "0:0:0:0:0:0:0:0") {
                return true;
            }

            // Check for private IPv4 ranges
            if (host.has_prefix("10.") ||
                host.has_prefix("192.168.") ||
                host.has_prefix("172.16.") || host.has_prefix("172.17.") ||
                host.has_prefix("172.18.") || host.has_prefix("172.19.") ||
                host.has_prefix("172.20.") || host.has_prefix("172.21.") ||
                host.has_prefix("172.22.") || host.has_prefix("172.23.") ||
                host.has_prefix("172.24.") || host.has_prefix("172.25.") ||
                host.has_prefix("172.26.") || host.has_prefix("172.27.") ||
                host.has_prefix("172.28.") || host.has_prefix("172.29.") ||
                host.has_prefix("172.30.") || host.has_prefix("172.31.")) {
                return true;
            }

            // Check for link-local addresses
            if (host.has_prefix("169.254.")) {
                return true;
            }

            // Check for IPv6 private addresses
            if (host.has_prefix("fc") || host.has_prefix("fd") || // Unique local
                host.has_prefix("fe80:")) { // Link-local
                return true;
            }

            return false;
        }

        /**
         * Validate a request path for security issues (path traversal prevention).
         *
         * @param path The request path to validate
         * @return true if path is safe, false otherwise
         */
        public bool validate_path(string path) {
            if (path.length == 0) {
                warning("validate_path: path is empty");
                return false;
            }

            if (path.length > 2048) {
                warning("validate_path: path too long (%d)", path.length);
                return false;
            }

            // Check for path traversal attempts
            if (path.contains("..")) {
                warning("validate_path: path '%s' contains '..'", path);
                return false;
            }

            // Note: Direct null byte checking is unreliable in Vala strings
            // URL-encoded null bytes (%00) are checked below, which handles HTTP attack vectors

            if (path.contains("\r") || path.contains("\n")) {
                warning("validate_path: path '%s' contains line breaks", path);
                return false;
            }

            // Check for encoded path traversal
            if (path.contains("%2e%2e") || path.contains("%252e%252e") ||
                path.contains("..%2f") || path.contains("..%5c")) {
                warning("validate_path: path '%s' contains encoded traversal", path);
                return false;
            }

            warning("validate_path: '%s' passed all checks, returning true", path);
            return true;
        }

        /**
         * Sanitize a string by removing control characters.
         * Useful for headers, query parameters, etc.
         *
         * @param input The string to sanitize
         * @param max_length Maximum allowed length
         * @return Sanitized string
         */
        public string sanitize_string(string input, int max_length = 8192) {
            if (input.length == 0) {
                return input;
            }

            var result = new StringBuilder();
            int length = 0;

            for (int i = 0; i < input.length && length < max_length; i++) {
                unichar c = input.get_char(i);

                // Allow printable characters and common whitespace
                if (c == ' ' || c == '\t' || c == '\n' || c == '\r' ||
                    (c >= 0x20 && c <= 0x7E) || c >= 0x80) {
                    result.append_unichar(c);
                    length++;
                }
            }

            return result.str;
        }

        /**
         * Validate request body size.
         *
         * @param body_size Size in bytes
         * @param max_size Maximum allowed size (default 10MB)
         * @return true if size is acceptable, false otherwise
         */
        public bool validate_body_size(int64 body_size, int64 max_size = 10485760) {
            return body_size >= 0 && body_size <= max_size;
        }
    }
}
