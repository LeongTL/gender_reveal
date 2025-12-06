# Reverted: Reveal Answer Permanent Color Fix

**Date:** December 6, 2025

## Changes Reverted

All changes from `REVEAL_ANSWER_PERMANENT_FIX.md` have been reverted because they were causing issues with the vote button's run_effect functionality.

---

## Files Modified

### 1. Flutter: `lib/services/firestore_service.dart`

**Reverted:** Removed `permanent` parameter from `sendThemeCommand()`

```dart
// BEFORE (with permanent parameter):
static Future<String> sendThemeCommand(
  String theme,
  int brightness, {
  bool permanent = false,
}) async {
  // ... sent permanent: permanent to Firebase
}

// AFTER (reverted):
static Future<String> sendThemeCommand(
  String theme,
  int brightness,
) async {
  // ... no permanent parameter
}
```

### 2. Flutter: `lib/screens/gender_reveal_screen.dart`

**Reverted:** Removed `permanent: true` from reveal sequence

```dart
// BEFORE:
await FirestoreService.sendThemeCommand(babyGender, 255, permanent: true);

// AFTER (reverted):
await FirestoreService.sendThemeCommand(babyGender, 255);
```

### 3. ESP32: `src/main.cpp`

**Reverted three changes:**

#### 3a. Removed fast blink color storage variables
```cpp
// REMOVED:
ThemeColor fastBlinkColor1 = {255, 255, 255};
ThemeColor fastBlinkColor2 = {255, 255, 255};
```

#### 3b. Reverted `startFastBlink()` function
```cpp
// REMOVED storing colors:
void startFastBlink(ThemeColor color1, ThemeColor color2, unsigned long customDuration) {
  // REMOVED: fastBlinkColor1 = color1;
  // REMOVED: fastBlinkColor2 = color2;
  
  fastBlinkMode = true;
  fastBlinkStartTime = millis();
  // ... rest of function
}
```

#### 3c. Reverted `updateFastBlink()` function
```cpp
// REVERTED to use currentTheme.colors instead of stored colors:
void updateFastBlink() {
  // ...
  if ((now / FAST_BLINK_SPEED) % 2 == 0) {
    setLEDsImmediate(currentTheme.colors[0].r, currentTheme.colors[0].g, currentTheme.colors[0].b);
  } else {
    setLEDsImmediate(currentTheme.colors[1].r, currentTheme.colors[1].g, currentTheme.colors[1].b);
  }
}
```

#### 3d. Reverted `set_theme` command handler
```cpp
// REMOVED permanent parameter handling:
if (command == "set_theme") {
  // REMOVED: FirebaseJsonData permanentData;
  // REMOVED: commandJson.get(permanentData, "parameters/permanent");
  // REMOVED: bool isPermanent = permanentData.success && permanentData.boolValue;
  
  // REVERTED: Always set timer (no permanent mode):
  if (theme == "boy") {
    setLEDsImmediate(30, 144, 255);
    themeTimerActive = true;  // ALWAYS true now
    themeStartTime = millis();
    Serial.println("🔵 Boy theme set");
  }
  // ... similar for girl and neutral
  
  // REMOVED: stopFastBlink() call
}
```

---

## Current Behavior (After Revert)

### Reveal Answer Sequence:
1. **Phase 1 (10 seconds):** Fast blink (may not show correct colors due to currentTheme dependency)
2. **Phase 2 (5 seconds):** Complete blackout
3. **Phase 3 (5 seconds):** Static gender color
4. **After Phase 3:** Returns to rainbow mode automatically

### Vote Effect:
- Should work correctly again
- Blue/pink comet animations should run when users vote

---

## Issue with Original Fix

The permanent color fix was causing the vote button's `run_effect` command to not work properly, preventing the comet animations from displaying when users cast their votes.

---

## Next Steps

To fix the reveal answer functionality properly without breaking vote effects:
1. Need to investigate why the changes interfered with `run_effect` commands
2. May need a different approach to keep the final color permanent
3. Consider using a different command or flag that doesn't interfere with running effects

---

## Notes

- The code is now back to its original state before the permanent fix
- Vote celebrations should work correctly
- Gender reveal will return to rainbow after 5 seconds (original behavior)
