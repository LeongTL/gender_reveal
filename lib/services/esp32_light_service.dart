import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// Service for controlling ESP32 RGB light over HTTP (Web only)
/// Simplified version for gender reveal - only 2 colors (pink/blue)
/// Singleton pattern ensures configuration is shared across all screens
class ESP32LightService {
  // Singleton instance
  static final ESP32LightService _instance = ESP32LightService._internal();

  // Factory constructor returns the singleton instance
  factory ESP32LightService() {
    return _instance;
  }

  // Private constructor for singleton
  ESP32LightService._internal();
  
  String? _deviceIP;
  
  String? get deviceIP => _deviceIP;
  bool get isConnected => _deviceIP != null;

  /// Set the ESP32 device IP address
  void setDeviceIP(String ip) {
    _deviceIP = ip.trim();
    debugPrint('ESP32 device IP set to: $_deviceIP');
  }

  /// Clear the device IP
  void clearDevice() {
    _deviceIP = null;
    debugPrint('ESP32 device cleared');
  }

  /// Send RGB color to ESP32
  /// Returns true if successful, false otherwise
  Future<bool> setRGB(int red, int green, int blue) async {
    if (_deviceIP == null) {
      debugPrint('No ESP32 device configured');
      return false;
    }

    try {
      // Use /color endpoint with POST method (matching ESP32 firmware)
      final url = 'http://$_deviceIP:80/color';
      debugPrint('🌐 Sending RGB to ESP32: R=$red G=$green B=$blue');
      debugPrint('📡 URL: $url');

      final uri = Uri.parse(url);
      
      // POST request with JSON body (matching ESP32 firmware expectation)
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Connection': 'close',
        },
        body: '{"r":$red,"g":$green,"b":$blue}',
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('⏱️ ESP32 request timed out');
          throw Exception('Request timed out');
        },
      );

      debugPrint('📡 ESP32 response status: ${response.statusCode}');
      debugPrint('📄 ESP32 response body: ${response.body}');

      if (response.statusCode == 200) {
        debugPrint('✅ ESP32 color updated successfully');
        return true;
      } else {
        debugPrint('❌ ESP32 responded with error: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error sending RGB to ESP32: $e');
      
      // Check for CORS error
      if (e.toString().toLowerCase().contains('cors') || 
          e.toString().toLowerCase().contains('failed to fetch') ||
          e.toString().toLowerCase().contains('network error')) {
        debugPrint('🚫 CORS Error Detected!');
        debugPrint('💡 Your ESP32 firmware needs CORS headers for web browser control');
        debugPrint('📝 Add these headers to your ESP32 HTTP server:');
        debugPrint('   server.sendHeader("Access-Control-Allow-Origin", "*");');
        debugPrint('   server.sendHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");');
        debugPrint('   server.sendHeader("Access-Control-Allow-Headers", "Content-Type");');
      }
      
      return false;
    }
  }

  /// Test connection to ESP32
  Future<bool> testConnection() async {
    if (_deviceIP == null) return false;

    try {
      // Try to access the root endpoint to test connection
      final url = 'http://$_deviceIP:80/';
      debugPrint('🔍 Testing ESP32 connection at: $url');

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 3),
        onTimeout: () => throw Exception('Connection timeout'),
      );

      debugPrint('📡 ESP32 response: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ ESP32 connection test failed: $e');
      return false;
    }
  }

  /// Preset colors for gender reveal
  static const Map<String, Map<String, int>> presetColors = {
    'pink': {'r': 255, 'g': 105, 'b': 180},  // Hot pink for girl
    'blue': {'r': 0, 'g': 191, 'b': 255},    // Deep sky blue for boy
    'off': {'r': 0, 'g': 0, 'b': 0},         // Turn off
  };

  /// Send preset color
  Future<bool> sendPresetColor(String colorName) async {
    final color = presetColors[colorName];
    if (color == null) {
      debugPrint('Invalid color preset: $colorName');
      return false;
    }

    return await setRGB(color['r']!, color['g']!, color['b']!);
  }

  /// Send girl color (pink)
  Future<bool> sendGirlColor() => sendPresetColor('pink');

  /// Send boy color (blue)
  Future<bool> sendBoyColor() => sendPresetColor('blue');

  /// Turn off light
  Future<bool> turnOff() => sendPresetColor('off');

  /// Send theme animation pattern to ESP32
  /// Theme data includes colors array and timing information
  Future<bool> sendTheme(Map<String, dynamic> themeData) async {
    if (_deviceIP == null) {
      debugPrint('No ESP32 device configured');
      return false;
    }

    try {
      final url = 'http://$_deviceIP:80/theme';
      debugPrint('🎨 Sending theme animation to ESP32');
      debugPrint('📡 URL: $url');
      debugPrint('🎨 Theme data: $themeData');

      final uri = Uri.parse(url);
      final jsonBody = jsonEncode(themeData);
      debugPrint('📤 Sending JSON body: $jsonBody');
      
      // POST request with JSON body containing theme pattern
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Connection': 'close',
        },
        body: jsonBody,
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('⏱️ ESP32 theme request timed out');
          throw Exception('Request timed out');
        },
      );

      debugPrint('📡 ESP32 theme response status: ${response.statusCode}');
      debugPrint('📄 ESP32 theme response body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final responseData = json.decode(response.body);
          if (responseData['status'] == 'ok') {
            debugPrint('✅ ESP32 theme animation started successfully');
            return true;
          }
        } catch (e) {
          debugPrint('⚠️ Response not JSON, treating as success for status 200');
          return true;
        }
        debugPrint('✅ ESP32 theme animation started successfully');
        return true;
      } else {
        debugPrint('❌ ESP32 theme responded with error: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error sending theme to ESP32: $e');
      
      // Check for CORS error
      if (kIsWeb && (e.toString().toLowerCase().contains('cors') || 
          e.toString().toLowerCase().contains('failed to fetch') ||
          e.toString().toLowerCase().contains('network error'))) {
        debugPrint('🚫 CORS Error Detected!');
        debugPrint('💡 Your ESP32 firmware needs CORS headers for web browser control');
        debugPrint('📝 Add these headers to your ESP32 HTTP server:');
        debugPrint('   server.sendHeader("Access-Control-Allow-Origin", "*");');
        debugPrint('   server.sendHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");');
        debugPrint('   server.sendHeader("Access-Control-Allow-Headers", "Content-Type");');
      }
      
      return false;
    }
  }

  /// Start rainbow effect on ESP32
  /// Returns true if successful, false otherwise
  Future<bool> startRainbow() async {
    if (_deviceIP == null) {
      debugPrint('No ESP32 device configured');
      return false;
    }

    try {
      final url = 'http://$_deviceIP:80/rainbow';
      debugPrint('🌈 Starting rainbow effect on ESP32');
      debugPrint('📡 URL: $url');

      final uri = Uri.parse(url);

      // POST request to start rainbow effect
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Connection': 'close',
            },
            body: '{}',
          )
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              debugPrint('⏱️ ESP32 rainbow request timed out');
              throw Exception('Request timed out');
            },
          );

      debugPrint('📡 ESP32 rainbow response status: ${response.statusCode}');
      debugPrint('📄 ESP32 rainbow response body: ${response.body}');

      if (response.statusCode == 200) {
        debugPrint('✅ ESP32 rainbow effect started successfully');
        return true;
      } else {
        debugPrint('❌ ESP32 responded with error: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error starting rainbow on ESP32: $e');
      return false;
    }
  }

}
