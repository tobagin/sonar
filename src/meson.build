# Vala sources
vala_sources = [
  'application.vala',
  'main_window.vala',
  'models.vala',
  'server.vala',
  'tunnel.vala',
  'request_row.vala',
  'preferences_dialog.vala',
  'shortcuts_dialog.vala',
  'statistics_dialog.vala',
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