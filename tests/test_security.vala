/*
 * Security testing suite for Sonar
 */

using Sonar;

void test_ssrf_prevention() {
    string error_msg;

    // Should block private IPs
    assert(!ValidationUtils.validate_forward_url("http://127.0.0.1:8080", true, out error_msg));
    assert(!ValidationUtils.validate_forward_url("http://localhost", true, out error_msg));
    assert(!ValidationUtils.validate_forward_url("http://192.168.1.1", true, out error_msg));
    assert(!ValidationUtils.validate_forward_url("http://10.0.0.1", true, out error_msg));
    assert(!ValidationUtils.validate_forward_url("http://172.16.0.1", true, out error_msg));

    // Should allow public IPs
    assert(ValidationUtils.validate_forward_url("https://api.example.com", true, out error_msg));
    assert(ValidationUtils.validate_forward_url("https://8.8.8.8", true, out error_msg));
}

void test_path_traversal_prevention() {
    string out_path;
    string? error;

    // Should block path traversal attempts
    assert(!ValidationUtils.validate_path("../../../etc/passwd", out out_path, out error));
    assert(!ValidationUtils.validate_path("/etc/passwd", out out_path, out error));
    assert(!ValidationUtils.validate_path("..\\windows\\system32", out out_path, out error));

    // Should allow normal paths
    assert(ValidationUtils.validate_path("/api/webhooks", out out_path, out error));
    assert(ValidationUtils.validate_path("/test", out out_path, out error));
}

void test_method_validation() {
    string out_method;
    string? error;

    // Should allow standard HTTP methods
    assert(ValidationUtils.validate_method("GET", out out_method, out error));
    assert(ValidationUtils.validate_method("POST", out out_method, out error));
    assert(ValidationUtils.validate_method("PUT", out out_method, out error));
    assert(ValidationUtils.validate_method("DELETE", out out_method, out error));

    // Should normalize case
    assert(ValidationUtils.validate_method("get", out out_method, out error));
    assert(out_method == "GET");

    // Should reject invalid methods
    assert(!ValidationUtils.validate_method("INVALID", out out_method, out error));
    assert(!ValidationUtils.validate_method("", out out_method, out error));
}

void test_body_size_limits() {
    string out_body;
    string? error;

    // Should accept reasonable sizes
    string small_body = "small payload";
    assert(ValidationUtils.validate_body_size(small_body, out out_body, out error));

    // Should reject oversized payloads (>10MB)
    var large_body = string.nfill(11 * 1024 * 1024, 'x'); // 11MB
    assert(!ValidationUtils.validate_body_size(large_body, out out_body, out error));
}

void test_input_sanitization() {
    string out_value;
    string? error;

    // Should sanitize SQL injection attempts
    string sql_inject = "'; DROP TABLE users; --";
    assert(ValidationUtils.sanitize_string_input(sql_inject, 1000, out out_value, out error));
    assert(!out_value.contains(";"));

    // Should handle XSS attempts
    string xss_attempt = "<script>alert('xss')</script>";
    assert(ValidationUtils.sanitize_string_input(xss_attempt, 1000, out out_value, out error));
    assert(!out_value.contains("<script>"));

    // Should enforce length limits
    string long_string = string.nfill(2000, 'a');
    assert(!ValidationUtils.sanitize_string_input(long_string, 1000, out out_value, out error));
}

int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/security/ssrf_prevention", test_ssrf_prevention);
    Test.add_func("/security/path_traversal", test_path_traversal_prevention);
    Test.add_func("/security/method_validation", test_method_validation);
    Test.add_func("/security/body_size_limits", test_body_size_limits);
    Test.add_func("/security/input_sanitization", test_input_sanitization);

    return Test.run();
}
