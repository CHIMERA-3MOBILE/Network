import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  // Simple XOR encryption for demonstration
  // In production, use proper encryption like AES
  String _generateKey() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return String.fromCharCodes(Iterable.generate(
        32, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }

  Map<String, dynamic> encryptMessage(String content, String key) {
    final encryptedBytes = _xorEncrypt(content, key);
    return {
      'encrypted': true,
      'data': base64.encode(encryptedBytes),
      'key': key,
      'algorithm': 'XOR',
    };
  }

  String decryptMessage(Map<String, dynamic> encryptedMessage) {
    if (!encryptedMessage['encrypted']) {
      return encryptedMessage['content'] ?? '';
    }
    
    final encryptedData = base64.decode(encryptedMessage['data']);
    final key = encryptedMessage['key'];
    return _xorDecrypt(encryptedData, key);
  }

  Uint8List _xorEncrypt(String text, String key) {
    final textBytes = utf8.encode(text);
    final keyBytes = utf8.encode(key);
    final encrypted = Uint8List(textBytes.length);
    
    for (int i = 0; i < textBytes.length; i++) {
      encrypted[i] = textBytes[i] ^ keyBytes[i % keyBytes.length];
    }
    
    return encrypted;
  }

  String _xorDecrypt(Uint8List encrypted, String key) {
    final keyBytes = utf8.encode(key);
    final decrypted = Uint8List(encrypted.length);
    
    for (int i = 0; i < encrypted.length; i++) {
      decrypted[i] = encrypted[i] ^ keyBytes[i % keyBytes.length];
    }
    
    return String.fromCharCodes(decrypted);
  }

  String generateSessionKey() {
    return _generateKey();
  }

  String hashDeviceId(String deviceId) {
    // Simple hash for device identification
    return deviceId.split('').map((c) => c.codeUnitAt(0).toRadixString(16)).join('');
  }
}
