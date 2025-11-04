# ESP32 RGB Light Integration for Gender Reveal

## Overview
This integration allows the Gender Reveal web app to control an ESP32 RGB light device over HTTP, showing pink for girl or blue for boy based on voting results.

## Files Added/Modified

### New Files
1. **`lib/services/esp32_light_service.dart`** - ESP32 HTTP control service
   - Handles HTTP communication with ESP32 device
   - Preset colors: Pink (255,105,180) for girl, Blue (0,191,255) for boy
   - Web-optimized with CORS error handling

### Modified Files
1. **`lib/screens/gender_reveal_screen.dart`**
   - Added ESP32 service instance
   - Added TEST button to send current gender color
   - Added Discovery button to configure ESP32 IP address
   - Both buttons only visible to admin user (UUID: ZtVkO42SpvcIm8yqOkzSbYIBH6s1)

2. **`pubspec.yaml`**
   - Added `http: ^1.1.0` dependency for HTTP requests

## How to Use

### 1. Configure ESP32 IP Address
- Click the **"Discovery"** button on the gender reveal screen
- Enter your ESP32 device IP address (e.g., `192.168.31.37`)
- Click **"Save"**

### 2. Test RGB Light
- Click the **"TEST"** button
- The app will send the current leading gender's color to the ESP32:
  - **Blue** if boys are winning
  - **Pink** if girls are winning
- You'll see a success/error message

### 3. Send "Reveal Answer" Theme Animation ✨ NEW!
- Click the **"Reveal Theme"** button
- Sends an alternating **pink/blue flashing animation** to ESP32
- Animation runs for 10 seconds with fast flashing (300ms per color)
- Perfect for building suspense before the gender reveal!

### 4. View Debug Logs
- Open browser DevTools Console (F12)
- Look for messages with emojis:
  - 🌐 = Web request being sent
  - 📡 = Response from ESP32
  - ✅ = Success
  - ❌ = Error
  - 🚫 = CORS error

## ESP32 Firmware Requirements

Your ESP32 must have an HTTP server with the following endpoints:

### Endpoint: POST `/color`
**Request:**
```json
{
  "r": 255,  // Red (0-255)
  "g": 105,  // Green (0-255)
  "b": 180   // Blue (0-255)
}
```

**Response:**
```json
{
  "status": "ok"
}
```

### Endpoint: POST `/theme` ✨ NEW!
**Request:**
```json
{
  "colors": [
    {"r": 255, "g": 20, "b": 147},   // Hot pink
    {"r": 0, "g": 0, "b": 255}        // Pure blue
  ],
  "duration": 300,           // Milliseconds per color
  "transitionTime": 0,       // Transition delay (0 = instant switch)
  "loop": true,              // Whether to loop the animation
  "totalDuration": 10000     // Total animation duration (ms)
}
```

**Response:**
```json
{
  "status": "ok"
}
```

**Implementation Notes:**
- ESP32 should cycle through the colors array
- Each color displays for `duration` milliseconds
- After all colors, wait `transitionTime` before repeating
- If `loop` is true, repeat until `totalDuration` expires
- Return to previous color/state after animation completes

### CORS Headers (Required for Web Browser)
Your ESP32 firmware must include these HTTP headers in responses:

```cpp
server.sendHeader("Access-Control-Allow-Origin", "*");
server.sendHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
server.sendHeader("Access-Control-Allow-Headers", "Content-Type");
```

### Handle OPTIONS Requests
```cpp
server.on("/color", HTTP_OPTIONS, []() {
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.sendHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  server.sendHeader("Access-Control-Allow-Headers", "Content-Type");
  server.send(204); // No Content
});
```

## Troubleshooting

### Issue: "Failed to update ESP32 light"
**Solutions:**
1. Check ESP32 is powered on and connected to WiFi
2. Verify IP address is correct (use Discovery to update)
3. Ensure ESP32 and web app are on same network
4. Check browser console for detailed error messages

### Issue: CORS Error in Browser Console
**Solution:**
Add CORS headers to your ESP32 firmware (see above)

### Issue: Request Timeout
**Solutions:**
1. Reduce network latency
2. Check ESP32 HTTP server is responding
3. Try accessing `http://[ESP32_IP]:80/` directly in browser

### Issue: Connection Refused
**Solutions:**
1. Verify ESP32 IP address
2. Check port 80 is open and listening
3. Disable any firewalls blocking port 80

## Color Reference

### Boy (Blue)
- RGB: (0, 191, 255)
- Hex: #00BFFF
- Name: Deep Sky Blue

### Girl (Pink)
- RGB: (255, 105, 180)
- Hex: #FF69B4
- Name: Hot Pink

## Technical Details

### HTTP Request Format
```
POST http://[ESP32_IP]:80/color
Content-Type: application/json
Connection: close

{"r":255,"g":105,"b":180}
```

### Timeout Settings
- Connection timeout: 5 seconds
- Request timeout: 5 seconds

### Rate Limiting
No rate limiting is currently implemented in the gender reveal app (unlike rgb_light which limits to 2 commands/second). This is intentional since we only send colors on explicit TEST button press.

## Future Enhancements

Possible improvements:
1. Auto-send color when gender is revealed
2. Save ESP32 IP to local storage
3. Add brightness control
4. Support multiple ESP32 devices
5. Add color animation effects
6. Send color updates in real-time as votes change

## References

- Based on implementation from `rgb_light` project
- ESP32 HTTP endpoints match existing ESP32 RGB firmware
- Web platform only (no mobile app support currently)
