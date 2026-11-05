import 'package:flutter_test/flutter_test.dart';
import 'package:tether/data/datasources/update_platform.dart';

void main() {
  test('the Windows helper carries its own values, quoted', () {
    final s = windowsHelperScript(zip: r"C:\Users\O'Neil\updates\t.zip", app: r'C:\Program Files\Tether', appPid: 42);
    expect(s, startsWith(r"$Zip = 'C:\Users\O''Neil\updates\t.zip'"));
    expect(s, contains(r"$App = 'C:\Program Files\Tether'"));
    expect(s, contains(r'$AppPid = 42'));
    expect(s, isNot(contains('param(')));
    expect(s, contains('Rename-Item'));
  });

  test('the helper starts through cmd, which lets it outlive the app', () {
    final args = windowsHelperLaunch(r'C:\x\apply-update.ps1');
    expect(args.take(5), ['/c', 'start', '', '/b', 'powershell.exe']);
    expect(args, containsAllInOrder(['-WindowStyle', 'Hidden', '-File', r'C:\x\apply-update.ps1']));
  });
}
