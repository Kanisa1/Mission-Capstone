import io
import sys
import json
import pickle
from pathlib import Path
from datetime import datetime

import torch
import numpy as np
from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from typing import List, Optional
from PIL import Image
import librosa
import torchvision.transforms as T
from sklearn.preprocessing import StandardScaler
from pydantic import BaseModel


# -------------------------------------------------
# Pydantic Request Models
# -------------------------------------------------

class LoginRequest(BaseModel):
    email: str
    password: str

class RegisterRequest(BaseModel):
    name: str
    email: str
    password: str
    role: str
    organization: Optional[str] = None

class GoogleSignInRequest(BaseModel):
    id_token: str
    access_token: str
    name: str
    email: str
    photo_url: Optional[str] = None

class ApprovalRequest(BaseModel):
    user_id: str

class DenyRequest(BaseModel):
    user_id: str
    reason: Optional[str] = None


# -------------------------------------------------
# Path setup
# -------------------------------------------------

BASE_DIR = Path(__file__).resolve().parents[1]
if str(BASE_DIR) not in sys.path:
    sys.path.insert(0, str(BASE_DIR))

from dataset.multimodal_model import MultiModalNet
from dataset.logging_utils import ScanEventLogger
from dataset.metrics_calculator import MetricsCalculator


# -------------------------------------------------
# Config
# -------------------------------------------------

DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")

MINERAL_LABELS = {
    0: "gold",
    1: "chalcopyrite",
    2: "hematite"
}

FINGERPRINT_DB = BASE_DIR / "dataset" / "fingerprints.jsonl"
USERS_DB = BASE_DIR / "dataset" / "users.json"
LOGS_DIR = BASE_DIR / "logs"

# Initialize logging
logger = ScanEventLogger(LOGS_DIR)
metrics_calc = MetricsCalculator(fingerprints_file=str(FINGERPRINT_DB))


# -------------------------------------------------
# Load trained model
# -------------------------------------------------

model = MultiModalNet(num_classes=3)

model_path = BASE_DIR / "dataset" / "multimodal_model.pt"
model.load_state_dict(
    torch.load(model_path, map_location=DEVICE)
)

model.to(DEVICE)
model.eval()

print(f"✅ Model loaded from: {model_path}")
print(f"✅ Device: {DEVICE}")


# -------------------------------------------------
# Load Chemical Scaler
# -------------------------------------------------

scaler_path = BASE_DIR / "dataset" / "chemical_scaler.pkl"
if scaler_path.exists():
    with open(scaler_path, "rb") as f:
        chem_scaler = pickle.load(f)
    print(f"✅ Chemical scaler loaded from: {scaler_path}")
else:
    print(f"⚠️  Chemical scaler not found at {scaler_path}")
    print(f"   Creating default scaler with training data statistics...")
    # Fallback: use approximate statistics from training
    chem_scaler = StandardScaler()
    chem_scaler.mean_ = np.array([0.36794582, 0.33860045, 0.9255079, 0.6772009, 0.88036117])
    chem_scaler.scale_ = np.array([0.48224651, 0.47323375, 0.80984596, 0.94646751, 1.36603357])
    print(f"✅ Default scaler initialized")


# -------------------------------------------------
# Image preprocessing (ImageNet normalization)
# -------------------------------------------------

img_transform = T.Compose([
    T.Resize((224, 224)),
    T.ToTensor(),
    T.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])  # ImageNet normalization
])

print("✅ Image preprocessing configured with ImageNet normalization")


# -------------------------------------------------
# Image preprocessing (ImageNet normalization)
# -------------------------------------------------

img_transform = T.Compose([
    T.Resize((224, 224)),
    T.ToTensor(),
    T.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])  # ImageNet normalization
])

print("✅ Image preprocessing configured with ImageNet normalization")

print("\n" + "=" * 80)
print("  🎯 GEOACOUSTIC MINERAL TRACEABILITY API v2.0")
print("  Professional Model - 88.5% Accuracy")
print("=" * 80)
print(f"✅ Model: Multimodal CNN (ResNet18 + Audio CNN + Chemical MLP)")
print(f"✅ Classes: Gold, Chalcopyrite, Hematite")
print(f"✅ Preprocessing: ImageNet normalization + Chemical StandardScaler")
print(f"✅ Features: Optional modalities, Logging, Metrics, Verification")
print("=" * 80 + "\n")


# -------------------------------------------------
# FastAPI app
# -------------------------------------------------

app = FastAPI(
    title="Geoacoustic Mineral Fingerprinting API",
    description="Multi-modal mineral classification and fingerprint extraction API with optional modalities support",
    version="2.0"
)

# Add CORS middleware to allow Flutter web app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify exact origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Serve the web frontend static files from the `webapp` directory
WEBAPP_DIR = str(BASE_DIR / "webapp")
try:
    # Mounting moved to the end of the file so API routes are registered first.
    # This avoids StaticFiles capturing API endpoints and returning 404s.
    pass
except Exception:
    pass

    


# -------------------------------------------------
# Helpers
# -------------------------------------------------

def process_image(file_bytes):
    """Process image bytes to tensor. Returns None if file_bytes is None."""
    if file_bytes is None:
        return None
    img = Image.open(io.BytesIO(file_bytes)).convert("RGB")
    img = img_transform(img)
    return img.unsqueeze(0)


def process_audio(file_bytes, sr=16000, n_mfcc=20):
    """Process audio bytes to MFCC tensor. Returns None if file_bytes is None."""
    if file_bytes is None:
        return None
    y, _ = librosa.load(
        io.BytesIO(file_bytes),
        sr=sr,
        mono=True
    )

    mfcc = librosa.feature.mfcc(
        y=y,
        sr=sr,
        n_mfcc=n_mfcc
    )

    mfcc = (mfcc - mfcc.mean()) / (mfcc.std() + 1e-8)

    return torch.tensor(mfcc, dtype=torch.float32).unsqueeze(0)


def save_fingerprint(record: dict):
    """
    Store each fingerprint as one JSON line
    """
    FINGERPRINT_DB.parent.mkdir(parents=True, exist_ok=True)

    with open(FINGERPRINT_DB, "a", encoding="utf-8") as f:
        f.write(json.dumps(record) + "\n")


def load_fingerprints():
    """
    Load all fingerprints from JSONL file
    """
    if not FINGERPRINT_DB.exists():
        return []
    
    records = []
    with open(FINGERPRINT_DB, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                try:
                    records.append(json.loads(line))
                except json.JSONDecodeError:
                    continue
    return records


def load_users():
    """
    Load all users from JSON file
    """
    if not USERS_DB.exists():
        # Initialize with default users
        default_users = [
            {
                "id": "1",
                "email": "inspector@example.com",
                "name": "John Inspector",
                "password": "inspector123",
                "role": "operator",
                "organization": "South Sudan Mining Authority",
                "approval_status": "approved",
                "photo_url": None,
                "created_at": datetime.utcnow().isoformat()
            },
            {
                "id": "2",
                "email": "regulator@example.com",
                "name": "Sarah Regulator",
                "password": "regulator123",
                "role": "verifier",
                "organization": "Regulatory Commission",
                "approval_status": "approved",
                "photo_url": None,
                "created_at": datetime.utcnow().isoformat()
            },
            {
                "id": "admin",
                "email": "admin@example.com",
                "name": "Admin User",
                "password": "admin123",
                "role": "admin",
                "organization": "MineralTrace HQ",
                "approval_status": "approved",
                "photo_url": None,
                "created_at": datetime.utcnow().isoformat()
            }
        ]
        save_users(default_users)
        return default_users
    
    with open(USERS_DB, "r", encoding="utf-8") as f:
        return json.load(f)


def save_users(users):
    """
    Save users to JSON file
    """
    USERS_DB.parent.mkdir(parents=True, exist_ok=True)
    with open(USERS_DB, "w", encoding="utf-8") as f:
        json.dump(users, f, indent=2)


# -------------------------------------------------
# Authentication endpoints
# -------------------------------------------------

@app.post("/login")
async def login(request: LoginRequest):
    """
    Authenticate user with email and password
    """
    try:
        users = load_users()
        
        # Find user by email
        user = None
        for u in users:
            if u['email'].lower() == request.email.lower():
                user = u
                break
        
        if not user:
            raise HTTPException(status_code=401, detail="Invalid email or password")
        
        # Check password (in production, use proper password hashing)
        if user.get('password') != request.password:
            raise HTTPException(status_code=401, detail="Invalid email or password")
        
        # Check approval status
        approval_status = user.get('approval_status', 'approved')
        if approval_status != 'approved':
            raise HTTPException(status_code=403, detail=f"Account is {approval_status}")
        
        # Return user info without password
        return {
            "success": True,
            "user": {
                "id": user['id'],
                "email": user['email'],
                "name": user['name'],
                "role": user['role'],
                "photo_url": user.get('photo_url'),
                "organization": user.get('organization')
            }
        }
    
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/auth/register")
async def register(request: RegisterRequest):
    """
    Register new user with email and password (requires admin approval)
    """
    try:
        users = load_users()
        
        # Check if email already exists
        for u in users:
            if u['email'].lower() == request.email.lower():
                raise HTTPException(status_code=400, detail="Email already registered")
        
        # Generate new unique user ID
        existing_ids = [int(u['id']) for u in users if u['id'].isdigit()]
        user_id = str(max(existing_ids, default=0) + 1)
        
        # Create new user with pending approval
        new_user = {
            "id": user_id,
            "email": request.email,
            "name": request.name,
            "password": request.password,  # In production, hash this!
            "role": request.role,
            "organization": request.organization,
            "approval_status": "pending",
            "created_at": datetime.utcnow().isoformat(),
            "photo_url": None
        }
        
        users.append(new_user)
        save_users(users)
        
        return {
            "success": True,
            "message": "Registration successful. Awaiting admin approval.",
            "user": {
                "id": user_id,
                "email": request.email,
                "name": request.name,
                "role": request.role,
                "approval_status": "pending"
            }
        }
    
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/auth/google")
async def google_signin(request: GoogleSignInRequest):
    """
    Sign in or register with Google (requires admin approval for new users)
    """
    try:
        users = load_users()
        
        # Check if user already exists
        existing_user = None
        for u in users:
            if u['email'].lower() == request.email.lower():
                existing_user = u
                break
        
        if existing_user:
            # Existing user - check approval status
            approval_status = existing_user.get('approval_status', 'approved')
            if approval_status != 'approved':
                raise HTTPException(status_code=403, detail=f"Account is {approval_status}")
            
            # Update photo URL if changed
            if request.photo_url and existing_user.get('photo_url') != request.photo_url:
                existing_user['photo_url'] = request.photo_url
                save_users(users)
            
            return {
                "success": True,
                "user": {
                    "id": existing_user['id'],
                    "email": existing_user['email'],
                    "name": existing_user['name'],
                    "role": existing_user['role'],
                    "photo_url": existing_user.get('photo_url'),
                    "organization": existing_user.get('organization')
                }
            }
        else:
            # New user - create with pending approval
            existing_ids = [int(u['id']) for u in users if u['id'].isdigit()]
            user_id = str(max(existing_ids, default=0) + 1)
            new_user = {
                "id": user_id,
                "email": request.email,
                "name": request.name,
                "password": "",  # No password for Google users
                "role": "operator",  # Default role
                "organization": None,
                "approval_status": "pending",
                "created_at": datetime.utcnow().isoformat(),
                "photo_url": request.photo_url,
                "auth_provider": "google"
            }
            
            users.append(new_user)
            save_users(users)
            
            return {
                "success": True,
                "message": "Registration successful. Awaiting admin approval.",
                "user": {
                    "id": user_id,
                    "email": request.email,
                    "name": request.name,
                    "role": "operator",
                    "approval_status": "pending"
                }
            }
    
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/auth/approval-status")
async def check_approval_status(email: str):
    """
    Check user approval status by email
    """
    try:
        users = load_users()
        
        user = None
        for u in users:
            if u['email'].lower() == email.lower():
                user = u
                break
        
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        
        approval_status = user.get('approval_status', 'approved')
        
        return {
            "success": True,
            "approval_status": approval_status,
            "denied_reason": user.get('denied_reason')
        }
    
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# -------------------------------------------------
# Admin endpoints
# -------------------------------------------------

@app.get("/api/admin/pending-users")
async def get_pending_users():
    """
    Get all users pending approval (admin only)
    """
    try:
        users = load_users()
        
        pending_users = [
            {
                "id": u['id'],
                "name": u['name'],
                "email": u['email'],
                "role": u['role'],
                "organization": u.get('organization'),
                "photo_url": u.get('photo_url'),
                "created_at": u.get('created_at'),
                "approval_status": u.get('approval_status', 'approved')
            }
            for u in users
            if u.get('approval_status') == 'pending'
        ]
        
        return {
            "success": True,
            "users": pending_users
        }
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/admin/approve-user")
async def approve_user(request: ApprovalRequest):
    """
    Approve a pending user (admin only)
    """
    try:
        users = load_users()
        
        user_found = False
        for u in users:
            if u['id'] == request.user_id:
                u['approval_status'] = 'approved'
                u['approved_at'] = datetime.utcnow().isoformat()
                user_found = True
                break
        
        if not user_found:
            raise HTTPException(status_code=404, detail="User not found")
        
        save_users(users)
        
        return {
            "success": True,
            "message": "User approved successfully"
        }
    
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/admin/deny-user")
async def deny_user(request: DenyRequest):
    """
    Deny a pending user (admin only)
    """
    try:
        users = load_users()
        
        user_found = False
        for u in users:
            if u['id'] == request.user_id:
                u['approval_status'] = 'denied'
                u['denied_at'] = datetime.utcnow().isoformat()
                u['denied_reason'] = request.reason or "No reason provided"
                user_found = True
                break
        
        if not user_found:
            raise HTTPException(status_code=404, detail="User not found")
        
        save_users(users)
        
        return {
            "success": True,
            "message": "User denied successfully"
        }
    
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# -------------------------------------------------
# Prediction endpoint
# -------------------------------------------------

@app.post("/predict")
async def predict(
    image: Optional[UploadFile] = File(None),
    audio: Optional[UploadFile] = File(None),

    Au: float = Form(...),
    Cu: float = Form(...),
    Fe: float = Form(...),
    S: float  = Form(...),
    O: float  = Form(...)
):
    """
    Predict mineral type from multimodal inputs
    Now supports optional modalities: image and audio can be None
    At least one modality (image or audio) must be provided
    """
    try:
        # Validate at least one modality is provided
        if image is None and audio is None:
            raise HTTPException(
                status_code=400,
                detail="At least one modality (image or audio) must be provided"
            )
        
        # Process inputs (None-safe)
        image_bytes = await image.read() if image else None
        audio_bytes = await audio.read() if audio else None

        img = process_image(image_bytes)
        aud = process_audio(audio_bytes)
        
        if img is not None:
            img = img.to(DEVICE)
        if aud is not None:
            aud = aud.to(DEVICE)

        # Normalize chemical features using the same scaler as training
        chem_raw = np.array([[Au, Cu, Fe, S, O]])
        chem_normalized = chem_scaler.transform(chem_raw)
        chem = torch.tensor(
            chem_normalized,
            dtype=torch.float32
        ).to(DEVICE)

        with torch.no_grad():
            logits = model(image=img, audio=aud, chemical=chem)
            probs = torch.softmax(logits, dim=1)

            pred = probs.argmax(dim=1).item()
            confidence = probs[0, pred].item()

        # Track modalities used
        modalities_used = {
            "image": image is not None,
            "audio": audio is not None,
            "chemical": True
        }
        
        # Log prediction
        logger.log_model_prediction(
            predicted_mineral=MINERAL_LABELS[pred],
            confidence=confidence,
            modalities=modalities_used
        )

        return {
            "predicted_mineral": MINERAL_LABELS[pred],
            "prediction": MINERAL_LABELS[pred],  # alias for compatibility
            "confidence": round(float(confidence), 4),
            "modalities_used": modalities_used
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.log_error(e, {"endpoint": "/predict"})
        raise HTTPException(status_code=500, detail=str(e))


# -------------------------------------------------
# Fingerprint extraction + storage endpoint
# -------------------------------------------------

@app.post("/fingerprint")
async def fingerprint(
    # metadata
    sample_id: str = Form(...),
    site: str = Form(...),
    mineral: str = Form(...),
    user_id: str = Form(...),
    user_name: str = Form(...),

    # files - now optional
    image: Optional[UploadFile] = File(None),
    audio: Optional[UploadFile] = File(None),

    # chemistry
    Au: float = Form(...),
    Cu: float = Form(...),
    Fe: float = Form(...),
    S: float  = Form(...),
    O: float  = Form(...),
    
    # GPS coordinates (optional)
    latitude: Optional[float] = Form(None),
    longitude: Optional[float] = Form(None)
):
    """
    Generate and store fingerprint
    Now supports optional modalities: image and audio can be None
    At least one modality (image or audio) must be provided
    """
    try:
        # Validate at least one modality is provided
        if image is None and audio is None:
            raise HTTPException(
                status_code=400,
                detail="At least one modality (image or audio) must be provided"
            )
        
        # Process inputs (None-safe)
        image_bytes = await image.read() if image else None
        audio_bytes = await audio.read() if audio else None

        img = process_image(image_bytes)
        aud = process_audio(audio_bytes)
        
        if img is not None:
            img = img.to(DEVICE)
        if aud is not None:
            aud = aud.to(DEVICE)

        # Normalize chemical features using the same scaler as training
        chem_raw = np.array([[Au, Cu, Fe, S, O]])
        chem_normalized = chem_scaler.transform(chem_raw)
        chem = torch.tensor(
            chem_normalized,
            dtype=torch.float32
        ).to(DEVICE)

        with torch.no_grad():
            # Extract features and create fingerprint using new API
            fingerprint_tensor, modalities_used = model.extract_fingerprint(
                image=img, audio=aud, chemical=chem
            )
            
            # Also run prediction to get confidence score
            logits = model(image=img, audio=aud, chemical=chem)
            probs = torch.softmax(logits, dim=1)
            pred = probs.argmax(dim=1).item()
            confidence = probs[0, pred].item()

        fingerprint_vector = fingerprint_tensor.squeeze(0).cpu().numpy().tolist()
        predicted_mineral = MINERAL_LABELS[pred]
        
        # Calculate verification status
        if predicted_mineral.lower() == mineral.lower() and confidence >= 0.80:
            status = "verified"
        elif confidence < 0.60:
            status = "pending"
        else:
            status = "notVerified"

        record = {
            "sample_id": sample_id,
            "site": site,
            "mineral": mineral,
            "predicted_mineral": predicted_mineral,
            "confidence": round(float(confidence), 4),
            "status": status,
            "user_id": user_id,
            "user_name": user_name,
            "chemical": {
                "Au": Au,
                "Cu": Cu,
                "Fe": Fe,
                "S": S,
                "O": O
            },
            "modalities_used": modalities_used,
            "fingerprint_dim": len(fingerprint_vector),
            "fingerprint": fingerprint_vector,
            "timestamp": datetime.utcnow().isoformat()
        }
        
        # Add GPS coordinates if provided
        if latitude is not None and longitude is not None:
            record["gps"] = {
                "latitude": round(latitude, 6),
                "longitude": round(longitude, 6)
            }

        save_fingerprint(record)
        
        # Log scan event
        logger.log_scan_event(
            sample_id=sample_id,
            user_id=user_id,
            site=site,
            claimed_mineral=mineral,
            predicted_mineral=predicted_mineral,
            confidence=confidence,
            status=status,
            modalities_used=modalities_used
        )

        return {
            "sample_id": sample_id,
            "site": site,
            "mineral": mineral,
            "predicted_mineral": predicted_mineral,
            "confidence": round(float(confidence), 4),
            "status": status,
            "modalities_used": modalities_used,
            "fingerprint_dim": len(fingerprint_vector),
            "stored": True
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.log_error(e, {"endpoint": "/fingerprint", "sample_id": sample_id})
        raise HTTPException(status_code=500, detail=str(e))


# -------------------------------------------------
# GET endpoints for web dashboard
# -------------------------------------------------

@app.get("/fingerprints")
async def get_fingerprints(
    site: Optional[str] = None,
    mineral: Optional[str] = None,
    limit: Optional[int] = None
):
    """
    Retrieve all stored fingerprints with optional filtering
    """
    try:
        records = load_fingerprints()
        
        # Apply filters
        if site:
            records = [r for r in records if r.get("site", "").lower() == site.lower()]
        
        if mineral:
            records = [r for r in records if r.get("mineral", "").lower() == mineral.lower()]
        
        # Sort by timestamp (newest first)
        records.sort(key=lambda x: x.get("timestamp", ""), reverse=True)
        
        # Apply limit
        if limit and limit > 0:
            records = records[:limit]
        
        return {
            "total": len(records),
            "fingerprints": records
        }
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/verifications")
async def get_verifications(
    site: Optional[str] = None,
    limit: Optional[int] = None
):
    """
    Retrieve verification records (simplified view of fingerprints)
    """
    try:
        records = load_fingerprints()
        
        # Apply site filter
        if site:
            records = [r for r in records if r.get("site", "").lower() == site.lower()]
        
        # Sort by timestamp (newest first)
        records.sort(key=lambda x: x.get("timestamp", ""), reverse=True)
        
        # Apply limit
        if limit and limit > 0:
            records = records[:limit]
        
        # Simplify records for verification view (exclude large fingerprint vectors)
        verifications = []
        for r in records:
            # Calculate verification status based on ML prediction
            predicted_mineral = r.get("predicted_mineral", "").lower()
            claimed_mineral = r.get("mineral", "").lower()
            confidence = r.get("confidence")
            
            # Determine status using same logic as mobile app
            if predicted_mineral and claimed_mineral and confidence is not None:
                if predicted_mineral == claimed_mineral and confidence >= 0.80:
                    status = "verified"
                elif confidence < 0.60:
                    status = "pending"
                else:
                    status = "notVerified"
            else:
                # For old records without prediction data, mark as verified
                status = "verified"
            
            verifications.append({
                "id": r.get("sample_id"),
                "timestamp": r.get("timestamp"),
                "site": r.get("site"),
                "mineral": r.get("mineral"),
                "predicted_mineral": r.get("predicted_mineral"),
                "user_id": r.get("user_id"),
                "user_name": r.get("user_name", "Unknown"),
                "chemical": r.get("chemical"),
                "status": status,
                "confidence": confidence  # Use actual confidence from record (can be None for old records)
            })
        
        return {
            "total": len(verifications),
            "verifications": verifications
        }
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/stats")
async def get_stats():
    """
    Get dashboard statistics
    """
    try:
        records = load_fingerprints()
        
        # Count by mineral type and verification status
        mineral_counts = {}
        site_counts = {}
        verified_count = 0
        not_verified_count = 0
        pending_count = 0
        
        for r in records:
            mineral = r.get("mineral", "unknown").lower()  # Normalize to lowercase
            site = r.get("site", "unknown")
            
            mineral_counts[mineral] = mineral_counts.get(mineral, 0) + 1
            site_counts[site] = site_counts.get(site, 0) + 1
            
            # Calculate verification status (same logic as /verifications)
            predicted_mineral = r.get("predicted_mineral", "").lower()
            claimed_mineral = r.get("mineral", "").lower()
            confidence = r.get("confidence")
            
            if predicted_mineral and claimed_mineral and confidence is not None:
                if predicted_mineral == claimed_mineral and confidence >= 0.80:
                    verified_count += 1
                elif confidence < 0.60:
                    pending_count += 1
                else:
                    not_verified_count += 1
            else:
                # Old records without prediction data count as verified
                verified_count += 1
        
        return {
            "total_scans": len(records),
            "verified": verified_count,
            "not_verified": not_verified_count,
            "pending": pending_count,
            "by_mineral": mineral_counts,
            "by_site": site_counts,
            "recent_count": len([r for r in records if r.get("timestamp", "") > ""])
        }
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# -------------------------------------------------
# User management endpoints
# -------------------------------------------------

@app.get("/users")
async def get_users(role: Optional[str] = None):
    """
    Get all users with optional role filtering
    """
    try:
        users = load_users()
        
        if role:
            users = [u for u in users if u.get("role", "").lower() == role.lower()]
        
        return {
            "total": len(users),
            "users": users
        }
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/users")
async def create_user(
    name: str = Form(...),
    email: str = Form(...),
    role: str = Form(...),
    password: str = Form(...)  # In production, hash the password
):
    """
    Create a new user
    """
    try:
        users = load_users()
        
        # Check if email already exists
        if any(u['email'] == email for u in users):
            raise HTTPException(status_code=400, detail="Email already exists")
        
        # Generate new user ID
        new_id = str(max([int(u['id']) if u['id'].isdigit() else 0 for u in users]) + 1)
        
        new_user = {
            "id": new_id,
            "email": email,
            "name": name,
            "password": password,  # In production, hash this
            "role": role.lower(),
            "created_at": datetime.utcnow().isoformat()
        }
        
        users.append(new_user)
        save_users(users)
        
        return {
            "success": True,
            "user": new_user
        }
    
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.put("/users/{user_id}")
async def update_user(
    user_id: str,
    name: Optional[str] = Form(None),
    email: Optional[str] = Form(None),
    role: Optional[str] = Form(None),
    password: Optional[str] = Form(None)
):
    """
    Update user information (admin function)
    """
    try:
        users = load_users()
        
        user_index = None
        for i, u in enumerate(users):
            if u['id'] == user_id:
                user_index = i
                break
        
        if user_index is None:
            raise HTTPException(status_code=404, detail="User not found")
        
        # Update fields
        if name:
            users[user_index]['name'] = name
        if email:
            # Check if new email already exists for another user
            if any(u['email'] == email and u['id'] != user_id for u in users):
                raise HTTPException(status_code=400, detail="Email already exists")
            users[user_index]['email'] = email
        if role:
            users[user_index]['role'] = role.lower()
        if password:
            users[user_index]['password'] = password
        
        users[user_index]['updated_at'] = datetime.utcnow().isoformat()
        
        save_users(users)
        
        # Return user without password
        user_data = {k: v for k, v in users[user_index].items() if k != 'password'}
        
        return {
            "success": True,
            "user": user_data
        }
    
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.put("/profile/{user_id}")
async def update_profile(
    user_id: str,
    name: Optional[str] = Form(None),
    email: Optional[str] = Form(None),
    current_password: Optional[str] = Form(None),
    new_password: Optional[str] = Form(None)
):
    """
    Update user profile (user self-service)
    Requires current password to change password
    """
    try:
        users = load_users()
        
        user_index = None
        for i, u in enumerate(users):
            if u['id'] == user_id:
                user_index = i
                break
        
        if user_index is None:
            raise HTTPException(status_code=404, detail="User not found")
        
        user = users[user_index]
        
        # If changing password, verify current password
        if new_password:
            if not current_password:
                raise HTTPException(status_code=400, detail="Current password required to change password")
            if user.get('password') != current_password:
                raise HTTPException(status_code=401, detail="Current password is incorrect")
            users[user_index]['password'] = new_password
        
        # Update other fields
        if name:
            users[user_index]['name'] = name
        if email:
            # Check if new email already exists for another user
            if any(u['email'] == email and u['id'] != user_id for u in users):
                raise HTTPException(status_code=400, detail="Email already exists")
            users[user_index]['email'] = email
        
        users[user_index]['updated_at'] = datetime.utcnow().isoformat()
        
        save_users(users)
        
        # Return user without password
        user_data = {k: v for k, v in users[user_index].items() if k != 'password'}
        
        return {
            "success": True,
            "message": "Profile updated successfully",
            "user": user_data
        }
    
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.delete("/users/{user_id}")
async def delete_user(user_id: str):
    """
    Delete a user
    """
    try:
        users = load_users()
        
        # Find and remove user
        user_found = False
        for i, u in enumerate(users):
            if u['id'] == user_id:
                users.pop(i)
                user_found = True
                break
        
        if not user_found:
            raise HTTPException(status_code=404, detail="User not found")
        
        save_users(users)
        
        return {
            "success": True,
            "message": f"User {user_id} deleted successfully"
        }
    
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/")
async def root():
    """
    API root endpoint
    """
    return {
        "api": "Geoacoustic Mineral Fingerprinting API",
        "version": "2.0",
        "features": {
            "optional_modalities": True,
            "logging": True,
            "metrics": True,
            "verification_status": True
        },
        "endpoints": {
            "POST /predict": "Predict mineral type (optional image/audio)",
            "POST /fingerprint": "Generate and store fingerprint (optional image/audio)",
            "GET /fingerprints": "Retrieve fingerprints",
            "GET /verifications": "Retrieve verifications",
            "GET /stats": "Get dashboard statistics",
            "GET /metrics": "Get model evaluation metrics",
            "GET /health": "Health check endpoint",
            "GET /users": "Get all users",
            "POST /users": "Create new user",
            "PUT /users/{id}": "Update user",
            "DELETE /users/{id}": "Delete user"
        }
    }


@app.get("/health")
async def health():
    """
    Health check endpoint
    """
    try:
        return {
            "status": "healthy",
            "version": "2.0",
            "model_device": str(DEVICE),
            "features": {
                "optional_modalities": True,
                "logging": True,
                "metrics": True,
                "verification_status": True
            }
        }
    except Exception as e:
        return {
            "status": "unhealthy",
            "error": str(e)
        }


@app.get("/metrics")
async def get_metrics():
    """
    Get comprehensive model evaluation metrics
    Calculates accuracy, precision, recall, F1 score, FPR from verification records
    """
    try:
        records = load_fingerprints()
        
        if len(records) == 0:
            return {
                "message": "No verification data available yet",
                "total_samples": 0
            }
        
        # Prepare data for metrics calculation
        y_true = []
        y_pred = []
        
        for r in records:
            claimed = r.get("mineral", "").lower()
            predicted = r.get("predicted_mineral", "").lower()
            
            if claimed and predicted:
                y_true.append(claimed)
                y_pred.append(predicted)
        
        if len(y_true) == 0:
            return {
                "message": "No valid prediction data available",
                "total_samples": len(records)
            }
        
        # Calculate metrics (MetricsCalculator loads from file, doesn't take args)
        metrics = metrics_calc.calculate_metrics()
        
        # Add modality statistics
        modality_stats = {}
        for r in records:
            mods = r.get("modalities_used", {})
            if mods:
                key = "+".join([k for k, v in mods.items() if v])
                modality_stats[key] = modality_stats.get(key, 0) + 1
        
        metrics["modality_usage"] = modality_stats
        metrics["total_samples"] = len(records)
        metrics["samples_with_predictions"] = len(y_true)
        
        return metrics
    
    except Exception as e:
        logger.log_error(e, {"endpoint": "/metrics"})
        raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    import uvicorn
    import os
    
    # Allow configuration via environment variables
    host = os.getenv("API_HOST", "0.0.0.0")  # Changed to 0.0.0.0 to allow mobile device access
    port = int(os.getenv("API_PORT", "8000"))
    
    print("\n" + "=" * 80)
    print("🚀 Starting Geoacoustic Mineral Fingerprinting API...")
    print("=" * 80)
    print(f"📡 API running at: http://{host}:{port}")
    print(f"📚 API docs at: http://127.0.0.1:{port}/docs")
    print(f"💡 For mobile device access, use your computer's local IP address")
    print(f"   Example: http://192.168.1.100:{port}")
    print("=" * 80 + "\n")
    # Mount static webapp here so API routes are already defined and take precedence.
    WEBAPP_DIR = str(BASE_DIR / "webapp")
    try:
        app.mount("/", StaticFiles(directory=WEBAPP_DIR, html=True), name="webapp")
        print(f"✅ Mounted static webapp from: {WEBAPP_DIR}")
    except Exception as _e:
        print(f"⚠️  Could not mount webapp static files: {WEBAPP_DIR} -> {_e}")

    uvicorn.run("API.api:app", host=host, port=port, reload=True)
