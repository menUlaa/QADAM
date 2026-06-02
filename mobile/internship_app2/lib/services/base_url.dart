import 'package:flutter/foundation.dart';

const _prod = 'https://qadam-backend.onrender.com';
const _local = 'http://localhost:8000';

/// Set to true to use local backend, false for production.
const _useLocal = true;

String get apiBaseUrl {
  if (_useLocal) {
    if (kIsWeb) return _local;
    return 'http://10.0.2.2:8000';
  }
  return _prod;
}
