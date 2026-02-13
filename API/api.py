import io
import sys
import json
from pathlib import Path
from datetime import datetime

import torch
import numpy as np
from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from typing import List, Optional
from PIL import Image
import librosa
import torchvision.transforms as T


# -------------------------------------------------
# Path setup
# -------------------------------------------------

BASE_DIR = Path(__file__).resolve().parents[1]
if str(BASE_DIR) not in sys.path:
    sys.path.insert(0, str(BASE_DIR))

from dataset.multimodal_model import MultiModalNet


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


# -------------------------------------------------
# Image preprocessing
# -------------------------------------------------

img_transform = T.Compose([
    T.Resize((224, 224)),
    T.ToTensor()
])


# -------------------------------------------------
# FastAPI app
# -------------------------------------------------

app = FastAPI(
    title="Geoacoustic Mineral Fingerprinting API",
    description="Multi-modal mineral classification and fingerprint extraction API",
    version="1.1"
)

# Add CORS middleware to allow Flutter web app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify exact origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# -------------------------------------------------
# Helpers
# -------------------------------------------------

def process_image(file_bytes):

    img = Image.open(io.BytesIO(file_bytes)).convert("RGB")
    img = img_transform(img)
    return img.unsqueeze(0)


def process_audio(file_bytes, sr=16000, n_mfcc=20):

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
                "role": "inspector",
                "created_at": datetime.utcnow().isoformat()
            },
            {
                "id": "2",
                "email": "regulator@example.com",
                "name": "Sarah Regulator",
                "password": "regulator123",
                "role": "regulator",
                "created_at": datetime.utcnow().isoformat()
            },
            {
                "id": "admin",
                "email": "admin@example.com",
                "name": "Admin User",
                "password": "admin123",
                "role": "admin",
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
# Authentication endpoint
# -------------------------------------------------

@app.post("/login")
async def login(email: str = Form(...), password: str = Form(...)):
    """
    Authenticate user with email and password
    """
    try:
        users = load_users()
        
        # Find user by email
        user = None
        for u in users:
            if u['email'].lower() == email.lower():
                user = u
                break
        
        if not user:
            raise HTTPException(status_code=401, detail="Invalid email or password")
        
        # Check password (in production, use proper password hashing)
        if user.get('password') != password:
            raise HTTPException(status_code=401, detail="Invalid email or password")
        
        # Return user info without password
        return {
            "success": True,
            "user": {
                "id": user['id'],
                "email": user['email'],
                "name": user['name'],
                "role": user['role']
            }
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
    image: UploadFile = File(...),
    audio: UploadFile = File(...),

    Au: float = Form(...),
    Cu: float = Form(...),
    Fe: float = Form(...),
    S: float  = Form(...),
    O: float  = Form(...)
):

    try:
        image_bytes = await image.read()
        audio_bytes = await audio.read()

        img = process_image(image_bytes).to(DEVICE)
        aud = process_audio(audio_bytes).to(DEVICE)

        chem = torch.tensor(
            [[Au, Cu, Fe, S, O]],
            dtype=torch.float32
        ).to(DEVICE)

        with torch.no_grad():
            logits = model(img, aud, chem)
            probs = torch.softmax(logits, dim=1)

            pred = probs.argmax(dim=1).item()
            confidence = probs[0, pred].item()

        return {
            "predicted_mineral": MINERAL_LABELS[pred],
            "confidence": round(float(confidence), 4)
        }

    except Exception as e:
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

    # files
    image: UploadFile = File(...),
    audio: UploadFile = File(...),

    # chemistry
    Au: float = Form(...),
    Cu: float = Form(...),
    Fe: float = Form(...),
    S: float  = Form(...),
    O: float  = Form(...)
):

    try:
        image_bytes = await image.read()
        audio_bytes = await audio.read()

        img = process_image(image_bytes).to(DEVICE)
        aud = process_audio(audio_bytes).to(DEVICE)

        chem = torch.tensor(
            [[Au, Cu, Fe, S, O]],
            dtype=torch.float32
        ).to(DEVICE)

        with torch.no_grad():

            f_img  = model.image_enc(img)
            f_aud  = model.audio_enc(aud)
            f_chem = model.chem_enc(chem)

            fused = torch.cat([f_img, f_aud, f_chem], dim=1)

        fingerprint_vector = fused.squeeze(0).cpu().numpy().tolist()

        record = {
            "sample_id": sample_id,
            "site": site,
            "mineral": mineral,
            "chemical": {
                "Au": Au,
                "Cu": Cu,
                "Fe": Fe,
                "S": S,
                "O": O
            },
            "fingerprint_dim": len(fingerprint_vector),
            "fingerprint": fingerprint_vector,
            "timestamp": datetime.utcnow().isoformat()
        }

        save_fingerprint(record)

        return {
            "sample_id": sample_id,
            "site": site,
            "mineral": mineral,
            "fingerprint_dim": len(fingerprint_vector),
            "stored": True
        }

    except Exception as e:
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
            verifications.append({
                "id": r.get("sample_id"),
                "timestamp": r.get("timestamp"),
                "site": r.get("site"),
                "mineral": r.get("mineral"),
                "chemical": r.get("chemical"),
                "status": "verified",
                "confidence": 0.95  # Mock confidence for now
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
        
        # Count by mineral type
        mineral_counts = {}
        site_counts = {}
        
        for r in records:
            mineral = r.get("mineral", "unknown")
            site = r.get("site", "unknown")
            
            mineral_counts[mineral] = mineral_counts.get(mineral, 0) + 1
            site_counts[site] = site_counts.get(site, 0) + 1
        
        return {
            "total_scans": len(records),
            "verified": len(records),  # All stored records are verified
            "not_verified": 0,
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
    role: Optional[str] = Form(None)
):
    """
    Update user information
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
        
        users[user_index]['updated_at'] = datetime.utcnow().isoformat()
        
        save_users(users)
        
        return {
            "success": True,
            "user": users[user_index]
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
        "version": "1.1",
        "endpoints": {
            "POST /predict": "Predict mineral type",
            "POST /fingerprint": "Generate and store fingerprint",
            "GET /fingerprints": "Retrieve fingerprints",
            "GET /verifications": "Retrieve verifications",
            "GET /stats": "Get dashboard statistics",
            "GET /users": "Get all users",
            "POST /users": "Create new user",
            "PUT /users/{id}": "Update user",
            "DELETE /users/{id}": "Delete user"
        }
    }


if __name__ == "__main__":
    import uvicorn
    print("Starting Geoacoustic Mineral Fingerprinting API...")
    print("API running at: http://127.0.0.1:8000")
    print("API docs at: http://127.0.0.1:8000/docs")
    uvicorn.run(app, host="127.0.0.1", port=8000, reload=True)
