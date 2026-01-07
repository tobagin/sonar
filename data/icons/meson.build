# Install application icon (SVG)
if get_option('profile') == 'development'
  icon_name = 'io.github.tobagin.sonar.Devel.svg'
else
  icon_name = 'io.github.tobagin.sonar.svg'
endif

install_data(
  join_paths('hicolor', 'scalable', 'apps', icon_name),
  install_dir: join_paths(get_option('datadir'), 'icons', 'hicolor', 'scalable', 'apps'),
  rename: app_id + '.svg'
)

# Install symbolic icons
install_data(
  join_paths('hicolor', 'scalable', 'actions', 'io.github.tobagin.sonar-filter-symbolic.svg'),
  install_dir: join_paths(get_option('datadir'), 'icons', 'hicolor', 'scalable', 'actions')
)