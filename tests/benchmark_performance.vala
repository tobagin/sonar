/*
 * Performance benchmarks for Sonar
 */

using Sonar;

void benchmark_request_indexing() {
    print("Benchmarking request indexing...\n");

    var index = new RequestIndex();
    var start_time = GLib.get_monotonic_time();

    // Add 1000 requests
    for (int i = 0; i < 1000; i++) {
        var request = new WebhookRequest() {
            id = @"req_$i",
            method = (i % 2 == 0) ? "GET" : "POST",
            path = @"/api/test/$i",
            body = @"{\"index\": $i}",
            timestamp = new DateTime.now_local(),
            content_type = "application/json"
        };
        index.add_request(request);
    }

    var index_time = GLib.get_monotonic_time() - start_time;
    print("  Indexed 1000 requests in %lld μs (%.2f μs/request)\n",
          index_time, (double)index_time / 1000.0);

    // Benchmark search
    start_time = GLib.get_monotonic_time();
    var results = index.filter_by_method("GET");
    var search_time = GLib.get_monotonic_time() - start_time;

    print("  Searched 1000 requests in %lld μs (O(1) lookup)\n", search_time);
    print("  Found %d results\n", results.size);

    assert(results.size == 500); // Half should be GET
}

void benchmark_json_caching() {
    print("\nBenchmarking JSON caching...\n");

    var request = new WebhookRequest() {
        id = "test",
        method = "POST",
        path = "/api/test",
        body = "{\"data\": \"large json payload\", \"nested\": {\"value\": 123}}",
        timestamp = new DateTime.now_local(),
        content_type = "application/json"
    };

    // First call - should parse
    var start_time = GLib.get_monotonic_time();
    var formatted1 = request.get_formatted_body();
    var first_time = GLib.get_monotonic_time() - start_time;

    // Second call - should use cache
    start_time = GLib.get_monotonic_time();
    var formatted2 = request.get_formatted_body();
    var cached_time = GLib.get_monotonic_time() - start_time;

    print("  First call (parse): %lld μs\n", first_time);
    print("  Cached call: %lld μs\n", cached_time);
    print("  Speedup: %.1fx\n", (double)first_time / (double)cached_time);

    assert(cached_time < first_time);
}

void benchmark_rate_limiter() {
    print("\nBenchmarking rate limiter...\n");

    var limiter = new RateLimiter(100, 100); // 100 req/s, burst 100
    var start_time = GLib.get_monotonic_time();

    int allowed = 0;
    int rejected = 0;

    // Send 200 requests
    for (int i = 0; i < 200; i++) {
        if (limiter.check_rate_limit(@"client_$i")) {
            allowed++;
        } else {
            rejected++;
        }
    }

    var check_time = GLib.get_monotonic_time() - start_time;

    print("  Checked 200 requests in %lld μs (%.2f μs/request)\n",
          check_time, (double)check_time / 200.0);
    print("  Allowed: %d, Rejected: %d\n", allowed, rejected);

    assert(allowed <= 100); // Should respect burst limit
}

void benchmark_signature_validation() {
    print("\nBenchmarking signature validation...\n");

    string payload = "{\"test\": \"data\", \"value\": 123}";
    string secret = "test_secret";

    // Generate signature
    var hmac = new GLib.Hmac(GLib.ChecksumType.SHA256, secret.data);
    hmac.update(payload.data);
    string signature = hmac.get_string();

    var start_time = GLib.get_monotonic_time();

    // Validate 1000 times
    for (int i = 0; i < 1000; i++) {
        SignatureValidator.validate_hmac_sha256(payload, signature, secret);
    }

    var validation_time = GLib.get_monotonic_time() - start_time;

    print("  Validated 1000 signatures in %lld μs (%.2f μs/validation)\n",
          validation_time, (double)validation_time / 1000.0);
}

void benchmark_export_formats() {
    print("\nBenchmarking export formats...\n");

    var requests = new Gee.ArrayList<WebhookRequest>();

    // Create 100 test requests
    for (int i = 0; i < 100; i++) {
        var request = new WebhookRequest() {
            id = @"req_$i",
            method = "POST",
            path = @"/api/test/$i",
            body = @"{\"index\": $i, \"data\": \"test payload\"}",
            timestamp = new DateTime.now_local(),
            content_type = "application/json"
        };
        requests.add(request);
    }

    // Benchmark HAR export
    var start_time = GLib.get_monotonic_time();
    var har_export = ExportUtils.export_to_har(requests);
    var har_time = GLib.get_monotonic_time() - start_time;

    print("  HAR export (100 requests): %lld μs\n", har_time);

    // Benchmark CSV export
    start_time = GLib.get_monotonic_time();
    var csv_export = ExportUtils.export_to_csv(requests);
    var csv_time = GLib.get_monotonic_time() - start_time;

    print("  CSV export (100 requests): %lld μs\n", csv_time);

    print("  HAR size: %d bytes, CSV size: %d bytes\n",
          har_export.length, csv_export.length);
}

int main(string[] args) {
    print("\n=== Sonar Performance Benchmarks ===\n\n");

    benchmark_request_indexing();
    benchmark_json_caching();
    benchmark_rate_limiter();
    benchmark_signature_validation();
    benchmark_export_formats();

    print("\n=== Benchmarks Complete ===\n");

    return 0;
}
