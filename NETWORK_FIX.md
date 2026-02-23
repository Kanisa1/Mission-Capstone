# Network Connection Fix

## Problem: Phone Can't Connect to API

Your registration is failing because your phone can't reach your computer.

## Solution: Use USB Connection (ADB Port Forward)

This works **without WiFi issues or firewall problems**:

### Step 1: Enable USB Debugging (Already Done ✅)

### Step 2: Forward the Port
Open PowerShell and run:
```powershell
adb reverse tcp:8000 tcp:8000
```

### Step 3: Update the App to Use localhost
The app will now use `http://localhost:8000` instead of `http://192.168.1.200:8000`

### Step 4: Reload the App
Press `R` in the Flutter terminal to hot restart.

## Alternative: Use Mobile Hotspot

If USB forwarding doesn't work:

1. **Turn OFF WiFi on your PC**
2. **Create Mobile Hotspot:**
   - Settings → Network & Internet → Mobile Hotspot
   - Turn ON "Share my Internet connection"
3. **Connect your phone** to the PC's hotspot
4. **Use IP:** `http://172.20.0.1:8000`
5. **Update constants.dart** to use `172.20.0.1`

## Check Which Network Your Phone Is On

On your phone:
- Settings → WiFi → [Connected Network Name]
- Compare with PC's network

## Quick Test

After fixing, open your phone's browser and go to:
- http://localhost:8000/docs (if using ADB forward)
OR
- http://172.20.0.1:8000/docs (if using hotspot)

If you see the API documentation page, it's working!
