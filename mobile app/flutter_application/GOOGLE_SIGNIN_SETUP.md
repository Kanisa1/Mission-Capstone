# Google Sign-In Setup Guide

## Current Status
✅ Code fixes applied:
- Fixed response parsing to match API structure
- Fixed approval status field names
- Added internet permissions to AndroidManifest.xml
- Updated both register and login screens

## Required Setup for Google Sign-In

### Step 1: Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project or use existing one
3. Add your Android app to the project

### Step 2: Get SHA-1 Fingerprint
Run this command in your project root:
```bash
cd android
./gradlew signingReport
```

For debug builds, copy the SHA-1 fingerprint from the output.

### Step 3: Download google-services.json
1. In Firebase Console, go to Project Settings
2. Download `google-services.json`
3. Place it in: `android/app/google-services.json`

### Step 4: Add Google Sign-In Support
The `google-services.json` file must contain your OAuth 2.0 client ID. Firebase generates this automatically when you:
1. Enable Google Sign-In in Firebase Authentication
2. Add your SHA-1 fingerprint in Firebase Project Settings

### Step 5: Update android/build.gradle
Add the Google services plugin:
```gradle
buildscript {
    dependencies {
        // Add this line
        classpath 'com.google.gms:google-services:4.3.15'
    }
}
```

### Step 6: Update android/app/build.gradle
Add at the bottom:
```gradle
apply plugin: 'com.google.gms.google-services'
```

## Alternative: Use Email Registration
If you don't want to set up Google Sign-In right now:
1. Use the email registration form on the Register screen
2. Fill in name, email, password, role, and organization
3. Wait for admin approval

## Testing Email Registration
1. **Register a new account:**
   - Email: test@example.com
   - Password: test123
   - Role: operator
   - Organization: Test Org

2. **Login as admin to approve:**
   - Email: admin@example.com
   - Password: admin123
   - Go to Profile → Admin → Pending Approvals
   - Approve the test account

3. **Login with approved account**

## Current Fix Summary
The Google Sign-In was failing because:
1. ❌ Wrong field names: `response['is_new_user']` → `response.containsKey('message')`
2. ❌ Wrong approval field: `response['status']` → `response['approval_status']`
3. ❌ Wrong user data access: `response['id']` → `response['user']['id']`
4. ❌ Missing internet permission in AndroidManifest.xml

All these have been fixed! However, Google Sign-In still requires Firebase configuration files to work.

## Next Steps
1. **For now:** Use email registration (it works!)
2. **Later:** Set up Firebase if you need Google Sign-In
3. **Test:** Try creating an account with email and approving it as admin
