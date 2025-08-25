# Desktop file
desktop_file_configured = configure_file(
  input: 'io.github.tobagin.sonar.desktop.in',
  output: app_id + '.desktop.in.configured',
  configuration: conf_data,
)

desktop_file = i18n.merge_file(
  input: desktop_file_configured,
  output: app_id + '.desktop',
  type: 'desktop',
  po_dir: join_paths(meson.project_source_root(), 'po'),
  install: true,
  install_dir: join_paths(get_option('datadir'), 'applications'),
)

# Validate desktop file
desktop_file_validate = find_program('desktop-file-validate', required: false)
if desktop_file_validate.found()
  test('validate-desktop', desktop_file_validate, args: [desktop_file])
endif

# MetaInfo file  
metainfo_file_configured = configure_file(
  input: 'io.github.tobagin.sonar.metainfo.xml.in',
  output: app_id + '.metainfo.xml.configured',
  configuration: conf_data,
)

install_data(metainfo_file_configured,
  install_dir: join_paths(get_option('datadir'), 'metainfo'),
  rename: app_id + '.metainfo.xml'
)

# Validate MetaInfo file
appstream_util = find_program('appstream-util', required: false)
if appstream_util.found()
  test('validate-metainfo', appstream_util, args: ['validate-relax', metainfo_file_configured])
endif

# GSchema
gschema_file = configure_file(
  input: 'io.github.tobagin.sonar.gschema.xml.in',
  output: app_id + '.gschema.xml',
  configuration: conf_data
)

install_data(gschema_file,
  install_dir: join_paths(get_option('datadir'), 'glib-2.0/schemas')
)

# Compile GSchema for testing
compile_schemas = find_program('glib-compile-schemas', required: false)
if compile_schemas.found()
  test('validate-schema', compile_schemas, args: ['--strict', '--dry-run', meson.current_source_dir()])
endif

# Resources
subdir('ui')
subdir('icons')