"""
Audio Quality Validation for Training Dataset
Validates all audio files before model training to ensure data quality.
Reports issues and generates quality metrics.
"""

import os
import json
import glob
import numpy as np
import librosa
from pathlib import Path
from collections import defaultdict
from datetime import datetime

# OOD thresholds (must match ood_config.json and api.py)
AUDIO_OOD_MIN_DURATION_SEC = 0.25
AUDIO_OOD_MIN_RMS = 0.003
AUDIO_OOD_MIN_DYNAMIC_STD = 0.003
AUDIO_OOD_MAX_PEAK = 1.0

SAMPLE_RATE = 16000


def validate_audio_file(audio_path):
    """
    Validate a single audio file.
    Returns: (is_valid, metrics, issues)
    """
    metrics = {
        "path": str(audio_path),
        "duration_sec": 0.0,
        "rms": 0.0,
        "peak": 0.0,
        "dynamic_std": 0.0,
        "sample_rate": 0,
    }
    issues = []
    
    try:
        y, sr = librosa.load(audio_path, sr=SAMPLE_RATE, mono=True)
        metrics["sample_rate"] = sr
    except Exception as e:
        issues.append(f"Failed to load: {str(e)}")
        return False, metrics, issues
    
    # Check duration
    duration_sec = float(len(y) / max(1, sr))
    metrics["duration_sec"] = round(duration_sec, 4)
    if duration_sec < AUDIO_OOD_MIN_DURATION_SEC:
        issues.append(f"Too short: {duration_sec:.3f}s (min: {AUDIO_OOD_MIN_DURATION_SEC}s)")
    
    # Check RMS (energy/loudness)
    rms = float(np.sqrt(np.mean(np.square(y)))) if y.size > 0 else 0.0
    metrics["rms"] = round(rms, 6)
    if rms < AUDIO_OOD_MIN_RMS:
        issues.append(f"Too silent: RMS={rms:.6f} (min: {AUDIO_OOD_MIN_RMS})")
    
    # Check peak (clipping)
    peak = float(np.max(np.abs(y))) if y.size > 0 else 0.0
    metrics["peak"] = round(peak, 6)
    if peak >= AUDIO_OOD_MAX_PEAK:
        issues.append(f"Possible clipping: peak={peak:.4f} (max: {AUDIO_OOD_MAX_PEAK})")
    
    # Check dynamic range (variation)
    dynamic_std = float(np.std(y)) if y.size > 0 else 0.0
    metrics["dynamic_std"] = round(dynamic_std, 6)
    if dynamic_std < AUDIO_OOD_MIN_DYNAMIC_STD:
        issues.append(f"Low dynamic range: std={dynamic_std:.6f} (min: {AUDIO_OOD_MIN_DYNAMIC_STD})")
    
    is_valid = len(issues) == 0
    return is_valid, metrics, issues


def main():
    """Validate all training audio files"""
    
    base_dir = Path("audio")
    if not base_dir.exists():
        print(f"❌ Audio directory not found: {base_dir}")
        return
    
    print("=" * 80)
    print("AUDIO QUALITY VALIDATION REPORT")
    print("=" * 80)
    print(f"Timestamp: {datetime.now().isoformat()}")
    print(f"Audio directory: {base_dir}")
    print()
    
    # Find all audio files
    audio_files = sorted(glob.glob(str(base_dir / "**" / "*.wav"), recursive=True))
    
    if not audio_files:
        print("❌ No audio files found!")
        return
    
    print(f"Found {len(audio_files)} audio files\n")
    
    # Validate all files
    results = {
        "total": 0,
        "valid": 0,
        "invalid": 0,
        "by_mineral": defaultdict(lambda: {"total": 0, "valid": 0, "invalid": 0}),
        "issues": [],
        "valid_files": [],
        "metrics": [],
    }
    
    for audio_path in audio_files:
        is_valid, metrics, issues = validate_audio_file(audio_path)
        results["total"] += 1
        results["metrics"].append(metrics)
        
        # Extract mineral type from path (e.g., "audio/site/mineral/file.wav")
        parts = Path(audio_path).parts
        mineral = parts[-2] if len(parts) >= 2 else "unknown"
        results["by_mineral"][mineral]["total"] += 1
        
        if is_valid:
            results["valid"] += 1
            results["by_mineral"][mineral]["valid"] += 1
            results["valid_files"].append(audio_path)
        else:
            results["invalid"] += 1
            results["by_mineral"][mineral]["invalid"] += 1
            results["issues"].append({
                "file": audio_path,
                "issues": issues,
                "metrics": metrics,
            })
    
    # Print summary
    print("SUMMARY")
    print("-" * 80)
    print(f"Total files:   {results['total']}")
    print(f"✅ Valid:      {results['valid']} ({100*results['valid']/results['total']:.1f}%)")
    print(f"❌ Invalid:    {results['invalid']} ({100*results['invalid']/results['total']:.1f}%)")
    print()
    
    # Print by mineral
    if results["by_mineral"]:
        print("BY MINERAL CLASS")
        print("-" * 80)
        for mineral, counts in sorted(results["by_mineral"].items()):
            pct = 100 * counts["valid"] / counts["total"] if counts["total"] > 0 else 0
            print(f"{mineral:20} {counts['valid']:3}/{counts['total']:3} valid ({pct:5.1f}%)")
        print()
    
    # Print statistics
    if results["metrics"]:
        print("STATISTICS")
        print("-" * 80)
        durations = [m["duration_sec"] for m in results["metrics"]]
        rms_values = [m["rms"] for m in results["metrics"]]
        peaks = [m["peak"] for m in results["metrics"]]
        stds = [m["dynamic_std"] for m in results["metrics"]]
        
        print(f"Duration (seconds)")
        print(f"  Min:    {min(durations):.3f}")
        print(f"  Max:    {max(durations):.3f}")
        print(f"  Mean:   {np.mean(durations):.3f}")
        print(f"  Median: {np.median(durations):.3f}")
        print()
        
        print(f"RMS (Energy)")
        print(f"  Min:    {min(rms_values):.6f}")
        print(f"  Max:    {max(rms_values):.6f}")
        print(f"  Mean:   {np.mean(rms_values):.6f}")
        print()
        
        print(f"Peak Amplitude")
        print(f"  Min:    {min(peaks):.6f}")
        print(f"  Max:    {max(peaks):.6f}")
        print(f"  Mean:   {np.mean(peaks):.6f}")
        print()
        
        print(f"Dynamic Range (Std)")
        print(f"  Min:    {min(stds):.6f}")
        print(f"  Max:    {max(stds):.6f}")
        print(f"  Mean:   {np.mean(stds):.6f}")
        print()
    
    # Print issues if any
    if results["issues"]:
        print("PROBLEMATIC FILES")
        print("-" * 80)
        for item in results["issues"]:
            print(f"\n❌ {item['file']}")
            for issue in item["issues"]:
                print(f"   • {issue}")
            metrics = item["metrics"]
            print(f"   Metrics: duration={metrics['duration_sec']:.3f}s, " +
                  f"rms={metrics['rms']:.6f}, peak={metrics['peak']:.6f}, " +
                  f"std={metrics['dynamic_std']:.6f}")
    else:
        print("✅ NO ISSUES FOUND - All audio files pass quality checks!")
        print()
    
    # Save detailed report
    report_file = "audio_validation_report.json"
    with open(report_file, "w") as f:
        # Convert defaultdict and non-serializable objects
        report_data = {
            "timestamp": datetime.now().isoformat(),
            "total": results["total"],
            "valid": results["valid"],
            "invalid": results["invalid"],
            "by_mineral": dict(results["by_mineral"]),
            "metrics_summary": {
                "duration_sec": {
                    "min": float(min([m["duration_sec"] for m in results["metrics"]])) if results["metrics"] else 0,
                    "max": float(max([m["duration_sec"] for m in results["metrics"]])) if results["metrics"] else 0,
                    "mean": float(np.mean([m["duration_sec"] for m in results["metrics"]])) if results["metrics"] else 0,
                },
                "rms": {
                    "min": float(min([m["rms"] for m in results["metrics"]])) if results["metrics"] else 0,
                    "max": float(max([m["rms"] for m in results["metrics"]])) if results["metrics"] else 0,
                    "mean": float(np.mean([m["rms"] for m in results["metrics"]])) if results["metrics"] else 0,
                },
            },
            "issues": [
                {
                    "file": item["file"],
                    "issues": item["issues"],
                    "metrics": item["metrics"],
                }
                for item in results["issues"]
            ],
        }
        json.dump(report_data, f, indent=2)
    
    print(f"✅ Detailed report saved: {report_file}")
    print("=" * 80)


if __name__ == "__main__":
    main()
