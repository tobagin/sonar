/*
 * Data models for the Sonar webhook inspector application.
 */

using Json;
using GLib;

namespace Sonar {
    
    /**
     * Model representing a received webhook request.
     */
    public class WebhookRequest : GLib.Object {
        public string id { get; set; }
        public DateTime timestamp { get; set; }
        public string method { get; set; }
        public string path { get; set; }
        public HashTable<string, string> headers { get; set; }
        public string body { get; set; }
        public HashTable<string, string> query_params { get; set; }
        public string? content_type { get; set; }
        public int64 content_length { get; set; default = -1; }
        public bool is_starred { get; set; default = false; }

        // Cache for formatted body (performance optimization)
        private string? _cached_formatted_body = null;
        
        public WebhookRequest() {
            this.id = Uuid.string_random();
            this.timestamp = new DateTime.now_local();
            this.headers = new HashTable<string, string>(str_hash, str_equal);
            this.query_params = new HashTable<string, string>(str_hash, str_equal);
        }
        
        public WebhookRequest.full(string method, string path, 
                                 HashTable<string, string> headers,
                                 string body,
                                 HashTable<string, string> query_params,
                                 string? content_type = null,
                                 int64 content_length = -1) {
            this.id = Uuid.string_random();
            this.timestamp = new DateTime.now_local();
            this.method = method;
            this.path = path;
            this.headers = headers;
            this.body = body;
            this.query_params = query_params;
            this.content_type = content_type;
            this.content_length = content_length;
        }
        
        public string to_string() {
            return @"$(method) $(path) at $(timestamp.format("%H:%M:%S"))";
        }
        
        public string get_formatted_body() {
            // Return cached version if available
            if (_cached_formatted_body != null) {
                return _cached_formatted_body;
            }

            if (body.length == 0) {
                _cached_formatted_body = "";
                return "";
            }

            // Try to parse as JSON for pretty formatting
            try {
                var parser = new Json.Parser();
                parser.load_from_data(body);
                var gen = new Json.Generator();
                gen.set_root(parser.get_root());
                gen.pretty = true;
                gen.indent = 2;
                _cached_formatted_body = gen.to_data(null);
                return _cached_formatted_body;
            } catch (Error e) {
                // Return as-is if not valid JSON
                _cached_formatted_body = body;
                return body;
            }
        }
        
        public string get_formatted_headers() {
            var builder = new StringBuilder();
            headers.foreach((key, value) => {
                if (builder.len > 0) {
                    builder.append("\n");
                }
                builder.append(@"$(key): $(value)");
            });
            return builder.str;
        }
        
        public Json.Node to_json() {
            var builder = new Json.Builder();
            builder.begin_object();
            
            builder.set_member_name("id");
            builder.add_string_value(id);
            
            builder.set_member_name("timestamp");
            builder.add_string_value(timestamp.format_iso8601());
            
            builder.set_member_name("method");
            builder.add_string_value(method);
            
            builder.set_member_name("path");
            builder.add_string_value(path);
            
            builder.set_member_name("body");
            builder.add_string_value(body);
            
            if (content_type != null) {
                builder.set_member_name("content_type");
                builder.add_string_value(content_type);
            }
            
            if (content_length >= 0) {
                builder.set_member_name("content_length");
                builder.add_int_value(content_length);
            }

            builder.set_member_name("is_starred");
            builder.add_boolean_value(is_starred);

            // Headers object
            builder.set_member_name("headers");
            builder.begin_object();
            headers.foreach((key, value) => {
                builder.set_member_name(key);
                builder.add_string_value(value);
            });
            builder.end_object();
            
            // Query params object
            builder.set_member_name("query_params");
            builder.begin_object();
            query_params.foreach((key, value) => {
                builder.set_member_name(key);
                builder.add_string_value(value);
            });
            builder.end_object();
            
            builder.end_object();
            return builder.get_root();
        }
        
        public static WebhookRequest? from_json(Json.Node node) {
            try {
                var obj = node.get_object();
                var request = new WebhookRequest();
                
                request.id = obj.get_string_member("id");
                
                var timestamp_str = obj.get_string_member("timestamp");
                request.timestamp = new DateTime.from_iso8601(timestamp_str, null);
                
                request.method = obj.get_string_member("method");
                request.path = obj.get_string_member("path");
                request.body = obj.get_string_member("body");
                
                if (obj.has_member("content_type") && !obj.get_null_member("content_type")) {
                    request.content_type = obj.get_string_member("content_type");
                }
                
                if (obj.has_member("content_length") && !obj.get_null_member("content_length")) {
                    request.content_length = obj.get_int_member("content_length");
                }

                if (obj.has_member("is_starred")) {
                    request.is_starred = obj.get_boolean_member("is_starred");
                }

                // Load headers
                var headers_obj = obj.get_object_member("headers");
                headers_obj.foreach_member((obj, name, node) => {
                    request.headers.set(name, node.get_string());
                });
                
                // Load query params
                var params_obj = obj.get_object_member("query_params");
                params_obj.foreach_member((obj, name, node) => {
                    request.query_params.set(name, node.get_string());
                });
                
                return request;
            } catch (Error e) {
                warning("Failed to parse WebhookRequest from JSON: %s", e.message);
                return null;
            }
        }
    }
    
    /**
     * Model representing a request template.
     */
    public class RequestTemplate : GLib.Object {
        public string id { get; set; }
        public string name { get; set; }
        public string description { get; set; }
        public string method { get; set; }
        public string path { get; set; }
        public HashTable<string, string> headers { get; set; }
        public string body { get; set; }
        public string? content_type { get; set; }
        public DateTime created_at { get; set; }

        public RequestTemplate() {
            this.id = Uuid.string_random();
            this.headers = new HashTable<string, string>(str_hash, str_equal);
            this.created_at = new DateTime.now_local();
        }

        public RequestTemplate.from_request(WebhookRequest request, string name, string description) {
            this();
            this.name = name;
            this.description = description;
            this.method = request.method;
            this.path = request.path;
            this.body = request.body;
            this.content_type = request.content_type;

            // Copy headers
            request.headers.foreach((key, value) => {
                this.headers.set(key, value);
            });
        }

        public Json.Node to_json() {
            var builder = new Json.Builder();
            builder.begin_object();

            builder.set_member_name("id");
            builder.add_string_value(this.id);

            builder.set_member_name("name");
            builder.add_string_value(this.name);

            builder.set_member_name("description");
            builder.add_string_value(this.description);

            builder.set_member_name("method");
            builder.add_string_value(this.method);

            builder.set_member_name("path");
            builder.add_string_value(this.path);

            builder.set_member_name("body");
            builder.add_string_value(this.body);

            if (this.content_type != null) {
                builder.set_member_name("content_type");
                builder.add_string_value(this.content_type);
            }

            builder.set_member_name("created_at");
            builder.add_string_value(this.created_at.to_unix().to_string());

            // Headers
            builder.set_member_name("headers");
            builder.begin_object();
            this.headers.foreach((key, value) => {
                builder.set_member_name(key);
                builder.add_string_value(value);
            });
            builder.end_object();

            builder.end_object();
            return builder.get_root();
        }

        public static RequestTemplate? from_json(Json.Node node) {
            if (node.get_node_type() != Json.NodeType.OBJECT) {
                return null;
            }

            var obj = node.get_object();
            var template = new RequestTemplate();

            if (obj.has_member("id")) {
                template.id = obj.get_string_member("id");
            }
            if (obj.has_member("name")) {
                template.name = obj.get_string_member("name");
            }
            if (obj.has_member("description")) {
                template.description = obj.get_string_member("description");
            }
            if (obj.has_member("method")) {
                template.method = obj.get_string_member("method");
            }
            if (obj.has_member("path")) {
                template.path = obj.get_string_member("path");
            }
            if (obj.has_member("body")) {
                template.body = obj.get_string_member("body");
            }
            if (obj.has_member("content_type")) {
                template.content_type = obj.get_string_member("content_type");
            }
            if (obj.has_member("created_at")) {
                var timestamp = int64.parse(obj.get_string_member("created_at"));
                template.created_at = new DateTime.from_unix_local(timestamp);
            }

            // Headers
            if (obj.has_member("headers")) {
                var headers_obj = obj.get_object_member("headers");
                headers_obj.foreach_member((obj, key, node) => {
                    template.headers.set(key, node.get_string());
                });
            }

            return template;
        }
    }

    /**
     * Model representing the current tunnel status.
     */
    public class TunnelStatus : GLib.Object {
        public bool active { get; set; default = false; }
        public string? public_url { get; set; default = null; }
        public DateTime? start_time { get; set; default = null; }
        public string? error { get; set; default = null; }
        
        public TunnelStatus() {
        }
        
        public TunnelStatus.with_url(string public_url) {
            this.active = true;
            this.public_url = public_url;
            this.start_time = new DateTime.now_local();
            this.error = null;
        }
        
        public TunnelStatus.with_error(string error) {
            this.active = false;
            this.public_url = null;
            this.start_time = null;
            this.error = error;
        }
        
        public string to_string() {
            if (active && public_url != null) {
                return @"Active: $(public_url)";
            } else if (error != null) {
                return @"Error: $(error)";
            }
            return "Inactive";
        }
    }
    
    /**
     * Storage for webhook requests with persistent history support.
     */
    public class RequestStorage : GLib.Object {
        private Gee.ArrayList<WebhookRequest> _requests;
        private Gee.ArrayList<WebhookRequest> _history;
        private Gee.ArrayList<RequestTemplate> _templates;
        private RequestIndex _index;
        private int _max_requests;
        private int _max_history;
        private File _data_dir;
        private File _history_file;
        private File _templates_file;

        public signal void request_added(WebhookRequest request);
        public signal void requests_cleared();
        public signal void history_changed();
        public signal void template_added(RequestTemplate template);
        public signal void template_deleted(string template_id);
        public signal void templates_changed();
        
        public RequestStorage(int max_history = 1000, owned string? data_dir = null) {
            this._requests = new Gee.ArrayList<WebhookRequest>();
            this._history = new Gee.ArrayList<WebhookRequest>();
            this._templates = new Gee.ArrayList<RequestTemplate>();
            this._index = new RequestIndex();
            this._max_requests = 1000;
            this._max_history = max_history;

            // Set up persistent storage
            if (data_dir == null) {
                // Use XDG_DATA_HOME if set (for Flatpak), otherwise fall back to default
                var xdg_data_home = Environment.get_variable("XDG_DATA_HOME");
                if (xdg_data_home != null && xdg_data_home.length > 0) {
                    data_dir = GLib.Path.build_filename(xdg_data_home, "sonar");
                } else {
                    data_dir = GLib.Path.build_filename(Environment.get_user_data_dir(), "sonar");
                }
            }

            this._data_dir = File.new_for_path(data_dir);

            try {
                this._data_dir.make_directory_with_parents();
            } catch (Error e) {
                if (e.code != IOError.EXISTS) {
                    warning("Failed to create data directory %s: %s", this._data_dir.get_path(), e.message);
                }
            }

            this._history_file = this._data_dir.get_child("history.json");
            this._templates_file = this._data_dir.get_child("templates.json");
            this._load_history_from_disk();
            this._load_templates_from_disk();
        }
        
        public void add_request(WebhookRequest request) {
            this._requests.add(request);

            // Add to index for fast lookups
            this._index.add_request(request);

            // Also add to history immediately
            this._history.insert(0, request);

            // Remove oldest requests if we exceed the limit
            while (this._requests.size > this._max_requests) {
                var removed = this._requests.remove_at(0);
                this._index.remove_request(removed);
            }

            // Limit history size
            while (this._history.size > this._max_history) {
                this._history.remove_at(this._history.size - 1);
            }

            // Save history to disk
            this._save_history_to_disk();

            request_added(request);
            history_changed();
        }
        
        public Gee.List<WebhookRequest> get_requests() {
            return this._requests.read_only_view;
        }
        
        public Gee.List<WebhookRequest> get_history() {
            return this._history.read_only_view;
        }
        
        public WebhookRequest? get_request_by_id(string request_id) {
            foreach (var request in this._requests) {
                if (request.id == request_id) {
                    return request;
                }
            }
            return null;
        }
        
        public WebhookRequest? get_history_request_by_id(string request_id) {
            foreach (var request in this._history) {
                if (request.id == request_id) {
                    return request;
                }
            }
            return null;
        }
        
        public void clear() {
            // Just clear active requests - don't move to history since they're already there
            this._requests.clear();
            this._index.clear();

            requests_cleared();
        }
        
        public void clear_history() {
            this._history.clear();
            this._save_history_to_disk();
            history_changed();
        }
        
        public bool remove_from_history(string request_id) {
            for (int i = 0; i < this._history.size; i++) {
                if (this._history[i].id == request_id) {
                    this._history.remove_at(i);
                    this._save_history_to_disk();
                    history_changed();
                    return true;
                }
            }
            return false;
        }
        
        public bool restore_from_history(string request_id) {
            for (int i = 0; i < this._history.size; i++) {
                if (this._history[i].id == request_id) {
                    var restored_request = this._history.remove_at(i);
                    this._requests.insert(0, restored_request);
                    this._save_history_to_disk();
                    history_changed();
                    request_added(restored_request);
                    return true;
                }
            }
            return false;
        }
        
        public int count() {
            return this._requests.size;
        }
        
        public int count_history() {
            return this._history.size;
        }
        
        public int get_total_count() {
            return this._requests.size + this._history.size;
        }
        
        public Gee.List<WebhookRequest> get_latest(int limit = 10) {
            var result = new Gee.ArrayList<WebhookRequest>();
            int start = int.max(0, this._requests.size - limit);
            for (int i = start; i < this._requests.size; i++) {
                result.add(this._requests[i]);
            }
            return result.read_only_view;
        }
        
        private void _load_history_from_disk() {
            try {
                if (!this._history_file.query_exists()) {
                    return;
                }
                
                uint8[] contents;
                this._history_file.load_contents(null, out contents, null);
                
                var parser = new Json.Parser();
                parser.load_from_data((string) contents);
                
                var array = parser.get_root().get_array();
                array.foreach_element((array, index, element) => {
                    var request = WebhookRequest.from_json(element);
                    if (request != null) {
                        this._history.add(request);
                    }
                });
                
                // Ensure we don't exceed max history
                while (this._history.size > this._max_history) {
                    this._history.remove_at(this._history.size - 1);
                }
                
            } catch (Error e) {
                warning("Failed to load history from disk: %s", e.message);
                this._history.clear();
            }
        }
        
        private void _save_history_to_disk() {
            try {
                var builder = new Json.Builder();
                builder.begin_array();
                
                foreach (var request in this._history) {
                    builder.add_value(request.to_json());
                }
                
                builder.end_array();
                
                var gen = new Json.Generator();
                gen.set_root(builder.get_root());
                gen.pretty = true;
                gen.indent = 2;
                
                var json_data = gen.to_data(null);
                
                // Write to temporary file first, then rename for atomicity
                var temp_file = this._data_dir.get_child("history.json.tmp");
                temp_file.replace_contents(json_data.data, null, false, 
                                         FileCreateFlags.REPLACE_DESTINATION, null);
                
                // Atomic replace
                temp_file.move(this._history_file, FileCopyFlags.OVERWRITE);
                
            } catch (Error e) {
                warning("Failed to save history to disk: %s", e.message);
            }
        }

        // Template management
        public void add_template(RequestTemplate template) {
            this._templates.add(template);
            this._save_templates_to_disk();
            this.template_added(template);
            this.templates_changed();
        }

        public void delete_template(string template_id) {
            for (int i = 0; i < this._templates.size; i++) {
                if (this._templates[i].id == template_id) {
                    this._templates.remove_at(i);
                    this._save_templates_to_disk();
                    this.template_deleted(template_id);
                    this.templates_changed();
                    break;
                }
            }
        }

        public Gee.ArrayList<RequestTemplate> get_templates() {
            return this._templates;
        }

        public RequestTemplate? get_template_by_id(string id) {
            foreach (var template in this._templates) {
                if (template.id == id) {
                    return template;
                }
            }
            return null;
        }

        private void _load_templates_from_disk() {
            if (!this._templates_file.query_exists()) {
                debug("Templates file does not exist yet");
                return;
            }

            try {
                uint8[] contents;
                this._templates_file.load_contents(null, out contents, null);

                var parser = new Json.Parser();
                parser.load_from_data((string) contents);

                var root = parser.get_root();
                if (root.get_node_type() != Json.NodeType.ARRAY) {
                    warning("Templates file is not a JSON array");
                    return;
                }

                var array = root.get_array();
                array.foreach_element((arr, index, node) => {
                    var template = RequestTemplate.from_json(node);
                    if (template != null) {
                        this._templates.add(template);
                    }
                });

                debug("Loaded %d templates from disk", this._templates.size);
            } catch (Error e) {
                warning("Failed to load templates from disk: %s", e.message);
            }
        }

        private void _save_templates_to_disk() {
            try {
                var builder = new Json.Builder();
                builder.begin_array();

                foreach (var template in this._templates) {
                    builder.add_value(template.to_json());
                }

                builder.end_array();

                var gen = new Json.Generator();
                gen.set_root(builder.get_root());
                gen.pretty = true;
                gen.indent = 2;

                var json_data = gen.to_data(null);

                // Write to temporary file first, then rename for atomicity
                var temp_file = this._data_dir.get_child("templates.json.tmp");
                temp_file.replace_contents(json_data.data, null, false,
                                         FileCreateFlags.REPLACE_DESTINATION, null);

                // Atomic replace
                temp_file.move(this._templates_file, FileCopyFlags.OVERWRITE);

            } catch (Error e) {
                warning("Failed to save templates to disk: %s", e.message);
            }
        }

        // Export functionality
        /**
         * Export current requests to the specified format.
         *
         * @param format Export format (HAR, CSV, CURL, JSON)
         * @return Exported data as string
         */
        public string export_current_requests(ExportFormat format) throws GLib.Error {
            return ExportUtils.export_requests(this._requests, format);
        }

        /**
         * Export request history to the specified format.
         *
         * @param format Export format (HAR, CSV, CURL, JSON)
         * @return Exported data as string
         */
        public string export_history(ExportFormat format) throws GLib.Error {
            return ExportUtils.export_requests(this._history, format);
        }

        /**
         * Export specific requests by ID to the specified format.
         *
         * @param request_ids List of request IDs to export
         * @param format Export format (HAR, CSV, CURL, JSON)
         * @return Exported data as string
         */
        public string export_selected_requests(Gee.ArrayList<string> request_ids, ExportFormat format) throws GLib.Error {
            var selected = new Gee.ArrayList<WebhookRequest>();

            foreach (var id in request_ids) {
                foreach (var request in this._requests) {
                    if (request.id == id) {
                        selected.add(request);
                        break;
                    }
                }
                // Also check history if not found in current requests
                if (selected.size < request_ids.size) {
                    foreach (var request in this._history) {
                        if (request.id == id && !selected.contains(request)) {
                            selected.add(request);
                            break;
                        }
                    }
                }
            }

            return ExportUtils.export_requests(selected, format);
        }

        /**
         * Export starred requests to the specified format.
         *
         * @param format Export format (HAR, CSV, CURL, JSON)
         * @return Exported data as string
         */
        public string export_starred_requests(ExportFormat format) throws GLib.Error {
            var starred = new Gee.ArrayList<WebhookRequest>();

            foreach (var request in this._history) {
                if (request.is_starred) {
                    starred.add(request);
                }
            }

            return ExportUtils.export_requests(starred, format);
        }

        /**
         * Save export to file.
         *
         * @param data Exported data string
         * @param file_path Path to save file
         */
        public void save_export_to_file(string data, string file_path) throws GLib.Error {
            ExportUtils.save_to_file(data, file_path);
        }

        // Search and filtering methods
        /**
         * Search requests by keyword.
         */
        public Gee.ArrayList<WebhookRequest> search(string query) {
            return this._index.search(query);
        }

        /**
         * Find requests by HTTP method.
         */
        public Gee.ArrayList<WebhookRequest> find_by_method(string method) {
            return this._index.find_by_method(method);
        }

        /**
         * Find requests by path.
         */
        public Gee.ArrayList<WebhookRequest> find_by_path(string path) {
            return this._index.find_by_path(path);
        }

        /**
         * Find requests by content type.
         */
        public Gee.ArrayList<WebhookRequest> find_by_content_type(string content_type) {
            return this._index.find_by_content_type(content_type);
        }

        /**
         * Get all starred requests.
         */
        public Gee.ArrayList<WebhookRequest> get_starred_requests() {
            return this._index.get_starred();
        }

        /**
         * Get index statistics.
         */
        public HashTable<string, int> get_index_statistics() {
            return this._index.get_statistics();
        }
    }
}