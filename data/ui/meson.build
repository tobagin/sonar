# Blueprint compiler
blueprint_compiler = find_program('blueprint-compiler', required: true)

# Compile blueprints
blueprints = []

# Compile main_window.blp
main_window_ui = custom_target(
  'main_window.ui',
  input: files('main_window.blp'),
  output: 'main_window.ui',
  command: [
    blueprint_compiler,
    'compile',
    '--output', '@OUTPUT@',
    '@INPUT@'
  ]
)
blueprints += main_window_ui

# Compile request_row.blp
request_row_ui = custom_target(
  'request_row.ui',
  input: files('request_row.blp'),
  output: 'request_row.ui',
  command: [
    blueprint_compiler,
    'compile',
    '--output', '@OUTPUT@',
    '@INPUT@'
  ]
)
blueprints += request_row_ui

# Compile preferences.blp
preferences_ui = custom_target(
  'preferences.ui',
  input: files('preferences.blp'),
  output: 'preferences.ui',
  command: [
    blueprint_compiler,
    'compile',
    '--output', '@OUTPUT@',
    '@INPUT@'
  ]
)
blueprints += preferences_ui

# Compile shortcuts_dialog.blp
shortcuts_dialog_ui = custom_target(
  'shortcuts_dialog.ui',
  input: files('shortcuts_dialog.blp'),
  output: 'shortcuts_dialog.ui',
  command: [
    blueprint_compiler,
    'compile',
    '--output', '@OUTPUT@',
    '@INPUT@'
  ]
)
blueprints += shortcuts_dialog_ui

# Compile statistics_dialog.blp
statistics_dialog_ui = custom_target(
  'statistics_dialog.ui',
  input: files('statistics_dialog.blp'),
  output: 'statistics_dialog.ui',
  command: [
    blueprint_compiler,
    'compile',
    '--output', '@OUTPUT@',
    '@INPUT@'
  ]
)
blueprints += statistics_dialog_ui

# Compile mock_response_dialog.blp
mock_response_dialog_ui = custom_target(
  'mock_response_dialog.ui',
  input: files('mock_response_dialog.blp'),
  output: 'mock_response_dialog.ui',
  command: [
    blueprint_compiler,
    'compile',
    '--output', '@OUTPUT@',
    '@INPUT@'
  ]
)
blueprints += mock_response_dialog_ui

# Get configuration data from parent
conf_data = get_variable('conf_data')

# Generate GResource XML from template  
gresource_xml = configure_file(
  input: 'sonar.gresource.xml.in',
  output: 'sonar.gresource.xml',
  configuration: conf_data
)

# Create GResource
ui_resources = gnome.compile_resources(
  'sonar-resources',
  gresource_xml,
  source_dir: meson.current_source_dir(),
  dependencies: blueprints,
)

# Make ui_resources available to parent
set_variable('ui_resources', ui_resources)