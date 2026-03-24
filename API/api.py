import io
import sys
import json
import pickle
import hashlib
import os
import time
from pathlib import Path
from datetime import datetime, timezone, timedelta
from threading import Lock

# CAT (Central Africa Time) is UTC+2
CAT = timezone(timedelta(hours=2))

import torch
import numpy as np
from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from typing import Any, Dict, List, Optional, Tuple
from PIL import Image
import librosa
import torchvision.transforms as T
from torchvision import models
from sklearn.preprocessing import StandardScaler
from pydantic import BaseModel
import csv
from web3 import Web3
from eth_account import Account

try:
    from openai import OpenAI
    OPENAI_AVAILABLE = True
except ImportError:
    OPENAI_AVAILABLE = False

# Email utilities
try:
    from .email_utils import (
        send_registration_confirmation,
        send_admin_approval_notification,
        send_approval_email,
        send_denial_email,
        send_admin_created_account_email,
        send_admin_new_account_notification,
        send_admin_scan_notification,
    )
except ImportError:
    from email_utils import (
        send_registration_confirmation,
        send_admin_approval_notification,
        send_approval_email,
        send_denial_email,
        send_admin_created_account_email,
        send_admin_new_account_notification,
        send_admin_scan_notification,
    )


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
    id_token: Optional[str] = ""
    access_token: Optional[str] = ""
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
AUDIT_CHAIN_DB = LOGS_DIR / "audit_chain.jsonl"

BLOCKCHAIN_ANCHOR_ENABLED = os.getenv("BLOCKCHAIN_ANCHOR_ENABLED", "false").strip().lower() in {"1", "true", "yes", "on"}
BLOCKCHAIN_RPC_URL = os.getenv("BLOCKCHAIN_RPC_URL", "").strip()
BLOCKCHAIN_PRIVATE_KEY = os.getenv("BLOCKCHAIN_PRIVATE_KEY", "").strip()
BLOCKCHAIN_FROM_ADDRESS = os.getenv("BLOCKCHAIN_FROM_ADDRESS", "").strip()
BLOCKCHAIN_EXPLORER_BASE = os.getenv("BLOCKCHAIN_EXPLORER_BASE", "https://amoy.polygonscan.com/tx/").strip()
BLOCKCHAIN_ANCHOR_GAS_LIMIT = int(os.getenv("BLOCKCHAIN_ANCHOR_GAS_LIMIT", "100000") or "100000")
_W3_LOCK = Lock()
_W3_CLIENT: Optional[Web3] = None
_AUDIT_CHAIN_LOCK = Lock()
_NONCE_LOCK = Lock()
_NEXT_NONCE: Optional[int] = None

# Initialize logging
logger = ScanEventLogger(LOGS_DIR)
metrics_calc = MetricsCalculator(fingerprints_file=str(FINGERPRINT_DB))



# NOTE: heavy resources (model, scaler, transforms) are loaded at application
# startup instead of import time to avoid issues with the Uvicorn reload
# mechanism on Windows (multiprocessing spawn + pickling of large objects).
# We'll initialize these globals in the FastAPI startup event below.

model = None
gate_model = None
gate_threshold = 0.5
chem_scaler = None
img_transform = None
multimodal_temperature = 1.0

MINERAL_GATE_MAX_PROB_THRESHOLD = 0.62
MINERAL_GATE_MARGIN_THRESHOLD = 0.18
MINERAL_GATE_ENTROPY_THRESHOLD = 0.80

OOD_CONFIDENCE_THRESHOLD = 0.85
OOD_EMBEDDING_SIM_THRESHOLD = 0.03

AUDIO_OOD_MIN_DURATION_SEC = 0.25
AUDIO_OOD_MIN_RMS = 0.003
AUDIO_OOD_MIN_DYNAMIC_STD = 0.003
AUDIO_OOD_MAX_PEAK = 1.0
AUDIO_OOD_EMBEDDING_SIM_THRESHOLD = 0.05
AUDIO_OOD_MIN_REF_COUNT = 5

REID_SAME_EXACT_THRESHOLD = 0.90
REID_LIKELY_SAME_THRESHOLD = 0.80
REID_SAME_MINERAL_THRESHOLD = 0.65
DUPLICATE_FINGERPRINT_SIM_THRESHOLD = 0.985

IMG_EMBED_DIM = 128
AUDIO_EMBED_DIM = 64
CHEM_EMBED_DIM = 32

# -------------------------------------------------
# Chemical dataset stats (per-mineral means)
# -------------------------------------------------

CHEMICAL_CSV = BASE_DIR / "dataset" / "chemical.csv"
MULTIMODAL_CALIBRATION_JSON = BASE_DIR / "dataset" / "multimodal_calibration.json"
OOD_CONFIG_JSON = BASE_DIR / "dataset" / "ood_config.json"
MINERAL_GATE_MODEL_PATH = BASE_DIR / "dataset" / "mineral_gate_model.pt"
MINERAL_GATE_CONFIG_PATH = BASE_DIR / "dataset" / "mineral_gate_config.json"
chemical_means = {}
chemical_overall_mean = None

DEFAULT_CHEM_SCALER_MEAN = np.array(
    [0.36794582, 0.33860045, 0.9255079, 0.6772009, 0.88036117],
    dtype=np.float64,
)
DEFAULT_CHEM_SCALER_SCALE = np.array(
    [0.48224651, 0.47323375, 0.80984596, 0.94646751, 1.36603357],
    dtype=np.float64,
)


def _build_fitted_fallback_scaler() -> StandardScaler:
    """Create a fitted scaler for inference, using dataset CSV when available."""
    scaler = StandardScaler()

    chem_rows = []
    if CHEMICAL_CSV.exists():
        try:
            with open(CHEMICAL_CSV, newline="", encoding="utf-8") as csvfile:
                reader = csv.DictReader(csvfile)
                for row in reader:
                    try:
                        chem_rows.append([
                            float(row.get("Au", 0.0)),
                            float(row.get("Cu", 0.0)),
                            float(row.get("Fe", 0.0)),
                            float(row.get("S", 0.0)),
                            float(row.get("O", 0.0)),
                        ])
                    except Exception:
                        continue
        except Exception:
            chem_rows = []

    if chem_rows:
        scaler.fit(np.asarray(chem_rows, dtype=np.float64))
        return scaler

    scaler.mean_ = DEFAULT_CHEM_SCALER_MEAN.copy()
    scaler.scale_ = DEFAULT_CHEM_SCALER_SCALE.copy()
    scaler.var_ = np.square(DEFAULT_CHEM_SCALER_SCALE)
    scaler.n_features_in_ = 5
    scaler.n_samples_seen_ = 1
    return scaler


def _validate_scaler_or_raise(scaler: StandardScaler) -> None:
    """Ensure scaler can transform 5 chemical features before serving requests."""
    probe = np.array([[0.0, 0.0, 0.0, 0.0, 0.0]], dtype=np.float64)
    _ = scaler.transform(probe)


def load_ood_thresholds_from_config() -> None:
    """Load OOD thresholds from JSON config when available."""
    global OOD_CONFIDENCE_THRESHOLD, OOD_EMBEDDING_SIM_THRESHOLD
    global AUDIO_OOD_MIN_DURATION_SEC, AUDIO_OOD_MIN_RMS, AUDIO_OOD_MIN_DYNAMIC_STD
    global AUDIO_OOD_MAX_PEAK, AUDIO_OOD_EMBEDDING_SIM_THRESHOLD, AUDIO_OOD_MIN_REF_COUNT

    if not OOD_CONFIG_JSON.exists():
        print(" OOD config file not found. Using in-code defaults")
        return

    try:
        with open(OOD_CONFIG_JSON, "r", encoding="utf-8") as f:
            cfg = json.load(f)

        OOD_CONFIDENCE_THRESHOLD = float(cfg.get("ood_confidence_threshold", OOD_CONFIDENCE_THRESHOLD))
        OOD_EMBEDDING_SIM_THRESHOLD = float(cfg.get("ood_embedding_similarity_threshold", OOD_EMBEDDING_SIM_THRESHOLD))

        AUDIO_OOD_MIN_DURATION_SEC = float(cfg.get("audio_ood_min_duration_sec", AUDIO_OOD_MIN_DURATION_SEC))
        AUDIO_OOD_MIN_RMS = float(cfg.get("audio_ood_min_rms", AUDIO_OOD_MIN_RMS))
        AUDIO_OOD_MIN_DYNAMIC_STD = float(cfg.get("audio_ood_min_dynamic_std", AUDIO_OOD_MIN_DYNAMIC_STD))
        AUDIO_OOD_MAX_PEAK = float(cfg.get("audio_ood_max_peak", AUDIO_OOD_MAX_PEAK))
        AUDIO_OOD_EMBEDDING_SIM_THRESHOLD = float(
            cfg.get("audio_ood_embedding_similarity_threshold", AUDIO_OOD_EMBEDDING_SIM_THRESHOLD)
        )
        AUDIO_OOD_MIN_REF_COUNT = int(cfg.get("audio_ood_min_reference_count", AUDIO_OOD_MIN_REF_COUNT))

        print(f" Loaded OOD config from: {OOD_CONFIG_JSON}")
        print(
            " OOD thresholds: "
            f"conf={OOD_CONFIDENCE_THRESHOLD:.3f}, "
            f"embed_sim={OOD_EMBEDDING_SIM_THRESHOLD:.3f}, "
            f"audio_embed_sim={AUDIO_OOD_EMBEDDING_SIM_THRESHOLD:.3f}"
        )
    except Exception as _e:
        print(f" Failed to load OOD config: {_e}")

def load_chemical_means():
    global chemical_means, chemical_overall_mean
    if not CHEMICAL_CSV.exists():
        chemical_means = {}
        chemical_overall_mean = None
        return

    sums = {}
    counts = {}

    with open(CHEMICAL_CSV, newline='', encoding='utf-8') as csvfile:
        reader = csv.DictReader(csvfile)
        for row in reader:
            mineral = row.get('mineral', '').strip().lower()
            try:
                au = float(row.get('Au', 0.0))
                cu = float(row.get('Cu', 0.0))
                fe = float(row.get('Fe', 0.0))
                s = float(row.get('S', 0.0))
                o = float(row.get('O', 0.0))
            except Exception:
                continue

            if mineral not in sums:
                sums[mineral] = [0.0, 0.0, 0.0, 0.0, 0.0]
                counts[mineral] = 0

            sums[mineral][0] += au
            sums[mineral][1] += cu
            sums[mineral][2] += fe
            sums[mineral][3] += s
            sums[mineral][4] += o
            counts[mineral] += 1

    for mineral, total in sums.items():
        cnt = counts.get(mineral, 1)
        chemical_means[mineral] = [v / cnt for v in total]

    # overall mean across all minerals
    all_totals = [0.0, 0.0, 0.0, 0.0, 0.0]
    all_count = 0
    for mineral, vals in sums.items():
        all_totals = [x + y for x, y in zip(all_totals, vals)]
        all_count += counts.get(mineral, 0)

    if all_count > 0:
        chemical_overall_mean = [v / all_count for v in all_totals]
    else:
        chemical_overall_mean = [0.0, 0.0, 0.0, 0.0, 0.0]


load_chemical_means()


# Image preprocessing and startup banner are configured during app startup


# -------------------------------------------------
# FastAPI app
# -------------------------------------------------

app = FastAPI(
    title="Geoacoustic Mineral Fingerprinting API",
    description="Multi-modal mineral classification and fingerprint extraction API with optional modalities support",
    version="2.0"
)

# Add CORS middleware to allow Flutter web app
allowed_origins_raw = os.getenv("ALLOWED_ORIGINS", "*")
allowed_origins = [origin.strip() for origin in allowed_origins_raw.split(",") if origin.strip()]
if not allowed_origins:
    allowed_origins = ["*"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=("*" not in allowed_origins),
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
# Startup: load heavy resources here (model, scaler, transforms)
# -------------------------------------------------

@app.on_event("startup")
async def startup_event():
    global model, gate_model, gate_threshold, chem_scaler, img_transform, chemical_means, chemical_overall_mean, multimodal_temperature

    print("Loading model and resources...")

    # Load trained model
    try:
        model_local = MultiModalNet(num_classes=3)
        model_path = BASE_DIR / "dataset" / "multimodal_model.pt"
        state = torch.load(model_path, map_location=DEVICE)
        model_local.load_state_dict(state)
        model_local.to(DEVICE)
        model_local.eval()
        model = model_local
        print(f" Model loaded from: {model_path}")
        print(f" Device: {DEVICE}")
    except Exception as _e:
        print(f" Failed to load model: {_e}")
        model = None

    # Load binary mineral gate model (mineral vs non-mineral)
    try:
        gm = models.resnet18(weights=None)
        gm.fc = torch.nn.Linear(gm.fc.in_features, 1)

        gate_checkpoint = torch.load(MINERAL_GATE_MODEL_PATH, map_location=DEVICE)
        if isinstance(gate_checkpoint, dict) and "model_state_dict" in gate_checkpoint:
            gm.load_state_dict(gate_checkpoint["model_state_dict"])
            gate_threshold = float(gate_checkpoint.get("threshold", gate_threshold))
        else:
            gm.load_state_dict(gate_checkpoint)

        if MINERAL_GATE_CONFIG_PATH.exists():
            with open(MINERAL_GATE_CONFIG_PATH, "r", encoding="utf-8") as f:
                gate_cfg = json.load(f)
            gate_threshold = float(gate_cfg.get("threshold", gate_threshold))

        gate_model = gm.to(DEVICE)
        gate_model.eval()
        print(f" Gate model loaded from: {MINERAL_GATE_MODEL_PATH}")
        print(f" Gate threshold: {gate_threshold:.3f}")
    except Exception as _e:
        gate_model = None
        print(f" Failed to load gate model: {_e}")

    # Load chemical scaler (safe fallback if missing)
    try:
        scaler_path = BASE_DIR / "dataset" / "chemical_scaler.pkl"
        if scaler_path.exists():
            with open(scaler_path, "rb") as f:
                chem_scaler = pickle.load(f)
            print(f" Chemical scaler loaded from: {scaler_path}")
        else:
            print(f"  Chemical scaler not found at {scaler_path}")
            print("   Creating fitted fallback scaler...")
            chem_scaler = _build_fitted_fallback_scaler()

        _validate_scaler_or_raise(chem_scaler)
        print(" Chemical scaler validated for inference")
    except Exception as _e:
        print(f" Failed to load/create chemical scaler: {_e}")
        chem_scaler = _build_fitted_fallback_scaler()
        try:
            _validate_scaler_or_raise(chem_scaler)
            print(" Recovered with fitted fallback scaler")
        except Exception as _scaler_e:
            print(f" Fallback scaler validation failed: {_scaler_e}")
            chem_scaler = None

    # Image preprocessing
    img_transform = T.Compose([
        T.Resize((224, 224)),
        T.ToTensor(),
        T.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
    ])
    print(" Image preprocessing configured with ImageNet normalization")

    # Load chemical means from CSV (if present)
    try:
        load_chemical_means()
    except Exception as _e:
        print(f" Failed to load chemical means: {_e}")

    # Load confidence calibration (temperature scaling)
    try:
        if MULTIMODAL_CALIBRATION_JSON.exists():
            with open(MULTIMODAL_CALIBRATION_JSON, "r", encoding="utf-8") as f:
                calibration = json.load(f)
            t = float(calibration.get("temperature", 1.0))
            multimodal_temperature = t if t > 0 else 1.0
            print(f" Loaded multimodal temperature: {multimodal_temperature:.4f}")
        else:
            multimodal_temperature = 1.0
            print(" Multimodal calibration file not found. Using temperature=1.0")
    except Exception as _e:
        multimodal_temperature = 1.0
        print(f" Failed to load multimodal calibration: {_e}")

    # Load tunable OOD thresholds
    load_ood_thresholds_from_config()

    # Check OpenAI configuration for chat assistant
    if OPENAI_AVAILABLE:
        openai_api_key = os.getenv("OPENAI_API_KEY", "").strip()
        if openai_api_key:
            print(" ✓ OpenAI API configured - Chat assistant will use GPT-3.5-turbo")
        else:
            print(" ⚠ OpenAI not configured (OPENAI_API_KEY env var missing) - Chat will use knowledge base fallback")
    else:
        print(" ⚠ OpenAI client not installed - Chat will use knowledge base fallback")
        print("   To enable: pip install openai")

    print("Startup complete")

    


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


def analyze_audio_input(file_bytes, sr=16000, n_mfcc=20) -> Tuple[Optional[torch.Tensor], Dict[str, float | bool | str]]:
    """
    Process audio into MFCC and compute lightweight OOD-oriented quality metrics.
    """
    if file_bytes is None:
        return None, {
            "provided": False,
            "duration_sec": 0.0,
            "rms": 0.0,
            "peak": 0.0,
            "dynamic_std": 0.0,
            "is_structural_ood": False,
            "quality_reason": "no_audio",
        }

    try:
        y, loaded_sr = librosa.load(io.BytesIO(file_bytes), sr=sr, mono=True)
    except Exception:
        return None, {
            "provided": True,
            "duration_sec": 0.0,
            "rms": 0.0,
            "peak": 0.0,
            "dynamic_std": 0.0,
            "is_structural_ood": True,
            "quality_reason": "audio_decode_failed",
        }

    duration_sec = float(len(y) / max(1, loaded_sr))
    rms = float(np.sqrt(np.mean(np.square(y)))) if y.size > 0 else 0.0
    peak = float(np.max(np.abs(y))) if y.size > 0 else 0.0
    dynamic_std = float(np.std(y)) if y.size > 0 else 0.0

    structural_ood = False
    quality_reason = "ok"
    if duration_sec < AUDIO_OOD_MIN_DURATION_SEC:
        structural_ood = True
        quality_reason = "too_short"
    elif rms < AUDIO_OOD_MIN_RMS:
        structural_ood = True
        quality_reason = "too_silent"
    elif dynamic_std < AUDIO_OOD_MIN_DYNAMIC_STD:
        structural_ood = True
        quality_reason = "low_dynamic_range"
    elif peak >= AUDIO_OOD_MAX_PEAK:
        structural_ood = True
        quality_reason = "possible_clipping"

    mfcc = librosa.feature.mfcc(y=y, sr=loaded_sr, n_mfcc=n_mfcc)
    mfcc = (mfcc - mfcc.mean()) / (mfcc.std() + 1e-8)
    tensor = torch.tensor(mfcc, dtype=torch.float32).unsqueeze(0)

    return tensor, {
        "provided": True,
        "duration_sec": round(duration_sec, 4),
        "rms": round(rms, 6),
        "peak": round(peak, 6),
        "dynamic_std": round(dynamic_std, 6),
        "is_structural_ood": bool(structural_ood),
        "quality_reason": quality_reason,
    }


def evaluate_mineral_gate(probs_tensor: torch.Tensor) -> dict:
    """
    Decide whether input looks like a mineral sample using softmax behavior.
    Returns gate metrics and decision.
    """
    probs = probs_tensor.squeeze(0).detach().cpu().numpy().astype(np.float64)

    if probs.size == 0:
        return {
            "is_mineral": False,
            "gate_confidence": 0.0,
            "max_probability": 0.0,
            "margin": 0.0,
            "normalized_entropy": 1.0,
        }

    sorted_probs = np.sort(probs)[::-1]
    max_prob = float(sorted_probs[0])
    second_prob = float(sorted_probs[1]) if len(sorted_probs) > 1 else 0.0
    margin = max_prob - second_prob

    safe_probs = np.clip(probs, 1e-12, 1.0)
    entropy = float(-np.sum(safe_probs * np.log(safe_probs)) / np.log(len(safe_probs)))

    gate_confidence = float(
        (0.6 * max_prob) +
        (0.3 * margin) +
        (0.1 * (1.0 - entropy))
    )

    is_mineral = (
        max_prob >= MINERAL_GATE_MAX_PROB_THRESHOLD and
        margin >= MINERAL_GATE_MARGIN_THRESHOLD and
        entropy <= MINERAL_GATE_ENTROPY_THRESHOLD
    )

    return {
        "is_mineral": bool(is_mineral),
        "gate_confidence": round(gate_confidence, 4),
        "max_probability": round(max_prob, 4),
        "margin": round(margin, 4),
        "normalized_entropy": round(entropy, 4),
    }


def apply_temperature(logits: torch.Tensor) -> torch.Tensor:
    temperature = multimodal_temperature if multimodal_temperature > 0 else 1.0
    return logits / temperature


def evaluate_binary_gate(image_tensor: Optional[torch.Tensor]) -> Dict[str, float | bool]:
    """
    Run trained binary gate model when image is available.
    Returns gate decision and confidence score.
    """
    if image_tensor is None or gate_model is None:
        return {
            "enabled": False,
            "is_mineral": True,
            "gate_probability": 1.0,
            "threshold": float(gate_threshold),
        }

    with torch.no_grad():
        logits = gate_model(image_tensor)
        prob_mineral = float(torch.sigmoid(logits).view(-1)[0].item())

    return {
        "enabled": True,
        "is_mineral": prob_mineral >= float(gate_threshold),
        "gate_probability": round(prob_mineral, 4),
        "threshold": float(gate_threshold),
    }


def cosine_similarity(vec_a: List[float], vec_b: List[float]) -> float:
    a = np.asarray(vec_a, dtype=np.float64)
    b = np.asarray(vec_b, dtype=np.float64)

    if a.size == 0 or b.size == 0 or a.shape != b.shape:
        return 0.0

    denom = float(np.linalg.norm(a) * np.linalg.norm(b))
    if denom <= 1e-12:
        return 0.0

    return float(np.dot(a, b) / denom)


def split_fingerprint_vector(vector: List[float]) -> Dict[str, np.ndarray]:
    arr = np.asarray(vector, dtype=np.float64)
    expected_dim = IMG_EMBED_DIM + AUDIO_EMBED_DIM + CHEM_EMBED_DIM
    if arr.size < expected_dim:
        return {
            "image": np.asarray([], dtype=np.float64),
            "audio": np.asarray([], dtype=np.float64),
            "chemical": np.asarray([], dtype=np.float64),
            "full": arr,
        }

    img_end = IMG_EMBED_DIM
    aud_end = IMG_EMBED_DIM + AUDIO_EMBED_DIM

    return {
        "image": arr[:img_end],
        "audio": arr[img_end:aud_end],
        "chemical": arr[aud_end:aud_end + CHEM_EMBED_DIM],
        "full": arr,
    }


def reid_similarity_shape_tolerant(
    query_vector: List[float],
    reference_vector: List[float],
    modalities_used: Optional[Dict[str, bool]] = None,
) -> Dict[str, float]:
    """
    Shape-tolerant similarity that emphasizes chemistry over image geometry.
    This helps when the same mineral is broken/melted and visual texture changes.
    """
    query_parts = split_fingerprint_vector(query_vector)
    ref_parts = split_fingerprint_vector(reference_vector)

    image_sim = cosine_similarity(query_parts["image"].tolist(), ref_parts["image"].tolist())
    audio_sim = cosine_similarity(query_parts["audio"].tolist(), ref_parts["audio"].tolist())
    chem_sim = cosine_similarity(query_parts["chemical"].tolist(), ref_parts["chemical"].tolist())
    full_sim = cosine_similarity(query_parts["full"].tolist(), ref_parts["full"].tolist())

    has_image = bool((modalities_used or {}).get("image", True))
    has_audio = bool((modalities_used or {}).get("audio", False))
    has_chemical = bool((modalities_used or {}).get("chemical", True))

    # Base weights are chemistry-heavy to be robust against shape change.
    base_weights = {
        "image": 0.20,
        "audio": 0.20,
        "chemical": 0.60,
    }

    active = []
    if has_image:
        active.append("image")
    if has_audio:
        active.append("audio")
    if has_chemical:
        active.append("chemical")

    if not active:
        weighted = full_sim
    else:
        total_w = sum(base_weights[k] for k in active)
        weighted = 0.0
        for k in active:
            wk = base_weights[k] / total_w
            if k == "image":
                weighted += wk * image_sim
            elif k == "audio":
                weighted += wk * audio_sim
            else:
                weighted += wk * chem_sim

    final_score = 0.7 * weighted + 0.3 * full_sim

    return {
        "final": float(final_score),
        "weighted": float(weighted),
        "full": float(full_sim),
        "image": float(image_sim),
        "audio": float(audio_sim),
        "chemical": float(chem_sim),
    }


def compute_class_centroids(records: List[dict]) -> Dict[str, List[float]]:
    grouped: Dict[str, List[np.ndarray]] = {}

    for record in records:
        vector = record.get("fingerprint")
        if not isinstance(vector, list) or not vector:
            continue

        label = (
            str(record.get("predicted_mineral") or record.get("mineral") or "")
            .strip()
            .lower()
        )
        if not label:
            continue

        grouped.setdefault(label, []).append(np.asarray(vector, dtype=np.float64))

    centroids: Dict[str, List[float]] = {}
    for label, vectors in grouped.items():
        if not vectors:
            continue
        stacked = np.stack(vectors, axis=0)
        centroids[label] = np.mean(stacked, axis=0).astype(np.float64).tolist()

    return centroids


def compute_audio_embedding_similarity(
    query_vector: List[float],
    records: List[dict],
) -> Dict[str, float | int]:
    """
    Compare query audio embedding against stored audio-enabled references.
    """
    query_audio = split_fingerprint_vector(query_vector)["audio"]
    if query_audio.size == 0 or float(np.linalg.norm(query_audio)) <= 1e-12:
        return {
            "max_similarity": 0.0,
            "mean_similarity": 0.0,
            "reference_count": 0,
        }

    sims: List[float] = []
    for record in records:
        vector = record.get("fingerprint")
        if not isinstance(vector, list) or not vector:
            continue

        has_audio_flag = bool((record.get("modalities_used") or {}).get("audio", False))
        ref_audio = split_fingerprint_vector(vector)["audio"]
        if ref_audio.size == 0:
            continue
        if float(np.linalg.norm(ref_audio)) <= 1e-12:
            continue

        # Keep backward compatibility: if modality flags are missing, rely on non-zero audio slice.
        if not has_audio_flag and "modalities_used" in record:
            continue

        sim = cosine_similarity(query_audio.tolist(), ref_audio.tolist())
        sims.append(float(sim))

    if not sims:
        return {
            "max_similarity": 0.0,
            "mean_similarity": 0.0,
            "reference_count": 0,
        }

    return {
        "max_similarity": float(max(sims)),
        "mean_similarity": float(sum(sims) / len(sims)),
        "reference_count": int(len(sims)),
    }


def compute_sample_mean_vectors(records: List[dict], target_mineral: Optional[str] = None) -> Dict[str, List[float]]:
    grouped: Dict[str, List[np.ndarray]] = {}
    target = (target_mineral or "").strip().lower()

    for record in records:
        vector = record.get("fingerprint")
        if not isinstance(vector, list) or not vector:
            continue

        sample_id = str(record.get("sample_id") or "").strip()
        if not sample_id:
            continue

        if target:
            rec_label = str(record.get("predicted_mineral") or record.get("mineral") or "").strip().lower()
            if rec_label and rec_label != target:
                continue

        grouped.setdefault(sample_id, []).append(np.asarray(vector, dtype=np.float64))

    means: Dict[str, List[float]] = {}
    for sample_id, vectors in grouped.items():
        if not vectors:
            continue
        stacked = np.stack(vectors, axis=0)
        means[sample_id] = np.mean(stacked, axis=0).astype(np.float64).tolist()

    return means


def describe_reid_similarity(similarity_score: float) -> Dict[str, object]:
    if similarity_score >= REID_SAME_EXACT_THRESHOLD:
        return {"status": "same_exact_sample", "is_same_sample": True}
    if similarity_score >= REID_LIKELY_SAME_THRESHOLD:
        return {"status": "likely_same_sample", "is_same_sample": False}
    if similarity_score >= REID_SAME_MINERAL_THRESHOLD:
        return {"status": "same_mineral_different_sample", "is_same_sample": False}
    return {"status": "different_or_unknown", "is_same_sample": False}


def save_fingerprint(record: dict):
    """
    Store each fingerprint as one JSON line
    """
    sample_id = str(record.get("sample_id") or "").strip()
    if sample_id and find_fingerprint_by_sample_id(sample_id):
        raise ValueError(f"Duplicate sample_id '{sample_id}' is not allowed")

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


def load_audit_chain() -> List[dict]:
    """
    Load blockchain-style audit blocks from JSONL ledger.
    """
    if not AUDIT_CHAIN_DB.exists():
        return []

    records = []
    with open(AUDIT_CHAIN_DB, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                records.append(json.loads(line))
            except json.JSONDecodeError:
                continue
    return records


def save_audit_chain(records: List[dict]) -> None:
    """
    Persist blockchain-style audit blocks as JSONL.
    """
    AUDIT_CHAIN_DB.parent.mkdir(parents=True, exist_ok=True)
    with _AUDIT_CHAIN_LOCK:
        with open(AUDIT_CHAIN_DB, "w", encoding="utf-8") as f:
            for record in records:
                f.write(json.dumps(record) + "\n")


def compute_audit_hash(block_payload: dict) -> str:
    canonical = json.dumps(block_payload, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


def append_audit_event(
    event_type: str,
    action: str,
    actor: str = "system",
    details: Optional[Dict[str, Any]] = None,
    source: str = "api",
    timestamp: Optional[str] = None,
) -> dict:
    """
    Append one immutable hash-chained audit block to ledger.
    """
    existing = load_audit_chain()
    previous = existing[-1] if existing else None

    block_index = int(previous.get("block_index", 0)) + 1 if previous else 1
    previous_hash = str(previous.get("hash") or "GENESIS") if previous else "GENESIS"
    ts_value = str(timestamp).strip() if timestamp is not None else ""
    block_timestamp = ts_value if ts_value else datetime.now(CAT).isoformat()

    payload = {
        "block_index": block_index,
        "timestamp": block_timestamp,
        "event_type": str(event_type or "system"),
        "action": str(action or "event"),
        "actor": str(actor or "system"),
        "source": str(source or "api"),
        "details": details or {},
        "previous_hash": previous_hash,
    }
    block_hash = compute_audit_hash(payload)

    block = {
        **payload,
        "hash": block_hash,
    }

    anchor_result = anchor_audit_block_hash(block)
    block.update(anchor_result)

    AUDIT_CHAIN_DB.parent.mkdir(parents=True, exist_ok=True)
    with open(AUDIT_CHAIN_DB, "a", encoding="utf-8") as f:
        f.write(json.dumps(block) + "\n")

    return block


def record_audit_event(
    event_type: str,
    action: str,
    actor: str = "system",
    details: Optional[Dict[str, Any]] = None,
    source: str = "api",
) -> None:
    """
    Safe wrapper that never interrupts primary API flow.
    """
    try:
        append_audit_event(
            event_type=event_type,
            action=action,
            actor=actor,
            details=details,
            source=source,
        )
    except Exception as audit_error:
        logger.log_error(audit_error, {"endpoint": "audit_chain_append", "action": action})


def _get_blockchain_client() -> Web3:
    global _W3_CLIENT

    if _W3_CLIENT is not None:
        return _W3_CLIENT

    if not BLOCKCHAIN_RPC_URL:
        raise ValueError("Missing BLOCKCHAIN_RPC_URL")

    with _W3_LOCK:
        if _W3_CLIENT is None:
            client = Web3(Web3.HTTPProvider(BLOCKCHAIN_RPC_URL, request_kwargs={"timeout": 30}))
            if not client.is_connected():
                raise RuntimeError("Could not connect to blockchain RPC provider")
            _W3_CLIENT = client

    return _W3_CLIENT


def _reset_cached_nonce() -> None:
    global _NEXT_NONCE
    with _NONCE_LOCK:
        _NEXT_NONCE = None


def _reserve_next_nonce(w3: Web3, sender: str) -> int:
    global _NEXT_NONCE

    with _NONCE_LOCK:
        pending_nonce = int(w3.eth.get_transaction_count(sender, "pending"))
        if _NEXT_NONCE is None or _NEXT_NONCE < pending_nonce:
            _NEXT_NONCE = pending_nonce

        nonce = _NEXT_NONCE
        _NEXT_NONCE += 1
        return nonce


def _is_retryable_nonce_error(exc: Exception) -> bool:
    message = str(exc).lower()
    return (
        "nonce too low" in message
        or "could not replace existing tx" in message
        or "replacement transaction underpriced" in message
        or "already known" in message
    )


def anchor_audit_block_hash(block: Dict[str, Any], include_bootstrap: bool = False) -> Dict[str, Any]:
    """
    Optionally anchor the audit block hash on-chain and return metadata.
    This never raises; failures are returned as status fields.
    """
    default_result = {
        "anchor_enabled": BLOCKCHAIN_ANCHOR_ENABLED,
        "anchor_status": "disabled",
        "anchor_tx_hash": None,
        "anchor_chain_id": None,
        "anchor_explorer_url": None,
        "anchor_error": None,
    }

    if not BLOCKCHAIN_ANCHOR_ENABLED:
        return default_result

    source = str(block.get("source") or "").strip().lower()
    if source.startswith("bootstrap") and not include_bootstrap:
        return {
            "anchor_enabled": True,
            "anchor_status": "skipped_bootstrap",
            "anchor_tx_hash": None,
            "anchor_chain_id": None,
            "anchor_explorer_url": None,
            "anchor_error": None,
        }

    try:
        private_key = BLOCKCHAIN_PRIVATE_KEY
        configured_from = BLOCKCHAIN_FROM_ADDRESS
        if not private_key:
            raise ValueError("Missing BLOCKCHAIN_PRIVATE_KEY")
        if not configured_from:
            raise ValueError("Missing BLOCKCHAIN_FROM_ADDRESS")

        w3 = _get_blockchain_client()
        sender = Account.from_key(private_key).address
        if sender.lower() != configured_from.lower():
            raise ValueError("BLOCKCHAIN_FROM_ADDRESS does not match private key")

        block_index = block.get("block_index")
        block_hash = str(block.get("hash") or "")
        block_timestamp = str(block.get("timestamp") or "")
        payload_text = f"audit-block|{block_index}|{block_hash}|{block_timestamp}"
        payload_hex = "0x" + payload_text.encode("utf-8").hex()

        chain_id = int(w3.eth.chain_id)
        last_error: Optional[Exception] = None

        for attempt in range(2):
            try:
                nonce = _reserve_next_nonce(w3, sender)
                gas_price = int(w3.eth.gas_price)
                tx = {
                    "chainId": chain_id,
                    "nonce": nonce,
                    "to": sender,
                    "value": 0,
                    "gas": int(BLOCKCHAIN_ANCHOR_GAS_LIMIT),
                    "gasPrice": gas_price,
                    "data": payload_hex,
                }

                signed = w3.eth.account.sign_transaction(tx, private_key=private_key)
                tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction).hex()
                return {
                    "anchor_enabled": True,
                    "anchor_status": "submitted",
                    "anchor_tx_hash": tx_hash,
                    "anchor_chain_id": chain_id,
                    "anchor_explorer_url": f"{BLOCKCHAIN_EXPLORER_BASE}{tx_hash}",
                    "anchor_error": None,
                }
            except Exception as exc:
                last_error = exc
                if attempt == 0 and _is_retryable_nonce_error(exc):
                    _reset_cached_nonce()
                    time.sleep(0.4)
                    continue
                raise

        raise last_error if last_error is not None else RuntimeError("Unknown blockchain anchor failure")
    except Exception as exc:
        return {
            "anchor_enabled": True,
            "anchor_status": "failed",
            "anchor_tx_hash": None,
            "anchor_chain_id": None,
            "anchor_explorer_url": None,
            "anchor_error": str(exc),
        }


@app.post("/audit-trail/anchor-missing")
async def anchor_missing_audit_entries(
    limit: int = 25,
    include_bootstrap: bool = False,
    retry_failed: bool = True,
):
    """
    Anchor missing audit events to the configured blockchain in controlled batches.
    """
    try:
        records = load_audit_chain()
        if not records:
            return {
                "status": "success",
                "message": "No audit records found",
                "processed": 0,
                "submitted": 0,
                "failed": 0,
                "skipped": 0,
                "remaining": 0,
                "updated_blocks": [],
            }

        requested_limit = max(1, int(limit or 25))
        batch_limit = min(requested_limit, 100)

        candidate_indices: List[int] = []
        for idx, block in enumerate(records):
            tx_hash = str(block.get("anchor_tx_hash") or "").strip()
            if tx_hash:
                continue

            source = str(block.get("source") or "").strip().lower()
            if source.startswith("bootstrap") and not include_bootstrap:
                continue

            anchor_status = str(block.get("anchor_status") or "").strip().lower()
            if anchor_status == "failed" and not retry_failed:
                continue

            candidate_indices.append(idx)

        target_indices = candidate_indices[:batch_limit]
        submitted = 0
        failed = 0
        skipped = 0
        updated_blocks: List[Dict[str, Any]] = []

        for idx in target_indices:
            block = records[idx]
            anchor_result = anchor_audit_block_hash(block, include_bootstrap=include_bootstrap)
            block.update(anchor_result)

            status = str(anchor_result.get("anchor_status") or "").strip().lower()
            if status == "submitted":
                submitted += 1
            elif status.startswith("skipped"):
                skipped += 1
            else:
                failed += 1

            updated_blocks.append({
                "block_index": block.get("block_index"),
                "anchor_status": block.get("anchor_status"),
                "anchor_tx_hash": block.get("anchor_tx_hash"),
                "anchor_error": block.get("anchor_error"),
            })

            # Basic pacing to reduce RPC throttling risk on public endpoints.
            time.sleep(0.2)

        if target_indices:
            save_audit_chain(records)

        remaining = max(0, len(candidate_indices) - len(target_indices))
        return {
            "status": "success",
            "processed": len(target_indices),
            "submitted": submitted,
            "failed": failed,
            "skipped": skipped,
            "remaining": remaining,
            "batch_limit": batch_limit,
            "total_candidates": len(candidate_indices),
            "include_bootstrap": include_bootstrap,
            "retry_failed": retry_failed,
            "last_updated": datetime.now(CAT).isoformat(),
            "updated_blocks": updated_blocks,
        }
    except Exception as e:
        logger.log_error(e, {"endpoint": "/audit-trail/anchor-missing"})
        raise HTTPException(status_code=500, detail=str(e))


def verify_audit_chain(records: List[dict]) -> Dict[str, Any]:
    """
    Verify integrity of blockchain-style hash chain.
    """
    if not records:
        return {
            "is_valid": True,
            "checked_blocks": 0,
            "invalid_block_index": None,
            "reason": None,
        }

    expected_previous_hash = "GENESIS"
    for idx, block in enumerate(records, start=1):
        payload = {
            "block_index": block.get("block_index"),
            "timestamp": block.get("timestamp"),
            "event_type": block.get("event_type"),
            "action": block.get("action"),
            "actor": block.get("actor"),
            "source": block.get("source"),
            "details": block.get("details") or {},
            "previous_hash": block.get("previous_hash"),
        }
        expected_hash = compute_audit_hash(payload)
        actual_hash = str(block.get("hash") or "")
        previous_hash = str(block.get("previous_hash") or "")

        if previous_hash != expected_previous_hash:
            return {
                "is_valid": False,
                "checked_blocks": idx,
                "invalid_block_index": block.get("block_index", idx),
                "reason": "previous_hash_mismatch",
            }
        if actual_hash != expected_hash:
            return {
                "is_valid": False,
                "checked_blocks": idx,
                "invalid_block_index": block.get("block_index", idx),
                "reason": "hash_mismatch",
            }

        expected_previous_hash = actual_hash

    return {
        "is_valid": True,
        "checked_blocks": len(records),
        "invalid_block_index": None,
        "reason": None,
    }


def parse_event_timestamp(value: Optional[str]) -> datetime:
    if not value:
        return datetime.now(CAT)
    text = str(value).strip()
    if not text:
        return datetime.now(CAT)
    try:
        if text.endswith("Z"):
            text = text[:-1] + "+00:00"
        return datetime.fromisoformat(text)
    except Exception:
        return datetime.now(CAT)


def bootstrap_audit_chain_from_existing_data(force: bool = False) -> Dict[str, Any]:
    """
    Build audit blockchain from existing fingerprints and users.
    """
    existing_chain = load_audit_chain()
    if existing_chain and not force:
        return {
            "bootstrapped": False,
            "reason": "already_initialized",
            "inserted_events": 0,
        }

    if force:
        AUDIT_CHAIN_DB.parent.mkdir(parents=True, exist_ok=True)
        with open(AUDIT_CHAIN_DB, "w", encoding="utf-8") as f:
            f.write("")

    timeline: List[Dict[str, Any]] = []

    for record in load_fingerprints():
        ts = str(record.get("timestamp") or datetime.now(CAT).isoformat())
        actor = str(record.get("user_name") or record.get("user_id") or "system")
        timeline.append({
            "timestamp": ts,
            "event_type": "scan",
            "action": "fingerprint_stored_legacy",
            "actor": actor,
            "source": "bootstrap.fingerprint",
            "details": {
                "sample_id": record.get("sample_id"),
                "site": record.get("site"),
                "claimed_mineral": record.get("mineral"),
                "predicted_mineral": record.get("predicted_mineral"),
                "confidence": record.get("confidence"),
                "status": record.get("status"),
                "backfilled": True,
            },
        })

    for user in load_users():
        created_at = user.get("created_at")
        if created_at:
            timeline.append({
                "timestamp": str(created_at),
                "event_type": "user",
                "action": "user_created_legacy",
                "actor": "system",
                "source": "bootstrap.users",
                "details": {
                    "user_id": user.get("id"),
                    "email": user.get("email"),
                    "role": user.get("role"),
                    "approval_status": user.get("approval_status"),
                    "backfilled": True,
                },
            })

        updated_at = user.get("updated_at")
        if updated_at:
            timeline.append({
                "timestamp": str(updated_at),
                "event_type": "user",
                "action": "user_updated_legacy",
                "actor": "system",
                "source": "bootstrap.users",
                "details": {
                    "user_id": user.get("id"),
                    "email": user.get("email"),
                    "role": user.get("role"),
                    "backfilled": True,
                },
            })

    timeline.sort(key=lambda event: parse_event_timestamp(event.get("timestamp")))

    append_audit_event(
        event_type="system",
        action="audit_chain_bootstrap",
        actor="system",
        details={
            "source_records": {
                "fingerprints": len(load_fingerprints()),
                "users": len(load_users()),
            },
            "backfilled_events": len(timeline),
        },
        source="bootstrap",
        timestamp=(timeline[0].get("timestamp") if timeline else datetime.now(CAT).isoformat()),
    )

    inserted = 1
    for event in timeline:
        append_audit_event(
            event_type=event["event_type"],
            action=event["action"],
            actor=event["actor"],
            details=event["details"],
            source=event["source"],
            timestamp=event["timestamp"],
        )
        inserted += 1

    return {
        "bootstrapped": True,
        "reason": "initialized_from_existing_data",
        "inserted_events": inserted,
    }


def find_fingerprint_by_sample_id(sample_id: str) -> Optional[dict]:
    """
    Return the first stored fingerprint record matching sample_id.
    """
    target = str(sample_id or "").strip()
    if not target:
        return None

    for record in load_fingerprints():
        if str(record.get("sample_id") or "").strip() == target:
            return record
    return None


def find_similar_fingerprint(
    query_vector: List[float],
    records: List[dict],
    similarity_threshold: float = DUPLICATE_FINGERPRINT_SIM_THRESHOLD,
) -> Optional[Dict[str, object]]:
    """
    Return the best-matching stored fingerprint when similarity crosses threshold.
    """
    best_match = None
    best_similarity = 0.0

    for record in records:
        vector = record.get("fingerprint")
        if not isinstance(vector, list) or not vector:
            continue

        similarity = cosine_similarity(query_vector, vector)
        if similarity > best_similarity:
            best_similarity = similarity
            best_match = record

    if best_match and best_similarity >= float(similarity_threshold):
        return {
            "record": best_match,
            "similarity": float(best_similarity),
        }

    return None


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
                "created_at": datetime.now(CAT).isoformat()
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
                "created_at": datetime.now(CAT).isoformat()
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
                "created_at": datetime.now(CAT).isoformat()
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
            "created_at": datetime.now(CAT).isoformat(),
            "photo_url": None
        }
        
        users.append(new_user)
        save_users(users)

        persisted_user = next((u for u in users if u.get('id') == user_id), new_user)

        record_audit_event(
            event_type="user",
            action="auth_register_pending",
            actor=request.email,
            details={
                "user_id": user_id,
                "role": request.role,
                "organization": request.organization,
            },
            source="auth.register",
        )
        
        # Step 1: Send confirmation email to user
        user_notification_sent = False
        try:
            user_notification_sent = bool(
                send_registration_confirmation(
                    persisted_user.get('name', request.name),
                    persisted_user.get('email', request.email),
                )
            )
            if not user_notification_sent:
                logger.log_error(
                    Exception("Registration user email returned False"),
                    {
                        "endpoint": "/api/auth/register",
                        "email": persisted_user.get('email', request.email),
                        "phase": "send_registration_confirmation",
                    },
                )
        except Exception as email_error:
            logger.log_error(
                email_error,
                {
                    "endpoint": "/api/auth/register",
                    "email": persisted_user.get('email', request.email),
                    "phase": "send_registration_confirmation",
                },
            )

        # Step 2: Get all pending users and notify admin
        admin_notification_sent = False
        pending_users = [u for u in users if u.get('approval_status') == 'pending']
        if pending_users:
            try:
                admin_notification_sent = bool(
                    send_admin_approval_notification(len(pending_users), pending_users)
                )
                if not admin_notification_sent:
                    logger.log_error(
                        Exception("Registration admin email returned False"),
                        {
                            "endpoint": "/api/auth/register",
                            "email": persisted_user.get('email', request.email),
                            "phase": "send_admin_approval_notification",
                            "pending_count": len(pending_users),
                        },
                    )
            except Exception as email_error:
                logger.log_error(
                    email_error,
                    {
                        "endpoint": "/api/auth/register",
                        "email": persisted_user.get('email', request.email),
                        "phase": "send_admin_approval_notification",
                        "pending_count": len(pending_users),
                    },
                )
        
        return {
            "success": True,
            "message": "Registration successful. Check your email for confirmation. Awaiting admin approval.",
            "notifications": {
                "user_email_sent": user_notification_sent,
                "admin_email_sent": admin_notification_sent,
            },
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

            record_audit_event(
                event_type="auth",
                action="google_signin",
                actor=request.email,
                details={
                    "user_id": existing_user.get("id"),
                    "existing_user": True,
                },
                source="auth.google",
            )
            
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
                "created_at": datetime.now(CAT).isoformat(),
                "photo_url": request.photo_url,
                "auth_provider": "google"
            }
            
            users.append(new_user)
            save_users(users)

            persisted_user = next((u for u in users if u.get('id') == user_id), new_user)

            record_audit_event(
                event_type="user",
                action="google_register_pending",
                actor=request.email,
                details={
                    "user_id": user_id,
                    "role": "operator",
                },
                source="auth.google",
            )

            # Send confirmation email to user and notify admin
            user_notification_sent = False
            try:
                user_notification_sent = bool(
                    send_registration_confirmation(
                        persisted_user.get('name', request.name),
                        persisted_user.get('email', request.email),
                    )
                )
                if not user_notification_sent:
                    logger.log_error(
                        Exception("Google registration user email returned False"),
                        {
                            "endpoint": "/api/auth/google",
                            "email": persisted_user.get('email', request.email),
                            "phase": "send_registration_confirmation",
                        },
                    )
            except Exception as email_error:
                logger.log_error(
                    email_error,
                    {
                        "endpoint": "/api/auth/google",
                        "email": persisted_user.get('email', request.email),
                        "phase": "send_registration_confirmation",
                    },
                )

            admin_notification_sent = False
            pending_users = [u for u in users if u.get('approval_status') == 'pending']
            if pending_users:
                try:
                    admin_notification_sent = bool(
                        send_admin_approval_notification(len(pending_users), pending_users)
                    )
                    if not admin_notification_sent:
                        logger.log_error(
                            Exception("Google registration admin email returned False"),
                            {
                                "endpoint": "/api/auth/google",
                                "email": persisted_user.get('email', request.email),
                                "phase": "send_admin_approval_notification",
                                "pending_count": len(pending_users),
                            },
                        )
                except Exception as email_error:
                    logger.log_error(
                        email_error,
                        {
                            "endpoint": "/api/auth/google",
                            "email": persisted_user.get('email', request.email),
                            "phase": "send_admin_approval_notification",
                            "pending_count": len(pending_users),
                        },
                    )
            
            return {
                "success": True,
                "message": "Registration successful. Awaiting admin approval.",
                "notifications": {
                    "user_email_sent": user_notification_sent,
                    "admin_email_sent": admin_notification_sent,
                },
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
        
        user = None
        for u in users:
            if u['id'] == request.user_id:
                user = u
                u['approval_status'] = 'approved'
                u['approved_at'] = datetime.now(CAT).isoformat()
                break
        
        if user is None:
            raise HTTPException(status_code=404, detail="User not found")
        
        save_users(users)
        
        # Send approval email to user
        approval_email_sent = False
        try:
            approval_email_sent = bool(send_approval_email(user['name'], user['email']))
            if not approval_email_sent:
                logger.log_error(
                    Exception("Approval email returned False"),
                    {
                        "endpoint": "/api/admin/approve-user",
                        "user_id": user.get("id"),
                        "email": user.get("email"),
                        "phase": "send_approval_email",
                    },
                )
        except Exception as email_error:
            logger.log_error(
                email_error,
                {
                    "endpoint": "/api/admin/approve-user",
                    "user_id": user.get("id"),
                    "email": user.get("email"),
                    "phase": "send_approval_email",
                },
            )

        record_audit_event(
            event_type="user",
            action="admin_approved_user",
            actor="admin",
            details={
                "user_id": user.get("id"),
                "email": user.get("email"),
                "status": "approved",
            },
            source="admin.approve-user",
        )
        
        return {
            "success": True,
            "message": "User approved successfully.",
            "notification": {
                "email_sent": approval_email_sent,
                "email": user.get("email"),
            },
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
        
        user = None
        for u in users:
            if u['id'] == request.user_id:
                user = u
                u['approval_status'] = 'denied'
                u['denied_at'] = datetime.now(CAT).isoformat()
                u['denied_reason'] = request.reason or "No reason provided"
                break
        
        if user is None:
            raise HTTPException(status_code=404, detail="User not found")
        
        save_users(users)
        
        # Send denial email to user
        denial_email_sent = False
        try:
            denial_email_sent = bool(
                send_denial_email(user['name'], user['email'], request.reason or "")
            )
            if not denial_email_sent:
                logger.log_error(
                    Exception("Denial email returned False"),
                    {
                        "endpoint": "/api/admin/deny-user",
                        "user_id": user.get("id"),
                        "email": user.get("email"),
                        "phase": "send_denial_email",
                    },
                )
        except Exception as email_error:
            logger.log_error(
                email_error,
                {
                    "endpoint": "/api/admin/deny-user",
                    "user_id": user.get("id"),
                    "email": user.get("email"),
                    "phase": "send_denial_email",
                },
            )

        record_audit_event(
            event_type="user",
            action="admin_denied_user",
            actor="admin",
            details={
                "user_id": user.get("id"),
                "email": user.get("email"),
                "reason": request.reason or "No reason provided",
                "status": "denied",
            },
            source="admin.deny-user",
        )
        
        return {
            "success": True,
            "message": "User denied successfully.",
            "notification": {
                "email_sent": denial_email_sent,
                "email": user.get("email"),
            },
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

    # Make chemical inputs optional. If missing, we'll fallback to dataset-derived means
    Au: Optional[float] = Form(None),
    Cu: Optional[float] = Form(None),
    Fe: Optional[float] = Form(None),
    S: Optional[float]  = Form(None),
    O: Optional[float]  = Form(None)
):
    """
    Predict mineral type from multimodal inputs
    Now supports optional modalities: image and audio can be None
    At least one modality (image or audio) must be provided
    """
    try:
        if image is None and audio is None:
            raise HTTPException(
                status_code=400,
                detail="At least one modality (image or audio) must be provided"
            )

        image_bytes = await image.read() if image else None
        audio_bytes = await audio.read() if audio else None

        img = process_image(image_bytes)
        aud, audio_quality = analyze_audio_input(audio_bytes)

        if img is None and aud is None:
            raise HTTPException(
                status_code=400,
                detail="Could not decode any valid modality from inputs (image/audio)."
            )

        if img is not None:
            img = img.to(DEVICE)
        if aud is not None:
            aud = aud.to(DEVICE)

        binary_gate = evaluate_binary_gate(img)
        if not bool(binary_gate["is_mineral"]):
            return {
                "is_mineral": False,
                "predicted_mineral": "unknown",
                "prediction": "unknown",
                "confidence": round(float(binary_gate["gate_probability"]), 4),
                "probabilities": {},
                "ood_status": "unknown",
                "max_embedding_similarity": 0.0,
                "similarity_score": 0.0,
                "centroid_similarities": {},
                "is_same_sample": False,
                "matched_sample_id": None,
                "reid_status": "unavailable_for_ood",
                "gate_confidence": round(float(binary_gate["gate_probability"]), 4),
                "gate_metrics": {
                    "binary_gate_enabled": bool(binary_gate["enabled"]),
                    "binary_gate_probability": round(float(binary_gate["gate_probability"]), 4),
                    "binary_gate_threshold": round(float(binary_gate["threshold"]), 4),
                },
                "rejection_reason": "Rejected by mineral gate (non-mineral detected).",
                "modalities_used": {
                    "image": img is not None,
                    "audio": aud is not None,
                    "chemical": False,
                },
                "chemical_used": {
                    "Au": None,
                    "Cu": None,
                    "Fe": None,
                    "S": None,
                    "O": None,
                },
            }

        with torch.no_grad():
            logits_init = model(image=img, audio=None, chemical=None)
            logits_init = apply_temperature(logits_init)
            probs_init = torch.softmax(logits_init, dim=1)
            pred_init = probs_init.argmax(dim=1).item()

        predicted_label_init = MINERAL_LABELS.get(pred_init, "").lower()
        mean_for_pred = chemical_means.get(predicted_label_init, chemical_overall_mean)
        if mean_for_pred is None:
            mean_for_pred = [0.0, 0.0, 0.0, 0.0, 0.0]

        used_chem = [
            mean_for_pred[0],
            mean_for_pred[1],
            mean_for_pred[2],
            mean_for_pred[3],
            mean_for_pred[4],
        ]

        chem_raw = np.array([used_chem])
        if chem_scaler is None:
            raise HTTPException(status_code=500, detail="Chemical scaler is not initialized on server startup")
        try:
            chem_normalized = chem_scaler.transform(chem_raw)
        except Exception as scaler_error:
            raise HTTPException(status_code=500, detail=f"Chemical scaler is not ready for inference: {scaler_error}")
        chem_tensor = torch.tensor(chem_normalized, dtype=torch.float32).to(DEVICE)

        with torch.no_grad():
            logits = model(image=img, audio=aud, chemical=chem_tensor)
            logits = apply_temperature(logits)
            probs = torch.softmax(logits, dim=1)
            pred = probs.argmax(dim=1).item()
            confidence = probs[0, pred].item()
            fingerprint_tensor, modalities_used = model.extract_fingerprint(
                image=img,
                audio=aud,
                chemical=chem_tensor,
            )

        predicted_mineral = MINERAL_LABELS[pred]
        probabilities_final = {
            MINERAL_LABELS[idx]: round(float(probs[0, idx].item()), 4)
            for idx in range(len(MINERAL_LABELS))
        }

        fingerprint_vector = fingerprint_tensor.squeeze(0).detach().cpu().numpy().astype(np.float64).tolist()
        records = load_fingerprints()
        class_centroids = compute_class_centroids(records)

        centroid_similarities = {
            mineral: round(cosine_similarity(fingerprint_vector, centroid), 4)
            for mineral, centroid in class_centroids.items()
        }
        max_embedding_similarity = max(centroid_similarities.values()) if centroid_similarities else 0.0
        predicted_centroid_similarity = centroid_similarities.get(predicted_mineral.lower(), 0.0)

        audio_embed_metrics = compute_audio_embedding_similarity(fingerprint_vector, records) if aud is not None else {
            "max_similarity": 0.0,
            "mean_similarity": 0.0,
            "reference_count": 0,
        }
        audio_max_similarity = float(audio_embed_metrics["max_similarity"])
        audio_ref_count = int(audio_embed_metrics["reference_count"])
        audio_quality_ood = bool(audio_quality.get("is_structural_ood", False)) if aud is not None else False
        audio_similarity_ood = (
            aud is not None and
            audio_ref_count >= AUDIO_OOD_MIN_REF_COUNT and
            audio_max_similarity < AUDIO_OOD_EMBEDDING_SIM_THRESHOLD
        )
        audio_ood = bool(audio_quality_ood or audio_similarity_ood)

        is_ood = (
            float(confidence) < OOD_CONFIDENCE_THRESHOLD or
            float(max_embedding_similarity) < OOD_EMBEDDING_SIM_THRESHOLD or
            audio_ood
        )
        ood_status = "unknown" if is_ood else "known"

        gate = evaluate_mineral_gate(probs)
        gate_confidence = round(
            float((gate["gate_confidence"] + max_embedding_similarity) / 2.0),
            4,
        )

        if is_ood:
            rejection_reason = "Input rejected as unknown/non-mineral-like by OOD rules."
            if audio_ood:
                rejection_reason = "Input rejected by audio OOD checks (out-of-domain or low-quality audio)."
            return {
                "is_mineral": False,
                "predicted_mineral": "unknown",
                "prediction": "unknown",
                "confidence": round(float(confidence), 4),
                "probabilities": probabilities_final,
                "ood_status": ood_status,
                "max_embedding_similarity": round(float(max_embedding_similarity), 4),
                "similarity_score": round(float(max_embedding_similarity), 4),
                "centroid_similarities": centroid_similarities,
                "is_same_sample": False,
                "matched_sample_id": None,
                "reid_status": "unavailable_for_ood",
                "gate_confidence": gate_confidence,
                "gate_metrics": {
                    "confidence": round(float(confidence), 4),
                    "max_probability": gate["max_probability"],
                    "margin": gate["margin"],
                    "normalized_entropy": gate["normalized_entropy"],
                    "max_embedding_similarity": round(float(max_embedding_similarity), 4),
                    "audio_ood": audio_ood,
                    "audio_quality_ood": audio_quality_ood,
                    "audio_similarity_ood": audio_similarity_ood,
                    "audio_embedding_similarity": round(float(audio_max_similarity), 4),
                    "audio_reference_count": audio_ref_count,
                },
                "audio_ood": audio_ood,
                "audio_quality": audio_quality,
                "audio_embedding_similarity": round(float(audio_max_similarity), 4),
                "audio_reference_count": audio_ref_count,
                "rejection_reason": rejection_reason,
                "modalities_used": modalities_used,
                "chemical_used": {
                    "Au": used_chem[0],
                    "Cu": used_chem[1],
                    "Fe": used_chem[2],
                    "S": used_chem[3],
                    "O": used_chem[4],
                },
            }

        sample_means = compute_sample_mean_vectors(records, target_mineral=predicted_mineral)
        best_sample_id = None
        best_similarity = 0.0

        best_similarity_components = {
            "final": 0.0,
            "weighted": 0.0,
            "full": 0.0,
            "image": 0.0,
            "audio": 0.0,
            "chemical": 0.0,
        }

        for sample_id, sample_vec in sample_means.items():
            sim_components = reid_similarity_shape_tolerant(
                query_vector=fingerprint_vector,
                reference_vector=sample_vec,
                modalities_used=modalities_used,
            )
            sim = float(sim_components["final"])
            if sim > best_similarity:
                best_similarity = sim
                best_sample_id = sample_id
                best_similarity_components = sim_components

        reid_info = describe_reid_similarity(best_similarity)

        logger.log_model_prediction(
            predicted_mineral=predicted_mineral,
            confidence=confidence,
            modalities=modalities_used
        )

        return {
            "is_mineral": True,
            "predicted_mineral": predicted_mineral,
            "prediction": predicted_mineral,
            "confidence": round(float(confidence), 4),
            "probabilities": probabilities_final,
            "ood_status": ood_status,
            "max_embedding_similarity": round(float(max_embedding_similarity), 4),
            "similarity_score": round(float(best_similarity), 4),
            "similarity_components": {
                "shape_tolerant_weighted": round(float(best_similarity_components["weighted"]), 4),
                "full_fingerprint": round(float(best_similarity_components["full"]), 4),
                "image": round(float(best_similarity_components["image"]), 4),
                "audio": round(float(best_similarity_components["audio"]), 4),
                "chemical": round(float(best_similarity_components["chemical"]), 4),
            },
            "predicted_class_centroid_similarity": round(float(predicted_centroid_similarity), 4),
            "centroid_similarities": centroid_similarities,
            "is_same_sample": bool(reid_info["is_same_sample"]),
            "matched_sample_id": best_sample_id,
            "reid_status": reid_info["status"] if best_sample_id else "no_reference_sample",
            "gate_confidence": gate_confidence,
            "audio_ood": audio_ood,
            "audio_quality": audio_quality,
            "audio_embedding_similarity": round(float(audio_max_similarity), 4),
            "audio_reference_count": audio_ref_count,
            "modalities_used": modalities_used,
            "chemical_used": {
                "Au": used_chem[0],
                "Cu": used_chem[1],
                "Fe": used_chem[2],
                "S": used_chem[3],
                "O": used_chem[4],
            },
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.log_error(e, {"endpoint": "/predict"})
        raise HTTPException(status_code=500, detail=str(e))


# -------------------------------------------------
# Verification endpoint (new)
# -------------------------------------------------

@app.post("/verify")
async def verify(
    image: Optional[UploadFile] = File(None),
    audio: Optional[UploadFile] = File(None),
    
    # chemistry fields
    Au: Optional[float] = Form(None),
    Cu: Optional[float] = Form(None),
    Fe: Optional[float] = Form(None),
    S: Optional[float]  = Form(None),
    O: Optional[float]  = Form(None),
    
    # allow direct lookup by fingerprint id
    fingerprint_id: Optional[str] = Form(None)
):
    """
    Verify a sample either by providing a known fingerprint ID or by
    submitting new modalities/chemical data.  The mobile client currently
    sends only `fingerprint_id` or `chemical` values, so this endpoint
    must exist to avoid 404 errors.

    For now we implement a simple lookup when `fingerprint_id` is given
    and otherwise return a placeholder response indicating verification is
    unavailable.  In future this could compute a full vector similarity
    against the fingerprint database.
    """
    try:
        # direct ID lookup
        if fingerprint_id:
            records = load_fingerprints()
            match = None
            for r in records:
                # sample_id is used as the primary key when storing
                if r.get("sample_id") == fingerprint_id or r.get("fingerprint_id") == fingerprint_id:
                    match = r
                    break

            if match:
                admin_notified = False
                try:
                    admin_notified = bool(
                        send_admin_scan_notification(
                            sample_id=str(match.get("sample_id") or fingerprint_id),
                            site=str(match.get("site") or "Unknown"),
                            mineral=str(match.get("mineral") or match.get("predicted_mineral") or "unknown"),
                            predicted_mineral=str(match.get("predicted_mineral") or "unknown"),
                            confidence=float(match.get("confidence") or 1.0),
                            status=str(match.get("status") or "verified"),
                            user_name=str(match.get("user_name") or "unknown"),
                            user_id=str(match.get("user_id") or "unknown"),
                            scanned_at=str(match.get("timestamp") or datetime.now(CAT).isoformat()),
                        )
                    )
                    if not admin_notified:
                        logger.log_error(
                            Exception("Admin scan email returned False on /verify (fingerprint_id)"),
                            {
                                "endpoint": "/verify",
                                "fingerprint_id": fingerprint_id,
                                "phase": "send_admin_scan_notification",
                            },
                        )
                except Exception as email_error:
                    logger.log_error(
                        email_error,
                        {
                            "endpoint": "/verify",
                            "fingerprint_id": fingerprint_id,
                            "phase": "send_admin_scan_notification",
                        },
                    )
                return {
                    "is_authentic": True,
                    "match_score": 1.0,
                    "matched_fingerprint_id": fingerprint_id,
                    "message": "Fingerprint record found",
                    "details": match,
                    "admin_notified": admin_notified,
                }
            else:
                # not found -> still 200 so client can handle gracefully
                return {
                    "is_authentic": False,
                    "match_score": 0.0,
                    "message": "Fingerprint ID not found",
                }

        # if chemical data provided, attempt a direct lookup against
        # stored records by comparing the five-element vector. this is a
        # very basic approach but gives the client something useful.
        if Au is not None and Cu is not None and Fe is not None and S is not None and O is not None:
            records = load_fingerprints()
            for r in records:
                chem = r.get("chemical") or {}
                try:
                    cAu = float(chem.get("Au", 0.0))
                    cCu = float(chem.get("Cu", 0.0))
                    cFe = float(chem.get("Fe", 0.0))
                    cS = float(chem.get("S", 0.0))
                    cO = float(chem.get("O", 0.0))
                except Exception:
                    continue
                if (abs(cAu - Au) < 1e-6 and
                    abs(cCu - Cu) < 1e-6 and
                    abs(cFe - Fe) < 1e-6 and
                    abs(cS - S) < 1e-6 and
                    abs(cO - O) < 1e-6):
                    admin_notified = False
                    try:
                        admin_notified = bool(
                            send_admin_scan_notification(
                                sample_id=str(r.get("sample_id") or "chemical-match"),
                                site=str(r.get("site") or "Unknown"),
                                mineral=str(r.get("mineral") or r.get("predicted_mineral") or "unknown"),
                                predicted_mineral=str(r.get("predicted_mineral") or "unknown"),
                                confidence=float(r.get("confidence") or 1.0),
                                status=str(r.get("status") or "verified"),
                                user_name=str(r.get("user_name") or "unknown"),
                                user_id=str(r.get("user_id") or "unknown"),
                                scanned_at=str(r.get("timestamp") or datetime.now(CAT).isoformat()),
                            )
                        )
                        if not admin_notified:
                            logger.log_error(
                                Exception("Admin scan email returned False on /verify (chemical match)"),
                                {
                                    "endpoint": "/verify",
                                    "phase": "send_admin_scan_notification",
                                    "sample_id": str(r.get("sample_id") or "chemical-match"),
                                },
                            )
                    except Exception as email_error:
                        logger.log_error(
                            email_error,
                            {
                                "endpoint": "/verify",
                                "phase": "send_admin_scan_notification",
                                "sample_id": str(r.get("sample_id") or "chemical-match"),
                            },
                        )
                    return {
                        "is_authentic": True,
                        "match_score": 1.0,
                        "matched_fingerprint_id": r.get("sample_id"),
                        "message": "Exact chemical match",
                        "details": r,
                        "admin_notified": admin_notified,
                    }
            # no exact match found
            return {
                "is_authentic": False,
                "match_score": 0.0,
                "message": "No matching chemical composition found",
            }

        # fallback if we reach here (shouldn't happen)
        return {
            "is_authentic": False,
            "match_score": 0.0,
            "message": "Verification not implemented for provided inputs",
        }
    except Exception as e:
        # log and convert to HTTP exception
        logger.log_error(e, {"endpoint": "/verify"})
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
    Au: Optional[float] = Form(None),
    Cu: Optional[float] = Form(None),
    Fe: Optional[float] = Form(None),
    S: Optional[float]  = Form(None),
    O: Optional[float]  = Form(None),
    
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
        existing_record = find_fingerprint_by_sample_id(sample_id)
        if existing_record:
            record_audit_event(
                event_type="scan",
                action="fingerprint_rejected_duplicate_sample_id",
                actor=user_name or user_id or "unknown",
                details={
                    "sample_id": sample_id,
                    "site": site,
                    "mineral": mineral,
                },
                source="fingerprint",
            )
            raise HTTPException(
                status_code=409,
                detail=(
                    f"Duplicate sample_id '{sample_id}' detected. "
                    "This ID already exists and cannot be stored again."
                ),
            )

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
        aud, audio_quality = analyze_audio_input(audio_bytes)

        if img is None and aud is None:
            raise HTTPException(
                status_code=400,
                detail="Could not decode any valid modality from inputs (image/audio)."
            )

        if aud is not None:
            # Enforce same audio OOD policy at storage time to keep DB clean.
            if bool(audio_quality.get("is_structural_ood", False)):
                raise HTTPException(
                    status_code=400,
                    detail=f"Audio rejected by quality checks: {audio_quality.get('quality_reason', 'invalid_audio')}"
                )
        
        if img is not None:
            img = img.to(DEVICE)
        if aud is not None:
            aud = aud.to(DEVICE)

        # If chemical inputs missing, do initial prediction with overall mean,
        # then use predicted mineral's dataset mean to extract fingerprint.

        initial_chem = chemical_overall_mean or [0.0, 0.0, 0.0, 0.0, 0.0]
        all_provided = None not in (Au, Cu, Fe, S, O)

        def run_model(chem_values):
            chem_raw = np.array([chem_values])
            if chem_scaler is None:
                raise HTTPException(status_code=500, detail="Chemical scaler is not initialized on server startup")
            try:
                chem_normalized = chem_scaler.transform(chem_raw)
            except Exception as scaler_error:
                raise HTTPException(status_code=500, detail=f"Chemical scaler is not ready for inference: {scaler_error}")
            chem_tensor = torch.tensor(chem_normalized, dtype=torch.float32).to(DEVICE)
            with torch.no_grad():
                fingerprint_tensor, modalities_used = model.extract_fingerprint(
                    image=img, audio=aud, chemical=chem_tensor
                )
                logits = model(image=img, audio=aud, chemical=chem_tensor)
                logits = apply_temperature(logits)
                probs = torch.softmax(logits, dim=1)
                pred_idx = probs.argmax(dim=1).item()
                confidence_val = probs[0, pred_idx].item()
            return fingerprint_tensor, modalities_used, pred_idx, confidence_val

        # For fingerprint endpoint: initial predict using image only
        # (we already have img and aud variables in scope)
        # We'll use the same approach: predict with image only, then use per-mineral mean
        # chemistry to extract the fingerprint.

        _, _, pred_init, _ = run_model(initial_chem)
        predicted_label_init = MINERAL_LABELS.get(pred_init, '').lower()
        mean_for_pred = chemical_means.get(predicted_label_init, chemical_overall_mean)
        if mean_for_pred is None:
            mean_for_pred = [0.0, 0.0, 0.0, 0.0, 0.0]

        used_chem = [
            mean_for_pred[0],
            mean_for_pred[1],
            mean_for_pred[2],
            mean_for_pred[3],
            mean_for_pred[4],
        ]

        fingerprint_tensor, modalities_used, pred, confidence = run_model(used_chem)

        fingerprint_vector = fingerprint_tensor.squeeze(0).cpu().numpy().tolist()
        predicted_mineral = MINERAL_LABELS[pred]

        records = load_fingerprints()

        if aud is not None:
            audio_embed_metrics = compute_audio_embedding_similarity(fingerprint_vector, records)
            audio_max_similarity = float(audio_embed_metrics.get("max_similarity", 0.0))
            audio_ref_count = int(audio_embed_metrics.get("reference_count", 0))
            if (
                audio_ref_count >= AUDIO_OOD_MIN_REF_COUNT and
                audio_max_similarity < AUDIO_OOD_EMBEDDING_SIM_THRESHOLD
            ):
                raise HTTPException(
                    status_code=400,
                    detail=(
                        "Audio rejected as out-of-domain by embedding similarity "
                        f"(sim={audio_max_similarity:.4f}, refs={audio_ref_count})."
                    ),
                )

        duplicate_match = find_similar_fingerprint(
            query_vector=fingerprint_vector,
            records=records,
        )
        if duplicate_match:
            matched_record = duplicate_match["record"]
            matched_sample_id = str(matched_record.get("sample_id") or "unknown")
            similarity_score = float(duplicate_match["similarity"])
            record_audit_event(
                event_type="scan",
                action="fingerprint_rejected_duplicate_content",
                actor=user_name or user_id or "unknown",
                details={
                    "sample_id": sample_id,
                    "matched_sample_id": matched_sample_id,
                    "similarity": round(similarity_score, 6),
                    "site": site,
                    "mineral": mineral,
                },
                source="fingerprint",
            )
            raise HTTPException(
                status_code=409,
                detail=(
                    f"Duplicate fingerprint detected (similarity={similarity_score:.4f}) "
                    f"to existing sample_id '{matched_sample_id}'."
                ),
            )
        
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
            "audio_quality": audio_quality,
            "modalities_used": modalities_used,
            "fingerprint_dim": len(fingerprint_vector),
            "fingerprint": fingerprint_vector,
            "timestamp": datetime.now(CAT).isoformat()
        }
        
        # Add GPS coordinates if provided
        if latitude is not None and longitude is not None:
            record["gps"] = {
                "latitude": round(latitude, 6),
                "longitude": round(longitude, 6)
            }

        save_fingerprint(record)

        admin_notified = False
        try:
            admin_notified = bool(send_admin_scan_notification(
                sample_id=sample_id,
                site=site,
                mineral=mineral,
                predicted_mineral=predicted_mineral,
                confidence=float(confidence),
                status=status,
                user_name=user_name,
                user_id=user_id,
                scanned_at=record["timestamp"],
            ))
            if not admin_notified:
                logger.log_error(
                    Exception("Admin scan email returned False on /fingerprint"),
                    {
                        "endpoint": "/fingerprint",
                        "sample_id": sample_id,
                        "phase": "send_admin_scan_notification",
                    },
                )
        except Exception as email_error:
            logger.log_error(
                email_error,
                {
                    "endpoint": "/fingerprint",
                    "sample_id": sample_id,
                    "phase": "send_admin_scan_notification",
                },
            )

        record_audit_event(
            event_type="scan",
            action="fingerprint_stored",
            actor=user_name or user_id or "unknown",
            details={
                "sample_id": sample_id,
                "site": site,
                "claimed_mineral": mineral,
                "predicted_mineral": predicted_mineral,
                "confidence": round(float(confidence), 4),
                "status": status,
            },
            source="fingerprint",
        )
        
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
            "stored": True,
            "admin_notified": admin_notified,
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
    password: str = Form(...),  # In production, hash the password
    organization: Optional[str] = Form(None)
):
    """
    Create a new user
    """
    try:
        users = load_users()
        
        # Check if email already exists (case-insensitive)
        normalized_email = email.strip().lower()
        if any(u.get('email', '').strip().lower() == normalized_email for u in users):
            raise HTTPException(status_code=400, detail="Email already exists")
        
        # Generate new user ID
        new_id = str(max([int(u['id']) if u['id'].isdigit() else 0 for u in users]) + 1)
        
        new_user = {
            "id": new_id,
            "email": normalized_email,
            "name": name.strip(),
            "password": password,  # In production, hash this
            "role": role.lower(),
            "organization": organization.strip() if organization else None,
            "approval_status": "approved",
            "photo_url": None,
            "created_at": datetime.now(CAT).isoformat()
        }
        
        users.append(new_user)
        save_users(users)

        record_audit_event(
            event_type="user",
            action="admin_created_user",
            actor="admin",
            details={
                "user_id": new_id,
                "email": normalized_email,
                "role": role.lower(),
            },
            source="users.create",
        )

        # Notify the newly created user that their account is active
        send_admin_created_account_email(new_user['name'], new_user['email'])
        # Notify admin that an account was created directly by admin action
        send_admin_new_account_notification(
            new_user['name'],
            new_user['email'],
            created_by="admin",
            approval_status="approved",
        )
        
        user_data = {k: v for k, v in new_user.items() if k != 'password'}

        return {
            "success": True,
            "user": user_data
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
        
        users[user_index]['updated_at'] = datetime.now(CAT).isoformat()
        updated_user = users[user_index]
        
        save_users(users)

        record_audit_event(
            event_type="user",
            action="admin_updated_user",
            actor="admin",
            details={
                "user_id": user_id,
                "email": updated_user.get("email"),
                "role": updated_user.get("role"),
            },
            source="users.update",
        )
        
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
    organization: Optional[str] = Form(None),
    photo_url: Optional[str] = Form(None),
    remove_photo: Optional[str] = Form(None),
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
            users[user_index]['name'] = name.strip()
        if email:
            normalized_email = email.strip().lower()
            # Check if new email already exists for another user
            if any(u.get('email', '').strip().lower() == normalized_email and u['id'] != user_id for u in users):
                raise HTTPException(status_code=400, detail="Email already exists")
            users[user_index]['email'] = normalized_email
        if organization is not None:
            users[user_index]['organization'] = organization.strip() if organization.strip() else None

        remove_photo_flag = str(remove_photo).lower() in ["1", "true", "yes", "on"] if remove_photo is not None else False
        if remove_photo_flag:
            users[user_index]['photo_url'] = None
        elif photo_url is not None:
            users[user_index]['photo_url'] = photo_url.strip() if photo_url.strip() else None
        
        users[user_index]['updated_at'] = datetime.now(CAT).isoformat()
        updated_user = users[user_index]
        
        save_users(users)

        record_audit_event(
            event_type="user",
            action="profile_updated",
            actor=updated_user.get("email") or user_id,
            details={
                "user_id": user_id,
                "name": updated_user.get("name"),
                "organization": updated_user.get("organization"),
            },
            source="profile.update",
        )
        
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
                deleted_user = {
                    "id": u.get("id"),
                    "email": u.get("email"),
                    "name": u.get("name"),
                    "role": u.get("role"),
                }
                users.pop(i)
                user_found = True
                break
        
        if not user_found:
            raise HTTPException(status_code=404, detail="User not found")
        
        save_users(users)

        record_audit_event(
            event_type="user",
            action="admin_deleted_user",
            actor="admin",
            details={
                "user_id": deleted_user.get("id"),
                "email": deleted_user.get("email"),
                "name": deleted_user.get("name"),
                "role": deleted_user.get("role"),
            },
            source="users.delete",
        )
        
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
            "GET /audit-trail/chain": "Get blockchain-backed audit trail",
            "POST /audit-trail/backfill": "Backfill blockchain audit trail from existing records",
            "POST /audit-trail/anchor-missing": "Anchor missing audit blocks to chain in controlled batches",
            "GET /analytics/realtime": "Get live analytics payload for dashboard charts",
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


def build_live_analytics_payload(records: List[dict]) -> Dict[str, object]:
    labels = [name.lower() for name in MINERAL_LABELS.values()]

    if not records:
        return {
            "status": "no_data",
            "message": "No verification data available yet",
            "last_updated": datetime.now(CAT).isoformat(),
            "refresh_seconds": 15,
            "total_samples": 0,
            "samples_with_predictions": 0,
            "accuracy": 0.0,
            "macro_precision": 0.0,
            "macro_recall": 0.0,
            "macro_f1": 0.0,
            "overall_metrics": {
                "accuracy": 0.0,
                "macro_precision": 0.0,
                "macro_recall": 0.0,
                "macro_f1_score": 0.0,
                "macro_fpr": 0.0,
                "avg_confidence": 0.0,
            },
            "per_class_metrics": {},
            "modality_usage": {},
            "confidence_distribution": {
                "labels": ["0-20%", "20-40%", "40-60%", "60-80%", "80-100%"],
                "bins": [0, 0, 0, 0, 0],
            },
            "pipeline": {
                "fingerprint_records": 0,
                "data_source": str(FINGERPRINT_DB),
            },
        }

    valid_records = []
    for record in records:
        claimed = str(record.get("mineral") or "").strip().lower()
        predicted = str(record.get("predicted_mineral") or "").strip().lower()
        if claimed and predicted:
            valid_records.append(record)

    metrics_raw = metrics_calc.calculate_metrics()
    overall = metrics_raw.get("overall_metrics", {}) if isinstance(metrics_raw, dict) else {}
    per_raw = metrics_raw.get("per_class_metrics", {}) if isinstance(metrics_raw, dict) else {}

    normalized_per_class: Dict[str, Dict[str, object]] = {}
    for mineral in labels:
        raw = per_raw.get(mineral, {}) if isinstance(per_raw, dict) else {}
        tp = int(raw.get("true_positives", 0) or 0)
        fp = int(raw.get("false_positives", 0) or 0)
        fn = int(raw.get("false_negatives", 0) or 0)
        tn = int(raw.get("true_negatives", 0) or 0)
        support = tp + fn
        total = tp + tn + fp + fn
        class_accuracy = (tp + tn) / total if total > 0 else 0.0

        normalized_per_class[mineral] = {
            "support": support,
            "accuracy": round(float(class_accuracy), 4),
            "precision": round(float(raw.get("precision", 0.0) or 0.0), 4),
            "recall": round(float(raw.get("recall", 0.0) or 0.0), 4),
            "f1_score": round(float(raw.get("f1_score", 0.0) or 0.0), 4),
            "fpr": round(float(raw.get("fpr", 0.0) or 0.0), 4),
            "specificity": round(float(raw.get("specificity", 0.0) or 0.0), 4),
            "true_positive": tp,
            "false_positive": fp,
            "false_negative": fn,
            "true_positives": tp,
            "false_positives": fp,
            "false_negatives": fn,
            "true_negatives": tn,
        }

    modality_usage: Dict[str, int] = {}
    for record in records:
        mods = record.get("modalities_used", {})
        if not isinstance(mods, dict) or not mods:
            continue
        active = [k for k, v in mods.items() if bool(v)]
        if not active:
            continue
        key = "+".join(active)
        modality_usage[key] = modality_usage.get(key, 0) + 1

    confidence_bins = [0, 0, 0, 0, 0]
    for record in valid_records:
        confidence = record.get("confidence")
        if confidence is None:
            continue
        try:
            conf = float(confidence)
        except Exception:
            continue
        conf = max(0.0, min(1.0, conf))
        bucket = min(int(conf * 5), 4)
        confidence_bins[bucket] += 1

    return {
        "status": "success",
        "last_updated": datetime.now(CAT).isoformat(),
        "refresh_seconds": 15,
        "total_samples": len(records),
        "samples_with_predictions": len(valid_records),
        "accuracy": round(float(overall.get("accuracy", 0.0) or 0.0), 4),
        "macro_precision": round(float(overall.get("macro_precision", 0.0) or 0.0), 4),
        "macro_recall": round(float(overall.get("macro_recall", 0.0) or 0.0), 4),
        "macro_f1": round(float(overall.get("macro_f1_score", 0.0) or 0.0), 4),
        "overall_metrics": overall,
        "per_class_metrics": normalized_per_class,
        "modality_usage": modality_usage,
        "confidence_distribution": {
            "labels": ["0-20%", "20-40%", "40-60%", "60-80%", "80-100%"],
            "bins": confidence_bins,
        },
        "pipeline": {
            "fingerprint_records": len(records),
            "data_source": str(FINGERPRINT_DB),
        },
    }


@app.get("/analytics/realtime")
async def get_analytics_realtime():
    """
    Real-time analytics payload for the dashboard.
    Reads latest fingerprint records and computes live metrics.
    """
    try:
        records = load_fingerprints()
        return build_live_analytics_payload(records)
    except Exception as e:
        logger.log_error(e, {"endpoint": "/analytics/realtime"})
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/audit-trail/chain")
async def get_audit_trail_chain(limit: Optional[int] = 200, auto_backfill: bool = True):
    """
    Return blockchain-style audit ledger with integrity verification.
    """
    try:
        records = load_audit_chain()
        backfill_info = {
            "bootstrapped": False,
            "reason": "not_required",
            "inserted_events": 0,
        }

        if auto_backfill and not records:
            backfill_info = bootstrap_audit_chain_from_existing_data(force=False)
            records = load_audit_chain()

        verification = verify_audit_chain(records)

        ordered = sorted(records, key=lambda x: x.get("block_index", 0), reverse=True)
        if limit and limit > 0:
            ordered = ordered[:limit]

        return {
            "status": "success",
            "chain_valid": bool(verification.get("is_valid", False)),
            "integrity": verification,
            "total_events": len(records),
            "returned_events": len(ordered),
            "latest_block_hash": records[-1].get("hash") if records else None,
            "genesis_hash": records[0].get("hash") if records else None,
            "last_updated": datetime.now(CAT).isoformat(),
            "backfill": backfill_info,
            "blocks": ordered,
        }
    except Exception as e:
        logger.log_error(e, {"endpoint": "/audit-trail/chain"})
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/audit-trail/backfill")
async def backfill_audit_trail(force: bool = False):
    """
    Manually rebuild blockchain audit trail from existing records.
    """
    try:
        result = bootstrap_audit_chain_from_existing_data(force=force)
        records = load_audit_chain()
        verification = verify_audit_chain(records)
        return {
            "status": "success",
            "result": result,
            "total_events": len(records),
            "chain_valid": bool(verification.get("is_valid", False)),
            "integrity": verification,
            "last_updated": datetime.now(CAT).isoformat(),
        }
    except Exception as e:
        logger.log_error(e, {"endpoint": "/audit-trail/backfill"})
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/metrics")
async def get_metrics():
    """
    Backward-compatible metrics endpoint.
    Returns the same live analytics payload used by /analytics/realtime.
    """
    try:
        records = load_fingerprints()
        return build_live_analytics_payload(records)
    
    except Exception as e:
        logger.log_error(e, {"endpoint": "/metrics"})
        raise HTTPException(status_code=500, detail=str(e))


# -------------------------------------------------
# AI Chat Assistant endpoints
# -------------------------------------------------

# Knowledge base for different features
CHAT_KNOWLEDGE_BASE = {
    "scanning": {
        "title": "How to Perform a Scan",
        "description": "Guide on using the mineral scanning feature",
        "tips": [
            "Make sure the mineral sample is clean and dry",
            "Take a clear, well-lit photograph from directly above",
            "Try to include audio from the mineral when possible for better accuracy",
            "If you have chemical analysis data, include it for more precise results",
            "The system works best with natural lighting",
        ],
        "help": """To perform a scan:
1. Navigate to the Scanner screen
2. Take a photo of your mineral sample in good lighting
3. Optionally record a short audio clip (5-30 seconds)
4. Enter chemical composition if available (Au, Cu, Fe, S, O percentages)
5. Press 'Scan' to analyze the sample

The AI will identify the mineral type and provide confidence scores.""",
    },
    "results": {
        "title": "Understanding Scan Results",
        "description": "How to interpret scan result metrics",
        "tips": [
            "Confidence Score shows how certain the AI is (higher is better)",
            "Look at the probability distribution for all possible minerals",
            "The Mineral Gate indicates if this is actually a mineral",
            "OOD Status shows if the sample is known or unknown",
            "Similarity Score measures how similar this is to stored samples",
        ],
        "help": """Scan Result Meanings:
- Confidence: 0-100% - How certain the AI is about the identification
- Probabilities: Likelihood of each mineral type
- Mineral Gate: Passed = mineral detected, Rejected = not a mineral
- OOD Status: Known = recognized mineral, Unknown = out-of-distribution
- Similarity Score: How similar to previously scanned samples
- Re-ID Status: Whether it matches a previously scanned sample

Higher confidence (>80%) results are more reliable.""",
    },
    "verification": {
        "title": "Verifying Samples",
        "description": "How to verify and authenticate mineral samples",
        "tips": [
            "Verification uses the stored fingerprint database",
            "More detailed scans provide better verification accuracy",
            "Multiple modalities (image + audio) improve results",
            "Chemical data helps confirm mineral identity",
        ],
        "help": """Verification Process:
1. After getting a scan result, tap 'Verify'
2. The system compares to stored mineral fingerprints
3. It calculates a match score against known samples
4. Higher match scores indicate better authentication

Verification statuses:
- Verified: Matches known sample (>80% confidence)
- Not Verified: Differs from known samples
- Pending: Needs more analysis""",
    },
    "chemical": {
        "title": "Chemical Composition Data",
        "description": "How to use and understand chemical data",
        "tips": [
            "Chemical elements can be Au (Gold), Cu (Copper), Fe (Iron), S (Sulfur), O (Oxygen)",
            "Values should be percentages or atomic percentages",
            "Not all elements may be present in every mineral",
            "Chemical data helps disambiguate visually similar minerals",
        ],
        "help": """Chemical Composition Guide:
- Au (Aurum/Gold): Often found in gold minerals
- Cu (Copper): Common in copper minerals and sulfides
- Fe (Iron): Present in many iron-bearing minerals
- S (Sulfur): Key component of sulfide minerals
- O (Oxygen): Found in oxides and silicates

Enter percentages if available from lab analysis.
If not available, the system uses typical values for the predicted mineral.""",
    },
    "general": {
        "title": "General Help",
        "description": "General app navigation and features",
        "tips": [
            "Use the navigation menu at the bottom to switch screens",
            "Scan history shows all previous scans on the History tab",
            "Your profile settings are in the Settings screen",
            "Admin dashboard available for authorized users",
        ],
        "help": """MineralTrace App Overview:
1. Scanner - Take and analyze mineral scans
2. Results - View detailed scan information
3. History - Browse previous scans
4. Verification - Authenticate samples
5. Profile - Manage your account
6. Settings - Configure app preferences

Use the AI Assistant (this chat) anytime for quick help!""",
    },
}

class ChatRequest(BaseModel):
    query: str
    context: str = "general"
    conversation_history: Optional[List[Dict[str, str]]] = None

def generate_ai_response(query: str, context: str, conversation_history: Optional[List[dict]] = None) -> str:
    """
    Generate an AI response to user queries using OpenAI GPT.
    Falls back to knowledge base if OpenAI is not available or properly configured.
    """
    # Try OpenAI first if available and configured
    if OPENAI_AVAILABLE:
        try:
            openai_api_key = os.getenv("OPENAI_API_KEY", "").strip()
            if not openai_api_key:
                raise ValueError("OPENAI_API_KEY environment variable not set")
            
            client = OpenAI(api_key=openai_api_key)
            
            # Build system prompt with app context
            system_prompt = """You are a helpful AI assistant for MineralTrace, a mineral identification and fingerprinting app.
            
The app helps users:
1. Scan and identify mineral samples using image, audio, and chemical composition data
2. Understand mineral scan results, confidence scores, and probabilities
3. Verify and authenticate mineral samples against a database
4. Track mineral samples across multiple sites

Guidelines:
- Keep responses concise and user-friendly (2-3 short paragraphs max)
- Provide practical, actionable advice
- Reference specific app features when relevant (Scanner, Results, Verification, History screens)
- For technical questions, explain in simple terms
- If unsure, suggest the user contact support or use the in-app help

App Features to Reference:
- Confidence Score: How sure the AI is about the identification (0-100%)
- Mineral Gate: Whether the sample was recognized as a mineral
- OOD Status: If the sample is known or unknown/out-of-distribution
- Similarity Score: How similar to previously scanned samples
- Verification: Authenticates samples against stored fingerprints
- Chemical Data: Au (Gold), Cu (Copper), Fe (Iron), S (Sulfur), O (Oxygen) percentages"""
            
            # Build messages list
            messages = [{"role": "system", "content": system_prompt}]
            
            # Add conversation history if available
            if conversation_history:
                for msg in conversation_history[-5:]:  # Keep last 5 messages for context
                    messages.append({
                        "role": msg.get("role", "user"),
                        "content": msg.get("content", ""),
                    })
            
            # Add current query
            messages.append({"role": "user", "content": query})
            
            # Call OpenAI API
            response = client.chat.completions.create(
                model="gpt-3.5-turbo",
                messages=messages,
                temperature=0.7,
                max_tokens=500,
                timeout=30
            )
            
            return response.choices[0].message.content.strip()
        
        except Exception as openai_error:
            # Log OpenAI error but fall back gracefully
            logger.log_error(openai_error, {
                "endpoint": "/api/chat/assist",
                "phase": "openai_call",
                "fallback": "knowledge_base"
            })
    
    # Fallback to knowledge base approach
    return generate_kb_response(query, context)

def generate_kb_response(query: str, context: str) -> str:
    """
    Generate a response using the knowledge base (fallback if OpenAI is unavailable)
    """
    query_lower = query.lower().strip()
    
    # Try to match against knowledge base
    kb = CHAT_KNOWLEDGE_BASE.get(context, CHAT_KNOWLEDGE_BASE.get("general"))
    
    # Smart keyword matching
    scanning_keywords = ["scan", "take", "photo", "image", "camera", "mineral", "analyze"]
    results_keywords = ["results", "confidence", "score", "probability", "understand", "mean"]
    verification_keywords = ["verify", "verification", "authenticate", "match", "fingerprint"]
    chemical_keywords = ["chemical", "composition", "element", "au", "cu", "fe", "s", "o"]
    
    score_scanning = sum(1 for kw in scanning_keywords if kw in query_lower)
    score_results = sum(1 for kw in results_keywords if kw in query_lower)
    score_verification = sum(1 for kw in verification_keywords if kw in query_lower)
    score_chemical = sum(1 for kw in chemical_keywords if kw in query_lower)
    
    # Pick the most relevant topic
    scores = {
        "scanning": score_scanning,
        "results": score_results,
        "verification": score_verification,
        "chemical": score_chemical,
    }
    best_topic = max(scores, key=scores.get) if max(scores.values()) > 0 else "general"
    
    # Get knowledge base entry
    entry = CHAT_KNOWLEDGE_BASE.get(best_topic, CHAT_KNOWLEDGE_BASE["general"])
    
    # Generate response based on query type
    if any(word in query_lower for word in ["how", "help", "explain", "what", "tutorial"]):
        return entry["help"]
    elif any(word in query_lower for word in ["tip", "advice", "best", "should", "recommend"]):
        tips_text = "\n".join([f"• {tip}" for tip in entry["tips"]])
        return f"**{entry['title']} Tips:**\n\n{tips_text}"
    else:
        response = f"{entry['help']}\n\n**Quick Tips:**\n"
        response += "\n".join([f"• {tip}" for tip in entry["tips"][:3]])
        return response

@app.post("/api/chat/assist")
async def chat_assist(request: ChatRequest):
    """
    AI assistant endpoint for chat queries
    Uses OpenAI GPT with fallback to knowledge base
    """
    try:
        if not request.query or not request.query.strip():
            raise HTTPException(status_code=400, detail="Query cannot be empty")
        
        response = generate_ai_response(
            query=request.query,
            context=request.context,
            conversation_history=request.conversation_history,
        )
        
        return {
            "status": "success",
            "response": response,
            "context": request.context,
            "timestamp": datetime.now(CAT).isoformat(),
            "ai_model": "gpt-3.5-turbo" if OPENAI_AVAILABLE else "knowledge_base",
        }
    
    except HTTPException:
        raise
    except Exception as e:
        logger.log_error(e, {"endpoint": "/api/chat/assist"})
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/chat/tips")
async def get_contextual_tips(screen: str = "general"):
    """
    Get tips for a specific screen/context
    """
    try:
        entry = CHAT_KNOWLEDGE_BASE.get(screen, CHAT_KNOWLEDGE_BASE.get("general"))
        return {
            "status": "success",
            "screen": screen,
            "title": entry.get("title", "Tips"),
            "tips": entry.get("tips", []),
            "timestamp": datetime.now(CAT).isoformat(),
        }
    except Exception as e:
        logger.log_error(e, {"endpoint": "/api/chat/tips"})
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/chat/help/{feature}")
async def get_feature_help(feature: str):
    """
    Get detailed help for a specific feature
    """
    try:
        entry = CHAT_KNOWLEDGE_BASE.get(feature.lower(), CHAT_KNOWLEDGE_BASE.get("general"))
        return {
            "status": "success",
            "feature": feature,
            "title": entry.get("title", "Help"),
            "help": entry.get("help", "No help available for this feature."),
            "description": entry.get("description", ""),
            "tips": entry.get("tips", []),
            "timestamp": datetime.now(CAT).isoformat(),
        }
    except Exception as e:
        logger.log_error(e, {"endpoint": "/api/chat/help/{feature}"})
        raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    import uvicorn
    import os
    
    # Allow configuration via environment variables
    host = os.getenv("API_HOST", "0.0.0.0")  # Changed to 0.0.0.0 to allow mobile device access
    port = int(os.getenv("API_PORT", "8000"))
    
    print("\n" + "=" * 80)
    print(" Starting Geoacoustic Mineral Fingerprinting API...")
    print("=" * 80)
    print(f" API running at: http://{host}:{port}")
    print(f" API docs at: http://127.0.0.1:{port}/docs")
    print(f" For mobile device access, use your computer's local IP address")
    print(f"   Example: http://192.168.1.100:{port}")
    print("=" * 80 + "\n")
    # Mount static webapp here so API routes are already defined and take precedence.
    WEBAPP_DIR = str(BASE_DIR / "webapp")
    try:
        app.mount("/", StaticFiles(directory=WEBAPP_DIR, html=True), name="webapp")
        print(f" Mounted static webapp from: {WEBAPP_DIR}")
    except Exception as _e:
        print(f"  Could not mount webapp static files: {WEBAPP_DIR} -> {_e}")

    uvicorn.run("API.api:app", host=host, port=port, reload=True)
