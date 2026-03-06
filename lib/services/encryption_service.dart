import 'package:encrypt/encrypt.dart' as encrypt;

class EncryptionService {
  late final encrypt.Encrypter _encrypter;
  final _iv = encrypt.IV.fromLength(16);

  // Key must be exactly 32 bytes for AES-256
  EncryptionService(String seed) {
    final key = encrypt.Key.fromUtf8(seed.padRight(32).substring(0, 32));
    _encrypter = encrypt.Encrypter(encrypt.AES(key));
  }

  String encryptField(String plainText) {
    return _encrypter.encrypt(plainText, iv: _iv).base64;
  }

  String decryptField(String cipherText) {
    return _encrypter.decrypt64(cipherText, iv: _iv);
  }
}