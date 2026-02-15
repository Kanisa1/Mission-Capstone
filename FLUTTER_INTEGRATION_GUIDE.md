# Flutter Mobile App Integration Guide

## Overview

This guide explains how the Flutter mobile application integrates with the FastAPI backend to provide a complete mineral traceability system.

## System Architecture

```
┌─────────────────────────┐
│  Flutter Mobile App     │
│  (Android/iOS)          │
│                         │
│  - User Interface       │
│  - Camera/Mic Access    │
│  - API Client           │
└───────────┬─────────────┘
            │ HTTP/REST
            │ JSON
            ▼
┌─────────────────────────┐
│  FastAPI Backend        │
│  (Python)               │
│                         │
│  - ML Model Inference   │
│  - Fingerprint Storage  │
│  - User Management      │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  Data Storage           │
│                         │
│  - fingerprints.jsonl   │
│  - users.json           │
│  - logs/                │
└─────────────────────────┘
```

## API Endpoints Used by Mobile App

### 1. Authentication
**Endpoint:** `POST /login`
- **Request:** Form data with `email` and `password`
- **Response:** User object with `id`, `name`, `email`, `role`
- **Flutter Implementation:** [lib/services/api_service.dart](UI/lib/services/api_service.dart#L13-L30)

### 2. Mineral Prediction
**Endpoint:** `POST /predict`
- **Request:** Multipart form with:
  - `image` (optional): Image file
  - `audio` (optional): Audio file
  - `Au`, `Cu`, `Fe`, `S`, `O`: Chemical composition values
- **Response:** Predicted mineral, confidence score, modalities used
- **Note:** At least one modality (image or audio) must be provided

### 3. Fingerprint Generation
**Endpoint:** `POST /fingerprint`
- **Request:** Multipart form with:
  - `image` (optional): Image file
  - `audio` (optional): Audio file
  - `Au`, `Cu`, `Fe`, `S`, `O`: Chemical composition values
  - `sample_id`, `site`, `mineral`, `user_id`, `user_name`: Metadata
- **Response:** Fingerprint data, verification status, confidence score
- **Flutter Implementation:** [lib/services/api_service.dart](UI/lib/services/api_service.dart#L60-L101)

### 4. Verification History
**Endpoint:** `GET /verifications`
- **Query Parameters:** `site` (optional), `limit` (optional)
- **Response:** List of verification records
- **Flutter Implementation:** [lib/services/api_service.dart](UI/lib/services/api_service.dart#L135-L151)

### 5. Statistics
**Endpoint:** `GET /stats`
- **Response:** System-wide statistics (total scans, verification rates, etc.)
- **Flutter Implementation:** [lib/services/api_service.dart](UI/lib/services/api_service.dart#L153-L157)

### 6. Health Check
**Endpoint:** `GET /health`
- **Response:** API health status and supported features
- **Flutter Implementation:** [lib/services/api_service.dart](UI/lib/services/api_service.dart#L159-L163)

## Configuration

### API Base URL Configuration

The API base URL is configured in [UI/lib/constants/api_config.dart](UI/lib/constants/api_config.dart):

```dart
class ApiConfig {
  static const String defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );
}
```

#### Development (Local Machine)
- **Default:** `http://127.0.0.1:8000`
- Use this when testing with Android emulator or iOS simulator

#### Development (Physical Device)
- **Android Device:** Use your computer's local IP address (e.g., `http://192.168.1.100:8000`)
- **iOS Device:** Use your computer's local IP address
- To find your IP:
  - **Windows:** Run `ipconfig` in terminal, look for IPv4 Address
  - **macOS/Linux:** Run `ifconfig` or `ip addr`

#### Production
- Set to your server's public URL (e.g., `https://api.example.com`)

### Changing API URL for Development

**Option 1: Modify api_config.dart**
```dart
static const String defaultBaseUrl = 'http://192.168.1.100:8000';
```

**Option 2: Use Environment Variable**
```bash
# Run with custom URL
flutter run --dart-define=API_BASE_URL=http://192.168.1.100:8000
```

**Option 3: Build with custom URL**
```bash
flutter build apk --dart-define=API_BASE_URL=https://api.example.com
```

## Mobile App Flow

### 1. User Login
1. User opens app → [OnboardingScreen](UI/lib/screens/mobile/onboarding_screen.dart) or [LoginScreen](UI/lib/screens/mobile/login_screen.dart)
2. Enter credentials → `ApiService.login()`
3. On success → Navigate to [HomeScreen](UI/lib/screens/mobile/home_screen.dart)

### 2. Mineral Scan & Verification
1. User taps "Start New Scan" → [ScanCaptureScreen](UI/lib/screens/mobile/scan_capture_screen.dart)
2. User captures:
   - **Image:** Using device camera or gallery
   - **Audio:** Recording acoustic signature
   - **Metadata:** Location, mining site, mineral type, notes
3. User reviews data → [ReviewSubmitScreen](UI/lib/screens/mobile/review_submit_screen.dart)
4. App submits to API:
   - Converts XFile to PlatformFile
   - Adds default chemical values based on mineral type
   - Calls `ApiService.generateFingerprint()`
5. API processes:
   - Extracts multimodal features
   - Runs ML prediction
   - Generates fingerprint
   - Stores in database
6. User sees result → [VerificationResultScreen](UI/lib/screens/mobile/verification_result_screen.dart)

### 3. View History
1. User taps "View History" → [VerificationHistoryScreen](UI/lib/screens/mobile/verification_history_screen.dart)
2. App loads records → `ApiService.getVerifications()`
3. Display list of past verifications with status badges

## Data Models

### User Model
```dart
class User {
  final String id;
  final String name;
  final String email;
  final UserRole role;
}
```

### VerificationRecord Model
```dart
class VerificationRecord {
  final String id;
  final DateTime timestamp;
  final String userId;
  final String userName;
  final MineralType mineralType;
  final String location;
  final String miningSite;
  final VerificationStatus status;
  final double confidenceScore;
  final String? notes;
}
```

### Mineral Types
- `gold`
- `chalcopyrite`
- `hematite`

### Verification Status
- `verified`: ML prediction matches user claim with high confidence (≥80%)
- `pending`: Low confidence (<60%), needs manual review
- `notVerified`: ML prediction differs from user claim or medium confidence

## Default Chemical Values

The mobile app uses default chemical composition values since the UI doesn't collect them from users:

```dart
// Gold
{'Au': 99.9, 'Cu': 0.05, 'Fe': 0.03, 'S': 0.01, 'O': 0.01}

// Chalcopyrite
{'Au': 0.5, 'Cu': 34.5, 'Fe': 30.5, 'S': 34.5, 'O': 0.0}

// Hematite
{'Au': 0.1, 'Cu': 0.2, 'Fe': 69.9, 'S': 0.0, 'O': 29.8}
```

**Note:** For production use, consider adding a chemical composition input screen or using XRF device integration.

## Optional Modalities Support

Both the API and mobile app support optional modalities:
- User must provide **at least one** of: Image OR Audio
- Chemical composition is always required
- The ML model adapts based on available modalities

### Example Scenarios:
1. **Image + Audio + Chemical** → Full multimodal analysis (best accuracy)
2. **Image + Chemical** → Visual + chemical analysis
3. **Audio + Chemical** → Acoustic + chemical analysis

## API Service Implementation

The `ApiService` class ([lib/services/api_service.dart](UI/lib/services/api_service.dart)) is the central interface for all API communication:

```dart
class ApiService {
  final String baseUrl;
  final http.Client _client;
  
  // Core methods
  Future<Map<String, dynamic>> login({...})
  Future<Map<String, dynamic>> predictSample({...})
  Future<Map<String, dynamic>> generateFingerprint({...})
  Future<Map<String, dynamic>> getFingerprints({...})
  Future<Map<String, dynamic>> getVerifications({...})
  Future<Map<String, dynamic>> getStats()
  Future<Map<String, dynamic>> getMetrics()
  Future<Map<String, dynamic>> getHealth()
  
  // User management
  Future<Map<String, dynamic>> getUsers({...})
  Future<Map<String, dynamic>> createUser({...})
  Future<Map<String, dynamic>> updateUser({...})
  Future<Map<String, dynamic>> deleteUser(String userId)
}
```

## Error Handling

### API Service Errors
The ApiService throws exceptions on HTTP errors:
```dart
try {
  final response = await apiService.generateFingerprint(...);
  // Handle success
} catch (e) {
  // Handle error
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Failed: $e')),
  );
}
```

### API Error Responses
The FastAPI backend returns structured error responses:
```json
{
  "detail": "Error message here"
}
```

## Testing the Integration

### 1. Start the Backend API
```bash
cd API
python api.py
```
API will run at: `http://127.0.0.1:8000`
API docs at: `http://127.0.0.1:8000/docs`

### 2. Update Flutter Configuration (if needed)
For physical device testing:
```dart
// In UI/lib/constants/api_config.dart
static const String defaultBaseUrl = 'http://YOUR_IP:8000';
```

### 3. Run Flutter App
```bash
cd UI
flutter run
```

### 4. Test Login
- Email: `inspector@example.com`
- Password: `inspector123`

Or:
- Email: `admin@example.com`
- Password: `admin123`

### 5. Test Mineral Scan
1. Login → Home → Start New Scan
2. Select mineral type (Gold/Chalcopyrite/Hematite)
3. Enter location and mining site
4. Capture image and record audio
5. Submit for verification
6. View result with verification status

## Dependencies

### Flutter Dependencies (pubspec.yaml)
```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.2.1                    # HTTP client for API calls
  file_picker: ^8.0.0             # File selection
  image_picker: ^1.0.7            # Camera/gallery access
  record: ^6.0.0                  # Audio recording
  path_provider: ^2.1.1           # File system paths
  permission_handler: ^11.1.0     # Runtime permissions
  shared_preferences: ^2.2.2      # Local storage
  intl: ^0.18.0                   # Date formatting
```

### Python Dependencies (requirements_ml.txt)
```
torch>=2.0.0
torchvision>=0.15.0
numpy>=1.24.0
pillow>=9.5.0
librosa>=0.10.0
fastapi>=0.109.0
uvicorn>=0.27.0
python-multipart>=0.0.6
scikit-learn>=1.3.0
```

## Security Considerations

### Current Implementation (Development)
- CORS allows all origins (`"*"`)
- Passwords stored in plain text
- No token-based authentication

### Production Recommendations
1. **CORS:** Restrict to specific mobile app domains
2. **Authentication:** Implement JWT tokens
3. **Password Security:** Use bcrypt or argon2 for hashing
4. **HTTPS:** Use SSL/TLS encryption
5. **API Keys:** Add API key validation
6. **Rate Limiting:** Implement request throttling

## Troubleshooting

### Issue: "Failed to connect to API"
**Solutions:**
1. Check API is running: Visit `http://127.0.0.1:8000/health`
2. For physical device: Use local IP instead of 127.0.0.1
3. Check firewall settings allow port 8000
4. Ensure device and computer are on same network

### Issue: "At least one modality must be provided"
**Solution:**
- Ensure image OR audio is captured before submitting
- Check file conversion logic in ReviewSubmitScreen

### Issue: "Model not loaded"
**Solution:**
- Verify `dataset/multimodal_model.pt` exists
- Check model was trained and saved properly

### Issue: "Chemical scaler not found"
**Solution:**
- API will create default scaler automatically
- Or run: `python dataset/save_scaler.py`

### Issue: CORS errors in browser console
**Solution:**
- API already configured with CORS middleware
- For production, update allowed origins in `api.py`

## Performance Optimization

### Mobile App
1. **Image Compression:** Already configured (maxWidth: 1920, quality: 85)
2. **Audio Settings:** 16kHz, mono, WAV format
3. **Lazy Loading:** Load verification history on demand
4. **Caching:** Consider caching user session locally

### API
1. **Model Loading:** Loaded once at startup
2. **GPU Acceleration:** Automatically uses CUDA if available
3. **Async Processing:** FastAPI handles requests asynchronously
4. **Logging:** Structured logging for debugging

## Next Steps

### Phase 1: Core Features (Current) ✅
- [x] User authentication
- [x] Mineral scanning with image/audio capture
- [x] ML-based verification
- [x] Verification history
- [x] API integration

### Phase 2: Enhancements (Recommended)
- [ ] Add chemical composition input screen
- [ ] Integrate XRF device for real chemical data
- [ ] Offline mode with local storage
- [ ] Export verification reports (PDF)
- [ ] Admin dashboard in mobile app
- [ ] Push notifications for verification updates
- [ ] Multi-language support
- [ ] Dark mode

### Phase 3: Production (Future)
- [ ] JWT authentication
- [ ] Password hashing
- [ ] Production API deployment (AWS/Azure/GCP)
- [ ] CDN for model files
- [ ] Database migration (PostgreSQL/MongoDB)
- [ ] Automated testing
- [ ] CI/CD pipeline
- [ ] App store deployment (Google Play/App Store)

## Support & Resources

### Documentation
- **FastAPI Docs:** `http://127.0.0.1:8000/docs`
- **Flutter Docs:** https://docs.flutter.dev
- **API Integration Guide:** This file

### Code References
- **API Implementation:** [API/api.py](API/api.py)
- **Flutter Service:** [UI/lib/services/api_service.dart](UI/lib/services/api_service.dart)
- **Mobile Screens:** [UI/lib/screens/mobile/](UI/lib/screens/mobile/)
- **Data Models:** [UI/lib/models/](UI/lib/models/)

### Contact
For questions or issues, refer to the project repository or contact the development team.

---

**Last Updated:** February 2026  
**API Version:** 2.0  
**Flutter Version:** 3.0+  
**Model Accuracy:** 88.5%
