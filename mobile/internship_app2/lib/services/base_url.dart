import 'package:flutter/foundation.dart';

const _productionUrl = 'https://web-production-5e667.up.railway.app';

/// Returns the correct backend URL depending on platform.
/// - Web / Release → production Railway backend
/// - Android emulator debug → 10.0.2.2 (special loopback alias)
String get apiBaseUrl {
  if (kReleaseMode) return _productionUrl;
  if (kIsWeb) return 'http://localhost:8000';
  return 'http://10.0.2.2:8000'; // Android emulator
}
