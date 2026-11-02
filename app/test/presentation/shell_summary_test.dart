import 'package:flutter_test/flutter_test.dart';
import 'package:tether/presentation/widgets/format.dart';

void main() {
  test('a long command is named by what it runs, not shown whole', () {
    final cases = {
      'cd /c/Users/pmaha/projects/personal/tether/server && git status --short | head -3; go test ./... 2>&1 | grep -v "no test files"': 'git status +3',
      'cd /srv/app && go test ./internal/hub 2>&1 | tail -5': 'go test ./internal/hub +1',
      'tail -n 40 ~/logs/wvs-v2-run.log': 'tail ~/logs/wvs-v2-run.log',
      'ls': 'ls',
      'tmux ls': 'tmux ls',
      'VAR=1 sudo systemctl restart nginx': 'systemctl restart nginx',
      r'C:\Windows\System32\tailscale.exe status': 'tailscale status',
      'ssh -o BatchMode=yes synlabs@host ls ~/x': 'ssh synlabs@host ls',
      'echo "a b" > out.txt': 'echo',
      '': '',
      'cd /srv': 'cd /srv',
    };
    cases.forEach((cmd, want) {
      expect(shellSummary(cmd), want, reason: cmd);
    });
  });

  test('only the first line counts, and the result is never longer than the limit', () {
    expect(shellSummary('cd /x && python - <<EOF\nprint(1)\nEOF'), 'python');
    final long = shellSummary('some-extremely-long-command-name-that-goes-on-and-on-forever --flag value other another third');
    expect(long.length, lessThanOrEqualTo(44));
    expect(long.endsWith('…'), isTrue);
    expect(shellSummary('a && b && c && d').endsWith('+3'), isTrue);
  });
}
