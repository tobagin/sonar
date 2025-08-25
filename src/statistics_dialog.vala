/**
 * Statistics dialog for the Sonar webhook inspector application.
 * 
 * This class displays comprehensive analytics about webhook requests including
 * method distribution, content types, endpoint usage, and timeline data.
 */

using Gtk;
using Adw;
using Gee;

namespace Sonar {
#if DEVELOPMENT
    [GtkTemplate (ui = "/io/github/tobagin/sonar/Devel/statistics_dialog.ui")]
#else
    [GtkTemplate (ui = "/io/github/tobagin/sonar/statistics_dialog.ui")]
#endif
    public class StatisticsDialog : Adw.Dialog {
        [GtkChild] private unowned Label total_requests_label;
        [GtkChild] private unowned Label unique_endpoints_label;
        [GtkChild] private unowned Label avg_size_label;
        [GtkChild] private unowned ListBox methods_list;
        [GtkChild] private unowned ListBox content_types_list;
        [GtkChild] private unowned ListBox endpoints_list;
        
        private RequestStorage storage;
        
        /**
         * Create a new statistics dialog.
         */
        public StatisticsDialog(RequestStorage storage) {
            Object();
            this.storage = storage;
            
            this.title = _("Request Statistics");
            
            // Load and display statistics
            this._load_statistics();
        }
        
        private void _load_statistics() {
            var all_requests = new ArrayList<WebhookRequest>();
            
            // Get current requests
            var current_requests = this.storage.get_requests();
            all_requests.add_all(current_requests);
            
            // Get history requests
            var history_requests = this.storage.get_history();
            all_requests.add_all(history_requests);
            
            if (all_requests.size == 0) {
                this._show_empty_state();
                return;
            }
            
            this._update_summary_cards(all_requests);
            this._update_methods_chart(all_requests);
            this._update_content_types_chart(all_requests);
            this._update_endpoints_list(all_requests);
        }
        
        private void _show_empty_state() {
            this.total_requests_label.set_text("0");
            this.unique_endpoints_label.set_text("0");
            this.avg_size_label.set_text("0 B");
            
            // Add empty state message
            var empty_label = new Label(_("No request data available yet.\nStart capturing webhooks to see statistics."));
            empty_label.set_justify(Justification.CENTER);
            empty_label.add_css_class("dim-label");
            
            
            // Add empty row to methods list
            var empty_row = new Adw.ActionRow();
            empty_row.set_title(_("No data available"));
            empty_row.set_subtitle(_("Start capturing webhooks to see statistics"));
            this.methods_list.append(empty_row);
        }
        
        private void _update_summary_cards(ArrayList<WebhookRequest> requests) {
            // Total requests
            this.total_requests_label.set_text(requests.size.to_string());
            
            // Unique endpoints
            var unique_paths = new HashSet<string>();
            int64 total_size = 0;
            
            foreach (var request in requests) {
                unique_paths.add(request.path);
                total_size += request.body.length;
            }
            
            this.unique_endpoints_label.set_text(unique_paths.size.to_string());
            
            // Average size
            if (requests.size > 0) {
                int64 avg_size = total_size / requests.size;
                this.avg_size_label.set_text(this._format_size(avg_size));
            } else {
                this.avg_size_label.set_text("0 B");
            }
        }
        
        private void _update_methods_chart(ArrayList<WebhookRequest> requests) {
            var method_counts = new HashMap<string, int>();
            
            // Count methods
            foreach (var request in requests) {
                string method = request.method;
                if (method_counts.has_key(method)) {
                    method_counts[method] = method_counts[method] + 1;
                } else {
                    method_counts[method] = 1;
                }
            }
            
            // Sort by count (descending)
            var sorted_methods = new ArrayList<Map.Entry<string, int>>();
            foreach (var entry in method_counts.entries) {
                sorted_methods.add(entry);
            }
            sorted_methods.sort((a, b) => {
                return b.value - a.value;
            });
            
            // Create ActionRows for methods
            foreach (var entry in sorted_methods) {
                var row = new Adw.ActionRow();
                
                double percentage = ((double)entry.value / requests.size) * 100;
                row.set_title(@"$(entry.value) requests ($(Math.round(percentage))%)");
                
                // Add method color indicator
                var method_label = new Label(entry.key);
                method_label.add_css_class("tag");
                method_label.add_css_class(this._get_method_color(entry.key));
                row.add_prefix(method_label);
                
                // Add progress bar
                var progress = new ProgressBar();
                progress.set_fraction((double)entry.value / requests.size);
                progress.set_valign(Align.CENTER);
                progress.add_css_class(this._get_method_color(entry.key));
                row.add_suffix(progress);
                
                this.methods_list.append(row);
            }
        }
        
        private void _update_content_types_chart(ArrayList<WebhookRequest> requests) {
            var content_type_counts = new HashMap<string, int>();
            
            // Count content types
            foreach (var request in requests) {
                string content_type = request.content_type ?? "unknown";
                
                // Simplify content type (remove charset, etc.)
                string[] parts = content_type.split(";");
                string clean_type = parts.length > 0 ? parts[0].strip() : content_type;
                
                if (content_type_counts.has_key(clean_type)) {
                    content_type_counts[clean_type] = content_type_counts[clean_type] + 1;
                } else {
                    content_type_counts[clean_type] = 1;
                }
            }
            
            // Sort by count (descending)
            var sorted_types = new ArrayList<Map.Entry<string, int>>();
            foreach (var entry in content_type_counts.entries) {
                sorted_types.add(entry);
            }
            sorted_types.sort((a, b) => {
                return b.value - a.value;
            });
            
            // Create ActionRows for content types (limit to top 10)
            int count = 0;
            foreach (var entry in sorted_types) {
                if (count >= 10) break;
                
                var row = new Adw.ActionRow();
                
                double percentage = ((double)entry.value / requests.size) * 100;
                row.set_title(@"$(entry.value) requests ($(Math.round(percentage))%)");
                row.set_subtitle(entry.key);
                
                // Add progress bar
                var progress = new ProgressBar();
                progress.set_fraction((double)entry.value / requests.size);
                progress.set_valign(Align.CENTER);
                progress.add_css_class("accent");
                row.add_suffix(progress);
                
                this.content_types_list.append(row);
                count++;
            }
        }
        
        private void _update_endpoints_list(ArrayList<WebhookRequest> requests) {
            var endpoint_counts = new HashMap<string, int>();
            
            // Count endpoints
            foreach (var request in requests) {
                string path = request.path;
                if (endpoint_counts.has_key(path)) {
                    endpoint_counts[path] = endpoint_counts[path] + 1;
                } else {
                    endpoint_counts[path] = 1;
                }
            }
            
            // Sort by count (descending)
            var sorted_endpoints = new ArrayList<Map.Entry<string, int>>();
            foreach (var entry in endpoint_counts.entries) {
                sorted_endpoints.add(entry);
            }
            sorted_endpoints.sort((a, b) => {
                return b.value - a.value;
            });
            
            // Add to list (limit to top 10)
            int count = 0;
            foreach (var entry in sorted_endpoints) {
                if (count >= 10) break;
                
                var row = new Adw.ActionRow();
                row.set_title(entry.key);
                row.set_subtitle(@"$(entry.value) requests");
                
                var count_label = new Label(entry.value.to_string());
                count_label.add_css_class("title-3");
                count_label.set_valign(Align.CENTER);
                row.add_suffix(count_label);
                
                this.endpoints_list.append(row);
                count++;
            }
        }
        
        
        private string _get_method_color(string method) {
            switch (method.up()) {
                case "GET":
                    return "success";
                case "POST":
                    return "accent";
                case "PUT":
                    return "warning";
                case "DELETE":
                    return "error";
                case "PATCH":
                    return "accent";
                default:
                    return "neutral";
            }
        }
        
        private string _format_size(int64 size_bytes) {
            if (size_bytes < 1024) {
                return @"$(size_bytes) B";
            } else if (size_bytes < 1024 * 1024) {
                return @"$(size_bytes / 1024) KB";
            } else {
                return @"$(size_bytes / (1024 * 1024)) MB";
            }
        }
    }
}