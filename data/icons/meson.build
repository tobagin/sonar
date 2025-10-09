# Install application icons
icon_sizes = ['16', '32', '48', '64', '128', '256', '512']

foreach size : icon_sizes
  install_data(
    join_paths('hicolor', '@0@x@0@'.format(size), 'apps', 'io.github.tobagin.sonar.png'),
    install_dir: join_paths(get_option('datadir'), 'icons', 'hicolor', '@0@x@0@'.format(size), 'apps'),
    rename: app_id + '.png'
  )
endforeach

# Install symbolic icons
install_data(
  join_paths('hicolor', 'scalable', 'actions', 'io.github.tobagin.sonar-filter-symbolic.svg'),
  install_dir: join_paths(get_option('datadir'), 'icons', 'hicolor', 'scalable', 'actions')
)