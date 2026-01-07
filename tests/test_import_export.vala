using GLib;
using Sonar;
using Gee;
using Json;

public void test_import_json() {
    string json_content = """
    [
        {
            "method": "POST",
            "path": "/webhook/test",
            "headers": {
                "Content-Type": "application/json"
            },
            "body": "{\"key\": \"value\"}",
            "query_params": {},
            "timestamp": "2023-01-01T12:00:00Z"
        }
    ]
    """;
    
    try {
        string tmp_path = GLib.Path.build_filename(Environment.get_tmp_dir(), "sonar_test_import.json");
        FileUtils.set_contents(tmp_path, json_content);
        var file = File.new_for_path(tmp_path);
        
        var requests = ImportUtils.import_from_json(file);
        
        assert(requests.size == 1);
        var req = requests.get(0);
        assert(req.method == "POST");
        assert(req.path == "/webhook/test");
        assert(req.body == "{\"key\": \"value\"}");
        
        // Cleanup
        FileUtils.remove(tmp_path);
    } catch (Error e) {
        print("Test failed: %s\n".printf(e.message));
        assert(false);
    }
}

public void test_import_har() {
    // Basic HAR structure
    string har_content = """
    {
        "log": {
            "entries": [
                {
                    "startedDateTime": "2023-01-01T12:00:00Z",
                    "request": {
                        "method": "GET",
                        "url": "http://example.com/api/data?q=1",
                        "headers": [
                            {"name": "Accept", "value": "application/json"}
                        ],
                        "postData": {
                            "mimeType": "text/plain",
                            "text": "body data"
                        }
                    }
                }
            ]
        }
    }
    """;
    
    try {
        string tmp_path = GLib.Path.build_filename(Environment.get_tmp_dir(), "sonar_test_import.har");
        FileUtils.set_contents(tmp_path, har_content);
        var file = File.new_for_path(tmp_path);
        
        var requests = ImportUtils.import_from_har(file);
        
        assert(requests.size == 1);
        var req = requests.get(0);
        assert(req.method == "GET");
        assert(req.body == "body data");
        // Update: HAR URL parsing should extract path
        assert(req.path == "/api/data");
        
        // Cleanup
        FileUtils.remove(tmp_path);
    } catch (Error e) {
        print("Test failed: %s\n".printf(e.message));
        assert(false);
    }
}

public int main(string[] args) {
    Test.init(ref args);
    
    Test.add_func("/import/json", test_import_json);
    Test.add_func("/import/har", test_import_har);
    
    return Test.run();
}
