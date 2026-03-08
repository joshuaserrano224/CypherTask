import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class KeyStorageService {
  final _storage = const FlutterSecureStorage();

  Future<void> saveDatabaseKey(String key) async {
    await _storage.write(key: 'db_encryption_key', value: key);
  }

  Future<String?> getDatabaseKey() async {
    return await _storage.read(key: 'db_encryption_key');
  }
}