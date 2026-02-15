# Complete Setup: API + Flutter
# This script provides instructions to run both the backend and frontend

Write-Host "=" * 80 -ForegroundColor Magenta
Write-Host "  Mineral Traceability System - Complete Setup" -ForegroundColor Magenta
Write-Host "=" * 80 -ForegroundColor Magenta
Write-Host ""

Write-Host "📋 This system consists of two components:" -ForegroundColor White
Write-Host "   1. FastAPI Backend (Python)" -ForegroundColor Cyan
Write-Host "   2. Flutter Mobile App (Dart/Flutter)" -ForegroundColor Cyan
Write-Host ""

Write-Host "🔧 Setup Instructions:" -ForegroundColor Yellow
Write-Host ""

Write-Host "=" * 80 -ForegroundColor Green
Write-Host "  STEP 1: Start the Backend API" -ForegroundColor Green
Write-Host "=" * 80 -ForegroundColor Green
Write-Host ""
Write-Host "  Open a NEW PowerShell terminal and run:" -ForegroundColor White
Write-Host "  > .\start_api.ps1" -ForegroundColor Cyan
Write-Host ""
Write-Host "  This will:" -ForegroundColor Gray
Write-Host "  - Create/activate Python virtual environment" -ForegroundColor Gray
Write-Host "  - Install required Python packages" -ForegroundColor Gray
Write-Host "  - Start the FastAPI server on port 8000" -ForegroundColor Gray
Write-Host "  - Display your local IP address for mobile access" -ForegroundColor Gray
Write-Host ""

Write-Host "=" * 80 -ForegroundColor Green
Write-Host "  STEP 2: (Optional) Update Flutter Configuration" -ForegroundColor Green
Write-Host "=" * 80 -ForegroundColor Green
Write-Host ""
Write-Host "  IF testing on a physical device:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  1. Note the IP address shown by start_api.ps1" -ForegroundColor White
Write-Host "  2. Open: UI/lib/constants/api_config.dart" -ForegroundColor White
Write-Host "  3. Update the defaultBaseUrl:" -ForegroundColor White
Write-Host ""
Write-Host "     static const String defaultBaseUrl = 'http://YOUR_IP:8000';" -ForegroundColor Cyan
Write-Host ""
Write-Host "  IF testing with emulator/simulator:" -ForegroundColor Yellow
Write-Host "  - No changes needed (uses http://127.0.0.1:8000 by default)" -ForegroundColor Gray
Write-Host ""

Write-Host "=" * 80 -ForegroundColor Green
Write-Host "  STEP 3: Start the Flutter App" -ForegroundColor Green
Write-Host "=" * 80 -ForegroundColor Green
Write-Host ""
Write-Host "  Open ANOTHER PowerShell terminal and run:" -ForegroundColor White
Write-Host "  > .\start_flutter.ps1" -ForegroundColor Cyan
Write-Host ""
Write-Host "  This will:" -ForegroundColor Gray
Write-Host "  - Install Flutter dependencies" -ForegroundColor Gray
Write-Host "  - Check for connected devices" -ForegroundColor Gray
Write-Host "  - Launch the mobile app" -ForegroundColor Gray
Write-Host ""

Write-Host "=" * 80 -ForegroundColor Green
Write-Host "  STEP 4: Test the App" -ForegroundColor Green
Write-Host "=" * 80 -ForegroundColor Green
Write-Host ""
Write-Host "  Login Credentials:" -ForegroundColor White
Write-Host ""
Write-Host "  Inspector Account:" -ForegroundColor Cyan
Write-Host "    Email: inspector@example.com" -ForegroundColor Gray
Write-Host "    Password: inspector123" -ForegroundColor Gray
Write-Host ""
Write-Host "  Admin Account:" -ForegroundColor Cyan
Write-Host "    Email: admin@example.com" -ForegroundColor Gray
Write-Host "    Password: admin123" -ForegroundColor Gray
Write-Host ""
Write-Host "  Regulator Account:" -ForegroundColor Cyan
Write-Host "    Email: regulator@example.com" -ForegroundColor Gray
Write-Host "    Password: regulator123" -ForegroundColor Gray
Write-Host ""

Write-Host "=" * 80 -ForegroundColor Yellow
Write-Host "  📚 Additional Resources" -ForegroundColor Yellow
Write-Host "=" * 80 -ForegroundColor Yellow
Write-Host ""
Write-Host "  - Comprehensive Guide: FLUTTER_INTEGRATION_GUIDE.md" -ForegroundColor White
Write-Host "  - API Documentation: http://127.0.0.1:8000/docs" -ForegroundColor White
Write-Host "  - Model Upgrade Guide: UPGRADE_GUIDE.md" -ForegroundColor White
Write-Host "  - Migration Summary: MIGRATION_SUMMARY.md" -ForegroundColor White
Write-Host ""

Write-Host "=" * 80 -ForegroundColor Magenta
Write-Host "  Ready to start? Run './start_api.ps1' first!" -ForegroundColor Magenta
Write-Host "=" * 80 -ForegroundColor Magenta
Write-Host ""

# Ask if user wants to start now
$response = Read-Host "Would you like to start the API now? (y/n)"
if ($response -eq 'y' -or $response -eq 'Y') {
    Write-Host ""
    Write-Host "🚀 Starting API..." -ForegroundColor Green
    & .\start_api.ps1
}
