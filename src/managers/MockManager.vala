/*
 * Manager for handling mock responses.
 */

using GLib;
using Json;

namespace Sonar {

    /**
     * Manages mock response settings.
     */
    public class MockManager : GLib.Object {
        public bool enabled { get; set; default = false; }
        public int status_code { get; set; default = 200; }
        public string content_type { get; set; default = "application/json"; }
        public string body { get; set; default = "{}"; }
        
        private File _config_file;
        
        public MockManager() {
            // Load config from disk if available
            var data_dir = GLib.Path.build_filename(Environment.get_user_data_dir(), "sonar");
            var dir = File.new_for_path(data_dir);
            try {
                if (!dir.query_exists()) {
                    dir.make_directory_with_parents();
                }
            } catch (Error e) {
                warning("Failed to create data dir: %s", e.message);
            }
            
            this._config_file = dir.get_child("mock_config.json");
            this.load_config();
        }
        
        public void save_config() {
            try {
                var builder = new Json.Builder();
                builder.begin_object();
                builder.set_member_name("enabled");
                builder.add_boolean_value(this.enabled);
                builder.set_member_name("status_code");
                builder.add_int_value(this.status_code);
                builder.set_member_name("content_type");
                builder.add_string_value(this.content_type);
                builder.set_member_name("body");
                builder.add_string_value(this.body);
                builder.end_object();
                
                var gen = new Json.Generator();
                gen.set_root(builder.get_root());
                gen.pretty = true;
                
                var data = gen.to_data(null);
                this._config_file.replace_contents(data.data, null, false, FileCreateFlags.REPLACE_DESTINATION, null);
                
            } catch (Error e) {
                warning("Failed to save mock config: %s", e.message);
            }
        }
        
        public void load_config() {
            try {
                if (!this._config_file.query_exists()) {
                    return;
                }
                
                uint8[] contents;
                this._config_file.load_contents(null, out contents, null);
                
                var parser = new Json.Parser();
                parser.load_from_data((string)contents);
                var root = parser.get_root().get_object();
                
                if (root.has_member("enabled")) this.enabled = root.get_boolean_member("enabled");
                if (root.has_member("status_code")) this.status_code = (int)root.get_int_member("status_code");
                if (root.has_member("content_type")) this.content_type = root.get_string_member("content_type");
                if (root.has_member("body")) this.body = root.get_string_member("body");
                
            } catch (Error e) {
                warning("Failed to load mock config: %s", e.message);
            }
        }
    }
}
