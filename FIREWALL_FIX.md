# Quick Guide: Allow API Server Through Firewall

## The Problem
Your phone shows: "No route to host (192.168.1.200:8000)"
This means Windows Firewall is blocking incoming connections.

## Solution (Choose One):

### Option A: Disable Firewall Temporarily (EASIEST)
1. Press `Windows + I` to open Settings
2. Go to "Privacy & Security" → "Windows Security"
3. Click "Firewall & network protection"
4. Click on "Private network" (your Wi-Fi)
5. Turn OFF "Microsoft Defender Firewall"
6. Try registration again in the app
7. Later, turn it back ON for security

### Option B: Add Firewall Rule (RECOMMENDED)
1. Press `Windows + X`
2. Select "Windows PowerShell (Admin)" or "Terminal (Admin)"
3. Paste this command:
```powershell
netsh advfirewall firewall add rule name="Python API Server" dir=in action=allow protocol=TCP localport=8000
```
4. Press Enter
5. You should see "Ok."
6. Try registration again

### Option C: When Windows Firewall Asks
If you see a Windows Security Alert popup:
- ✅ Check "Private networks"
- ✅ Click "Allow access"

## After Fixing:
Try registering again in your app:
- Name: Kanisa Thiak
- Email: k.thiak@alustudent.com
- Role: Operator
- Password: Kenisa@123

The registration should work!

## Verify It Worked:
Open your browser and go to: http://192.168.1.200:8000/docs
If you see the API docs page, the firewall is open!
