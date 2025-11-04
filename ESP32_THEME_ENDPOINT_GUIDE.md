# ESP32 Firmware - Adding /theme Endpoint

## Problem
The `/theme` endpoint is returning CORS errors while `/color` works fine.

## Solution
Your ESP32 firmware needs to add the `/theme` endpoint with the same CORS handling as `/color`.

## ESP32 Arduino Code

### Step 1: Add CORS Headers Function
```cpp
// Add this function at the top of your code
void sendCORSHeaders() {
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.sendHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  server.sendHeader("Access-Control-Allow-Headers", "Content-Type");
}
```

### Step 2: Add OPTIONS Handler (Required for CORS Preflight)
```cpp
// Handle OPTIONS requests (CORS preflight)
server.on("/theme", HTTP_OPTIONS, []() {
  sendCORSHeaders();
  server.send(204); // No Content
});

server.on("/color", HTTP_OPTIONS, []() {
  sendCORSHeaders();
  server.send(204); // No Content
});
```

### Step 3: Add /theme POST Handler
```cpp
// Handle POST /theme - Theme animation
server.on("/theme", HTTP_POST, []() {
  sendCORSHeaders(); // Send CORS headers first
  
  if (server.hasArg("plain")) {
    String body = server.arg("plain");
    
    // Parse JSON
    DynamicJsonDocument doc(2048);
    DeserializationError error = deserializeJson(doc, body);
    
    if (error) {
      server.send(400, "application/json", "{\"status\":\"error\",\"message\":\"Invalid JSON\"}");
      return;
    }
    
    // Extract theme parameters
    JsonArray colors = doc["colors"];
    int duration = doc["duration"] | 1200;           // Default 1200ms per color
    int transitionTime = doc["transitionTime"] | 0;  // Default 0ms transition
    bool loop = doc["loop"] | true;                   // Default loop = true
    int totalDuration = doc["totalDuration"] | 10000; // Default 10 seconds
    
    // Start theme animation in background
    startThemeAnimation(colors, duration, transitionTime, loop, totalDuration);
    
    server.send(200, "application/json", "{\"status\":\"ok\"}");
  } else {
    server.send(400, "application/json", "{\"status\":\"error\",\"message\":\"No body\"}");
  }
});
```

### Step 4: Update /color Handler (Add CORS)
Make sure your `/color` endpoint also sends CORS headers:

```cpp
server.on("/color", HTTP_POST, []() {
  sendCORSHeaders(); // Add this line
  
  // ...rest of your existing /color code...
  
  server.send(200, "application/json", response);
});
```

### Step 5: Implement Theme Animation Logic
```cpp
// Global variables for theme animation
bool themeAnimating = false;
unsigned long themeStartTime = 0;
unsigned long lastColorChangeTime = 0;
int currentThemeColorIndex = 0;
int themeColorCount = 0;
int themeDuration = 1200;
int themeTransitionTime = 0;
int themeTotalDuration = 10000;
bool themeLoop = true;

// Array to store theme colors (max 20 colors)
struct ThemeColor {
  int r;
  int g;
  int b;
};
ThemeColor themeColors[20];

void startThemeAnimation(JsonArray colors, int duration, int transitionTime, bool loop, int totalDuration) {
  themeAnimating = true;
  themeStartTime = millis();
  lastColorChangeTime = millis();
  currentThemeColorIndex = 0;
  themeColorCount = min((int)colors.size(), 20);
  themeDuration = duration;
  themeTransitionTime = transitionTime;
  themeLoop = loop;
  themeTotalDuration = totalDuration;
  
  // Store colors
  for (int i = 0; i < themeColorCount; i++) {
    JsonObject color = colors[i];
    themeColors[i].r = color["r"] | 0;
    themeColors[i].g = color["g"] | 0;
    themeColors[i].b = color["b"] | 0;
  }
  
  // Set first color immediately
  if (themeColorCount > 0) {
    setRGBColor(themeColors[0].r, themeColors[0].g, themeColors[0].b);
  }
}

void updateThemeAnimation() {
  if (!themeAnimating) return;
  
  unsigned long now = millis();
  unsigned long elapsed = now - themeStartTime;
  
  // Check if total duration expired
  if (elapsed >= themeTotalDuration) {
    themeAnimating = false;
    Serial.println("Theme animation completed");
    return;
  }
  
  // Check if it's time to change color
  if (now - lastColorChangeTime >= themeDuration + themeTransitionTime) {
    lastColorChangeTime = now;
    currentThemeColorIndex++;
    
    // Loop back to start if needed
    if (currentThemeColorIndex >= themeColorCount) {
      if (themeLoop) {
        currentThemeColorIndex = 0;
      } else {
        themeAnimating = false;
        return;
      }
    }
    
    // Set new color
    ThemeColor& color = themeColors[currentThemeColorIndex];
    setRGBColor(color.r, color.g, color.b);
    
    Serial.print("Theme color ");
    Serial.print(currentThemeColorIndex);
    Serial.print(": R=");
    Serial.print(color.r);
    Serial.print(" G=");
    Serial.print(color.g);
    Serial.print(" B=");
    Serial.println(color.b);
  }
}

void setRGBColor(int r, int g, int b) {
  // Your LED control code here
  // Example for WS2812B:
  // strip.setPixelColor(0, strip.Color(r, g, b));
  // strip.show();
  
  // Or for analog RGB:
  // analogWrite(RED_PIN, r);
  // analogWrite(GREEN_PIN, g);
  // analogWrite(BLUE_PIN, b);
}
```

### Step 6: Update loop()
Add theme animation update to your main loop:

```cpp
void loop() {
  server.handleClient(); // Handle HTTP requests
  updateThemeAnimation(); // Update theme animation
  
  // ...rest of your loop code...
}
```

## Required Libraries

Add to your Arduino IDE:
```cpp
#include <ESP8266WebServer.h>  // or <WebServer.h> for ESP32
#include <ArduinoJson.h>
```

Install via Library Manager:
- **ESP8266WebServer** or **WebServer** (built-in for ESP32)
- **ArduinoJson** by Benoit Blanchon (v6.x)

## Testing

After uploading the firmware:

1. **Test /color endpoint:**
   ```bash
   curl -X POST http://192.168.31.37/color \
     -H "Content-Type: application/json" \
     -d '{"r":255,"g":0,"b":0}'
   ```

2. **Test /theme endpoint:**
   ```bash
   curl -X POST http://192.168.31.37/theme \
     -H "Content-Type: application/json" \
     -d '{
       "colors": [
         {"r":255,"g":20,"b":147},
         {"r":0,"g":0,"b":255}
       ],
       "duration": 300,
       "transitionTime": 0,
       "loop": true,
       "totalDuration": 10000
     }'
   ```

3. **Test CORS (from browser console):**
   ```javascript
   fetch('http://192.168.31.37/theme', {
     method: 'POST',
     headers: {'Content-Type': 'application/json'},
     body: JSON.stringify({
       colors: [{r:255,g:20,b:147},{r:0,g:0,b:255}],
       duration: 300,
       transitionTime: 0,
       loop: true,
       totalDuration: 10000
     })
   }).then(r => r.json()).then(console.log);
   ```

## Troubleshooting

### "Failed to fetch" Error
- **Cause**: Missing CORS headers
- **Fix**: Make sure `sendCORSHeaders()` is called in ALL endpoints
- **Fix**: Add OPTIONS handler for preflight requests

### Theme doesn't animate
- **Cause**: `updateThemeAnimation()` not called in loop
- **Fix**: Add to `loop()` function

### Colors don't change
- **Cause**: `setRGBColor()` not implemented correctly
- **Fix**: Check your LED control code (WS2812B, analog, etc.)

### Only first color shows
- **Cause**: Duration too long or loop not working
- **Fix**: Check `themeDuration` and `themeLoop` values
- **Fix**: Add Serial.println() to debug color changes

## Expected Behavior

When you click **"Reveal Theme"** in the gender reveal app:

1. 🎨 ESP32 receives theme pattern (2 colors: pink & blue)
2. ⚡ ESP32 starts flashing pink ⟷ blue (300ms per color)
3. 🔄 Flashing continues for 10 seconds
4. 💖 ESP32 receives static pink color as final state
5. 💗 After 10 seconds, ESP32 shows static pink

## Debugging

Add Serial debug output:
```cpp
void loop() {
  server.handleClient();
  updateThemeAnimation();
  
  // Debug every 5 seconds
  static unsigned long lastDebug = 0;
  if (millis() - lastDebug > 5000) {
    lastDebug = millis();
    Serial.print("Theme animating: ");
    Serial.println(themeAnimating ? "YES" : "NO");
    if (themeAnimating) {
      Serial.print("Current color index: ");
      Serial.println(currentThemeColorIndex);
    }
  }
}
```

## Complete Example

See the full working example in: `ESP32_THEME_FIRMWARE_EXAMPLE.ino` (create this file with the complete code above)
