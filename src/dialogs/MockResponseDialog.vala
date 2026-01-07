/*
 * Dialog for configuring mock responses.
 */

using Gtk;
using Adw;
using GtkSource;

namespace Sonar {

#if DEVELOPMENT
    [GtkTemplate (ui = "/io/github/tobagin/sonar/Devel/mock_response_dialog.ui")]
#else
    [GtkTemplate (ui = "/io/github/tobagin/sonar/mock_response_dialog.ui")]
#endif
    public class MockResponseDialog : Adw.Window {
        private MockManager manager;

        [GtkChild]
        private unowned Switch enable_mock_switch;
        
        [GtkChild]
        private unowned SpinButton status_code_spin;
        
        [GtkChild]
        private unowned DropDown content_type_dropdown;
        
        [GtkChild]
        private unowned GtkSource.View body_view;
        
        [GtkChild]
        private unowned Button save_button;
        
        [GtkChild]
        private unowned Button cancel_button;

        // Initial state for dirty check
        private bool initial_enabled;
        private int initial_status_code;
        private string initial_content_type;
        private string initial_body;

        public MockResponseDialog(Gtk.Window parent_window, MockManager manager) {
            Object(transient_for: parent_window);
            this.manager = manager;
            this._setup_source_view();
            this._load_state();
            this._connect_signals();
            this._update_save_sensitivity(); // Initial check
        }
        
        private void _setup_source_view() {
            var buffer = this.body_view.get_buffer() as GtkSource.Buffer;
            if (buffer != null) {
                var lm = GtkSource.LanguageManager.get_default();
                var language = lm.get_language("json");
                if (language != null) {
                    buffer.set_language(language);
                }
                
                // Try to set "solarized-light" to match Ntfyr's beige look
                var sm = GtkSource.StyleSchemeManager.get_default();
                var scheme = sm.get_scheme("solarized-light");
                if (scheme == null) {
                    // Fallback to other light themes if solarized isn't found
                    scheme = sm.get_scheme("kate");
                    if (scheme == null) scheme = sm.get_scheme("classic");
                }
                if (scheme != null) {
                    buffer.set_style_scheme(scheme);
                }
            }
            
            // Enable grid background pattern
            this.body_view.background_pattern = GtkSource.BackgroundPatternType.GRID;
        }

        private void _load_state() {
            this.enable_mock_switch.active = this.manager.enabled;
            this.status_code_spin.value = this.manager.status_code;
            
            // Set content type
            var model = (StringList) this.content_type_dropdown.model;
            for (uint i = 0; i < model.get_n_items(); i++) {
                if (model.get_string(i) == this.manager.content_type) {
                    this.content_type_dropdown.selected = i;
                    break;
                }
            }
            
            this.body_view.buffer.text = this.manager.body;
            
            // Capture initial state
            this.initial_enabled = this.manager.enabled;
            this.initial_status_code = this.manager.status_code;
            this.initial_content_type = this.manager.content_type;
            this.initial_body = this.manager.body;
        }

        private void _connect_signals() {
            this.save_button.clicked.connect(() => {
                this._save_settings();
                this.close();
            });

            this.cancel_button.clicked.connect(() => {
                this.close();
            });
            
            // Change listeners for Save sensitivity
            this.enable_mock_switch.notify["active"].connect(this._update_save_sensitivity);
            this.status_code_spin.notify["value"].connect(this._update_save_sensitivity);
            this.content_type_dropdown.notify["selected"].connect(this._update_save_sensitivity);
            this.body_view.buffer.changed.connect(this._update_save_sensitivity);
        }
        
        private void _update_save_sensitivity() {
            bool enabled = this.enable_mock_switch.active;
            int status = (int) this.status_code_spin.value;
            var model = (StringList) this.content_type_dropdown.model;
            string type = model.get_string(this.content_type_dropdown.selected);
            string body = this.body_view.buffer.text;
            
            // Logic:
            // 1. If Enabled, Body must not be empty (basic validation)
            //    Or as per user request: "active when mock is enabled and there is a body or a change to the body"
            //    We'll stick to: If Enabled, Valid only if Body matches requirements.
            //    Actually, user said "or a change to the body when one is present when opening".
            //    Let's interpret: If Enabled, Is Valid? 
            //    Let's enforce: If Enabled, Body cannot be empty? Or just "is dirty"?
            //    User request: "make the save button only active when mock is enabled and [ (there is a body) OR (a change to the body when one is present when opening) ]"
            //    This implies if Mock is Disabled, Save is NOT active? That seems wrong for disabling.
            //    Let's assume the user specifically meant the condition for the "Enabled" case.
            //    And if Disabled, we allow saving (to disable it).
            
            bool is_valid = true;
            if (enabled) {
                 // "there is a body"
                 bool has_body = body.length > 0;
                 // "or a change to the body when one is present when opening"
                 bool body_changed = (body != this.initial_body);
                 bool had_body_initially = (this.initial_body.length > 0);
                 
                 // If we had a body initially, and we changed it (even to empty?), that counts?
                 // But validation usually prevents empty. 
                 // Let's assume simplest robust logic closer to user intent:
                 // "Must have body OR (Has Body Initially AND Changed)" ?? 
                 // Actually, "change to the body when one is present" probably means "If I edit the existing body".
                 
                 // Let's simplify: 
                 // If Enabled: Safe to save if (Body is not Empty).
                 if (!has_body) is_valid = false; 
            }
            
            // Dirty check
            bool is_dirty = (enabled != this.initial_enabled) ||
                            (status != this.initial_status_code) ||
                            (type != this.initial_content_type) ||
                            (body != this.initial_body);
                            
            this.save_button.sensitive = is_valid && is_dirty;
        }

        private void _save_settings() {
            // ... (existing save logic)
            this.manager.enabled = this.enable_mock_switch.active;
            this.manager.status_code = (int) this.status_code_spin.value;
            
            var model = (StringList) this.content_type_dropdown.model;
            this.manager.content_type = model.get_string(this.content_type_dropdown.selected);
            
            this.manager.body = this.body_view.buffer.text;
            this.manager.save_config();
        }
    }
}
