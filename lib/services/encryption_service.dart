import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';

/// Service for encrypting and decrypting sensitive data like baby gender
/// 
/// Uses AES encryption with a secret key to protect sensitive information
/// from being accidentally seen in the database.
class EncryptionService {
  // WARNING: In production, store this key securely (environment variables, secure storage, etc.)
  // This is a sample key for development. Change this to your own secret key!
  
  // Create a fixed 32-byte key for AES-256
  static final Uint8List _keyBytes = Uint8List.fromList([
    77, 121, 83, 101, 99, 114, 101, 116, // MySecret
    75, 101, 121, 49, 50, 51, 52, 53,   // Key12345
    54, 55, 56, 57, 48, 49, 50, 51,     // 67890123
    52, 53, 54, 55, 56, 57, 48, 49      // 45678901
  ]); // Total: 32 bytes
  
  // Create encrypter instance with fixed key
  static final _key = Key(_keyBytes);
  static final _encrypter = Encrypter(AES(_key));
  
  /// Encrypts a plain text string (e.g., "boy" or "girl")
  /// 
  /// Returns an encrypted string that looks like random characters
  /// so you can't accidentally see the answer in the database.
  /// 
  /// Example: "boy" → "a8f3e2d1b5c7f9e3..."
  static String encryptGender(String plainGender) {
    try {
      // Create a fixed IV for consistency (so same input gives same output)
      // This allows us to query encrypted data consistently
      final fixedIV = IV.fromBase64('AAAAAAAAAAAAAAAAAAAAAA=='); // 16 bytes of zeros
      
      final encrypted = _encrypter.encrypt(plainGender, iv: fixedIV);
      return encrypted.base64;
    } catch (e) {
      throw Exception('Failed to encrypt gender: $e');
    }
  }
  
  /// Decrypts an encrypted string back to plain text
  /// 
  /// Takes the encrypted string from database and returns original value.
  /// 
  /// Example: "a8f3e2d1b5c7f9e3..." → "boy"
  static String decryptGender(String encryptedGender) {
    try {
      // Use the same fixed IV used for encryption
      final fixedIV = IV.fromBase64('AAAAAAAAAAAAAAAAAAAAAA=='); // 16 bytes of zeros
      
      final encrypted = Encrypted.fromBase64(encryptedGender);
      final decrypted = _encrypter.decrypt(encrypted, iv: fixedIV);
      return decrypted;
    } catch (e) {
      throw Exception('Failed to decrypt gender: $e');
    }
  }
  
  /// Helper method to get encrypted values for both genders
  /// 
  /// Returns a map with encrypted versions of "boy" and "girl"
  /// Useful for database queries or debugging.
  static Map<String, String> getEncryptedGenders() {
    return {
      'boy_encrypted': encryptGender('boy'),
      'girl_encrypted': encryptGender('girl'),
    };
  }
  
  /// Validates if a string is a valid encrypted gender
  /// 
  /// Attempts to decrypt and checks if result is "boy" or "girl"
  static bool isValidEncryptedGender(String encryptedValue) {
    try {
      final decrypted = decryptGender(encryptedValue);
      return decrypted == 'boy' || decrypted == 'girl';
    } catch (e) {
      return false;
    }
  }
  
  /// Debug method to show what encrypted values look like
  /// 
  /// Prints encrypted versions so you can see how they appear in database
  static void printEncryptedExamples() {
    print('=== ENCRYPTED GENDER EXAMPLES ===');
    print('Original "boy" → Encrypted: "${encryptGender('boy')}"');
    print('Original "girl" → Encrypted: "${encryptGender('girl')}"');
    print('================================');
  }
}
