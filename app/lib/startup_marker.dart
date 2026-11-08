import 'dart:io';

import 'package:flutter/widgets.dart';

/// After an update, the updater starts the new app with TETHER_UPDATE_OK set
/// to a file name and waits for it. Writing it after the first frame tells
/// the updater the app came up; without it the old version is put back.
void reportUpdateOk() {
  final path = Platform.environment['TETHER_UPDATE_OK'];
  if (path == null || path.isEmpty) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    try {
      File(path).writeAsStringSync('ok');
    } on FileSystemException {
      // The updater times out and puts the old version back.
    }
  });
}
