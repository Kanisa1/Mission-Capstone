"""
Organize raw audio files into the standard training dataset structure.
Converts audio formats, renames files consistently, and creates metadata.
"""

import os
import glob
import shutil
from pathlib import Path
from scipy.io import wavfile
import soundfile as sf
import librosa

# Configuration
BASE_DIR = Path(__file__).parent
RAW_AUDIO_DIR = BASE_DIR / "audio"
ORGANIZED_AUDIO_DIR = BASE_DIR / "audio_organized"

# Class mapping
MINERAL_CLASSES = {
    "Gold": "gold",
    "gold": "gold",
    "hematite": "hematite",
    "chalcopyrite": "chalcopyrite",
    "non-mineral audio": "non-mineral",
    "non_mineral": "non-mineral",
}

SITE_NAME = "Dataset"  # Generic site name for all audio
SAMPLE_RATE = 16000


def organize_audio_files():
    """Organize audio files into standard structure and convert to WAV."""
    
    print(f"📂 Organizing audio from: {RAW_AUDIO_DIR}")
    print(f"📁 Output directory: {ORGANIZED_AUDIO_DIR}")
    
    # Create output directory structure
    ORGANIZED_AUDIO_DIR.mkdir(exist_ok=True)
    site_dir = ORGANIZED_AUDIO_DIR / SITE_NAME
    site_dir.mkdir(exist_ok=True)
    
    total_files = 0
    organized_files = 0
    failed_files = 0
    
    # Process each mineral class
    for class_name, class_label in MINERAL_CLASSES.items():
        raw_class_dir = RAW_AUDIO_DIR / class_name
        
        if not raw_class_dir.exists():
            print(f"⏭️  Skipping {class_name} (not found)")
            continue
        
        print(f"\n🔄 Processing class: {class_name} → {class_label}")
        
        # Create output class directory
        output_class_dir = site_dir / class_label
        output_class_dir.mkdir(exist_ok=True)
        
        # Get all audio files (WAV, AIFF, etc.)
        audio_files = []
        for ext in ["*.wav", "*.aiff", "*.aif", "*.mp3", "*.flac"]:
            audio_files.extend(raw_class_dir.glob(f"**/{ext}"))
            audio_files.extend(raw_class_dir.glob(f"{ext}"))
        
        audio_files = list(set(audio_files))  # Remove duplicates
        total_files += len(audio_files)
        
        print(f"   Found {len(audio_files)} audio files")
        
        # Process each file
        for idx, audio_path in enumerate(sorted(audio_files)):
            try:
                # Standard naming: SITE_MINERAL_###.wav
                new_filename = f"{SITE_NAME}_{class_label}_{idx:03d}.wav"
                output_path = output_class_dir / new_filename
                
                # Load audio and resample to 16kHz
                print(f"   [{idx+1}/{len(audio_files)}] Converting: {audio_path.name}...", end="")
                y, sr = librosa.load(str(audio_path), sr=SAMPLE_RATE, mono=True)
                
                # Save as WAV
                sf.write(str(output_path), y, SAMPLE_RATE)
                organized_files += 1
                print(f" ✓")
                
            except Exception as e:
                failed_files += 1
                print(f" ✗ Error: {str(e)}")
                continue
        
        print(f"   Organized: {organized_files} files so far")
    
    print(f"\n" + "="*60)
    print(f"✅ SUMMARY")
    print(f"="*60)
    print(f"Total files processed: {total_files}")
    print(f"Successfully organized: {organized_files}")
    print(f"Failed: {failed_files}")
    print(f"\nOutput location: {ORGANIZED_AUDIO_DIR}")
    print(f"Ready for training! 🚀")


if __name__ == "__main__":
    organize_audio_files()
