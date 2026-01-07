# Library sources (core logic + UI)
lib_sources = [
  'MainWindow.vala',
  'models/Models.vala',
  'managers/MockManager.vala',
  'managers/RateLimiter.vala',
  'managers/SecurityManager.vala',
  'managers/Server.vala',
  'managers/Tunnel.vala',
  'utils/ExportUtils.vala',
  'utils/ImportUtils.vala',
  'utils/RequestIndex.vala',
  'utils/RequestRow.vala',
  'utils/SignatureValidator.vala',
  'utils/ValidationUtils.vala',
  'dialogs/PreferencesDialog.vala',
  'dialogs/MockResponseDialog.vala',
  'dialogs/ShortcutsDialog.vala',
  'dialogs/StatisticsDialog.vala',
]

# Application entry point
app_sources = [
  'Application.vala',
]

# Dependencies
dependencies = [
  gtk_dep,
  adw_dep,
  gio_dep,
  json_glib_dep,
  libsoup_dep,
  gee_dep,
  libsecret_dep,
  gtksource_dep,
]

# Create static library for core logic (to be shared with tests)
libsonar = static_library('sonar-core',
  lib_sources,
  config_vala,
  ui_resources,
  dependencies: dependencies,
  vala_args: vala_args,
  c_args: c_args,
)

# Declare dependency for the library
sonar_dep = declare_dependency(
  link_with: libsonar,
  dependencies: dependencies + [math_dep],
  include_directories: include_directories('.'),
)

# Compile the application
sonar_exe = executable(meson.project_name(),
  app_sources,
  ui_resources,
  dependencies: [sonar_dep],
  install: true,
  vala_args: vala_args,
  c_args: c_args,
)