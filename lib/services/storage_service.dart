import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'dart:math';

class StorageService {
  final _storage = const FlutterSecureStorage();
  final String _dbKeyName = 'ciphertask_hardware_key';

  Future<String> getDatabaseKey() async {
    String? key = await _storage.read(key: _dbKeyName);
    if (key == null) {
      key = _generateSecureRandomKey();
      await _storage.write(key: _dbKeyName, value: key);
    }
    return key;
  }

  String _generateSecureRandomKey() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64UrlEncode(values);
  }
}