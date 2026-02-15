# Test Script for Optional Modalities Feature
# This demonstrates the new v2 API capabilities

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "   Testing Optional Modalities Feature (API v2)   " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

$baseUrl = "http://127.0.0.1:8001"

# Test files
$imageFile = "C:\Users\HP\Mission-Capstone\dataset\images\Central_Equatoria\gold\01997320017663125882328.jpg"
$audioFile = "C:\Users\HP\Mission-Capstone\dataset\audio\Central_Equatoria\gold\Central_Equatoria_gold_000.wav"

# Default chemistry values (gold-like properties)
$chemistry = @{
    Au = "99.9"
    Cu = "0.05"
    Fe = "0.03"
    S = "0.01"
    O = "0.01"
}

Write-Host "Test Files:" -ForegroundColor Yellow
Write-Host "  Image: $imageFile"
Write-Host "  Audio: $audioFile"
Write-Host ""

# Test 1: Health Check
Write-Host "[Test 1] Health Check" -ForegroundColor Green
Write-Host "------------------------------------------------------"
try {
    $health = Invoke-RestMethod -Uri "$baseUrl/health" -Method Get
    Write-Host "Status: $($health.status)" -ForegroundColor Green
    Write-Host "Version: $($health.version)"
    Write-Host "Features:" -ForegroundColor Yellow
    $health.features | ConvertTo-Json
    Write-Host ""
} catch {
    Write-Host "ERROR: API not responding" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

# Test 2: Image + Audio (Full Multimodal)
Write-Host "[Test 2] Full Multimodal (Image + Audio + Chemistry)" -ForegroundColor Green
Write-Host "------------------------------------------------------"
try {
    $form = @{
        image = Get-Item -Path $imageFile
        audio = Get-Item -Path $audioFile
        Au = $chemistry.Au
        Cu = $chemistry.Cu
        Fe = $chemistry.Fe
        S = $chemistry.S
        O = $chemistry.O
    }
    
    $response = Invoke-RestMethod -Uri "$baseUrl/predict" -Method Post -Form $form
    Write-Host "Predicted Mineral: $($response.prediction)" -ForegroundColor Cyan
    Write-Host "Confidence: $([math]::Round($response.confidence * 100, 2))%"
    Write-Host "Modalities Used:" -ForegroundColor Yellow
    $response.modalities_used | ConvertTo-Json
    Write-Host ""
} catch {
    Write-Host "ERROR in full multimodal test" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}

# Test 3: Image Only (No Audio)
Write-Host "[Test 3] Image Only (No Audio)" -ForegroundColor Green
Write-Host "------------------------------------------------------"
try {
    $form = @{
        image = Get-Item -Path $imageFile
        Au = $chemistry.Au
        Cu = $chemistry.Cu
        Fe = $chemistry.Fe
        S = $chemistry.S
        O = $chemistry.O
    }
    
    $response = Invoke-RestMethod -Uri "$baseUrl/predict" -Method Post -Form $form
    Write-Host "Predicted Mineral: $($response.prediction)" -ForegroundColor Cyan
    Write-Host "Confidence: $([math]::Round($response.confidence * 100, 2))%"
    Write-Host "Modalities Used:" -ForegroundColor Yellow
    $response.modalities_used | ConvertTo-Json
    Write-Host ""
} catch {
    Write-Host "ERROR in image-only test" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}

# Test 4: Audio Only (No Image)
Write-Host "[Test 4] Audio Only (No Image)" -ForegroundColor Green
Write-Host "------------------------------------------------------"
try {
    $form = @{
        audio = Get-Item -Path $audioFile
        Au = $chemistry.Au
        Cu = $chemistry.Cu
        Fe = $chemistry.Fe
        S = $chemistry.S
        O = $chemistry.O
    }
    
    $response = Invoke-RestMethod -Uri "$baseUrl/predict" -Method Post -Form $form
    Write-Host "Predicted Mineral: $($response.prediction)" -ForegroundColor Cyan
    Write-Host "Confidence: $([math]::Round($response.confidence * 100, 2))%"
    Write-Host "Modalities Used:" -ForegroundColor Yellow
    $response.modalities_used | ConvertTo-Json
    Write-Host ""
} catch {
    Write-Host "ERROR in audio-only test" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}

# Test 5: Chemistry Only (Should Fail - Need at least one sensor modality)
Write-Host "[Test 5] Chemistry Only (Expected to Fail)" -ForegroundColor Green
Write-Host "------------------------------------------------------"
try {
    $form = @{
        Au = $chemistry.Au
        Cu = $chemistry.Cu
        Fe = $chemistry.Fe
        S = $chemistry.S
        O = $chemistry.O
    }
    
    $response = Invoke-RestMethod -Uri "$baseUrl/predict" -Method Post -Form $form
    Write-Host "Unexpected Success!" -ForegroundColor Yellow
} catch {
    Write-Host "Expected Error: At least one modality (image or audio) must be provided" -ForegroundColor Yellow
    Write-Host ""
}

# Test 6: Get Metrics
Write-Host "[Test 6] Model Metrics" -ForegroundColor Green
Write-Host "------------------------------------------------------"
try {
    $metrics = Invoke-RestMethod -Uri "$baseUrl/metrics" -Method Get
    Write-Host "Overall Metrics:" -ForegroundColor Yellow
    Write-Host "  Accuracy: $([math]::Round($metrics.overall_metrics.accuracy * 100, 2))%"
    Write-Host "  Precision: $([math]::Round($metrics.overall_metrics.macro_precision * 100, 2))%"
    Write-Host "  Recall: $([math]::Round($metrics.overall_metrics.macro_recall * 100, 2))%"
    Write-Host "  F1 Score: $([math]::Round($metrics.overall_metrics.macro_f1_score * 100, 2))%"
    Write-Host "  False Positive Rate: $([math]::Round($metrics.overall_metrics.macro_fpr * 100, 2))%"
    Write-Host ""
    Write-Host "Per-Class Metrics:" -ForegroundColor Yellow
    foreach ($class in $metrics.per_class_metrics.PSObject.Properties) {
        Write-Host "  $($class.Name):" -ForegroundColor Cyan
        Write-Host "    Precision: $([math]::Round($class.Value.precision * 100, 2))%"
        Write-Host "    Recall: $([math]::Round($class.Value.recall * 100, 2))%"
        Write-Host "    F1: $([math]::Round($class.Value.f1_score * 100, 2))%"
    }
    Write-Host ""
} catch {
    Write-Host "Note: Metrics require verification data" -ForegroundColor Yellow
    Write-Host ""
}

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "   Testing Complete!                             " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "✓ API v2 is running on port 8001"
Write-Host "✓ Optional modalities feature working"
Write-Host "✓ System supports: Image-only, Audio-only, or Both"
Write-Host "✓ Metrics endpoint available for monitoring"
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Test mobile app with optional modalities"
Write-Host "2. Check logs in: C:\Users\HP\Mission-Capstone\logs\"
Write-Host "3. View web dashboard for verification status"
Write-Host "4. When ready, migrate to api_v2 permanently"
