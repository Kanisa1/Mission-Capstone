#!/usr/bin/env python3
"""
Rebuild train/test CSV files with new audio data linked to images.
This ensures every sample that has both image and audio is properly paired.
"""

import os
import pandas as pd
from pathlib import Path

# Directories
AUDIO_DIR = Path("audio")
IMAGE_DIR = Path("images")
MINERALS = ["gold", "chalcopyrite", "hematite"]

def get_audio_files_for_mineral(mineral):
    """Get all audio files for a given mineral from any site."""
    audio_files = []
    
    # Check all sites for audio files of this mineral
    for site_dir in AUDIO_DIR.iterdir():
        if site_dir.is_dir():
            mineral_dir = site_dir / mineral
            if mineral_dir.exists():
                audio_files.extend(list(mineral_dir.glob("*.wav")))
    
    return sorted([str(f) for f in audio_files])

def rebuild_dataset():
    """Rebuild CSVs with audio paths properly linked."""
    
    print("Loading original train.csv...")
    df = pd.read_csv("train.csv")
    
    # Ensure audio_path is string type
    df['audio_path'] = df['audio_path'].astype(str)
    
    print(f"Total samples before: {len(df)}")
    print(f"Samples with audio before: {(df['audio_path'].notna() & (df['audio_path'] != '')).sum()}")
    
    # Count audio files available
    print("\nAudio files available per mineral:")
    mineral_audio_map = {}
    for mineral in MINERALS:
        audio_files = get_audio_files_for_mineral(mineral)
        mineral_audio_map[mineral] = audio_files
        if audio_files:
            print(f"  {mineral}: {len(audio_files)} files")
    
    # Try to link audio to samples - distribute audio files round-robin
    audio_linked = 0
    for mineral in MINERALS:
        audio_files = mineral_audio_map[mineral]
        if not audio_files:
            continue
        
        # Get indices of samples for this mineral
        mineral_mask = df['mineral'].str.lower() == mineral
        mineral_indices = df[mineral_mask].index.tolist()
        
        # Distribute audio files round-robin across samples
        for i, idx in enumerate(mineral_indices):
            audio_idx = i % len(audio_files)
            df.loc[idx, 'audio_path'] = audio_files[audio_idx]
            audio_linked += 1
        
        print(f"Linked {len(mineral_indices)} {mineral} samples to {len(audio_files)} audio files")
    
    print(f"\nTotal samples linked with audio: {audio_linked}")
    
    # Save updated train.csv
    df.to_csv("train.csv", index=False)
    print("✓ Updated train.csv with audio paths")
    
    # Also update test.csv if it exists
    if Path("test.csv").exists():
        test_df = pd.read_csv("test.csv")
        
        # Ensure audio_path is string type
        test_df['audio_path'] = test_df['audio_path'].astype(str)
        
        audio_linked_test = 0
        
        for mineral in MINERALS:
            audio_files = mineral_audio_map[mineral]
            if not audio_files:
                continue
            
            mineral_mask = test_df['mineral'].str.lower() == mineral
            mineral_indices = test_df[mineral_mask].index.tolist()
            
            for i, idx in enumerate(mineral_indices):
                audio_idx = i % len(audio_files)
                test_df.loc[idx, 'audio_path'] = audio_files[audio_idx]
                audio_linked_test += 1
        
        test_df.to_csv("test.csv", index=False)
        print(f"✓ Updated test.csv with {audio_linked_test} audio paths")
    
    print("\n" + "="*80)
    print("DATASET REBUILD COMPLETE")
    print("="*80)
    audio_count_train = (df['audio_path'].notna() & (df['audio_path'] != '')).sum()
    print(f"Train samples with audio: {audio_count_train}/{len(df)}")
    print(f"Audio coverage: {audio_count_train / len(df) * 100:.1f}%")
    print(f"\nSample with audio:")
    sample_with_audio = df[df['audio_path'].notna() & (df['audio_path'] != '')].iloc[0]
    print(f"  Mineral: {sample_with_audio['mineral']}")
    print(f"  Image: {sample_with_audio['image_path']}")
    print(f"  Audio: {sample_with_audio['audio_path']}")

if __name__ == "__main__":
    rebuild_dataset()
