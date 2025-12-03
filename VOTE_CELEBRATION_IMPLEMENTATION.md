# Vote Celebration Effect Implementation

## Overview
This document describes the implementation of the "sparkle burst" vote celebration effect that triggers when users vote for boy or girl predictions. The effect displays a 3-second white + vote color fast blink on the ESP32 RGB LEDs, then automatically returns to rainbow mode.

## Key Design Decision: Singleton Pattern

**The ESP32 service now uses a singleton pattern**, meaning there's only ONE instance shared across all screens. This ensures that:
- ✅ Configure ESP32 IP in **gender_reveal_screen** only
- ✅ Configuration automatically available in **vote_screen**
- ✅ No need to configure twice
- ✅ Consistent state across the entire app

## Implementation Details

### 1. ESP32 Firmware Changes (`esp32_rgb_controller/src/main.cpp`)

#### Added Rainbow Restart Endpoint
```cpp
// New endpoint: POST /rainbow
void handleRainbowCommand() {
  sendCORSHeaders();
  Serial.println("=== Rainbow Command Received ===");
  
  // Stop any active themes or effects
  stopThemeAnimation();
  stopFastBlink();
  
  // Start rainbow effect
  startRainbowEffect();
  
  // Send success response
  server.send(200, "application/json", "{\"status\":\"ok\",\"message\":\"Rainbow effect started\"}");
}
```

#### Enhanced Theme Command with Custom Blink Duration
```cpp
// Now accepts optional "blinkDuration" parameter in milliseconds
if (doc.containsKey("blinkDuration")) {
  totalDuration = doc["blinkDuration"];
  Serial.print("Using custom blink duration: ");
  Serial.print(totalDuration);
  Serial.println("ms");
}
```

**Example Request:**
```json
POST /theme
{
  "colors": [
    {"r": 255, "g": 255, "b": 255},  // White sparkle
    {"r": 137, "g": 207, "b": 240}   // Boy blue
  ],
  "blinkDuration": 3000  // 3 seconds
}
```

### 2. Flutter Service Changes (`esp32_light_service.dart`)

#### Singleton Pattern Implementation
```dart
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
  // ...rest of the class
}
```

**Usage in any screen:**
```dart
final _esp32Service = ESP32LightService(); // Always gets the same instance
```

#### New `startRainbow()` Method
```dart
/// Start rainbow effect on ESP32
Future<bool> startRainbow() async {
  if (_deviceIP == null) {
    debugPrint('No ESP32 device configured');
    return false;
  }

  try {
    final url = 'http://$_deviceIP:80/rainbow';
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Connection': 'close',
      },
      body: '{}',
    ).timeout(const Duration(seconds: 5));

    return response.statusCode == 200;
  } catch (e) {
    debugPrint('❌ Error starting rainbow on ESP32: $e');
    return false;
  }
}
```

### 3. Vote Screen Changes (`vote_screen.dart`)

#### Vote Celebration Method
```dart
/// Triggers ESP32 vote celebration effect (sparkle burst)
void _triggerVoteCelebration(Color voteColor) async {
  if (!_esp32Service.isConnected) {
    debugPrint('ESP32 not connected, skipping vote celebration effect');
    return;
  }

  try {
    // Send 2-color fast blink theme: white + vote color
    // This creates a "sparkle burst" effect for 3 seconds
    final themeData = {
      'colors': [
        {'r': 255, 'g': 255, 'b': 255}, // White (sparkle)
        {'r': voteColor.red, 'g': voteColor.green, 'b': voteColor.blue}, // Vote color
      ],
      'blinkDuration': 3000, // 3 seconds
    };

    debugPrint('🎉 Sending vote celebration theme to ESP32');
    final success = await _esp32Service.sendTheme(themeData);

    if (success) {
      // Wait for the celebration effect to complete
      await Future.delayed(const Duration(seconds: 3));

      // Restart rainbow mode
      if (mounted && _esp32Service.isConnected) {
        debugPrint('🌈 Restarting rainbow mode after vote celebration');
        await _esp32Service.startRainbow();
      }
    }
  } catch (e) {
    debugPrint('❌ Error triggering vote celebration: $e');
  }
}
```

#### Integration with Vote Handler
```dart
void _handleVote(BuildContext context, Color color, VoidCallback onVote) {
  final now = DateTime.now();

  // Check cooldown to prevent spam
  if (_lastVoteTime != null &&
      now.difference(_lastVoteTime!) < _voteCooldown) {
    _triggerFireworkAsync(context, color);
    _triggerVoteCelebration(color);  // ✨ Added
    return;
  }

  _lastVoteTime = now;
  HapticFeedback.lightImpact();
  onVote();
  
  // Trigger both firework animation and ESP32 celebration
  _triggerFireworkAsync(context, color);
  _triggerVoteCelebration(color);  // ✨ Added
}
```

## User Flow

### Configuration (One-Time Setup)
1. Open **Gender Reveal Screen** (admin only)
2. Click settings icon (⚙️) in AppBar
3. Select "Configure ESP32 RGB Light"
4. Enter ESP32 IP address (e.g., `192.168.1.100`)
5. Click "Save"

### Vote Celebration (Automatic)
1. User opens **Vote Screen**
2. User clicks "Boy" or "Girl" button
3. **Simultaneously:**
   - 🎆 Firework animation displays on screen
   - ✨ ESP32 shows 3-second sparkle burst (white + vote color)
   - 🌈 ESP32 automatically returns to rainbow mode
4. User can vote again immediately (no blocking)

## Technical Features

### Non-Blocking Design
- ✅ Vote celebration runs asynchronously
- ✅ Doesn't block UI or voting functionality
- ✅ Multiple rapid votes are handled gracefully

### Failsafe Behavior
- ✅ Works even if ESP32 is not configured
- ✅ Gracefully skips celebration if ESP32 is offline
- ✅ Doesn't show errors to user (silent failure)

### Shared Configuration
- ✅ Configure once in gender reveal screen
- ✅ Automatically available in vote screen
- ✅ No duplicate configuration dialogs needed

## Color Mapping

| Vote Type | Vote Color (Flutter) | Sparkle Effect |
|-----------|---------------------|----------------|
| Boy       | `#89CFF0` (Baby Blue) | White + Blue fast blink |
| Girl      | `#F4C2C2` (Baby Pink) | White + Pink fast blink |

## Timing Details

| Phase | Duration | Description |
|-------|----------|-------------|
| Sparkle Burst | 3 seconds | White + vote color fast blink (300ms per color) |
| Transition | Instant | Smooth transition to rainbow |
| Rainbow Mode | Continuous | Running gradient effect until next command |

## Testing Checklist

- [ ] Configure ESP32 IP in gender reveal screen
- [ ] Verify ESP32 shows rainbow effect on startup
- [ ] Vote for Boy → Check 3-second blue sparkle burst → Verify rainbow resumes
- [ ] Vote for Girl → Check 3-second pink sparkle burst → Verify rainbow resumes
- [ ] Test rapid voting (cooldown = 300ms)
- [ ] Test with ESP32 disconnected (should skip celebration gracefully)
- [ ] Verify no configuration needed in vote screen
- [ ] Check that configuration persists during app session

## File Changes Summary

### Modified Files:
1. **ESP32 Firmware:**
   - `esp32_rgb_controller/src/main.cpp` (added rainbow endpoint, custom blink duration)

2. **Flutter App:**
   - `lib/services/esp32_light_service.dart` (singleton pattern, startRainbow method)
   - `lib/screens/vote_screen.dart` (vote celebration trigger, ESP32 service integration)

### No Changes Needed:
- `gender_reveal_screen.dart` (already has ESP32 configuration UI)

## Future Enhancements

- [ ] Add different celebration effects (e.g., pulse, fade)
- [ ] Customize celebration duration via settings
- [ ] Add sound effects synchronized with LED effects
- [ ] Store ESP32 IP in local storage for persistence across sessions

---

**Implementation Date:** December 3, 2025  
**Status:** ✅ Complete and ready for testing
