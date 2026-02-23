# Mineral Tracer Mobile App

A Flutter-based mobile application for multimodal mineral identification and traceability.

## Features

- **🔐 Secure Authentication**: Email/password login with PIN protection
- **📸 Multimodal Scanning**: Capture images, record audio, and enter chemical data
- **🤖 AI-Powered Identification**: Real-time mineral identification using machine learning
- **📊 Analytics Dashboard**: View scan history, statistics, and insights
- **✅ Verification System**: Verify mineral authenticity with fingerprint matching
- **📱 Modern UI**: Beautiful, intuitive interface based on Material Design

## Supported Minerals

- Gold
- Chalcopyrite
- Hematite

## Technologies

- **Framework**: Flutter 3.6+
- **State Management**: Provider
- **API Communication**: HTTP
- **Local Storage**: Shared Preferences
- **Charts**: FL Chart
- **Image Handling**: Image Picker, Camera
- **Audio**: Record, Audio Waveforms
- **QR Code**: QR Flutter, QR Code Scanner

## Getting Started

### Prerequisites

- Flutter SDK 3.6 or higher
- Dart SDK 3.0 or higher
- Android Studio / VS Code with Flutter extension
- Android device or emulator (API level 21+)
- iOS device or simulator (iOS 12+)

### Installation

1. **Navigate to the mobile app directory**:
   ```bash
   cd "mobile app/flutter_application"
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Configure Backend API**:
   Update the API base URL in `lib/config/constants.dart`:
   ```dart
   static const String baseUrl = 'http://YOUR_API_HOST:8000';
   ```

4. **Run the app**:
   ```bash
   # For Android
   flutter run

   # For iOS
   flutter run -d ios

   # For specific device
   flutter devices
   flutter run -d DEVICE_ID
   ```

## Project Structure

```
lib/
├── config/
│   ├── constants.dart      # App constants and configuration
│   └── theme.dart          # App theme and styling
├── models/
│   ├── user.dart           # User data model
│   ├── scan.dart           # Scan data model
│   ├── prediction_result.dart
│   └── verification_result.dart
├── services/
│   ├── api_service.dart    # API communication service
│   └── storage_service.dart # Local storage service
├── screens/
│   ├── auth/
│   │   ├── login_screen.dart
│   │   └── pin_screen.dart
│   ├── main/
│   │   └── main_screen.dart    # Bottom navigation
│   ├── home/
│   │   └── home_screen.dart    # Dashboard
│   ├── scan/
│   │   ├── scan_screen.dart
│   │   └── scan_result_screen.dart
│   ├── history/
│   │   └── history_screen.dart
│   └── profile/
│       └── profile_screen.dart
└── main.dart               # App entry point
```

## Features Overview

### Authentication
- Email and password login
- 4-digit PIN setup and verification
- Secure session management

### Scanning
- Image capture from camera or gallery
- Audio recording (optional)
- Chemical composition input (optional)
- Site location selection
- Multi-modal prediction

### Results
- Real-time mineral identification
- Confidence scores
- Probability distribution
- Scan details and metadata

### History
- View all past scans
- Filter by mineral type
- Search functionality
- Detailed scan information

### Profile
- User information display
- Account settings
- Analytics access
- Logout functionality

## API Integration

The app communicates with the backend REST API for:
- User authentication
- Mineral prediction
- Verification
- Scan history
- Metrics and analytics

API endpoints are defined in `lib/config/constants.dart`.

## Demo Credentials

```
Email: admin@mineraltrace.com
Password: admin123
```

## Building for Production

### Android

1. Configure signing in `android/app/build.gradle`
2. Build APK:
   ```bash
   flutter build apk --release
   ```
3. Build App Bundle:
   ```bash
   flutter build appbundle --release
   ```

### iOS

1. Configure signing in Xcode
2. Build IPA:
   ```bash
   flutter build ios --release
   ```

## Troubleshooting

### Common Issues

1. **Dependencies not resolving**:
   ```bash
   flutter pub cache repair
   flutter pub get
   ```

2. **Build errors**:
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

3. **Network errors**:
   - Check API URL in constants.dart
   - Ensure backend server is running
   - Check device network connectivity

## License

Part of Mission Capstone Project © 2026

## Support

For issues and questions, please refer to the main project repository.

