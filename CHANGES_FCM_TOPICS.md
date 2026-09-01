# FCM Topics Implementation - Complete Summary

## Overview
Implemented exclusive FCM (Firebase Cloud Messaging) topics per house/module in both the Flutter application and ESP32 firmware. Each module now has its own configurable FCM topic, allowing selective notification delivery to authorized devices.

## Files Modified/Created

### Flutter Application

#### 1. **lib/utils/fcm_utils.dart** (NEW)
- **Purpose**: Utility class for FCM topic validation and generation
- **Key Functions**:
  - `validateTopic(String? topic)`: Validates topic format
    - Max 900 characters
    - Only allows: letters, numbers, `_`, `-`, `.`, `~`, `%`
    - Returns error message or null if valid
  - `generateSecureTopic()`: Generates secure topic in format `sentinel_<32_hex_chars>`

#### 2. **lib/services/esp32_service.dart** (MODIFIED)
- **Changes**:
  - Updated `salvarConfiguracoes()` method to accept `fcmTopic` parameter
  - Now sends fcmtopic to ESP32 in POST request body

#### 3. **lib/services/fcm_subscription_service.dart** (NEW)
- **Purpose**: Manages FCM topic subscriptions for all modules
- **Key Methods**:
  - `subscribeToAllModuleTopics()`: Subscribes to all saved modules' FCM topics
    - Loads all modules from database
    - Extracts fcmtopic from each module's specificSettings
    - Falls back to `'campainha'` for old modules without fcmtopic
    - Subscribes to each unique topic
  - `unsubscribeFromTopicIfUnused(String topic)`: Unsubscribes only if no other module uses the topic
    - Prevents unsubscribing from topics still in use
    - Never unsubscribes from default topic
- **Platform**: Android only (uses Firebase Messaging)

#### 4. **lib/screens/module_edit_screen.dart** (MODIFIED)
- **Changes**:
  - Added `_fcmTopicController` for FCM topic field
  - Added FCM topic section in UI with:
    - Explanatory text: "Celulares com este mesmo tópico receberão os alertas deste módulo."
    - Text field for topic input with validation
    - "Gerar" (Generate) button to create secure topic
  - Updated `initState()` to load fcmtopic from module settings
  - Updated `dispose()` to clean up controller
  - Updated `_loadFromDevice()` to load fcmtopic from `/status` endpoint
  - Updated `_validateFcmTopic()` to validate topic format
  - Updated `_saveModule()` to:
    - Include fcmtopic in POST to ESP32
    - Handle FCM subscription changes:
      - Unsubscribe from old topic if it changed
      - Subscribe to new topic
    - Track old topic to detect changes

#### 5. **lib/main.dart** (MODIFIED)
- **Changes**:
  - Removed hardcoded `_fcmTopicName = 'campainha'` constant
  - Changed to `_defaultFcmTopic = 'campainha'` for fallback
  - Added import for `ModuleService`
  - Updated `_initializeFCMService()` to call `_subscribeToAllModuleTopics()` instead of hardcoded topic subscription
  - Added new method `_subscribeToAllModuleTopics()`:
    - Loads all modules at startup
    - Subscribes to each module's fcmtopic
    - Falls back to default topic for modules without fcmtopic
    - Handles errors gracefully with fallback to default
    - Logs each subscription for debugging

### ESP32 Firmware

#### **esp32/sentinel_hub_esp32.ino** (MODIFIED)
- **New Variables**:
  - `fcmTopic` - stores the FCM topic (default: "campainha")
  - `storedDuckdom`, `storedDucktok`, `storedCamp1`, `storedCamp2` - additional configuration

- **New Function**:
  - `validateFcmTopic(const String& topic)`: Validates topic format
    - Returns false if empty or > 900 chars
    - Returns false if contains invalid characters
    - Only allows: a-z, A-Z, 0-9, `_`, `-`, `.`, `~`, `%`

- **Updated Functions**:
  - `handleStatus()`: Now returns only exposed fields (security improvement)
    - Returns: status, device, duckdom, camp1, camp2, fcmtopic
    - Does NOT return: ssid, pass, ntfy, connected, ip (sensitive data hidden)
  
  - `handleSalvar()` (formerly handleUpdateConfig):
    - Renamed endpoint from `/updateConfig` to `/salvar`
    - Accepts: duckdom, ducktok, camp1, camp2, fcmtopic
    - Does NOT accept: ssid, pass, ntfy (separate endpoint)
    - Validates fcmtopic before saving
    - Returns HTTP 400 with error JSON if validation fails (no restart)
    - Returns HTTP 200 and restarts on success
  
  - `loadPreferences()`: Loads all new fields including fcmtopic (default: "campainha")

- **Updated Routing**:
  - Both captive portal and normal mode register `/salvar` endpoint
  - `/status` endpoint updated with new response format

## Behavior Changes

### On Android App Startup
1. Firebase Cloud Messaging initialized
2. All stored modules loaded
3. For each module with fcmtopic → subscribe to that topic
4. For old modules without fcmtopic → subscribe to default "campainha"
5. Each topic subscription logged for debugging

### On Module Save (Android)
1. Module data sent to ESP32 via POST `/salvar`
2. ESP32 validates fcmtopic:
   - If invalid → returns HTTP 400 with error (no restart)
   - If valid → saves to Preferences and restarts
3. Flutter app receives success (HTTP 200)
4. App updates local database with new module settings
5. FCM topic subscription updated:
   - Old topic: unsubscribed (if no other module uses it)
   - New topic: subscribed
6. User sees success message

### On Linux/Windows
- Firebase and FCM services **not initialized** (no impact)
- Module management works normally (local database only)
- No FCM topic handling

## Backward Compatibility

### For Old Modules Without fcmtopic
- Get default topic "campainha" assigned
- Work with existing devices already subscribed to "campainha"
- Can be updated to have custom topic via UI

### For Old ESP32 Firmware
- Won't support the new `/salvar` endpoint format
- Won't validate or persist fcmtopic
- Can still receive configuration if using old `/updateConfig` endpoint

## Validation Rules

### FCM Topic Validation (Both Firmware and App)
- **Empty Check**: Topic cannot be empty
- **Length**: Maximum 900 characters
- **Characters**: Only `[a-zA-Z0-9_\-.~%]` allowed
- **Error Handling**:
  - App: Shows validation error in UI
  - Firmware: Returns HTTP 400 with JSON error, does NOT restart

## API Changes

### GET /status
**OLD Response**:
```json
{
  "connected": true,
  "ip": "192.168.1.100",
  "ssid": "MyWiFi",
  "topic": "sentinel_hub"
}
```

**NEW Response**:
```json
{
  "status": "ok",
  "device": "ESP32",
  "duckdom": "mydevice.duckdns.org",
  "camp1": "12345",
  "camp2": "67890",
  "fcmtopic": "sentinel_7f29c4a9d83e41c2b5f6078a1d9e34bc"
}
```

### POST /salvar
**Accepted Parameters**:
- `duckdom` (DuckDNS domain)
- `ducktok` (DuckDNS token)
- `camp1` (Doorbell code 1)
- `camp2` (Doorbell code 2)
- `fcmtopic` (FCM topic)

**Response on Validation Error** (HTTP 400):
```json
{
  "error": "Tópico FCM inválido. Máximo 900 caracteres. Apenas letras, números, _, -, ., ~, %."
}
```

**Response on Success** (HTTP 200):
```json
{
  "success": true
}
```
*(Device restarts after this response)*

## Build Status

### Successful Builds
- ✅ **Android (APK)**: All architectures built successfully
  - armeabi-v7a (31.9MB)
  - arm64-v8a (35.2MB)
  - x86_64 (40.1MB)
- ✅ **Linux**: Built successfully
- ⚠️ **Windows**: Must build on Windows host (not tested on Linux)

### Analysis
- ✅ Flutter analyze: All warnings fixed (6 unrelated pre-existing issues)

## Testing Checklist

### 1. **Generate FCM Topic in App**
- [ ] Open ModuleEditScreen (create or edit module)
- [ ] Scroll to "Configuração FCM" section
- [ ] Click "Gerar" button
- [ ] Verify topic format: `sentinel_<32_hex_chars>`
- [ ] Topic should be copy-able and editable

### 2. **Validate FCM Topic Input**
- [ ] Try saving with empty topic → should show error
- [ ] Try saving with >900 characters → should show error
- [ ] Try saving with invalid characters → should show error
- [ ] Enter valid topic → should save without validation error

### 3. **Save Module to ESP32**
- [ ] Enter all required fields
- [ ] Set a custom FCM topic
- [ ] Click "Salvar"
- [ ] Module should appear in saved list
- [ ] Check app logs: `[kTsentinel FCM] Inscrito no tópico "sentinel_xxxxx"`

### 4. **Load Configuration from ESP32**
- [ ] Click "Carregar do ESP32" button
- [ ] Verify fcmtopic field is populated from `/status` endpoint
- [ ] Other fields (duckdom, camp1, camp2) should also load

### 5. **Confirm Topic Return in GET /status**
- [ ] Query `GET http://esp32.local/status`
- [ ] Response should include: `fcmtopic`
- [ ] Response should NOT include: `ssid`, `pass`, `ntfy`, `connected`, `ip`

### 6. **Multiple Modules with Different Topics**
- [ ] Create 2+ modules with different fcmtopic values
- [ ] App should subscribe to all unique topics
- [ ] Check logs: should show subscription to each topic
- [ ] Trigger alert on different modules → verify only subscribed devices receive

### 7. **Module Topic Change (Old → New)**
- [ ] Save module with topic "sentinel_aaa..."
- [ ] Edit same module, change to "sentinel_bbb..."
- [ ] App should:
  - [ ] Unsubscribe from old topic (if no other module uses it)
  - [ ] Subscribe to new topic
  - Check logs for both operations

### 8. **Backward Compatibility**
- [ ] Edit old module without fcmtopic field
- [ ] Leave fcmtopic empty
- [ ] App should fall back to "campainha"
- [ ] Check logs: `[kTsentinel FCM] Inscrito no tópico "campainha"`

### 9. **Cross-Platform Behavior**
- [ ] **Android**: Firebase initialized, topics managed
- [ ] **Linux**: No Firebase initialization, module management works normally
- [ ] **Windows**: No Firebase initialization, module management works normally

### 10. **Alert Reception**
- [ ] Send FCM message to `sentinel_xxxxx` topic from Firebase Console
- [ ] Only devices subscribed to that exact topic should receive alert
- [ ] Verify notification appears with correct title/body
- [ ] Verify Android logs show message receipt

### 11. **Error Scenarios**
- [ ] ESP32 validation error (fcmtopic > 900 chars)
  - [ ] Firmware returns HTTP 400
  - [ ] Firmware does NOT restart
  - [ ] App shows error message
  
- [ ] Network error during save
  - [ ] ESP32 not reachable
  - [ ] App shows connection error
  - [ ] No FCM subscription changes

### 12. **App Initialization**
- [ ] Close and reopen app
- [ ] All saved modules' topics should be subscribed during startup
- [ ] Check logs: all topics listed as subscribed

## Key Security Notes

1. **Private Keys NOT Exposed**: Firebase credentials remain on device, never sent
2. **Secrets in GET Restricted**: DuckDNS token only sent in POST when user updates
3. **Sensitive Data Hidden**: WiFi credentials and passwords not in `/status` response
4. **Topic Validation**: Both client and server validate topic format
5. **No Default Secrets**: Default topic is "campainha" (public, not a secret)

## Troubleshooting

### No FCM Messages Received
1. Check Android logs: `[kTsentinel FCM]` entries
2. Verify device is subscribed to correct topic
3. Verify FCM message sent to correct topic in Firebase Console
4. Check Firebase Project ID matches `google-services.json`

### Topic Validation Fails
1. Ensure topic ≤ 900 characters
2. Check only valid characters used: `[a-zA-Z0-9_-.~%]`
3. Ensure topic is not empty
4. Test with generated topic format

### Old Modules Not Getting Topics
1. Clear app data and reinstall
2. Re-add modules via UI to assign fcmtopic
3. Or edit existing modules to add/update fcmtopic

### ESP32 Won't Restart After Saving
1. Check validation error in HTTP 400 response
2. Verify fcmtopic format
3. Check ESP32 has sufficient memory
4. Manually reset ESP32 if needed

## Future Improvements

1. **Topic Sharing**: Allow multiple modules to share one topic
2. **Topic Categories**: Group topics by house/area
3. **Encryption**: Encrypt fcmtopic in local storage
4. **Topic History**: Log topic changes for audit trail
5. **Bulk Operations**: Subscribe/unsubscribe to multiple topics at once
