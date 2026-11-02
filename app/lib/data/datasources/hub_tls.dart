import 'dart:io';

import 'package:crypto/crypto.dart';

/// Trusts a hub's self-signed certificate by the SHA-256 fingerprint learnt
/// when pairing. Certificates from a public CA pass the platform's checks and
/// never reach this; it only decides about ones the platform would reject.
class HubTls {
  /// Hex SHA-256 of the pinned certificate; empty pins nothing.
  String fingerprint = '';

  /// Shared by the REST client and the WebSocket.
  late final HttpClient httpClient = HttpClient()..badCertificateCallback = _pinned;

  bool _pinned(X509Certificate cert, String host, int port) =>
      fingerprint.isNotEmpty && sha256.convert(cert.der).toString() == fingerprint.toLowerCase();
}
