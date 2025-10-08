/**
 * Keyboard shortcuts dialog for the Sonar webhook inspector application.
 *
 * This class displays all available keyboard shortcuts in an organized manner
 * using Libadwaita's ShortcutsDialog component.
 */

using Gtk;
using Adw;

namespace Sonar {
    public class ShortcutsDialog : GLib.Object {
        private Adw.ShortcutsDialog dialog;

        /**
         * Create a new keyboard shortcuts dialog.
         */
        public ShortcutsDialog() {
            GLib.Object();
            create_dialog();
        }

        private void create_dialog() {
#if DEVELOPMENT
            string resource_path = "/io/github/tobagin/sonar/Devel/shortcuts_dialog.ui";
#else
            string resource_path = "/io/github/tobagin/sonar/shortcuts_dialog.ui";
#endif

            try {
                var builder = new Gtk.Builder();
                builder.add_from_resource(resource_path);
                this.dialog = builder.get_object("shortcuts_dialog") as Adw.ShortcutsDialog;
            } catch (Error e) {
                critical("Failed to load shortcuts dialog: %s", e.message);
            }
        }

        /**
         * Show the keyboard shortcuts dialog.
         */
        public void present(Gtk.Widget parent) {
            if (this.dialog != null) {
                this.dialog.present(parent);
            }
        }
    }
}