"""
Reorganize to keep only Jupyter notebooks in notebook_ml/
Move all other files back to dataset/
"""

import os
import shutil
from pathlib import Path

base_path = Path(r"c:\Users\HP\Mission-Capstone")
notebook_ml_path = base_path / "notebook_ml"
dataset_path = base_path / "dataset"

# Ensure dataset folder exists
dataset_path.mkdir(exist_ok=True)

# Jupyter notebook files to keep in notebook_ml
notebook_files = {
    "location_discrimination_analysis.ipynb",
    "train_multimodal.ipynb"
}

# Files/folders to move back to dataset
items_to_move_back = [
    "build_dataset_split.py",
    "build_open_set_splits.py",
    "calibrate_audio_ood.py",
    "data_scripting.py",
    "generate_chemical_dataset.py",
    "generate_realistic_chemical.py",
    "generate_synthetic_audio.py",
    "mindat_download_by_mineral_name.py",
    "multimodal_dataset.py",
    "organize_audio_dataset.py",
    "rebuild_dataset_with_audio.py",
    "record_audio_samples.py",
    "save_scaler.py",
    "smoke_predict_gate.py",
    "test_loader.py",
    "validate_audio_quality.py",
    "mineral_gate_config.json",
    "mineral_gate_model.pt",
    "multimodal_calibration.json",
    "multimodal_model.pt",
    "multimodal_model.py",
    "requirements_ml.txt",
    "test_fingerprints.csv",
    "test_fingerprints.npy",
    "test_labels.npy",
    "train_internal.csv",
    "audio",
    "audio_organized",
    "images"
]

print("=" * 70)
print("REORGANIZING: Moving non-notebook files back to dataset/")
print("=" * 70)

moved_count = 0
for item_name in items_to_move_back:
    source = notebook_ml_path / item_name
    dest = dataset_path / item_name
    
    if source.exists():
        # Remove destination if it exists
        if dest.exists():
            if dest.is_dir():
                print(f"  Removing existing directory: {item_name}/")
                shutil.rmtree(dest)
            else:
                print(f"  Removing existing file: {item_name}")
                dest.unlink()
        
        # Move item
        print(f"  ✓ Moving: {item_name}")
        shutil.move(str(source), str(dest))
        moved_count += 1
    else:
        print(f"  ⚠ Not found: {item_name}")

print()
print("=" * 70)
print("NOTEBOOKS REMAINING in notebook_ml/:")
print("=" * 70)

for item in notebook_ml_path.iterdir():
    if item.is_file() and item.suffix == ".ipynb":
        print(f"  ✓ {item.name}")

print()
print("=" * 70)
print(f"Successfully moved {moved_count} items back to dataset/")
print("=" * 70)

# Verify final state
print("\nFinal state:")
notebook_ml_count = len(list(notebook_ml_path.glob('*')))
dataset_count = len(list(dataset_path.glob('*')))
print(f"  notebook_ml/ contains: {notebook_ml_count} items")
print(f"  dataset/ contains: {dataset_count} items")
