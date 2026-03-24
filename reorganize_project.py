"""
Reorganize project structure - move notebooks and related ML files to notebook_ml folder
"""
import os
import shutil
from pathlib import Path

PROJECT_ROOT = r"c:\Users\HP\Mission-Capstone"
NOTEBOOK_ML_DIR = os.path.join(PROJECT_ROOT, "notebook_ml")
DATASET_DIR = os.path.join(PROJECT_ROOT, "dataset")

# Ensure notebook_ml folder exists
os.makedirs(NOTEBOOK_ML_DIR, exist_ok=True)

# Files to move to notebook_ml
files_to_move = [
    # Notebooks
    (os.path.join(PROJECT_ROOT, "location_discrimination_analysis.ipynb"), 
     os.path.join(NOTEBOOK_ML_DIR, "location_discrimination_analysis.ipynb")),
    
    (os.path.join(DATASET_DIR, "train_multimodal.ipynb"), 
     os.path.join(NOTEBOOK_ML_DIR, "train_multimodal.ipynb")),
    
    # ML-related scripts at root
    (os.path.join(PROJECT_ROOT, "data_scripting.py"), 
     os.path.join(NOTEBOOK_ML_DIR, "data_scripting.py")),
    
    (os.path.join(PROJECT_ROOT, "mindat_download_by_mineral_name.py"), 
     os.path.join(NOTEBOOK_ML_DIR, "mindat_download_by_mineral_name.py")),
    
    (os.path.join(PROJECT_ROOT, "requirements_ml.txt"), 
     os.path.join(NOTEBOOK_ML_DIR, "requirements_ml.txt")),
]

# ML-related scripts from dataset folder to move to notebook_ml
dataset_ml_scripts = [
    "build_dataset_split.py",
    "build_open_set_splits.py",
    "calibrate_audio_ood.py",
    "generate_chemical_dataset.py",
    "generate_realistic_chemical.py",
    "generate_synthetic_audio.py",
    "multimodal_dataset.py",
    "multimodal_model.py",
    "organize_audio_dataset.py",
    "rebuild_dataset_with_audio.py",
    "record_audio_samples.py",
    "save_scaler.py",
    "smoke_predict_gate.py",
    "test_loader.py",
    "validate_audio_quality.py",
    "train_internal.csv",
    "test_fingerprints.csv",
    "test_fingerprints.npy",
    "test_labels.npy",
    "mineral_gate_model.pt",
    "multimodal_model.pt",
    "mineral_gate_config.json",
    "multimodal_calibration.json",
]

print("📁 Starting project reorganization...")
print(f"📍 Moving files to: {NOTEBOOK_ML_DIR}\n")

moved_count = 0
skipped_count = 0

# Move files from root and dataset
for src, dst in files_to_move:
    if os.path.exists(src):
        try:
            shutil.move(src, dst)
            print(f"✓ Moved: {os.path.basename(src)}")
            moved_count += 1
        except Exception as e:
            print(f"✗ Error moving {os.path.basename(src)}: {e}")
    else:
        print(f"⊘ Not found: {os.path.basename(src)}")
        skipped_count += 1

# Move dataset ML scripts
print("\n📊 Moving dataset ML scripts...")
for script in dataset_ml_scripts:
    src = os.path.join(DATASET_DIR, script)
    dst = os.path.join(NOTEBOOK_ML_DIR, script)
    if os.path.exists(src):
        try:
            shutil.move(src, dst)
            print(f"✓ Moved: {script}")
            moved_count += 1
        except Exception as e:
            print(f"✗ Error moving {script}: {e}")
    else:
        print(f"⊘ Not found: {script}")
        skipped_count += 1

# Copy audio and images folders to preserve them
print("\n🎵 Handling media folders...")
for folder in ["audio", "audio_organized", "images"]:
    src_folder = os.path.join(DATASET_DIR, folder)
    dst_folder = os.path.join(NOTEBOOK_ML_DIR, folder)
    if os.path.exists(src_folder):
        try:
            if os.path.exists(dst_folder):
                shutil.rmtree(dst_folder)
            shutil.copytree(src_folder, dst_folder)
            print(f"✓ Copied: {folder}/")
        except Exception as e:
            print(f"✗ Error copying {folder}: {e}")

print("\n" + "="*60)
print(f"✅ Reorganization complete!")
print(f"📊 Files moved: {moved_count}")
print(f"⚠️  Files skipped/not found: {skipped_count}")
print(f"📂 New structure: notebook_ml/")
print("="*60)
