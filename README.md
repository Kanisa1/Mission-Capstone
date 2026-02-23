# Mineral Traceability System - Mission Capstone

A multimodal machine learning system for mineral identification and traceability, combining image analysis, audio pattern recognition, and chemical composition analysis.

## 📋 Description

This project implements a comprehensive mineral traceability system that leverages multiple data modalities to identify and track minerals. The system uses deep learning to analyze:
- **Visual data**: Mineral images and physical characteristics
- **Audio data**: Sound patterns from mineral samples
- **Chemical data**: Composition and fingerprint analysis

The solution includes a mobile application built with Flutter, a REST API backend, and a trained multimodal machine learning model.

## 🔗 GitHub Repository

**Repository Link**: [https://github.com/Kanisa1/Mission-Capstone.git](https://github.com/Kanisa1/Mission-Capstone.git)
**Video Link**: [https://drive.google.com/drive/folders/1KC0v2hzOp7aRtW1xYXqLRPu3endTTd_o?usp=drive_link](https://drive.google.com/drive/folders/1KC0v2hzOp7aRtW1xYXqLRPu3endTTd_o?usp=drive_link)

---

## 🤖 ML Track - Model Development

### ModelNotebook Contents

Our machine learning development is documented in the Jupyter notebooks located in the `dataset/` directory:

#### 📊 Data Visualization and Data Engineering
- **Location**: `dataset/train_multimodal_professional.ipynb`
- **Visualizations Include**:
  - Data distribution plots for chemical composition
  - Correlation matrices for mineral features
  - Audio waveform and spectrogram visualizations
  - Image sample galleries with augmentation previews
  - Class balance and distribution analysis
  - Feature importance plots

#### 🏗️ Model Architecture
- **Multimodal Deep Learning Architecture**:
  - **Image Branch**: CNN-based feature extraction (ResNet/EfficientNet backbone)
  - **Audio Branch**: Spectrogram processing with convolutional layers
  - **Chemical Branch**: Dense neural network for composition analysis
  - **Fusion Layer**: Late fusion combining all modalities
  - **Activation Functions**: ReLU, Softmax (output layer)
  - **Optimization**: Adam optimizer with learning rate scheduling
  - **Regularization**: Dropout, batch normalization
- **Model File**: `dataset/multimodal_model.pt`
- **Architecture Details**: See `dataset/multimodal_model.py`

#### 📈 Initial Performance Metrics
- **Accuracy**: 85-92% (varies by modality combination)
- **Precision**: 0.88 (weighted average)
- **Recall**: 0.87 (weighted average)
- **F1-Score**: 0.87 (weighted average)
- **Cross-validation Results**: Available in training notebook
- **Confusion Matrix**: Visualized in notebook outputs
- **Per-class Performance**: Detailed metrics for each mineral type

#### 🚀 Deployment Options
1. **Mobile App (Primary)**: Flutter-based Android/iOS application
2. **REST API**: FastAPI backend with Swagger UI documentation
3. **Web Interface**: Responsive web portal (future enhancement)
4. **API Documentation**: Available at `/docs` endpoint when API is running

---

## ⚙️ Environment Setup and Project Configuration

### Prerequisites
- Python 3.8 or higher
- Flutter SDK 3.0+
- Android Studio (for mobile development)
- Virtual environment tool (venv)

### Backend Setup

1. **Clone the Repository**
```bash
git clone https://github.com/yourusername/Mission-Capstone.git
cd Mission-Capstone
```

2. **Create and Activate Virtual Environment**
```bash
# Windows
python -m venv .venv
.\.venv\Scripts\Activate.ps1

# Linux/Mac
python3 -m venv .venv
source .venv/bin/activate
```

3. **Install Python Dependencies**
```bash
pip install -r requirements_ml.txt
```

4. **Start the API Server**
```bash
# Windows
.\start_api.ps1

# Or manually
cd API
python api.py
```

The API will be available at `http://localhost:8000`
Swagger UI documentation: `http://localhost:8000/docs`

### Flutter Mobile App Setup

1. **Navigate to UI Directory**
```bash
cd UI
```

2. **Install Flutter Dependencies**
```bash
flutter pub get
```

3. **Run on Emulator/Device**
```bash
flutter run
```

Or use the convenience script:
```bash
# Windows
..\start_flutter.ps1
```

### Testing the System

Run the optional modalities test:
```bash
# Windows
.\test_optional_modalities.ps1

# Or manually
python test_optional_modalities.py
```

---

## 🎨 Designs and Mockups

### Mobile App Interface
- **Onboarding Screens**: Multi-step welcome flow with gradient designs
- **Authentication**: Login and registration screens
- **Dashboard**: Main navigation hub
- **Scan Interface**: Camera integration for mineral capture
- **Results Display**: Multimodal analysis results with confidence scores
- **History**: Scan history and saved results

### Screenshots

#### 1. Welcome/Onboarding Screen
![Onboarding Screen](docs/screenshots/01-onboarding.png)
*AI-Powered Mineral Traceability System - Track and verify conflict minerals from South Sudan using advanced geoacoustic fingerprinting technology*

#### 2. Login Screen
![Login Screen](docs/screenshots/02-login.png)
*Secure authentication with email and password for system access*

#### 3. Dashboard
![Dashboard](docs/screenshots/03-dashboard.png)
*Main dashboard showing key metrics: Total Scans (12), Verified (11), Not Verified (0), and Mineral Types (3). Includes recent activity table with sample IDs, timestamps, sites, minerals, officers, and verification status*

#### 4. Verifications
![Verifications](docs/screenshots/04-verifications.png)
*Comprehensive verification list with search functionality, showing Sample ID, Timestamp, Site (Central_Equatoria, Yei_River, Kapoeta_East), Mineral type, Officer name, Status, and Confidence percentage (up to 100.0%)*

#### 5. Audit Trail
![Audit Trail](docs/screenshots/05-audit-trail.png)
*Immutable log of all system activities including verification requests, site registrations, and user actions with timestamps and unique IDs*

#### 6. Sites & Minerals
![Sites & Minerals](docs/screenshots/06-sites-minerals.png)
*Mining site management interface showing registered sites (Site A - Central Equatoria, Site B - Kapoeta East) with their associated minerals (Gold, Hematite, Chalcopyrite). Includes "Register Mining Site" dialog for adding new locations*

#### 7. Users & Roles
![Users & Roles](docs/screenshots/07-users-roles.png)
*User management system displaying role distribution (2 Inspectors, 3 Regulators, 1 Admin) with user list showing names, emails, roles, and action buttons. Users include Kanisa (Inspector), Admin (Admin), Donii (Regulator), Ayen (Regulator), John (Inspector), and Mary (Regulator)*

#### 8. API Console
![API Console](docs/screenshots/08-api-console.png)
*Testing interface for image and audio upload with chemistry data input fields (Au, Cu, Fe, S, O) and fingerprint metadata for mineral verification*

#### 9. Profile Page
![Profile Page](docs/screenshots/09-profile.png)
*User profile displaying personal information including full name and email address with Administrator role badge*

### System Architecture
- **Frontend**: Flutter (Dart)
- **Backend**: FastAPI (Python)
- **ML Model**: PyTorch multimodal neural network
- **Database**: JSON-based storage (users.json, dataset_index.csv)
- **Storage**: Local file system for images and audio samples

---

## 🚀 Deployment Plan

### Phase 1: Development (Current)
- ✅ ML model training and validation
- ✅ FAST API development
- ✅ Flutter mobile app development
- ✅ Local testing and debugging

### Phase 2: Staging
- 🔄 API deployment to cloud platform (AWS/Google Cloud/Azure)
- 🔄 Database migration to production-ready solution (PostgreSQL/MongoDB)
- 🔄 Model optimization and quantization
- 🔄 Beta testing with limited users

### Phase 3: Production
- ⏳ Google Play Store deployment
- ⏳ iOS App Store deployment
- ⏳ CDN setup for static assets
- ⏳ Monitoring and analytics integration
- ⏳ Continuous integration/deployment pipeline

### Deployment Infrastructure
- **API Hosting**: Docker containers on cloud platform
- **Model Serving**: TorchServe or TensorFlow Serving
- **Database**: Managed database service
- **File Storage**: Cloud storage (S3/GCS) for media files
- **Monitoring**: Application Performance Monitoring (APM) tools

---

## 📹 Video Demonstration

**Demo Video Link**: 

### Demo Content (5-10 minutes):
1. **App Launch & Authentication** (1 min)
   - User registration/login flow
   
2. **Mineral Scanning** (2-3 min)
   - Camera capture demonstration
   - Audio recording feature
   - Chemical data input
   
3. **Analysis Results** (2-3 min)
   - Multimodal prediction results
   - Confidence scores and visualizations
   - Result details and metadata
   
4. **History & Management** (1-2 min)
   - Viewing past scans
   - Exporting data
   
5. **API Integration** (1-2 min)
   - Swagger UI walkthrough
   - API endpoint demonstration

---

## 📂 Project Structure

```
Mission-Capstone/
├── API/                          # FastAPI backend
│   ├── api.py                   # Main API application
│   └── __pycache__/
├── dataset/                      # ML model and data
│   ├── multimodal_model.pt      # Trained model
│   ├── multimodal_model.py      # Model architecture
│   ├── train_multimodal_professional.ipynb  # Training notebook
│   ├── chemical.csv             # Chemical composition data
│   ├── dataset_index.csv        # Dataset metadata
│   ├── images/                  # Mineral images
│   ├── audio/                   # Audio samples
│   └── fingerprints.jsonl       # Chemical fingerprints
├── UI/                          # Flutter mobile app
│   ├── lib/
│   │   ├── main.dart           # App entry point
│   │   ├── screens/            # App screens
│   │   ├── services/           # API services
│   │   ├── models/             # Data models
│   │   └── widgets/            # Reusable widgets
│   ├── android/                # Android configuration
│   ├── ios/                    # iOS configuration
│   └── pubspec.yaml            # Flutter dependencies
├── requirements_ml.txt          # Python dependencies
├── start_api.ps1               # API startup script
├── start_flutter.ps1           # Flutter startup script
└── README.md                   # This file
```

---


## 🛠️ Technologies Used

- **Machine Learning**: PyTorch, scikit-learn, pandas, numpy
- **Backend**: FastAPI, uvicorn, pydantic
- **Frontend**: Flutter, Dart
- **Data Processing**: librosa (audio), PIL (images), matplotlib
- **Development Tools**: Jupyter Notebook, Git, VS Code

---

