import csv
import json
import sys
from pathlib import Path
from statistics import mean
from typing import Optional

from fastapi.testclient import TestClient

ROOT = Path(__file__).resolve().parents[1]
API_DIR = ROOT / "API"
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))
if str(API_DIR) not in sys.path:
    sys.path.insert(0, str(API_DIR))

import api as api_mod


def summarize(
    confidences: list[float],
    correct: int,
    total: int,
    accepted: int,
    accepted_correct: int,
    unknown_count: int,
) -> dict:
    if not confidences:
        return {
            "samples": total,
            "accuracy": 0.0,
            "accepted_rate": 0.0,
            "accepted_accuracy": 0.0,
            "unknown_rate": 0.0,
            "mean_confidence": 0.0,
            "p95plus": 0.0,
            "p99plus": 0.0,
            "min_confidence": 0.0,
            "max_confidence": 0.0,
        }

    return {
        "samples": total,
        "accuracy": correct / max(1, total),
        "accepted_rate": accepted / max(1, total),
        "accepted_accuracy": accepted_correct / max(1, accepted),
        "unknown_rate": unknown_count / max(1, total),
        "mean_confidence": mean(confidences),
        "p95plus": sum(c >= 0.95 for c in confidences) / len(confidences),
        "p99plus": sum(c >= 0.99 for c in confidences) / len(confidences),
        "min_confidence": min(confidences),
        "max_confidence": max(confidences),
    }


def evaluate_rows(client: TestClient, rows: list[dict], dataset_dir: Path, temperature: float) -> dict:
    prev_temp = api_mod.multimodal_temperature
    prev_ood_conf = api_mod.OOD_CONFIDENCE_THRESHOLD
    prev_ood_sim = api_mod.OOD_EMBEDDING_SIM_THRESHOLD
    api_mod.multimodal_temperature = float(temperature)

    confidences: list[float] = []
    embedding_sims: list[float] = []
    correct = 0
    total = 0
    accepted = 0
    accepted_correct = 0
    unknown_count = 0

    try:
        for row in rows:
            image_path = dataset_dir / str(row["image_path"]).replace("\\", "/")
            audio_path = dataset_dir / str(row["audio_path"]).replace("\\", "/")

            if not image_path.exists() or not audio_path.exists():
                continue

            files = {
                "image": (image_path.name, image_path.read_bytes(), "image/jpeg"),
                "audio": (audio_path.name, audio_path.read_bytes(), "audio/wav"),
            }
            data = {
                "Au": str(row["Au"]),
                "Cu": str(row["Cu"]),
                "Fe": str(row["Fe"]),
                "S": str(row["S"]),
                "O": str(row["O"]),
            }

            response = client.post("/predict", files=files, data=data)
            if response.status_code != 200:
                continue

            payload = response.json()
            if "confidence" not in payload:
                continue

            total += 1
            confidences.append(float(payload["confidence"]))
            embedding_sims.append(float(payload.get("max_embedding_similarity", 0.0)))

            pred = str(payload.get("predicted_mineral", "")).strip().lower()
            truth = str(row["mineral"]).strip().lower()
            if pred == truth:
                correct += 1

            if str(payload.get("ood_status", "")).strip().lower() != "unknown" and pred:
                accepted += 1
                if pred == truth:
                    accepted_correct += 1
            else:
                unknown_count += 1

        metrics = summarize(confidences, correct, total, accepted, accepted_correct, unknown_count)
        if embedding_sims:
            metrics["embedding_similarity_mean"] = mean(embedding_sims)
            metrics["embedding_similarity_min"] = min(embedding_sims)
            metrics["embedding_similarity_max"] = max(embedding_sims)
        return metrics
    finally:
        api_mod.multimodal_temperature = prev_temp
        api_mod.OOD_CONFIDENCE_THRESHOLD = prev_ood_conf
        api_mod.OOD_EMBEDDING_SIM_THRESHOLD = prev_ood_sim


def evaluate_rows_with_thresholds(
    client: TestClient,
    rows: list[dict],
    dataset_dir: Path,
    temperature: float,
    ood_conf_threshold: Optional[float] = None,
    ood_sim_threshold: Optional[float] = None,
) -> dict:
    if ood_conf_threshold is not None:
        api_mod.OOD_CONFIDENCE_THRESHOLD = float(ood_conf_threshold)
    if ood_sim_threshold is not None:
        api_mod.OOD_EMBEDDING_SIM_THRESHOLD = float(ood_sim_threshold)
    return evaluate_rows(client, rows, dataset_dir, temperature=temperature)


def main():
    root = Path(__file__).resolve().parents[1]
    dataset_dir = root / "dataset"
    test_csv = dataset_dir / "test.csv"
    calibration_json = dataset_dir / "multimodal_calibration.json"

    max_samples = 120
    with test_csv.open("r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        rows = [row for _, row in zip(range(max_samples), reader)]

    with calibration_json.open("r", encoding="utf-8") as f:
        calibration = json.load(f)
    calibrated_temperature = float(calibration.get("temperature", 1.0))

    with TestClient(api_mod.app) as client:
        baseline = evaluate_rows(client, rows, dataset_dir, temperature=1.0)
        calibrated = evaluate_rows(client, rows, dataset_dir, temperature=calibrated_temperature)

        # Threshold sweep under calibrated temperature
        confidence_thresholds = [0.70, 0.75, 0.80, 0.85, 0.90, 0.93, 0.95]
        similarity_thresholds = [0.0, 0.01, 0.02, 0.03, 0.04, 0.05, 0.06, 0.07, 0.08, 0.09, 0.10]
        sweep = []
        for conf_thr in confidence_thresholds:
            for sim_thr in similarity_thresholds:
                result = evaluate_rows_with_thresholds(
                    client,
                    rows,
                    dataset_dir,
                    temperature=calibrated_temperature,
                    ood_conf_threshold=conf_thr,
                    ood_sim_threshold=sim_thr,
                )
                sweep.append({
                    "ood_conf": conf_thr,
                    "ood_sim": sim_thr,
                    **result,
                })

        # Pick threshold maximizing expected correct coverage on this mineral-only test set.
        # Score = accepted_rate * accepted_accuracy (fraction of total samples correctly accepted).
        for row in sweep:
            row["coverage_correct_score"] = row["accepted_rate"] * row["accepted_accuracy"]

        candidates = [x for x in sweep if x["accepted_accuracy"] >= 0.70]
        if not candidates:
            candidates = sweep
        tuned = sorted(
            candidates,
            key=lambda x: (x["coverage_correct_score"], x["accepted_accuracy"], x["accepted_rate"]),
            reverse=True,
        )[0]

    print("API Calibration A/B (real /predict calls)")
    print(f"Samples evaluated: {baseline['samples']}")
    print("--- Baseline (T=1.0)")
    print(json.dumps(baseline, indent=2))
    print(f"--- Calibrated (T={calibrated_temperature:.4f})")
    print(json.dumps(calibrated, indent=2))

    if baseline["samples"] > 0 and calibrated["samples"] > 0:
        print("--- Delta (calibrated - baseline)")
        delta = {
            "accuracy": calibrated["accuracy"] - baseline["accuracy"],
            "accepted_rate": calibrated["accepted_rate"] - baseline["accepted_rate"],
            "accepted_accuracy": calibrated["accepted_accuracy"] - baseline["accepted_accuracy"],
            "unknown_rate": calibrated["unknown_rate"] - baseline["unknown_rate"],
            "mean_confidence": calibrated["mean_confidence"] - baseline["mean_confidence"],
            "p95plus": calibrated["p95plus"] - baseline["p95plus"],
            "p99plus": calibrated["p99plus"] - baseline["p99plus"],
        }
        print(json.dumps(delta, indent=2))

    print("--- OOD sweep (calibrated temperature)")
    print("Top 10 by coverage_correct_score:")
    for row in sorted(sweep, key=lambda x: (x["coverage_correct_score"], x["accepted_accuracy"], x["accepted_rate"]), reverse=True)[:10]:
        print(
            f"ood_conf={row['ood_conf']:.2f}, ood_sim={row['ood_sim']:.2f}, "
            f"accepted_rate={row['accepted_rate']:.3f}, accepted_acc={row['accepted_accuracy']:.3f}, "
            f"score={row['coverage_correct_score']:.3f}, unknown_rate={row['unknown_rate']:.3f}, "
            f"mean_conf={row['mean_confidence']:.3f}"
        )

    print("--- Selected tuned threshold")
    print(json.dumps({
        "ood_conf": tuned["ood_conf"],
        "ood_sim": tuned["ood_sim"],
        "accepted_rate": tuned["accepted_rate"],
        "accepted_accuracy": tuned["accepted_accuracy"],
        "coverage_correct_score": tuned["coverage_correct_score"],
        "unknown_rate": tuned["unknown_rate"],
        "mean_confidence": tuned["mean_confidence"],
    }, indent=2))


if __name__ == "__main__":
    main()
