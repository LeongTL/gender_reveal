# How to Upload ESP32 Firmware

## Quick Upload Methods

### Method 1: VS Code PlatformIO Extension (Recommended)

If you have PlatformIO extension installed in VS Code:

1. Open the `esp32_rgb_controller` folder in VS Code
2. Look for the PlatformIO icon in the left sidebar (alien head icon)
3. Click on it to open PlatformIO panel
4. Under "PROJECT TASKS" → "esp32dev" → "General", click "Upload"
5. Wait for compilation and upload to complete

### Method 2: PlatformIO Command Line

If you have PlatformIO CLI installed:

```bash
cd /Users/leongtl/Documents/project/esp32_rgb_controller
pio run --target upload
```

### Method 3: Arduino IDE

If you prefer Arduino IDE:

1. Install ESP32 board support:
   - Open Arduino IDE
   - Go to File → Preferences
   - Add to "Additional Board Manager URLs": 
     `https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json`
   - Go to Tools → Board → Boards Manager
   - Search for "esp32" and install "ESP32 by Espressif Systems"

2. Install required libraries:
   - Tools → Manage Libraries
   - Install: ArduinoJson, Adafruit NeoPixel

3. Open and upload:
   - Open `/Users/leongtl/Documents/project/esp32_rgb_controller/src/main.cpp`
   - Tools → Board → ESP32 Arduino → ESP32 Dev Module
   - Tools → Port → Select your ESP32 port (usually /dev/cu.usbserial-*)
   - Click Upload button (→)

## Install PlatformIO (If Not Installed)

### Option A: VS Code Extension (Easiest)

1. Open VS Code
2. Click Extensions icon (⇧⌘X)
3. Search for "PlatformIO IDE"
4. Click Install
5. Restart VS Code
6. Done! You'll see PlatformIO icon in sidebar

### Option B: Command Line Install

```bash
# Install Python if needed
brew install python3

# Install PlatformIO Core
pip3 install platformio

# Verify installation
pio --version
```

If `pio` command is not found after install, add to PATH:

```bash
# Add to ~/.zshrc
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# Verify again
pio --version
```

## Troubleshooting Upload Issues

### Error: "Serial port not found"

**Solution**: Check USB connection and port permissions

```bash
# List available serial ports
ls /dev/cu.*

# You should see something like:
# /dev/cu.usbserial-0001
# /dev/cu.SLAB_USBtoUART
# /dev/cu.wchusbserial1234
```

If nothing shows up:
1. Check USB cable is connected
2. Check USB cable supports data (not just charging)
3. Install USB-to-Serial driver for your ESP32:
   - CP2102: https://www.silabs.com/developers/usb-to-uart-bridge-vcp-drivers
   - CH340: https://github.com/adrianmihalko/ch340g-ch34g-ch34x-mac-os-x-driver

### Error: "Permission denied"

**Solution**: Add user to dialout group (Linux) or grant permissions (Mac)

```bash
# Mac - grant terminal access to USB devices
# System Preferences → Security & Privacy → Files and Folders
# Check box for "Terminal" or "VS Code"

# Or use sudo (temporary fix)
sudo pio run --target upload
```

### Error: "Timed out waiting for packet header"

**Solution**: Put ESP32 in flash mode manually

1. Hold down BOOT button on ESP32
2. Press and release RESET button (while holding BOOT)
3. Release BOOT button
4. Try upload again
5. Press RESET button after upload completes

### Error: "Compilation failed"

**Solution**: Check code syntax and dependencies

```bash
# Clean build and try again
cd /Users/leongtl/Documents/project/esp32_rgb_controller
pio run --target clean
pio run --target upload
```

## Verify Successful Upload

After uploading, you should see:

```
Hard resetting via RTS pin...
========================= [SUCCESS] Took X.XX seconds =========================
```

### Check ESP32 Serial Monitor

```bash
# Using PlatformIO
pio device monitor

# Or in VS Code PlatformIO
# Click PlatformIO icon → Project Tasks → Monitor
```

You should see:
```
Connecting to WiFi: AOT_Titan
WiFi Connected!
IP Address: 192.168.1.XXX
🌈 Rainbow effect started as default
Ready for commands!
```

## Quick Test After Upload

1. **Note the IP address** from serial monitor
2. **Test in browser**: Open `http://192.168.1.XXX` (replace with your ESP32 IP)
3. **Should see**: ESP32 RGB Controller status page
4. **Test vote celebration**:
   - Open Flutter app
   - Set ESP32 IP in settings
   - Cast a vote
   - Watch for 3-second running effect → auto-return to rainbow

## Current Firmware Features

After uploading the latest firmware, your ESP32 will have:

✅ **Rainbow mode** as default on startup
✅ **Running/chasing comet effect** for vote celebrations
✅ **Auto-return to rainbow** after running effect (3 seconds)
✅ **Proper CORS headers** for browser compatibility
✅ **Fast, smooth animations** optimized for 500 LEDs
✅ **Debug logging** via serial monitor

## Files You're Uploading

- **Main code**: `src/main.cpp` (1509 lines)
- **Configuration**: `platformio.ini`
- **WiFi config**: `include/config.h` (if exists)

## Upload Checklist

- [ ] ESP32 connected to computer via USB
- [ ] USB cable supports data transfer (not just power)
- [ ] PlatformIO or Arduino IDE installed
- [ ] Required libraries installed (ArduinoJson, Adafruit NeoPixel)
- [ ] WiFi credentials set in code (WIFI_SSID, WIFI_PASSWORD)
- [ ] Correct board selected (ESP32 Dev Module)
- [ ] Serial port selected and accessible
- [ ] Upload initiated and successful
- [ ] Serial monitor shows "Ready for commands!"
- [ ] Rainbow effect is visible on LEDs

---

**Ready to upload?** Choose your preferred method above and follow the steps! 🚀
