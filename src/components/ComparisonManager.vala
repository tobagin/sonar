/*
 * Request comparison manager component.
 */

using Gtk;
using Adw;
using GLib;
using Pango;
using Gee;

namespace Sonar {

    /**
     * Manages request comparison functionality.
     */
    public class ComparisonManager : GLib.Object {
        private MainWindow parent_window;
        private WebhookRequest? comparison_request = null;
        private HashMap<string, RequestRow> request_rows;

        public signal void show_toast(string message, int timeout = 3);
        public signal void comparison_state_changed();

        public ComparisonManager(MainWindow parent_window, HashMap<string, RequestRow> request_rows) {
            this.parent_window = parent_window;
            this.request_rows = request_rows;
        }

        public void select_for_comparison(WebhookRequest request) {
            this.comparison_request = request;

            // Enable compare buttons on all request rows
            this._update_compare_buttons_state();

            show_toast(@"Selected request for comparison. Click Compare on another request to see differences.");
            comparison_state_changed();
        }

        public void compare_with_selected(WebhookRequest request) {
            if (this.comparison_request == null) {
                show_toast("Please select a request for comparison first");
                return;
            }

            this._show_comparison_dialog(this.comparison_request, request);
        }

        public WebhookRequest? get_comparison_request() {
            return this.comparison_request;
        }

        private void _update_compare_buttons_state() {
            // Update all request rows to enable/disable compare button
            foreach (var entry in this.request_rows.entries) {
                var row = entry.value;
                row.update_compare_button_state(this.comparison_request != null);
            }
        }

        private void _show_comparison_dialog(WebhookRequest request1, WebhookRequest request2) {
            var dialog = new Adw.Dialog();
            dialog.set_title("Compare Requests");
            dialog.set_content_width(1000);
            dialog.set_content_height(700);

            // Create toolbar with close button
            var toolbar = new Adw.ToolbarView();
            var header = new Adw.HeaderBar();
            toolbar.add_top_bar(header);

            // Create scrolled window for comparison content
            var scrolled = new ScrolledWindow();
            scrolled.set_vexpand(true);

            // Main comparison layout
            var main_box = new Box(Orientation.VERTICAL, 12);
            main_box.set_margin_top(12);
            main_box.set_margin_bottom(12);
            main_box.set_margin_start(12);
            main_box.set_margin_end(12);

            // Request headers
            var header_box = new Box(Orientation.HORIZONTAL, 12);
            header_box.set_homogeneous(true);

            var request1_header = this._create_request_header_box(request1, "Request 1");
            var request2_header = this._create_request_header_box(request2, "Request 2");

            header_box.append(request1_header);
            header_box.append(request2_header);
            main_box.append(header_box);

            // Comparison sections
            main_box.append(this._create_comparison_section("Method",
                request1.method, request2.method, request1.method != request2.method));

            main_box.append(this._create_comparison_section("Path",
                request1.path, request2.path, request1.path != request2.path));

            main_box.append(this._create_comparison_section("Content-Type",
                request1.content_type ?? "N/A",
                request2.content_type ?? "N/A",
                request1.content_type != request2.content_type));

            main_box.append(this._create_comparison_text_section("Headers",
                request1.get_formatted_headers(),
                request2.get_formatted_headers()));

            main_box.append(this._create_comparison_text_section("Body",
                request1.get_formatted_body(),
                request2.get_formatted_body()));

            scrolled.set_child(main_box);
            toolbar.set_content(scrolled);
            dialog.set_child(toolbar);

            dialog.present(this.parent_window);

            // Clear comparison selection after showing dialog
            this.comparison_request = null;
            this._update_compare_buttons_state();
            comparison_state_changed();
        }

        private Box _create_request_header_box(WebhookRequest request, string title) {
            var box = new Box(Orientation.VERTICAL, 6);

            var title_label = new Label(title);
            title_label.add_css_class("title-3");
            title_label.set_xalign(0);

            var time_label = new Label(request.timestamp.format("%Y-%m-%d %H:%M:%S"));
            time_label.add_css_class("dim-label");
            time_label.set_xalign(0);

            box.append(title_label);
            box.append(time_label);

            return box;
        }

        private Box _create_comparison_section(string label, string value1, string value2, bool different) {
            var box = new Box(Orientation.VERTICAL, 6);

            var label_widget = new Label(label);
            label_widget.add_css_class("heading");
            label_widget.set_xalign(0);
            box.append(label_widget);

            var values_box = new Box(Orientation.HORIZONTAL, 12);
            values_box.set_homogeneous(true);

            var value1_box = new Box(Orientation.VERTICAL, 0);
            var value1_label = new Label(value1);
            value1_label.set_xalign(0);
            value1_label.set_wrap(true);
            value1_label.set_wrap_mode(Pango.WrapMode.WORD_CHAR);
            if (different) {
                value1_label.add_css_class("warning");
            }
            value1_box.append(value1_label);

            var value2_box = new Box(Orientation.VERTICAL, 0);
            var value2_label = new Label(value2);
            value2_label.set_xalign(0);
            value2_label.set_wrap(true);
            value2_label.set_wrap_mode(Pango.WrapMode.WORD_CHAR);
            if (different) {
                value2_label.add_css_class("warning");
            }
            value2_box.append(value2_label);

            values_box.append(value1_box);
            values_box.append(value2_box);
            box.append(values_box);

            return box;
        }

        private Box _create_comparison_text_section(string label, string text1, string text2) {
            var box = new Box(Orientation.VERTICAL, 6);

            var label_widget = new Label(label);
            label_widget.add_css_class("heading");
            label_widget.set_xalign(0);
            box.append(label_widget);

            var text_box = new Box(Orientation.HORIZONTAL, 12);
            text_box.set_homogeneous(true);

            // Text view 1
            var scrolled1 = new ScrolledWindow();
            scrolled1.set_vexpand(true);
            scrolled1.set_min_content_height(150);
            var text_view1 = new TextView();
            text_view1.set_editable(false);
            text_view1.set_monospace(true);
            text_view1.set_wrap_mode(Gtk.WrapMode.WORD_CHAR);
            text_view1.get_buffer().set_text(text1, -1);
            scrolled1.set_child(text_view1);

            // Text view 2
            var scrolled2 = new ScrolledWindow();
            scrolled2.set_vexpand(true);
            scrolled2.set_min_content_height(150);
            var text_view2 = new TextView();
            text_view2.set_editable(false);
            text_view2.set_monospace(true);
            text_view2.set_wrap_mode(Gtk.WrapMode.WORD_CHAR);
            text_view2.get_buffer().set_text(text2, -1);
            scrolled2.set_child(text_view2);

            text_box.append(scrolled1);
            text_box.append(scrolled2);
            box.append(text_box);

            return box;
        }
    }
}
