using GLib;
using Sonar;
using Soup;

public void test_mock_enabled() {
    var storage = new RequestStorage();
    var server = new WebhookServer(storage);
    
    // Configure mock
    server.mock_manager.enabled = true;
    server.mock_manager.status_code = 418;
    server.mock_manager.content_type = "text/plain";
    server.mock_manager.body = "I am a teapot";
    
    // Create a dummy request to intercept?
    // Testing SoupServer directly is hard without running it.
    // We can start the server and send a request to it.
    
    try {
        MainLoop loop = new MainLoop();
        server.start(8090, "127.0.0.1");
        
        var session = new Session();
        var msg = new Message("GET", "http://127.0.0.1:8090/webhook");
        
        session.send_and_read_async.begin(msg, Priority.DEFAULT, null, (obj, res) => {
            try {
                Bytes bytes = session.send_and_read_async.end(res);
                
                assert(msg.status_code == 418);
                string response_body = (string)bytes.get_data();

                assert(response_body == "I am a teapot");
                
                loop.quit();
            } catch (Error e) {
                Test.message("Request failed: %s", e.message);
                Test.fail();
                loop.quit();
            }
        });
        
        // Run loop with timeout
        Timeout.add_seconds(2, () => {
            loop.quit();
            error("Test timed out");
            return false;
        });
        
        loop.run();
        server.stop();
        
    } catch (Error e) {
        server.stop();
        Test.message("Server error: %s", e.message);
        Test.fail();
    }
}

public int main(string[] args) {
    Test.init(ref args);
    
    Test.add_func("/mock/enabled", test_mock_enabled);
    
    return Test.run();
}
