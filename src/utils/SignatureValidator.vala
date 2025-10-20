/*
 * Webhook signature validation utility.
 */

using GLib;

namespace Sonar {

    /**
     * Validates webhook signatures from various providers.
     * Supports HMAC-SHA256, HMAC-SHA1, and other common signing methods.
     */
    public class SignatureValidator : GLib.Object {
        /**
         * Signature algorithm types
         */
        public enum Algorithm {
            HMAC_SHA256,
            HMAC_SHA1,
            HMAC_SHA512
        }

        /**
         * Validate HMAC-SHA256 signature (GitHub, Stripe style)
         *
         * @param payload The request body as string
         * @param signature The signature from header (with or without prefix)
         * @param secret The shared secret key
         * @param prefix Optional prefix like "sha256=" (will be stripped)
         * @return true if signature is valid
         */
        public static bool validate_hmac_sha256(string payload, string signature, string secret, string? prefix = null) {
            string clean_signature = signature;
            if (prefix != null && signature.has_prefix(prefix)) {
                clean_signature = signature.substring(prefix.length);
            }

            var computed = compute_hmac_sha256(payload, secret);
            return secure_compare(computed, clean_signature);
        }

        /**
         * Validate HMAC-SHA1 signature (legacy webhook providers)
         *
         * @param payload The request body as string
         * @param signature The signature from header
         * @param secret The shared secret key
         * @param prefix Optional prefix like "sha1="
         * @return true if signature is valid
         */
        public static bool validate_hmac_sha1(string payload, string signature, string secret, string? prefix = null) {
            string clean_signature = signature;
            if (prefix != null && signature.has_prefix(prefix)) {
                clean_signature = signature.substring(prefix.length);
            }

            var computed = compute_hmac_sha1(payload, secret);
            return secure_compare(computed, clean_signature);
        }

        /**
         * Validate GitHub webhook signature
         * Format: sha256=<signature>
         */
        public static bool validate_github_signature(string payload, string signature, string secret) {
            return validate_hmac_sha256(payload, signature, secret, "sha256=");
        }

        /**
         * Validate Stripe webhook signature
         * Format: t=<timestamp>,v1=<signature>
         */
        public static bool validate_stripe_signature(string payload, string signature, string secret, int64 tolerance_seconds = 300) {
            // Parse Stripe signature format
            var parts = signature.split(",");
            int64 timestamp = 0;
            string? sig_v1 = null;

            foreach (var part in parts) {
                if (part.has_prefix("t=")) {
                    timestamp = int64.parse(part.substring(2));
                } else if (part.has_prefix("v1=")) {
                    sig_v1 = part.substring(3);
                }
            }

            if (sig_v1 == null || timestamp == 0) {
                return false;
            }

            // Check timestamp tolerance (prevent replay attacks)
            var now = new DateTime.now_utc().to_unix();
            if ((now - timestamp).abs() > tolerance_seconds) {
                warning("Stripe signature timestamp outside tolerance window");
                return false;
            }

            // Compute signature with timestamp
            var signed_payload = @"$timestamp.$payload";
            var computed = compute_hmac_sha256(signed_payload, secret);

            return secure_compare(computed, sig_v1);
        }

        /**
         * Validate generic HMAC signature with configurable algorithm
         */
        public static bool validate_hmac(string payload, string signature, string secret, Algorithm algorithm, string? prefix = null) {
            switch (algorithm) {
                case Algorithm.HMAC_SHA256:
                    return validate_hmac_sha256(payload, signature, secret, prefix);
                case Algorithm.HMAC_SHA1:
                    return validate_hmac_sha1(payload, signature, secret, prefix);
                case Algorithm.HMAC_SHA512:
                    string clean_signature = signature;
                    if (prefix != null && signature.has_prefix(prefix)) {
                        clean_signature = signature.substring(prefix.length);
                    }
                    var computed = compute_hmac_sha512(payload, secret);
                    return secure_compare(computed, clean_signature);
                default:
                    return false;
            }
        }

        /**
         * Compute HMAC-SHA256 signature
         */
        private static string compute_hmac_sha256(string payload, string secret) {
            var hmac = new Hmac(ChecksumType.SHA256, secret.data);
            hmac.update(payload.data);

            // Get hex digest directly
            return hmac.get_string();
        }

        /**
         * Compute HMAC-SHA1 signature
         */
        private static string compute_hmac_sha1(string payload, string secret) {
            var hmac = new Hmac(ChecksumType.SHA1, secret.data);
            hmac.update(payload.data);

            return hmac.get_string();
        }

        /**
         * Compute HMAC-SHA512 signature
         */
        private static string compute_hmac_sha512(string payload, string secret) {
            var hmac = new Hmac(ChecksumType.SHA512, secret.data);
            hmac.update(payload.data);

            return hmac.get_string();
        }

        /**
         * Timing-safe string comparison to prevent timing attacks
         */
        private static bool secure_compare(string a, string b) {
            if (a.length != b.length) {
                return false;
            }

            int result = 0;
            for (int i = 0; i < a.length; i++) {
                result |= a[i] ^ b[i];
            }

            return result == 0;
        }
    }
}
