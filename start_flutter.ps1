# Quick Start: Run Flutter Mobile App
# This script runs the Flutter mobile application

Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "  Starting Flutter Mobile App" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host ""

# Check if Flutter is installed
try {
    $flutterVersion = flutter --version 2>&1 | Select-String "Flutter"
    Write-Host "✅ Flutter detected: $flutterVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Flutter not found. Please install Flutter first." -ForegroundColor Red
    Write-Host "   Visit: https://docs.flutter.dev/get-started/install" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "🔄 Checking dependencies..." -ForegroundColor Yellow

cd UI

# Check if dependencies are installed
if (!(Test-Path "pubspec.lock")) {
    Write-Host "📦 Installing Flutter dependencies..." -ForegroundColor Yellow
    flutter pub get
    Write-Host "✅ Dependencies installed" -ForegroundColor Green
} else {
    Write-Host "✅ Dependencies already installed" -ForegroundColor Green
}

Write-Host ""
Write-Host "=" * 80 -ForegroundColor Green
Write-Host "  ⚙️  Configuration Check" -ForegroundColor Green
Write-Host "=" * 80 -ForegroundColor Green
Write-Host "  Current API URL is configured in:" -ForegroundColor White
Write-Host "  lib/constants/api_config.dart" -ForegroundColor Cyan
Write-Host ""
Write-Host "  For testing with emulator/simulator:" -ForegroundColor White
Write-Host "  - Use http://127.0.0.1:8000 (default)" -ForegroundColor Gray
Write-Host ""
Write-Host "  For testing with physical device:" -ForegroundColor White
Write-Host "  - Update to http://YOUR_IP:8000" -ForegroundColor Gray
Write-Host "  - Run 'ipconfig' to find your local IP address" -ForegroundColor Gray
Write-Host "=" * 80 -ForegroundColor Green
Write-Host ""

# Check for connected devices
Write-Host "🔍 Checking for connected devices..." -ForegroundColor Yellow
$devices = flutter devices
Write-Host $devices

Write-Host ""
Write-Host "🚀 Starting Flutter app..." -ForegroundColor Green
Write-Host ""

# Run the app
flutter run
