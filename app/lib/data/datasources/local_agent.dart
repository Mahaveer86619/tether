import 'dart:io';

/// Starts this machine's tether-agent, which install-agent.ps1 registers as
/// an on-demand scheduled task rather than a logon one.
Future<void> startLocalAgent() async {
  if (!Platform.isWindows) return;
  try {
    // Detached so no console window flashes; the task ignores a second instance.
    await Process.start('schtasks', ['/Run', '/TN', 'Tether Agent'], mode: ProcessStartMode.detached);
  } on ProcessException {
    // No task on this machine: the agent is not installed here.
  }
}
