# Location Prediction, Discrimination & Site Classification Analysis

## Executive Summary

The MineralTrace system contains **comprehensive location discrimination capability** that achieves **89.2% ± 1.8% accuracy** in inferring mining site origin from mineral characteristics using multimodal ML. However, the **active location prediction logic in the Android/Flutter app and API is currently minimal** — the system primarily passes through user-selected/GPS-detected physical locations rather than inferring mining sites from mineral data.

---

## 1. LOCATION DISCRIMINATION MODEL & ANALYSIS

### 1.1 Notebook Analysis File
**File:** [location_discrimination_analysis.ipynb](location_discrimination_analysis.ipynb)

**Purpose:** Comprehensive analysis of the system's ability to discriminate minerals by their geological origin location.

**Key Findings:**
- **3×3 Confusion Matrix** showing prediction accuracy across three South Sudan mining sites:
  - **Kapoeta_East**: 87.5% correct classification
  - **Central_Equatoria**: 89.2% correct classification  
  - **Yei_River**: 91.0% correct classification (BEST PERFORMANCE)

**Confusion Matrix Data:**
```
                    Pred: Kapoeta  Pred: Central  Pred: Yei_River
Actual: Kapoeta_East      87.5%           8.0%          4.5%
Actual: Central_Equatoria   5.0%          89.2%          5.8%
Actual: Yei_River           3.2%           5.8%         91.0%
```

**Cross-location Misclassification Rate:** 10.8% (acceptable for supply chain verification)

**Multimodal Approach:**
- **Visual features** identify location-specific mineral appearance
- **Audio signatures** capture geoacoustic variations by site  
- **Chemical composition** reflects geological origin differences
- Combined achieves 89.2% vs ~70% with single modality

**Statistical Metrics:**
- Overall Accuracy: 89.2% ± 1.8%
- Mean Sensitivity (True Positive Rate): 89.2% ± 1.4%
- Mean Specificity (True Negative Rate): 94.7%
- 95% CI for diagonal accuracy: 86.43% - 92.03%

**Status:** System READY for field validation in South Sudan mining sites

---

## 2. BACKEND API IMPLEMENTATION

### 2.1 `/predict` Endpoint
**File:** [API/api.py](API/api.py) (lines 2104-2400+)

**Location Parameters Accepted:**
- No explicit location prediction parameters in the endpoint signature
- The endpoint focuses on **mineral classification** from image/audio/chemical modalities

**What the API Does:**
1. Accepts image, audio, and optional chemical data (Au, Cu, Fe, S, O)
2. Processes through multimodal neural network
3. Predicts mineral type (gold, chalcopyrite, hematite)
4. Computes confidence scores and OOD (out-of-domain) detection
5. Extracts fingerprint vectors for re-identification
6. **Does NOT infer location** from mineral characteristics

**Key Functions:**
- `evaluate_mineral_gate()` - Binary decision: is this a mineral?
- `compute_class_centroids()` (line 753) - Computes per-mineral centroids for similarity matching
- `compute_audio_embedding_similarity()` - Compares audio signatures
- `reid_similarity_shape_tolerant()` - Re-identification with emphasis on chemical features

### 2.2 `/verify` Endpoint
**File:** [API/api.py](API/api.py) (lines 2406-2800+)

**Site Field Handling:**
- Accepts fingerprint matching by ID or multimodal input
- Returns `site` field from stored fingerprint record
- **Does NOT infer site** — just retrieves stored value

**Functions Called:**
- `find_fingerprint_by_sample_id()` - Direct lookup
- `find_similar_fingerprint()` - Fingerprint similarity matching

### 2.3 `/stats` Endpoint  
**File:** [API/api.py](API/api.py) (lines 2941+)

**Aggregation Logic:**
```python
site_counts = {}
for r in records:
    site = r.get("site", "unknown")
    site_counts[site] = site_counts.get(site, 0) + 1
```

**Does NOT predict location** — aggregates by site field from stored records

---

## 3. DATASET STRUCTURE & SITE DEFINITIONS

### 3.1 Site Constants Defined In:

**Mobile App:**
- [mobile app/MineralTrace/lib/config/constants.dart](mobile%20app/MineralTrace/lib/config/constants.dart) (line 38):
  ```dart
  static const List<String> siteLocations = [
    'Central_Equatoria',
    'Kapoeta_East',
    'Yei_River',
  ];
  ```

**Web App:**
- [webapp/js/config.js](webapp/js/config.js) (line 28):
  ```javascript
  const SITES = ['Kapoeta_East', 'Central_Equatoria', 'Yei_River'];
  ```

### 3.2 Data Split Scripts

These scripts **organize training data by site** but do NOT perform location discrimination:

| File | Purpose | Sites Used |
|------|---------|-----------|
| [dataset/build_dataset_split.py](dataset/build_dataset_split.py) | Creates train/val/test splits | TRAIN: Kapoeta_East, Central_Equatoria<br>TEST: Yei_River |
| [dataset/build_open_set_splits.py](dataset/build_open_set_splits.py) | Open-set classification splits | Same as above |
| [dataset/generate_chemical_dataset.py](dataset/generate_chemical_dataset.py) | Generates synthetic chemical data per mineral | All three sites |
| [dataset/generate_synthetic_audio.py](dataset/generate_synthetic_audio.py) | Creates synthetic audio samples | All three sites |
| [dataset/record_audio_samples.py](dataset/record_audio_samples.py) | Records real audio samples | All three sites |
| [data_scripting.py](data_scripting.py) | Web scraping for mineral images | All three sites |

---

## 4. FLUTTER MOBILE APP LOCATION HANDLING

### 4.1 Location Detection Flow
**File:** [mobile app/MineralTrace/lib/screens/scan/scan_screen.dart](mobile%20app/MineralTrace/lib/screens/scan/scan_screen.dart)

**Current Implementation:**
```dart
// Line 473
final locationName = await _resolveLocationName(position);

setState(() {
  _currentPosition = position;
  _detectedLocation = locationName;  // GPS-based location name
  _isLoadingLocation = false;
});
```

**What `_resolveLocationName()` Does (line 213):**
1. Attempts to match GPS coordinates to **known physical places** (NOT mining sites)
2. Uses reverse geocoding via `placemarkFromCoordinates()`
3. Falls back to map API lookup
4. Returns formatted coordinates if no match found

**Known Physical Places (line 35-47):**
```dart
static const List<_KnownPlace> _knownPlaces = [
  _KnownPlace(
    name: 'African Leadership University',
    latitude: -1.9439,
    longitude: 30.0928,
    radiusMeters: 3000,
  ),
  _KnownPlace(
    name: 'Kagarama',
    latitude: -1.9958,
    longitude: 30.1174,
    radiusMeters: 2500,
  ),
];
```

### 4.2 How `_detectedLocation` is Used in Scan
**File:** [mobile app/MineralTrace/lib/screens/scan/scan_screen.dart](mobile%20app/MineralTrace/lib/screens/scan/scan_screen.dart) (line 538-575)

```dart
// Step 1: Predict mineral type
final result = await _apiService.predict(
  imageFile: _imageFile,
  audioFile: _audioFile,
  chemicalData: null,
  siteId: _detectedLocation,  // ← GPS-detected location name
  userId: userId,
  latitude: _currentPosition?.latitude,
  longitude: _currentPosition?.longitude,
);

// Step 2: Extract fingerprint with detected location
final fingerprintResponse = await _apiService.extractFingerprint(
  sampleId: scanId,
  site: _detectedLocation ?? 'Unknown',  // ← Passed as 'site'
  mineral: result.predictedMineral,
  // ... other parameters
);
```

### 4.3 Dart Model Classes
**File:** [mobile app/MineralTrace/lib/models/prediction_result.dart](mobile%20app/MineralTrace/lib/models/prediction_result.dart)

**PredictionResult has location field:**
```dart
class PredictionResult {
  final String? location;  // ← Stores returned location/site
  // ... other fields
  
  factory PredictionResult.fromJson(Map<String, dynamic> json) {
    // Line 74: location: json['location'] ?? json['site_id'] ?? json['site_name'],
  }
}
```

---

## 5. WEB APP UI FILTERING

### 5.1 Site Filters in UI
- [webapp/verifications.html](webapp/verifications.html) (line 118) - Site dropdown filter
- [webapp/scans.html](webapp/scans.html) (line 116) - Site filter with three options
- [webapp/index.html](webapp/index.html) (line 330) - Mineral distribution heatmap with site selection

**All filters show same three sites:**
- Central_Equatoria
- Kapoeta_East
- Yei_River

### 5.2 Client-Side Site Performance Calculation
**File:** [webapp/js/api.js](webapp/js/api.js) (line 98+)

```javascript
// Calculate site performance
const sitePerformance = {};
SITES.forEach(site => {
  const sitePreds = predictions.filter(p => p.site === site);
  const siteCorrect = sitePreds.filter(p => 
    p.predicted?.toLowerCase() === p.expected?.toLowerCase()
  ).length;
  
  sitePerformance[site] = {
    total: siteCounts[site] || 0,
    // ...
  };
});
```

**Does NOT infer site** — filters existing data by site field

---

## 6. FINGERPRINT STORAGE & RETRIEVAL

### 6.1 Fingerprint Record Structure
**File:** [API/api.py](API/api.py) (lines 2697-2760)

Fingerprints stored in `dataset/fingerprints.jsonl` with fields:
```python
record = {
    "sample_id": sample_id,
    "site": site,  # ← User-provided site, not inferred
    "mineral": mineral,  # Claimed mineral
    "predicted_mineral": predicted_mineral,
    "confidence": confidence,
    "status": status,  # "verified", "pending", "notVerified"
    "user_id": user_id,
    "user_name": user_name,
    "timestamp": datetime.now().isoformat(),
    "fingerprint": fingerprint_vector,  # Multimodal embedding
    "modalities_used": modalities_used,
    # ... other fields
}
```

### 6.2 Verification Status Logic  
**File:** [API/api.py](API/api.py) (lines 2716-2724)

```python
# Calculate verification status based on prediction confidence
if predicted_mineral.lower() == mineral.lower() and confidence >= 0.80:
    status = "verified"
elif confidence < 0.60:
    status = "pending"
else:
    status = "notVerified"
```

**Does NOT use site in verification** — only mineral prediction + confidence

---

## 7. LOCATION DISCRIMINATION RESEARCH

### 7.1 Documentation Files

**File:** [CHAPTER_5_RESULTS_AND_SYSTEM_PERFORMANCE.md](CHAPTER_5_RESULTS_AND_SYSTEM_PERFORMANCE.md) (lines 50-100+)

Contains:
- Full location discrimination matrix and confusion matrix
- Per-site accuracy metrics
- Statistical significance testing
- Cross-location misclassification analysis
- Impact for regulatory compliance

**Key Quote:**
> "Geological signature (combination of image, audio, chemical features) is location-specific"
> "89.2% accuracy is sufficient for regulatory provenance verification"

### 7.2 Research Findings Summary

From [location_discrimination_analysis.ipynb](location_discrimination_analysis.ipynb):

**Deployment Readiness Criteria Met:**
- ✓ Accuracy exceeds 85% threshold for production use
- ✓ Confidence calibration validates reliability (3.5% MSE)
- ✓ System is READY for field validation in South Sudan

**Regulatory Compliance:**
- 89.2% accuracy provides strong evidence for supply chain verification  
- <11% cross-location error acceptable for provenance validation
- Optional blockchain anchoring enhances immutable record-keeping

---

## 8. KEY FINDINGS & GAPS

### 8.1 What DOES Exist
✅ **Location Discrimination Model** - 89.2% accuracy in distinguishing minerals by origin  
✅ **Multimodal Training Data** - Organized by site with visual/audio/chemical features  
✅ **Fingerprint Extraction** - Embeds location-specific geoacoustic signatures  
✅ **Research Validation** - Comprehensive analysis notebook with statistical results  
✅ **UI Site Filtering** - Allows filtering scans by mining site  
✅ **Blockchain Audit Trail** - Records site information immutably  

### 8.2 What DOESN'T Exist  
❌ **Active Location Inference in API** - `/predict` endpoint takes no location inference action  
❌ **Location Prediction Endpoint** - No `/predict-location` or similar endpoint  
❌ **Automatic Site Assignment** - No ML model actively predicting site during scanning  
❌ **Location Classifier Model** - Training/inference code for location-specific classifier  
❌ **Site Validation/Enforcement** - No check that predicted mineral matches expected site signature  

### 8.3 Information Gap
The **location discrimination research is comprehensive but not operationalized** in the active API. The system *could* predict mining site from mineral characteristics but *doesn't currently do so* during scanning.

---

## 9. TECHNICAL RECOMMENDATIONS

### Option A: Operationalize Location Prediction
Add `/predict-with-location` endpoint that:
1. Calls existing mineral prediction
2. Computes location discriminator scores
3. Returns top-3 likely mining sites with confidence scores
4. Allows site validation against operator claim

### Option B: Site-Conditional Verification
Enhance fingerprint matching to:
1. Compute site-specific embedding centroids  
2. Weight re-identification matches by geographic consistency
3. Flag samples with high mineral-confidence but low geographic plausibility

### Option C: Progressive Integration
1. Return location prediction as optional field (non-blocking)
2. Log for analytics/audit trail
3. Use for training signal refinement in future model versions

---

## Summary Table

| Component | Type | Location | Function | Status |
|-----------|------|----------|----------|--------|
| Location Discrimination Analysis | Research | [location_discrimination_analysis.ipynb](location_discrimination_analysis.ipynb) | 89.2% accuracy on geoacoustic ML | ✅ Complete |
| Site Constants | Config | Constants.dart, config.js | Define 3 mining sites | ✅ Complete |
| Fingerprint Storage | DB | API/api.py | Store site field with scans | ✅ Complete |
| GPS Location Detection | Mobile | scan_screen.dart | Detect physical location | ✅ Complete |
| Site Filtering UI | Frontend | scans.html, verifications.html | Filter by site | ✅ Complete |
| Location Prediction API | Backend | API/api.py | Infer site from minerals | ❌ NOT IMPLEMENTED |
| Automatic Site Assignment | ML | N/A | Auto-assign site to scan | ❌ NOT IMPLEMENTED |
| Site Validation Logic | Backend | N/A | Check scan matches expected site | ❌ NOT IMPLEMENTED |

