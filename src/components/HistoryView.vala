/*
 * History view component for managing request history.
 */

using Gtk;
using Adw;
using GLib;
using Json;

namespace Sonar {

    /**
     * Manages the history view display and interactions.
     */
    public class HistoryView : GLib.Object {
        // UI widgets
        private ListBox history_list;
        private SearchEntry search_entry;
        private DropDown method_filter;
        private MainWindow parent_window;

        // References
        private RequestStorage storage;

        public signal void history_item_deleted(string request_id);
        public signal void show_toast(string message, int timeout = 3);

        public HistoryView(ListBox history_list,
                          SearchEntry search_entry,
                          DropDown method_filter,
                          MainWindow parent_window,
                          RequestStorage storage) {
            this.history_list = history_list;
            this.search_entry = search_entry;
            this.method_filter = method_filter;
            this.parent_window = parent_window;
            this.storage = storage;

            this._setup_method_filter();
            this._connect_signals();
        }

        private void _setup_method_filter() {
            // Create a string list with HTTP methods
            var methods = new StringList(null);
            methods.append("All Methods");
            methods.append("GET");
            methods.append("POST");
            methods.append("PUT");
            methods.append("PATCH");
            methods.append("DELETE");
            methods.append("HEAD");
            methods.append("OPTIONS");

            // Set the model for the dropdown
            this.method_filter.set_model(methods);
            this.method_filter.set_selected(0); // Default to "All Methods"
        }

        private void _connect_signals() {
            this.search_entry.search_changed.connect(this._on_search_changed);
            this.method_filter.notify["selected"].connect(this._on_method_filter_changed);
        }

        private void _on_search_changed() {
            string search_text = this.search_entry.get_text().strip().down();
            this._filter_history(search_text);
        }

        private void _on_method_filter_changed() {
            // Trigger filtering when method selection changes
            string search_text = this.search_entry.get_text().strip().down();
            this._filter_history(search_text);
        }

        public void load_history() {
            // Clear existing history items
            Widget? child = this.history_list.get_first_child();
            while (child != null) {
                var next = child.get_next_sibling();
                this.history_list.remove(child);
                child = next;
            }

            // Load history requests
            var history = this.storage.get_history();
            foreach (var request in history) {
                var row = new RequestRow(request, this.parent_window, true); // History mode
                this.history_list.append(row);
            }
        }

        private void _filter_history(string search_text) {
            // Get selected method filter
            var methods_model = this.method_filter.get_model() as StringList;
            string? selected_method = null;
            if (methods_model != null) {
                uint selected_index = this.method_filter.get_selected();
                selected_method = methods_model.get_string(selected_index);
            }

            // Filter implementation with both search text and method
            Widget? child = this.history_list.get_first_child();
            while (child != null) {
                if (child is RequestRow) {
                    var row = child as RequestRow;
                    var request = row.get_request();

                    // Check search text match
                    bool text_matches = search_text.length == 0 ||
                                      request.method.down().contains(search_text) ||
                                      request.path.down().contains(search_text) ||
                                      request.body.down().contains(search_text);

                    // Check method filter match
                    bool method_matches = selected_method == null ||
                                        selected_method == "All Methods" ||
                                        request.method == selected_method;

                    // Show row only if both filters match
                    child.set_visible(text_matches && method_matches);
                }
                child = child.get_next_sibling();
            }
        }

        public void export_history() {
            var history = this.storage.get_history();

            if (history.size == 0) {
                show_toast("No history to export");
                return;
            }

            // Create file chooser dialog
            var file_dialog = new Gtk.FileDialog();
            file_dialog.set_title("Export History");
            file_dialog.set_initial_name("sonar-history.json");

            // Set up file filters
            var json_filter = new Gtk.FileFilter();
            json_filter.add_pattern("*.json");
            json_filter.add_suffix("json");

            var all_filter = new Gtk.FileFilter();
            all_filter.add_pattern("*");

            var filters = new GLib.ListStore(typeof(Gtk.FileFilter));
            filters.append(json_filter);
            filters.append(all_filter);
            file_dialog.set_filters(filters);

            file_dialog.save.begin(this.parent_window, null, (obj, res) => {
                try {
                    var file = file_dialog.save.end(res);
                    this._save_history_to_file(file);
                } catch (Error e) {
                    // User cancelled or error occurred
                    if (!(e is Gtk.DialogError.CANCELLED)) {
                        show_toast("Export cancelled");
                    }
                }
            });
        }

        private void _save_history_to_file(File file) {
            try {
                var history = this.storage.get_history();

                var builder = new Json.Builder();
                builder.begin_object();
                builder.set_member_name("exported_at");
                builder.add_string_value(new DateTime.now_utc().format_iso8601());
                builder.set_member_name("total_requests");
                builder.add_int_value(history.size);
                builder.set_member_name("requests");
                builder.begin_array();

                foreach (var request in history) {
                    builder.add_value(request.to_json());
                }

                builder.end_array();
                builder.end_object();

                var gen = new Json.Generator();
                gen.set_root(builder.get_root());
                gen.pretty = true;
                gen.indent = 2;

                var json_data = gen.to_data(null);

                file.replace_contents(json_data.data, null, false,
                                    FileCreateFlags.REPLACE_DESTINATION, null);

                show_toast(@"History exported to $(file.get_basename())");

            } catch (Error e) {
                show_toast(@"Export failed: $(e.message)");
            }
        }

        public void show_clear_confirmation() {
            var dialog = new Adw.AlertDialog(
                _("Clear All History"),
                _("Are you sure you want to clear all request history? This action cannot be undone.")
            );

            dialog.add_response("cancel", _("Cancel"));
            dialog.add_response("clear", _("Clear History"));
            dialog.set_response_appearance("clear", Adw.ResponseAppearance.DESTRUCTIVE);
            dialog.set_default_response("cancel");
            dialog.set_close_response("cancel");

            dialog.response.connect((response) => {
                if (response == "clear") {
                    this.storage.clear_history();
                    this.load_history(); // Refresh the history view
                    show_toast("History cleared");
                }
            });

            dialog.present(this.parent_window);
        }

        public void show_delete_item_confirmation(string request_id) {
            var dialog = new Adw.AlertDialog(
                _("Delete Request"),
                _("Are you sure you want to delete this request from history? This action cannot be undone.")
            );

            dialog.add_response("cancel", _("Cancel"));
            dialog.add_response("delete", _("Delete"));
            dialog.set_response_appearance("delete", Adw.ResponseAppearance.DESTRUCTIVE);
            dialog.set_default_response("cancel");
            dialog.set_close_response("cancel");

            dialog.response.connect((response) => {
                if (response == "delete") {
                    if (this.storage.remove_from_history(request_id)) {
                        this.load_history(); // Refresh the history view
                        show_toast("Request deleted from history");
                        history_item_deleted(request_id);
                    }
                }
            });

            dialog.present(this.parent_window);
        }

        public void show_statistics() {
            var dialog = new StatisticsDialog(this.storage);
            dialog.present(this.parent_window);
        }
    }
}
