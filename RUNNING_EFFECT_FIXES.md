# Running Effect Fixes - December 3, 2025

## Issues Fixed

### ✅ Issue 1: Running Mode Too Slow for 500 LEDs
**Problem:** Comet moved only 1 LED every 30ms, taking forever to traverse 500 LEDs.

**Solution:**
```cpp
// Before:
const unsigned long RUNNING_UPDATE_INTERVAL = 30;  // 30ms
const int COMET_TAIL_LENGTH = 8;
runningPosition = (runningPosition + 1) % NUM_LEDS;  // Move 1 LED per update

// After:
const unsigned long RUNNING_UPDATE_INTERVAL = 10;  // 10ms (3x faster)
const int COMET_TAIL_LENGTH = 15;  // Longer tail for visibility
const int COMET_SPEED = 5;  // Move 5 LEDs per update
runningPosition = (runningPosition + COMET_SPEED) % NUM_LEDS;
```

**Result:** Comet now moves **15x faster** (3x faster updates × 5x LEDs per update)

---

### ✅ Issue 2: Not Returning to Rainbow After Running
**Problem:** `stopRunningEffect()` turned off all LEDs, preventing rainbow from taking over.

**Solution:**
```cpp
// Before:
void stopRunningEffect() {
  runningEffectActive = false;
  setLEDsImmediate(0, 0, 0); // ❌ Turned off LEDs!
  Serial.println("RUNNING effect stopped");
}

// After:
void stopRunningEffect() {
  runningEffectActive = false;
  // ✅ Don't turn off LEDs - let next effect take over immediately
  Serial.println("RUNNING effect stopped - ready for next effect");
}
```

**Result:** Rainbow effect can now start immediately after running effect ends.

---

### ✅ Issue 3: Investigating White Color Issue
**Problem:** LEDs showing white instead of blue (boy) or pink (girl).

**Diagnosis Added:**
1. Added detailed logging in Flutter to show actual RGB values being sent
2. ESP32 already logs received color values
3. Need to check serial monitor output to see what's being received

**Flutter Debug Output (Added):**
```dart
debugPrint('Sending vote celebration to ESP32:');
debugPrint('  Color RGB: (${voteColor.red}, ${voteColor.green}, ${voteColor.blue})');
debugPrint('  Mode: running, Duration: 3000ms');
```

**Expected Values:**
- Boy vote: RGB(137, 207, 240) - Baby Blue #89CFF0
- Girl vote: RGB(244, 194, 194) - Baby Pink #F4C2C2

**ESP32 Serial Output (Already exists):**
```
=== RUNNING/CHASING MODE DETECTED ===
Starting running effect with color RGB(137, 207, 240) for 3 seconds
🏃 Starting RUNNING/CHASING effect: RGB(137, 207, 240), Duration: 3000ms, Tail: 15 LEDs
```

---

## Speed Calculations

### Before:
- Update interval: 30ms
- LEDs per update: 1
- Time to traverse 500 LEDs: 500 × 30ms = **15 seconds**
- Effect duration: 3 seconds
- **Result: Only covers 100 LEDs in 3 seconds** ❌

### After:
- Update interval: 10ms
- LEDs per update: 5
- Time to traverse 500 LEDs: (500 / 5) × 10ms = **1 second**
- Effect duration: 3 seconds
- **Result: Comet makes 3 complete passes in 3 seconds!** ✅

---

## Troubleshooting White Color Issue

### Step 1: Check Flutter Console
When you press a vote button, you should see:
```
Sending vote celebration to ESP32:
  Color RGB: (137, 207, 240)  ← Should be blue for boy
  Mode: running, Duration: 3000ms
```

OR:
```
Sending vote celebration to ESP32:
  Color RGB: (244, 194, 194)  ← Should be pink for girl
  Mode: running, Duration: 3000ms
```

### Step 2: Check ESP32 Serial Monitor
```bash
cd /Users/leongtl/Documents/project/esp32_rgb_controller
~/.platformio/penv/bin/platformio device monitor
```

When you vote, you should see:
```
=== Theme Command Received ===
Request body: {"colors":[{"r":137,"g":207,"b":240}],"mode":"running","duration":3000}
=== RUNNING/CHASING MODE DETECTED ===
Starting running effect with color RGB(137, 207, 240) for 3 seconds
🏃 Starting RUNNING/CHASING effect: RGB(137, 207, 240), Duration: 3000ms, Tail: 15 LEDs
```

### Possible Causes if Still White:

#### Cause A: Default Color Not Overwritten
The default `runningColor` is `{255, 255, 255}` (white). If the color isn't being set, it stays white.

**Check:** Look at ESP32 serial output - does it show the correct RGB values?

#### Cause B: Color Values Being Lost
The `ThemeColor` struct might not be copying correctly.

**Fix:** Already in place - the code explicitly sets `runningColor = color;`

#### Cause C: Strip Color Order Wrong
Some LED strips use GRB or other color orders instead of RGB.

**Test:** Try sending pure red RGB(255, 0, 0) - if it shows as green, color order is wrong.

**Fix in `main.cpp`:**
```cpp
// Current:
Adafruit_NeoPixel strip(NUM_LEDS, LED_PIN, NEO_GRB + NEO_KHZ800);

// If colors are wrong, try:
Adafruit_NeoPixel strip(NUM_LEDS, LED_PIN, NEO_RGB + NEO_KHZ800);
// or
Adafruit_NeoPixel strip(NUM_LEDS, LED_PIN, NEO_GRBW + NEO_KHZ800);
```

---

## Testing Procedure

### Test 1: Speed Test
1. Vote for Boy
2. Observe: Comet should traverse the entire 500 LED strip in ~1 second
3. Result: Should make ~3 complete passes in 3 seconds

### Test 2: Rainbow Return Test
1. Vote for Boy
2. Wait 3 seconds
3. Observe: Rainbow effect should start immediately after running effect ends
4. Result: No black/off period between effects

### Test 3: Color Test
1. **Vote for Boy:**
   - Flutter console should show: `Color RGB: (137, 207, 240)`
   - ESP32 should show: `RGB(137, 207, 240)`
   - LEDs should show: Baby blue comet
   
2. **Vote for Girl:**
   - Flutter console should show: `Color RGB: (244, 194, 194)`
   - ESP32 should show: `RGB(244, 194, 194)`
   - LEDs should show: Baby pink comet

---

## Files Changed

### ESP32 Firmware (`main.cpp`):
1. ✅ Changed `RUNNING_UPDATE_INTERVAL` from 30ms to 10ms
2. ✅ Changed `COMET_TAIL_LENGTH` from 8 to 15 LEDs
3. ✅ Added `COMET_SPEED` constant (5 LEDs per update)
4. ✅ Updated `updateRunningEffect()` to move COMET_SPEED LEDs per update
5. ✅ Fixed `stopRunningEffect()` to not turn off LEDs

### Flutter (`vote_screen.dart`):
1. ✅ Added detailed color logging for troubleshooting

---

## Next Steps if White Color Persists

1. **Check Serial Monitor Output**
   - Run `platformio device monitor`
   - Vote and check if RGB values are correct in serial output

2. **If ESP32 receives correct values but shows white:**
   - Check LED strip wiring
   - Verify power supply is adequate for 500 LEDs
   - Test with `setLEDsImmediate(137, 207, 240)` directly

3. **If ESP32 receives (255, 255, 255):**
   - Issue is in Flutter or HTTP transmission
   - Check browser console for HTTP request details
   - Verify ESP32 IP is correct

4. **Manual Test:**
   ```bash
   curl -X POST http://[ESP32_IP]:80/theme \
     -H "Content-Type: application/json" \
     -d '{"colors":[{"r":137,"g":207,"b":240}],"mode":"running","duration":3000}'
   ```
   
   LEDs should show blue comet. If still white, problem is in ESP32 code.

---

**Status:** Fixes applied and uploaded ✅  
**Test:** Vote and check serial monitor for color values  
**Expected:** Fast blue/pink comet that returns to rainbow
