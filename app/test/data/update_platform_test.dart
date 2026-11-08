import 'package:flutter_test/flutter_test.dart';
import 'package:tether/data/datasources/update_platform.dart';

void main() {
  test('the updater is given what it needs, one argument each', () {
    final args = updaterArguments(zip: r'C:\u dir\t.zip', app: r'C:\Users\a b\Tether', appPid: 42, log: r'C:\u dir\apply-update.log', ok: r'C:\u dir\update-ok');
    expect(args, ['-zip', r'C:\u dir\t.zip', '-app', r'C:\Users\a b\Tether', '-pid', '42', '-log', r'C:\u dir\apply-update.log', '-ok', r'C:\u dir\update-ok']);
    expect(updaterName, 'tether-updater.exe');
  });
}
