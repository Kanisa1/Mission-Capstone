# Add firewall rule for Python API Server
# Run this script as Administrator

Write-Host "Adding firewall rule for port 8000..." -ForegroundColor Cyan

try {
    netsh advfirewall firewall add rule name="Python API Server" dir=in action=allow protocol=TCP localport=8000
    Write-Host "✅ Firewall rule added successfully!" -ForegroundColor Green
    Write-Host "Your phone should now be able to connect to the API." -ForegroundColor Green
} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Please run this script as Administrator" -ForegroundColor Yellow
}

Write-Host "`nPress any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
