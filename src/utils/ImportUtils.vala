/*
 * Import utilities for webhook requests from various formats.
 */

using GLib;
using Json;

namespace Sonar {

    /**
     * Utility class for importing webhook requests from various formats.
     */
    public class ImportUtils : GLib.Object {

        /**
         * Import requests from a SONAR/JSON file.
         *
         * @param file The file to import from
         * @return List of imported requests
         */
        public static Gee.ArrayList<WebhookRequest> import_from_json(File file) throws Error {
            var requests = new Gee.ArrayList<WebhookRequest>();

            // Read file content
            FileInputStream stream = file.read();
            DataInputStream data_stream = new DataInputStream(stream);
            string? line = null;
            StringBuilder json_builder = new StringBuilder();

            while ((line = data_stream.read_line(null)) != null) {
                json_builder.append(line);
            }

            // Parse JSON
            var parser = new Json.Parser();
            parser.load_from_data(json_builder.str);
            var root = parser.get_root();

            if (root.get_node_type() != Json.NodeType.ARRAY) {
                // Check if it's the export format with metadata
                if (root.get_node_type() == Json.NodeType.OBJECT) {
                    var obj = root.get_object();
                    if (obj.has_member("requests") && obj.get_member("requests").get_node_type() == Json.NodeType.ARRAY) {
                        return parse_requests_array(obj.get_array_member("requests"));
                    }
                }
                throw new IOError.INVALID_ARGUMENT("Invalid JSON format: Root must be an array or contain a 'requests' array");
            }

            return parse_requests_array(root.get_array());
        }
        
        private static Gee.ArrayList<WebhookRequest> parse_requests_array(Json.Array array) {
            var requests = new Gee.ArrayList<WebhookRequest>();
            
            array.foreach_element((arr, index, node) => {
                if (node.get_node_type() == Json.NodeType.OBJECT) {
                    try {
                        var request = WebhookRequest.from_json(node);
                        requests.add(request);
                    } catch (Error e) {
                        warning("Failed to parse request at index %u: %s", index, e.message);
                    }
                }
            });
            
            return requests;
        }

        /**
         * Import requests from a HAR (HTTP Archive) file.
         *
         * @param file The file to import from
         * @return List of imported requests
         */
        public static Gee.ArrayList<WebhookRequest> import_from_har(File file) throws Error {
            var requests = new Gee.ArrayList<WebhookRequest>();

            // Read file content
            FileInputStream stream = file.read();
            DataInputStream data_stream = new DataInputStream(stream);
            string? line = null;
            StringBuilder json_builder = new StringBuilder();

            while ((line = data_stream.read_line(null)) != null) {
                json_builder.append(line);
            }

            // Parse JSON
            var parser = new Json.Parser();
            parser.load_from_data(json_builder.str);
            var root = parser.get_root();

            if (root.get_node_type() != Json.NodeType.OBJECT) {
                throw new IOError.INVALID_ARGUMENT("Invalid HAR format: Root must be an object");
            }

            var log = root.get_object().get_object_member("log");
            if (!log.has_member("entries")) {
                throw new IOError.INVALID_ARGUMENT("Invalid HAR format: Missing 'entries'");
            }

            var entries = log.get_array_member("entries");
            entries.foreach_element((arr, index, node) => {
                try {
                    var entry = node.get_object();
                    var request_obj = entry.get_object_member("request");
                    
                    // Essential HAR request fields
                    string method = request_obj.get_string_member("method");
                    string url = request_obj.get_string_member("url");
                    
                    // Parse URL to get path and query params
                    // Basic parsing, assuming standard HAR URL format
                    string path = url;
                    // Strip protocol and host if present (HAR usually includes full URL)
                    if (url.contains("://")) {
                        var uri = Uri.parse(url, UriFlags.NONE);
                        path = uri.get_path();
                        if (uri.get_query() != null) {
                            // Query will be handled via queryString array in HAR usually
                            // But if HAR doesn't split it, we might need to parse it manually
                            // For this implementation effectively trust the HAR 'queryString' array
                        }
                    }

                    // Headers
                    var headers = new HashTable<string, string>(str_hash, str_equal);
                    if (request_obj.has_member("headers")) {
                        var headers_arr = request_obj.get_array_member("headers");
                        headers_arr.foreach_element((h_arr, h_idx, h_node) => {
                            var h_obj = h_node.get_object();
                            string name = h_obj.get_string_member("name");
                            string value = h_obj.get_string_member("value");
                            headers.set(name, value);
                        });
                    }

                    // Query Params
                    var query_params = new HashTable<string, string>(str_hash, str_equal);
                    if (request_obj.has_member("queryString")) {
                        var query_arr = request_obj.get_array_member("queryString");
                        query_arr.foreach_element((q_arr, q_idx, q_node) => {
                            var q_obj = q_node.get_object();
                            string name = q_obj.get_string_member("name");
                            string value = q_obj.get_string_member("value");
                            query_params.set(name, value);
                        });
                    }

                    // Body
                    string body = "";
                    string? content_type = null;
                    if (request_obj.has_member("postData")) {
                        var post_data = request_obj.get_object_member("postData");
                        if (post_data.has_member("text")) {
                            body = post_data.get_string_member("text");
                        }
                        if (post_data.has_member("mimeType")) {
                            content_type = post_data.get_string_member("mimeType");
                        }
                    }

                    // Content Length
                    int64 content_length = -1;
                    if (request_obj.has_member("bodySize")) {
                         content_length = request_obj.get_int_member("bodySize");
                    }
                    if (content_length == -1 && body.length > 0) {
                        content_length = body.length;
                    }

                    // Timestamp
                    string timestamp_str = entry.get_string_member("startedDateTime");
                    // Parse ISO8601 timestamp
                    // For simplicity, we might just use current time if parsing fails,
                    // but let's try to parse using GLib.DateTime
                    // Note: GLib.DateTime.new_from_iso8601 is available in newer GLib versions
                    
                    // Construct WebhookRequest
                    // We need to bypass the 'private' or 'internal' constructors if they are not public
                    // Assuming WebhookRequest.full is accessible as seen in Server.vala
                    
                    var request = new WebhookRequest.full(
                        method,
                        path,
                        headers,
                        body,
                        query_params,
                        content_type,
                        content_length
                    );
                    
                    // TODO: Set custom timestamp if possible
                    // request.timestamp = ... (if timestamp is settable)

                    requests.add(request);

                } catch (Error e) {
                    warning("Failed to parse HAR entry at index %u: %s", index, e.message);
                }
            });

            return requests;
        }
    }
}
