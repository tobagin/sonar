/*
 * Filter manager for request filtering and search.
 */

using Gtk;
using GLib;
using Gee;

namespace Sonar {

    /**
     * Manages request filtering and search functionality.
     */
    public class FilterManager : GLib.Object {
        // Filter widgets
        private SearchEntry search_entry;
        private DropDown method_filter;
        private DropDown content_type_filter;
        private DropDown time_filter;
        private ToggleButton starred_only_toggle;

        // Filter state
        private string? filter_method = null;
        private string? filter_content_type = null;
        private string? filter_time_range = null;
        private string? filter_search_text = null;

        // References
        private RequestStorage storage;
        private HashMap<string, RequestRow> request_rows;

        public signal void filters_changed();

        public FilterManager(SearchEntry search_entry,
                           DropDown method_filter,
                           DropDown content_type_filter,
                           DropDown time_filter,
                           ToggleButton starred_only_toggle,
                           RequestStorage storage,
                           HashMap<string, RequestRow> request_rows) {
            this.search_entry = search_entry;
            this.method_filter = method_filter;
            this.content_type_filter = content_type_filter;
            this.time_filter = time_filter;
            this.starred_only_toggle = starred_only_toggle;
            this.storage = storage;
            this.request_rows = request_rows;

            this._setup_filter_dropdowns();
            this._connect_signals();
        }

        private void _setup_filter_dropdowns() {
            // HTTP Method filter
            var methods = new string[] {"All Methods", "GET", "POST", "PUT", "DELETE", "PATCH", "HEAD", "OPTIONS"};
            this.method_filter.set_model(new StringList(methods));
            this.method_filter.set_selected(0);

            // Content Type filter
            var content_types = new string[] {
                "All Types",
                "application/json",
                "application/x-www-form-urlencoded",
                "multipart/form-data",
                "text/plain",
                "text/html",
                "application/xml"
            };
            this.content_type_filter.set_model(new StringList(content_types));
            this.content_type_filter.set_selected(0);

            // Time filter
            var time_ranges = new string[] {
                "All Time",
                "Last 5 minutes",
                "Last 15 minutes",
                "Last 30 minutes",
                "Last hour",
                "Last 24 hours"
            };
            this.time_filter.set_model(new StringList(time_ranges));
            this.time_filter.set_selected(0);
        }

        private void _connect_signals() {
            this.search_entry.search_changed.connect(this._on_search_changed);
            this.method_filter.notify["selected"].connect(this._on_filter_changed);
            this.content_type_filter.notify["selected"].connect(this._on_filter_changed);
            this.time_filter.notify["selected"].connect(this._on_filter_changed);
            this.starred_only_toggle.toggled.connect(this._on_filter_changed);
        }

        private void _on_search_changed() {
            this.filter_search_text = this.search_entry.get_text().strip();
            this.apply_filters();
        }

        private void _on_filter_changed() {
            // Get selected filter values
            var method_idx = this.method_filter.get_selected();
            var content_type_idx = this.content_type_filter.get_selected();
            var time_idx = this.time_filter.get_selected();

            // Update filter state
            this.filter_method = method_idx > 0 ? this._get_method_from_index((int)method_idx) : null;
            this.filter_content_type = content_type_idx > 0 ? this._get_content_type_from_index((int)content_type_idx) : null;
            this.filter_time_range = time_idx > 0 ? this._get_time_range_from_index((int)time_idx) : null;

            // Apply filters
            this.apply_filters();
        }

        public void apply_filters() {
            // Iterate through all request rows and show/hide based on filters
            var requests = this.storage.get_requests();

            foreach (var request in requests) {
                var row = this.request_rows.get(request.id);
                if (row != null) {
                    bool should_show = this.request_matches_filters(request);
                    row.set_visible(should_show);
                }
            }

            filters_changed();
        }

        public bool request_matches_filters(WebhookRequest request) {
            // Starred filter
            if (this.starred_only_toggle.get_active() && !request.is_starred) {
                return false;
            }

            // Method filter
            if (this.filter_method != null && request.method != this.filter_method) {
                return false;
            }

            // Content type filter
            if (this.filter_content_type != null) {
                if (request.content_type == null || !request.content_type.contains(this.filter_content_type)) {
                    return false;
                }
            }

            // Time filter
            if (this.filter_time_range != null) {
                if (!this._is_within_time_range(request.timestamp, this.filter_time_range)) {
                    return false;
                }
            }

            // Search text filter
            if (this.filter_search_text != null && this.filter_search_text.length > 0) {
                string search_lower = this.filter_search_text.down();
                bool matches = request.path.down().contains(search_lower) ||
                              request.body.down().contains(search_lower);
                if (!matches) {
                    return false;
                }
            }

            return true;
        }

        public void clear_filters() {
            // Reset all filters
            this.method_filter.set_selected(0);
            this.content_type_filter.set_selected(0);
            this.time_filter.set_selected(0);
            this.search_entry.set_text("");
            this.starred_only_toggle.set_active(false);

            // Clear filter state
            this.filter_method = null;
            this.filter_content_type = null;
            this.filter_time_range = null;
            this.filter_search_text = null;

            // Refresh display
            this.apply_filters();
        }

        private bool _is_within_time_range(DateTime timestamp, string range) {
            var now = new DateTime.now_local();
            var diff = now.difference(timestamp);

            switch (range) {
                case "Last 5 minutes":
                    return diff <= 5 * TimeSpan.MINUTE;
                case "Last 15 minutes":
                    return diff <= 15 * TimeSpan.MINUTE;
                case "Last 30 minutes":
                    return diff <= 30 * TimeSpan.MINUTE;
                case "Last hour":
                    return diff <= TimeSpan.HOUR;
                case "Last 24 hours":
                    return diff <= 24 * TimeSpan.HOUR;
                default:
                    return true;
            }
        }

        private string? _get_method_from_index(int index) {
            switch (index) {
                case 1: return "GET";
                case 2: return "POST";
                case 3: return "PUT";
                case 4: return "DELETE";
                case 5: return "PATCH";
                case 6: return "HEAD";
                case 7: return "OPTIONS";
                default: return null;
            }
        }

        private string? _get_content_type_from_index(int index) {
            switch (index) {
                case 1: return "application/json";
                case 2: return "application/x-www-form-urlencoded";
                case 3: return "multipart/form-data";
                case 4: return "text/plain";
                case 5: return "text/html";
                case 6: return "application/xml";
                default: return null;
            }
        }

        private string? _get_time_range_from_index(int index) {
            switch (index) {
                case 1: return "Last 5 minutes";
                case 2: return "Last 15 minutes";
                case 3: return "Last 30 minutes";
                case 4: return "Last hour";
                case 5: return "Last 24 hours";
                default: return null;
            }
        }
    }
}
