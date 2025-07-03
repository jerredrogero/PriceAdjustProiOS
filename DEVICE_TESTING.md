# 📱 Device Testing Guide for PriceAdjustPro

## 🚀 Quick Setup (5 minutes)

### Prerequisites
- iPhone running iOS 15.0 or later
- Mac with Xcode installed
- Lightning/USB-C cable
- Apple ID (free account works)

## Step-by-Step Setup

### 1. Connect Your Device
```bash
1. Connect iPhone to Mac with cable
2. Unlock iPhone and tap "Trust This Computer" when prompted
3. Enter iPhone passcode to confirm trust
```

### 2. Open Project in Xcode
```bash
1. Open Xcode
2. File → Open → PriceAdjustPro.xcodeproj
3. Wait for project to load
```

### 3. Configure Signing (CRITICAL STEP)
```bash
1. Click "PriceAdjustPro" (blue icon) in left navigator
2. Select "PriceAdjustPro" target (not the project)
3. Click "Signing & Capabilities" tab
4. Check ✅ "Automatically manage signing"
5. In "Team" dropdown, select your Apple ID
6. Change "Bundle Identifier" to something unique:
   
   FROM: com.priceadjustpro.ios
   TO:   com.yourname.priceadjustpro
   
   (Replace "yourname" with your actual name)
```

### 4. Select Your Device
```bash
1. In Xcode toolbar, click device dropdown (next to play button)
2. Select your iPhone from the list
3. Should show "Your iPhone's Name" instead of simulator
```

### 5. Build and Run
```bash
1. Press ⌘R (or click Play button)
2. Xcode will build and install app on your phone
3. App should open automatically on your iPhone
```

## 🛠️ Troubleshooting Common Issues

### Issue: "Could not launch app"
**Solution:**
```bash
1. iPhone Settings → General → VPN & Device Management
2. Find your Apple ID under "Developer App"  
3. Tap your Apple ID → Trust → Trust
4. Try running app again in Xcode
```

### Issue: "Developer Mode Required" (iOS 16+)
**Solution:**
```bash
1. iPhone Settings → Privacy & Security → Developer Mode
2. Turn ON Developer Mode
3. Restart iPhone
4. Try building again
```

### Issue: "Provisioning profile errors"
**Solution:**
```bash
1. Change Bundle Identifier to something more unique
2. Clean build: Product → Clean Build Folder (⌘⇧K)
3. Try building again
4. If still failing, try signing out and back into Xcode with Apple ID
```

### Issue: "No code signature found"
**Solution:**
```bash
1. Signing & Capabilities → Uncheck "Automatically manage signing"
2. Then re-check "Automatically manage signing"  
3. Select your team again
4. Clean and rebuild
```

## 🧪 Testing Notifications

### 1. Grant Permissions
```bash
1. When app first opens, it will ask for notification permissions
2. Tap "Allow" to enable notifications
3. If you missed it: iPhone Settings → PriceAdjustPro → Notifications → Allow
```

### 2. Access Testing Tools
```bash
1. In app: Settings tab → scroll down to "Developer Testing"
2. You'll see 5 test buttons for different notification types
```

### 3. Test Basic Notification
```bash
1. Tap "Test Basic Notification"
2. IMMEDIATELY press Home button (background the app)
3. Wait 3-5 seconds
4. Notification should appear on lock screen/banner! 🎉
```

### 4. Test All Notification Types
```bash
Try each button:
- Test Basic Notification → Generic test
- Test Sale Alert → 🏷️ Sale notification  
- Test Price Drop Alert → 📉 Price drop
- Test Receipt Processed → ✅ Receipt done
- Advanced Testing → Custom notification
```

## 📱 Different Testing Scenarios

### Foreground Testing
```bash
1. Keep app open while testing
2. Notifications appear as banners at top
3. Good for seeing immediate feedback
```

### Background Testing  
```bash
1. Background app after tapping test button
2. Notifications appear on lock screen
3. More realistic user experience
```

### Lock Screen Testing
```bash
1. Lock iPhone after triggering notification
2. Screen will light up when notification arrives
3. Tests real-world notification experience
```

## 🔍 Debugging Tools

### Console Logs in Xcode
```bash
1. Keep Xcode open while testing on device
2. View → Debug Area → Show Debug Area (⌘⇧Y)
3. Look for logs like:
   - "🧪 Test notification sent!"
   - "Advanced test notification scheduled"
   - Any error messages
```

### iPhone Settings Debug
```bash
Check notification settings:
iPhone Settings → PriceAdjustPro → Notifications
- Allow Notifications: ON
- Alert Style: Banners or Alerts (NOT "None")
- Badge App Icon: ON
- Play Sound: ON
```

## ⚡ Advanced Testing

### Test Real Scenarios
```bash
1. Force refresh "On Sale" tab multiple times
2. Force refresh "Price Adjustments" tab
3. Look for console logs about new sales/adjustments
4. These would trigger real notifications in production
```

### Test Navigation
```bash
1. Send test notification
2. When notification appears, TAP it
3. App should open and navigate to correct screen
4. Verify navigation works properly
```

### Test Different iOS States
```bash
- Do Not Disturb mode (notifications should queue)
- Low power mode (should still work)
- Different alert styles (Banners vs Alerts)
- Background app refresh settings
```

## 📊 Success Checklist

### Initial Setup ✅
- [ ] App builds and runs on device without errors
- [ ] No signing/provisioning issues
- [ ] App opens normally

### Notification Permissions ✅
- [ ] App requests notification permissions on first launch
- [ ] Permissions granted in iPhone Settings
- [ ] Developer Testing section visible in app

### Basic Functionality ✅  
- [ ] All 5 test buttons work without crashing
- [ ] Console logs show success messages
- [ ] Notifications appear within 5 seconds

### Advanced Features ✅
- [ ] Tapping notifications opens app correctly
- [ ] Different notification types show correct emoji/text
- [ ] No duplicate or spam notifications
- [ ] Works in different app states (foreground/background)

## 🎯 What to Test Next

### User Experience Testing
```bash
1. Are notifications helpful or annoying?
2. Is the timing appropriate?
3. Is the content clear and actionable?
4. Do they provide real value to users?
```

### Performance Testing
```bash
1. Battery impact during extended use
2. Memory usage while notifications are active
3. App responsiveness after many notifications
```

### Edge Case Testing
```bash
1. What happens with no internet connection?
2. What if user denies notification permissions?
3. How does it handle rapid-fire notifications?
4. Works across different iPhone models/iOS versions?
```

## 🚨 Emergency Fixes

### If App Won't Install
```bash
1. Delete app from iPhone if it exists
2. Clean derived data: rm -rf ~/Library/Developer/Xcode/DerivedData/PriceAdjustPro-*
3. Restart Xcode
4. Change Bundle Identifier again
5. Try building fresh
```

### If Notifications Don't Work
```bash
1. Check iPhone Settings → Notifications → PriceAdjustPro
2. Delete and reinstall app
3. Make sure you background the app after tapping test
4. Check Xcode console for error messages
5. Try different notification types
```

### If Build Keeps Failing
```bash
1. Try a completely different Bundle Identifier
2. Clean build folder in Xcode (Product → Clean Build Folder)
3. Restart Xcode
4. Restart iPhone
5. Try with different Apple ID if needed
```

## 🎉 Success!

Once you see notifications appearing on your iPhone, you've successfully set up device testing! 

**Next steps:**
1. Test different notification types
2. Verify navigation from notifications works
3. Test in different scenarios (background, locked, etc.)
4. Share feedback on notification content/timing
5. Test with real data (refresh sales/price adjustments)

**Remember:** Real device testing is the only way to properly test notifications, so this setup is essential for validating your notification system works correctly! 📱✨