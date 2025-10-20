/*
 * Unit tests for SignatureValidator
 */

using Sonar;

void test_hmac_sha256() {
    // Test basic HMAC-SHA256
    string payload = "test payload";
    string secret = "test_secret";
    string computed_signature = "8b94f84726ba2ea09adb00b18e4ea9e5a08f7f9c5d40fe63fe0ef5485c6aef3e";

    assert(SignatureValidator.validate_hmac_sha256(payload, computed_signature, secret));
    assert(!SignatureValidator.validate_hmac_sha256(payload, "invalid_signature", secret));
}

void test_github_signature() {
    string payload = "{\"zen\":\"Design for failure.\"}";
    string secret = "my_github_secret";

    // Compute valid GitHub signature
    var hmac = new GLib.Hmac(GLib.ChecksumType.SHA256, secret.data);
    hmac.update(payload.data);
    string signature = "sha256=" + hmac.get_string();

    assert(SignatureValidator.validate_github_signature(payload, signature, secret));
    assert(!SignatureValidator.validate_github_signature(payload, "sha256=invalid", secret));
}

void test_stripe_signature() {
    string payload = "{\"type\":\"payment_intent.succeeded\"}";
    string secret = "whsec_test_secret";
    int64 timestamp = new DateTime.now_utc().to_unix();

    // Build Stripe-style signature
    var signed_payload = @"$timestamp.$payload";
    var hmac = new GLib.Hmac(GLib.ChecksumType.SHA256, secret.data);
    hmac.update(signed_payload.data);
    string signature = @"t=$timestamp,v1=$(hmac.get_string())";

    assert(SignatureValidator.validate_stripe_signature(payload, signature, secret));

    // Test with expired timestamp
    int64 old_timestamp = timestamp - 400; // 400 seconds ago (outside tolerance)
    var old_signed = @"$old_timestamp.$payload";
    var old_hmac = new GLib.Hmac(GLib.ChecksumType.SHA256, secret.data);
    old_hmac.update(old_signed.data);
    string old_signature = @"t=$old_timestamp,v1=$(old_hmac.get_string())";

    assert(!SignatureValidator.validate_stripe_signature(payload, old_signature, secret, 300));
}

void test_hmac_sha1() {
    string payload = "legacy webhook";
    string secret = "old_secret";

    var hmac = new GLib.Hmac(GLib.ChecksumType.SHA1, secret.data);
    hmac.update(payload.data);
    string signature = hmac.get_string();

    assert(SignatureValidator.validate_hmac_sha1(payload, signature, secret));
}

void test_secure_compare() {
    // Secure compare should handle equal length strings correctly
    assert(SignatureValidator.validate_hmac_sha256("test",
        "9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08",
        "9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08") == false); // Different secrets
}

int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/signature/hmac_sha256", test_hmac_sha256);
    Test.add_func("/signature/github", test_github_signature);
    Test.add_func("/signature/stripe", test_stripe_signature);
    Test.add_func("/signature/hmac_sha1", test_hmac_sha1);
    Test.add_func("/signature/secure_compare", test_secure_compare);

    return Test.run();
}
