# Vala sources
vala_sources = [
  'Application.vala',
  'MainWindow.vala',
  'models/Models.vala',
  'managers/Server.vala',
  'managers/Tunnel.vala',
  'utils/RequestRow.vala',
  'dialogs/PreferencesDialog.vala',
  'dialogs/ShortcutsDialog.vala',
  'dialogs/StatisticsDialog.vala',
]

# Dependencies
dependencies = [
  gtk_dep,
  adw_dep,
  gio_dep,
  json_glib_dep,
  libsoup_dep,
  gee_dep,
]

# Compile the application
sonar_exe = executable(meson.project_name(),
  vala_sources,
  config_vala,
  ui_resources,
  dependencies: dependencies + [math_dep],
  install: true,
  vala_args: vala_args,
  c_args: c_args,
)