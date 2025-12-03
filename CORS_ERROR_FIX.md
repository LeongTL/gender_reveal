# CORS Error Fix & Rainbow Not Showing Issue

## Problem Analysis

The error shows:
```
❌ Error sending theme to ESP32: ClientException: Failed to fetch, uri=http://192.168.31.37/theme
🚫 CORS Error Detected!
```

### Root Causes:

1. **ESP32 Not Responding**: "Failed to fetch" means the ESP32 isn't answering HTTP requests
2. **Possible ESP32 Crash**: The running effect might have caused the ESP32 to crash or hang
3. **Network Issue**: ESP32 might have disconnected from WiFi

---

## Quick Fixes

### Fix 1: Restart ESP32
**Most likely solution!**

1. **Unplug and replug the ESP32** to restart it
2. Wait 5 seconds for it to boot up
3. Check if rainbow effect starts automatically
4. Try voting again

### Fix 2: Check ESP32 Serial Monitor

```bash
cd /Users/leongtl/Documents/project/esp32_rgb_controller
~/.platformio/penv/bin/platformio device monitor
```

Look for:
- **Boot messages**: Should see "ESP32 RGB Controller Starting"
- **Crash/restart**: Look for "Guru Meditation Error" or "Core panic"
- **WiFi connection**: Should see "WiFi connected" and IP address
- **Rainbow start**: Should see "🌈 Rainbow effect started as default"

**If you see crash messages**, the running effect is causing ESP32 to crash!

---

## Permanent Fix: Increase ESP32 Stability

The issue is likely that the fast running effect (updating 500 LEDs every 10ms) is overwhelming the ESP32. Let me create a more stable version:

### Changes Needed in ESP32 `main.cpp`:

#### 1. Add Watchdog Reset in Running Effect

The ESP32 watchdog timer might be triggering because the LED updates take too long.

**Add this at the top of the file:**
```cpp
#include <esp_task_wdt.h>
```

**In updateRunningEffect(), add watchdog reset:**
```cpp
void updateRunningEffect() {
  if (!runningEffectActive) return;
  
  unsigned long now = millis();
  
  // Feed the watchdog to prevent reset
  esp_task_wdt_reset();  // ← ADD THIS LINE
  
  // Check if duration has elapsed
  if (now - runningStartTime >= runningDuration) {
    stopRunningEffect();
    return;
  }
  
  // ... rest of the code
}
```

#### 2. Optimize LED Updates for 500 LEDs

For 500 LEDs, we need to be smarter about updates:

**Current Settings (May cause crashes):**
```cpp
const unsigned long RUNNING_UPDATE_INTERVAL = 10;  // 10ms
const int COMET_TAIL_LENGTH = 15;
const int COMET_SPEED = 5;
```

**Recommended Settings for 500 LEDs:**
```cpp
const unsigned long RUNNING_UPDATE_INTERVAL = 20;  // 20ms (safer)
const int COMET_TAIL_LENGTH = 20;  // Longer tail for better visibility
const int COMET_SPEED = 10;  // Faster movement to cover more ground
```

This gives: 500 LEDs / 10 = 50 updates × 20ms = **1 second per full pass** (still 3 passes in 3 seconds!)

#### 3. Add Safety Check in Loop

Make sure the ESP32 doesn't hang:

**In main loop(), add:**
```cpp
void loop() {
  // Feed watchdog first thing
  esp_task_wdt_reset();
  
  server.handleClient();
  // ... rest of loop
}
```

---

## Alternative: Simpler Running Effect

If ESP32 keeps crashing, use a simpler effect that updates fewer LEDs:

```cpp
void updateRunningEffect() {
  if (!runningEffectActive) return;
  
  unsigned long now = millis();
  
  // Check if duration has elapsed
  if (now - runningStartTime >= runningDuration) {
    stopRunningEffect();
    return;
  }
  
  // Update only at specified intervals
  if (now - runningLastUpdate < RUNNING_UPDATE_INTERVAL) {
    return;
  }
  runningLastUpdate = now;
  
  // Move position
  runningPosition = (runningPosition + COMET_SPEED) % NUM_LEDS;
  
  // SIMPLER APPROACH: Only update a small section, not entire strip
  int startLED = max(0, runningPosition - COMET_TAIL_LENGTH);
  int endLED = min(NUM_LEDS, runningPosition + 1);
  
  // Clear only the section we're updating
  for (int i = startLED; i < endLED; i++) {
    strip.setPixelColor(i, 0, 0, 0);
  }
  
  // Draw only the comet (not the entire strip)
  for (int i = 0; i <= COMET_TAIL_LENGTH; i++) {
    int pos = runningPosition - i;
    if (pos >= 0 && pos < NUM_LEDS) {
      float brightness = 1.0 - (float)i / (COMET_TAIL_LENGTH + 1);
      brightness = brightness * brightness;
      
      uint8_t r = runningColor.r * brightness;
      uint8_t g = runningColor.g * brightness;
      uint8_t b = runningColor.b * brightness;
      
      strip.setPixelColor(pos, strip.Color(r, g, b));
    }
  }
  
  strip.show();
}
```

---

## Testing Steps

### Step 1: Check if ESP32 is Alive
```bash
ping 192.168.31.37
```

If no response → ESP32 crashed or disconnected

### Step 2: Manually Test Theme Endpoint
```bash
curl -v -X POST http://192.168.31.37:80/theme \
  -H "Content-Type: application/json" \
  -d '{"colors":[{"r":255,"g":20,"b":147}],"mode":"running","duration":3000}'
```

**If this works** → CORS issue in Flutter  
**If this fails** → ESP32 is crashed/hung

### Step 3: Test Rainbow Endpoint
```bash
curl -v -X POST http://192.168.31.37:80/rainbow \
  -H "Content-Type: application/json" \
  -d '{}'
```

Should start rainbow immediately.

---

## Immediate Actions

1. **Restart ESP32** (unplug/replug) ← DO THIS FIRST
2. **Monitor serial output** while voting
3. **Look for crash messages** or "Guru Meditation Error"
4. **Check if rainbow starts after boot**

If ESP32 crashes during running effect:
- The effect is too intensive for 500 LEDs
- Need to implement watchdog reset or simpler algorithm
- Consider reducing update frequency or tail length

---

## Why Rainbow Doesn't Return

The running effect completes, then Flutter tries to send `/rainbow` command, but:
1. ESP32 has already crashed
2. ESP32 is unresponsive
3. Network connection lost

**Fix:** Restart ESP32, then we'll optimize the code to prevent crashes.

---

## Quick Test Without Running Effect

To verify ESP32 works without the running effect, temporarily disable it in vote screen:

**In `vote_screen.dart`, comment out the ESP32 call:**
```dart
void _triggerVoteCelebration(Color voteColor) async {
  // TEMPORARILY DISABLED FOR TESTING
  return;
  
  // ... rest of code
}
```

Then vote - if ESP32 stays stable, the running effect is causing the crash.

---

**Priority Actions:**
1. ✅ Restart ESP32 NOW
2. 📊 Check serial monitor for crash logs
3. 🔧 Apply stability fixes if crashes occur
4. 🧪 Test with simpler effect if needed
