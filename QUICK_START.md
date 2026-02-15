# Flutter-Backend Integration - Quick Start Guide

## 🚀 Quick Start (5 Minutes)

### Prerequisites
- ✅ Python 3.8+ installed
- ✅ Flutter SDK installed
- ✅ Android Studio/Xcode (for emulator) OR physical device connected

### Step 1: Start Backend API
Open PowerShell terminal in project root:
```powershell
.\start_api.ps1
```

**Note the IP address shown** (e.g., `http://192.168.1.100:8000`) for mobile device testing.

### Step 2: Update Flutter Config (if using physical device)
Edit `UI/lib/constants/api_config.dart`:
```dart
static const String defaultBaseUrl = 'http://YOUR_IP:8000';
```

Skip this step if using emulator/simulator (uses `http://127.0.0.1:8000` by default).

### Step 3: Start Flutter App
Open **another** PowerShell terminal:
```powershell
.\start_flutter.ps1
```

### Step 4: Login & Test
Use these credentials:
- **Email:** `inspector@example.com`
- **Password:** `inspector123`

---

## 📱 Testing Mineral Scanning

1. **Login** with credentials above
2. **Tap "Start New Scan"**
3. **Select mineral type:** Gold, Chalcopyrite, or Hematite
4. **Enter location and mining site**
5. **Capture image** from camera or gallery
6. **Record audio** (tap to start/stop recording)
7. **Review & Submit**
8. **View verification result** with confidence score

---

## 🔧 Configuration Reference

### API Endpoints
| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/login` | POST | User authentication |
| `/predict` | POST | Quick mineral prediction |
| `/fingerprint` | POST | Generate & store fingerprint |
| `/verifications` | GET | List verification history |
| `/stats` | GET | System statistics |
| `/health` | GET | API health check |
| `/metrics` | GET | Model performance metrics |

### Default Users
| Email | Password | Role |
|-------|----------|------|
| inspector@example.com | inspector123 | inspector |
| admin@example.com | admin123 | admin |
| regulator@example.com | regulator123 | regulator |

### Verification Status Logic
| Condition | Status | Badge Color |
|-----------|--------|-------------|
| ML matches claim + confidence ≥80% | Verified | Green |
| Confidence < 60% | Pending | Orange |
| ML differs OR 60% ≤ confidence < 80% | Not Verified | Red |

### Default Chemical Values
The mobile app uses these default values (since UI doesn't collect them):

**Gold:**
- Au: 99.9%, Cu: 0.05%, Fe: 0.03%, S: 0.01%, O: 0.01%

**Chalcopyrite:**
- Au: 0.5%, Cu: 34.5%, Fe: 30.5%, S: 34.5%, O: 0.0%

**Hematite:**
- Au: 0.1%, Cu: 0.2%, Fe: 69.9%, S: 0.0%, O: 29.8%

---

## 🐛 Troubleshooting

### Problem: "Cannot connect to API"
**Solutions:**
1. Verify API is running at `http://127.0.0.1:8000/health`
2. For physical device: Use your computer's local IP (not 127.0.0.1)
3. Ensure device and computer are on same WiFi network
4. Check Windows Firewall allows port 8000

### Problem: "At least one modality must be provided"
**Solution:** 
- Capture **both** image AND audio before submitting
- App requires at least one (but you should provide both)

### Problem: Flutter dependencies not found
**Solution:**
```powershell
cd UI
flutter pub get
```

### Problem: Python packages not installed
**Solution:**
```powershell
.\venv\Scripts\Activate.ps1
pip install -r requirements_ml.txt
```

---

## 📊 System Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Flutter Mobile App                    │
│                     (Android/iOS)                        │
│  ┌───────────┐  ┌──────────┐  ┌─────────────────────┐  │
│  │  Camera   │  │   Mic    │  │   ApiService        │  │
│  │  Picker   │  │ Recorder │  │   (HTTP Client)     │  │
│  └───────────┘  └──────────┘  └─────────────────────┘  │
└───────────────────────────┬─────────────────────────────┘
                            │ REST API (JSON)
                            │ Multipart Form Data
                            ▼
┌─────────────────────────────────────────────────────────┐
│                   FastAPI Backend                        │
│                (Python + PyTorch)                        │
│  ┌────────────────┐  ┌────────────────┐  ┌──────────┐  │
│  │ MultiModalNet  │  │  Fingerprint   │  │  Auth    │  │
│  │  (ML Model)    │  │    Storage     │  │ Manager  │  │
│  │  88.5% Acc     │  │  (JSONL)       │  │ (JSON)   │  │
│  └────────────────┘  └────────────────┘  └──────────┘  │
└─────────────────────────────────────────────────────────┘
```

---

## 🔗 Integration Flow

```
Mobile App Flow:
1. User Login → ApiService.login() → Backend validates
2. Start Scan → Capture image/audio → Local preview
3. Submit → Convert to PlatformFile → POST /fingerprint
4. Backend processes → ML inference → Store fingerprint
5. Return result → Display verification status → History

Data Flow:
User Input → Mobile UI → ApiService → FastAPI → Model → Database
                                                    ↓
                                              Response JSON
                                                    ↓
                                     Display Result ← Parse ← Mobile
```

---

## 📚 Documentation

### Comprehensive Guides
- **Full Integration Guide:** `FLUTTER_INTEGRATION_GUIDE.md` (detailed)
- **Model Upgrade Guide:** `UPGRADE_GUIDE.md`
- **Migration Summary:** `MIGRATION_SUMMARY.md`
- **Improving Accuracy:** `IMPROVING_MODEL_ACCURACY.md`

### API Documentation
- **Interactive Docs:** http://127.0.0.1:8000/docs (Swagger UI)
- **Alternative Docs:** http://127.0.0.1:8000/redoc (ReDoc)

### Code References
- **Backend API:** `API/api.py`
- **Flutter Service:** `UI/lib/services/api_service.dart`
- **Mobile Screens:** `UI/lib/screens/mobile/`
- **ML Model:** `dataset/multimodal_model.py`

---

## 📈 Next Steps

### Immediate Testing
1. ✅ Test login with provided credentials
2. ✅ Complete a full mineral scan workflow
3. ✅ View verification history
4. ✅ Check API documentation at `/docs`

### For Production
- [ ] Use real chemical composition data (XRF device)
- [ ] Implement JWT authentication
- [ ] Hash passwords (bcrypt/argon2)
- [ ] Deploy API to cloud (AWS/Azure/GCP)
- [ ] Update CORS to specific origins
- [ ] Add rate limiting
- [ ] Use PostgreSQL database
- [ ] Deploy Flutter app to Play Store/App Store

### Feature Enhancements
- [ ] Add chemical composition input screen
- [ ] Offline mode with local caching
- [ ] Export reports as PDF
- [ ] Push notifications
- [ ] Multi-language support
- [ ] Dark mode
- [ ] Admin panel in mobile app

---

## 💡 Tips

1. **Development:** Use emulator for fastest iteration
2. **Testing:** Use physical device for camera/mic testing
3. **Debugging:** Check API logs in terminal for errors
4. **Network:** Ensure firewall allows port 8000
5. **Performance:** API uses GPU automatically if available
6. **Storage:** Fingerprints saved in `dataset/fingerprints.jsonl`
7. **Logs:** Check `logs/` directory for scan history

---

## 🎯 Success Criteria

Your integration is working correctly when:
- ✅ You can login successfully
- ✅ API health check returns `{"status": "healthy"}`
- ✅ You can capture image and audio
- ✅ Submission returns verification status
- ✅ History screen shows past verifications
- ✅ Confidence scores are reasonable (>70% for correct mineral)

---

## 🆘 Support

### If You're Stuck:
1. Check terminal output for error messages
2. Visit API docs: http://127.0.0.1:8000/docs
3. Review `FLUTTER_INTEGRATION_GUIDE.md` for details
4. Check Flutter logs: `flutter logs`
5. Verify model file exists: `dataset/multimodal_model.pt`

### Common Issues:
- **CORS Error:** Already configured, should work
- **Connection Refused:** API not running or wrong IP
- **File Not Found:** Model not trained yet
- **Permission Denied:** Grant camera/mic permissions

---

**Version:** 2.0  
**Last Updated:** February 2026  
**Model Accuracy:** 88.5%  
**Minerals Supported:** Gold, Chalcopyrite, Hematite
