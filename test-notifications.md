# 📱 PriceAdjustPro Notification Testing Guide

## 🎯 Overview
This guide provides comprehensive testing procedures for the notification system in PriceAdjustPro iOS app.

## 🚀 Quick Start Testing

### 1. Enable Notifications (First Time Setup)
```
1. Open the app on a REAL DEVICE (notifications don't work in simulator)
2. Grant notification permissions when prompted
3. Go to Settings → Notifications → verify permissions are enabled
```

### 2. Access Testing Tools
```
1. Open app → Settings → "Developer Testing" section (only visible in Debug builds)
2. Tap different test buttons to trigger notifications
3. Put app in background or lock screen to see notifications
```

## 🧪 Testing Scenarios

### Scenario 1: Basic Notification Test
**Goal**: Verify basic notification delivery works

**Steps**:
1. Open Settings → Developer Testing
2. Tap "Test Basic Notification"
3. Put app in background immediately
4. Wait 2-5 seconds
5. **Expected**: See test notification appear

**Success Criteria**:
- ✅ Notification appears with correct title/body
- ✅ Notification sound plays
- ✅ App badge updates

### Scenario 2: Sale Alert Test
**Goal**: Test sale-specific notifications

**Steps**:
1. Settings → Developer Testing → "Test Sale Alert"
2. Background the app
3. **Expected**: "🏷️ New Sale Alert!" notification

**Success Criteria**:
- ✅ Sale-specific emoji and messaging
- ✅ Tapping notification opens "On Sale" tab
- ✅ Notification includes savings amount

### Scenario 3: Price Drop Alert Test
**Goal**: Test price adjustment notifications

**Steps**:
1. Settings → Developer Testing → "Test Price Drop Alert" 
2. Background the app
3. **Expected**: "📉 Price Drop Alert!" notification

**Success Criteria**:
- ✅ Price drop specific messaging
- ✅ Shows old price vs new price
- ✅ Shows savings amount

### Scenario 4: Receipt Processing Test
**Goal**: Test receipt completion notifications

**Steps**:
1. Settings → Developer Testing → "Test Receipt Processed"
2. Background the app
3. **Expected**: "✅ Receipt Processed!" notification

**Success Criteria**:
- ✅ Receipt-specific messaging
- ✅ Shows receipt number
- ✅ Shows item count

### Scenario 5: Advanced Custom Testing
**Goal**: Test custom notification parameters

**Steps**:
1. Settings → Developer Testing → "Advanced Testing"
2. Modify title, body, and delay
3. Send custom notification
4. **Expected**: Custom notification with specified content

## 🔍 Integration Testing

### Test Real Data Flow
```
1. Trigger actual API calls that would generate notifications:
   - Force refresh "On Sale" tab multiple times
   - Force refresh "Price Adjustments" tab multiple times
   - Add/process receipts

2. Monitor console logs for notification triggers:
   - Look for "Found X new sale items" logs
   - Look for "Found X new price adjustments" logs
```

### Test Navigation from Notifications
```
1. Send test notifications
2. Tap on notifications when they appear
3. Verify app opens to correct tab:
   - Sale alerts → On Sale tab
   - Price drops → On Sale tab  
   - Receipt processed → Receipts tab
```

## 📊 Performance Testing

### Load Testing
```
1. Use Advanced Testing to send multiple notifications rapidly
2. Verify system handles multiple notifications gracefully
3. Check that spam prevention works (max 3 notifications per batch)
```

### Battery Impact Testing
```
1. Enable all notification types
2. Use app normally for extended period
3. Monitor battery usage in Settings → Battery
```

## 🐛 Error Scenarios

### Permission Denied Test
```
1. Go to iOS Settings → PriceAdjustPro → Notifications
2. Turn OFF "Allow Notifications"
3. Try sending test notifications
4. **Expected**: Graceful handling, no crashes
```

### Network Error Test
```
1. Turn off WiFi/cellular
2. Try refreshing sales/price adjustments
3. **Expected**: No notification attempts, error handling
```

## 📱 Device-Specific Testing

### Test on Multiple Devices
- iPhone (different sizes: SE, standard, Plus/Max)
- Different iOS versions (15.0+)
- Different notification settings (banners, alerts, etc.)

### Test Different States
```
- App in foreground (notifications should show as banners)
- App in background (notifications show on lock screen)
- Device locked (notifications wake screen)
- Do Not Disturb mode (notifications should queue)
```

## 📋 Verification Checklist

### Notification Content ✅
- [ ] Correct emoji usage (🏷️, 📉, ✅, 🛍️)
- [ ] Clear, actionable text
- [ ] Proper formatting of prices/savings
- [ ] No typos or formatting issues

### Notification Behavior ✅
- [ ] Appropriate sound/vibration
- [ ] Correct app badge updates
- [ ] Proper timing (not too frequent)
- [ ] Respect user notification settings

### Navigation ✅
- [ ] Tapping notification opens correct tab
- [ ] App state properly restored
- [ ] No crashes when opening from notification
- [ ] Proper handling of deep linking

### Edge Cases ✅
- [ ] No notifications on initial app install
- [ ] No duplicate notifications
- [ ] Proper handling when notifications disabled
- [ ] Graceful degradation on errors

## 🔧 Troubleshooting

### No Notifications Appearing
```
1. Check iOS Settings → PriceAdjustPro → Notifications
2. Verify "Allow Notifications" is ON
3. Check alert style (Banners vs Alerts)
4. Restart app and try again
5. Check console logs for errors
```

### Notifications Not Opening App Correctly
```
1. Verify NotificationManager action handlers
2. Check NSNotification.Name extensions exist
3. Test navigation manually in app
```

### Performance Issues
```
1. Check if too many notifications being sent
2. Verify spam prevention is working
3. Monitor memory usage during testing
```

## 📈 Success Metrics

### Functionality
- ✅ 100% of test notifications deliver successfully
- ✅ Navigation works for all notification types
- ✅ No crashes during notification flow

### User Experience
- ✅ Notifications are helpful, not annoying
- ✅ Timing feels natural (not spammy)
- ✅ Clear value proposition in each notification

### Performance
- ✅ No noticeable battery drain
- ✅ Fast notification delivery (< 5 seconds)
- ✅ Smooth app opening from notifications

## 🔄 Automated Testing

### Run Unit Tests
```bash
# In Xcode, press Cmd+U to run all tests
# Or run specific test classes:
# - NotificationManagerTests
# - NotificationViewModelTests
```

### CI/CD Integration
```yaml
# Example GitHub Actions test step
- name: Run Tests
  run: |
    xcodebuild test \
      -scheme PriceAdjustPro \
      -destination 'platform=iOS Simulator,name=iPhone 15' \
      -testPlan PriceAdjustProTests
```

## 📝 Test Results Template

```
Date: ___________
Tester: ___________
Device: ___________
iOS Version: ___________

Test Results:
[ ] Basic notification delivery
[ ] Sale alert content and navigation  
[ ] Price drop alert content and navigation
[ ] Receipt processing alert
[ ] Custom notification testing
[ ] Permission handling
[ ] Error scenarios
[ ] Performance acceptable

Issues Found:
1. ________________________________
2. ________________________________
3. ________________________________

Overall Status: PASS / FAIL / NEEDS WORK
```

## 🎉 Next Steps

After completing testing:
1. Document any issues found
2. Update notification copy if needed
3. Adjust timing/frequency based on user feedback
4. Consider A/B testing different notification styles
5. Monitor real-world usage analytics

---
**Note**: This testing should be done on real devices, as iOS Simulator doesn't support push notifications.