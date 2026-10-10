import 'package:equatable/equatable.dart';

/// What went wrong, in terms the domain and UI understand. Every repository
/// method returns these instead of throwing.
sealed class Failure extends Equatable {
  const Failure(this.message);

  /// Detail for logs; may be technical.
  final String message;

  /// Short sentence for the user.
  String get userMessage;

  @override
  List<Object?> get props => [runtimeType, message];
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
  @override
  String get userMessage => "Can't reach the hub. Check Tailscale and that tether-hub is running.";
}

class TimeoutFailure extends Failure {
  const TimeoutFailure(super.message);
  @override
  String get userMessage => 'The hub took too long to answer. Try again.';
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([super.message = 'unauthorized']);
  @override
  String get userMessage => 'The hub rejected the token. Check it in Settings.';
}

class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message);
  @override
  String get userMessage => 'Not found on the hub: $message.';
}

class NodeOfflineFailure extends Failure {
  const NodeOfflineFailure([super.message = 'node is not connected']);
  @override
  String get userMessage => 'That device is offline right now.';
}

/// The session is open in someone's terminal and can't take input from here.
class TerminalActiveFailure extends Failure {
  const TerminalActiveFailure([super.message = 'session is open in a terminal']);
  @override
  String get userMessage => 'This session is open in a terminal. Fork it to continue from here.';
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
  @override
  String get userMessage => message;
}

class ServerFailure extends Failure {
  const ServerFailure(super.message, {this.code = ''});
  final String code;
  @override
  String get userMessage => 'The hub reported an error: $message';
  @override
  List<Object?> get props => [...super.props, code];
}

class StorageFailure extends Failure {
  const StorageFailure(super.message);
  @override
  String get userMessage => "Couldn't save settings on this device: $message";
}

class NotConnectedFailure extends Failure {
  const NotConnectedFailure([super.message = 'not connected']);
  @override
  String get userMessage => 'Not connected to the hub yet.';
}

class UnexpectedFailure extends Failure {
  const UnexpectedFailure(super.message);
  @override
  String get userMessage => 'Something went wrong: $message';
}
