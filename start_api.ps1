# Quick Start: Run Backend API
# This script starts the FastAPI backend server

Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "  Starting Mineral Traceability API" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host ""

# Check if virtual environment exists
if (!(Test-Path "venv")) {
    Write-Host "⚠️  Virtual environment not found. Creating one..." -ForegroundColor Yellow
    python -m venv venv
    Write-Host "✅ Virtual environment created" -ForegroundColor Green
}

# Activate virtual environment
Write-Host "🔄 Activating virtual environment..." -ForegroundColor Yellow
& .\venv\Scripts\Activate.ps1

# Check if requirements are installed
Write-Host "🔄 Checking dependencies..." -ForegroundColor Yellow
$pipList = pip list
if ($pipList -notmatch "fastapi") {
    Write-Host "📦 Installing dependencies..." -ForegroundColor Yellow
    pip install -r requirements_ml.txt
    Write-Host "✅ Dependencies installed" -ForegroundColor Green
}

# Get local IP address for mobile device access
$localIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.InterfaceAlias -notmatch "Loopback"} | Select-Object -First 1).IPAddress

Write-Host ""
Write-Host "=" * 80 -ForegroundColor Green
Write-Host "  📱 Mobile Device Configuration" -ForegroundColor Green
Write-Host "=" * 80 -ForegroundColor Green
Write-Host "  To connect from a mobile device on the same network," -ForegroundColor White
Write-Host "  update the API URL in Flutter app to:" -ForegroundColor White
Write-Host ""
Write-Host "  http://${localIP}:8000" -ForegroundColor Cyan
Write-Host ""
Write-Host "  File: UI/lib/constants/api_config.dart" -ForegroundColor Gray
Write-Host "=" * 80 -ForegroundColor Green
Write-Host ""

# Start the API
Write-Host "🚀 Starting API server..." -ForegroundColor Green
Write-Host ""

cd API
python api.py
