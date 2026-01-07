# Configure tests
import_export_test = executable('test-import-export',
  ['test_import_export.vala'],
  dependencies: [sonar_dep],
  vala_args: vala_args,
)

test('Import/Export', import_export_test)

mock_server_test = executable('test-mock-server',
  ['test_mock_server.vala'],
  dependencies: [sonar_dep],
  vala_args: vala_args,
)

test('Mock Server', mock_server_test)
