# Vala sources
vala_sources = [
  'Application.vala',
  'MainWindow.vala',
  'models/Models.vala',
  'managers/RateLimiter.vala',
  'managers/SecurityManager.vala',
  'managers/Server.vala',
  'managers/Tunnel.vala',
  'utils/ExportUtils.vala',
  'utils/RequestIndex.vala',
  'utils/RequestRow.vala',
  'utils/SignatureValidator.vala',
  'utils/ValidationUtils.vala',
  # Components disabled due to circular reference crash (Task 2.1)
  # 'components/FilterManager.vala',
  # 'components/HistoryView.vala',
  # 'components/ComparisonManager.vala',
  # 'components/TunnelController.vala',
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
  libsecret_dep,
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