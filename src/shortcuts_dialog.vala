/**
 * Keyboard shortcuts dialog for the Sonar webhook inspector application.
 * 
 * This class displays all available keyboard shortcuts in an organized manner
 * using Libadwaita components for a professional interface.
 */

using Gtk;
using Adw;

namespace Sonar {
#if DEVELOPMENT
    [GtkTemplate (ui = "/io/github/tobagin/sonar/Devel/shortcuts_dialog.ui")]
#else
    [GtkTemplate (ui = "/io/github/tobagin/sonar/shortcuts_dialog.ui")]
#endif
    public class ShortcutsDialog : Adw.Dialog {
        
        /**
         * Create a new keyboard shortcuts dialog.
         */
        public ShortcutsDialog() {
            GLib.Object();
            
            // Set dialog properties
            this.title = _("Keyboard Shortcuts");
            
            // Setup dialog
            setup_dialog();
        }
        
        private void setup_dialog() {
            // The UI is defined in the Blueprint template
            // This method can be used for additional setup if needed
        }
        
        /**
         * Show the keyboard shortcuts dialog.
         */
        public void show_dialog(Gtk.Widget parent) {
            this.present(parent);
        }
    }
}