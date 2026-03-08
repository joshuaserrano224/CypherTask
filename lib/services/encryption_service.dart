import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

class EncryptionService {
  final _storage = const FlutterSecureStorage();
  encrypt.Key? _key;
  encrypt.IV? _iv;

  Future<void> init() async {
    // 1. Try to read both the Key and the IV
    String? storedKey = await _storage.read(key: 'master_key_v1');
    String? storedIv = await _storage.read(key: 'master_iv_v1');

    if (storedKey != null && storedIv != null) {
      // 2. Both found! Load them.
      _key = encrypt.Key.fromBase64(storedKey);
      _iv = encrypt.IV.fromBase64(storedIv);
      debugPrint("CRYPT_SYSTEM: Existing Keys Restored. Encryption Ready.");
    } else {
      // 3. One or both missing? Generate NEW ones and save.
      final newKey = encrypt.Key.fromSecureRandom(32);
      final newIv = encrypt.IV.fromSecureRandom(16);
      
      await _storage.write(key: 'master_key_v1', value: newKey.base64);
      await _storage.write(key: 'master_iv_v1', value: newIv.base64);
      
      _key = newKey;
      _iv = newIv;
      debugPrint("CRYPT_SYSTEM: New Protocol Keys Generated and Locked.");
    }
  }

  String encryptText(String text) {
    if (_key == null || _iv == null) return "INIT_FAIL";
    final encrypter = encrypt.Encrypter(encrypt.AES(_key!));
    return encrypter.encrypt(text, iv: _iv!).base64;
  }

  String decryptText(String cipherText) {
    try {
      if (_key == null || _iv == null) return "INIT_FAIL";
      final encrypter = encrypt.Encrypter(encrypt.AES(_key!));
      return encrypter.decrypt64(cipherText, iv: _iv!);
    } catch (e) {
      debugPrint("DECRYPT_FAILURE: $e");
      return "DECRYPT_ERROR: Key/IV Mismatch";
    }
  }
}