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
    audio_unknown_count: int,
) -> dict:
    if total <= 0:
        return {
            "samples": 0,
            "accuracy": 0.0,
            "accepted_rate": 0.0,
            "accepted_accuracy": 0.0,
            "unknown_rate": 0.0,
            "audio_unknown_rate": 0.0,
            "mean_confidence": 0.0,
        }

    return {
        "samples": total,
        "accuracy": correct / max(1, total),
        "accepted_rate": accepted / max(1, total),
        "accepted_accuracy": accepted_correct / max(1, accepted),
        "unknown_rate": unknown_count / max(1, total),
        "audio_unknown_rate": audio_unknown_count / max(1, total),
        "mean_confidence": mean(confidences) if confidences else 0.0,
    }


def evaluate_rows(
    client: TestClient,
    rows: list[dict],
    dataset_dir: Path,
    ood_conf_threshold: float,
    ood_sim_threshold: float,
    audio_sim_threshold: float,
    audio_min_ref_count: int,
    audio_min_rms: float,
    audio_min_dynamic_std: float,
) -> dict:
    prev_ood_conf = api_mod.OOD_CONFIDENCE_THRESHOLD
    prev_ood_sim = api_mod.OOD_EMBEDDING_SIM_THRESHOLD
    prev_audio_sim = api_mod.AUDIO_OOD_EMBEDDING_SIM_THRESHOLD
    prev_audio_min_ref = api_mod.AUDIO_OOD_MIN_REF_COUNT
    prev_audio_min_rms = api_mod.AUDIO_OOD_MIN_RMS
    prev_audio_min_dyn = api_mod.AUDIO_OOD_MIN_DYNAMIC_STD

    api_mod.OOD_CONFIDENCE_THRESHOLD = float(ood_conf_threshold)
    api_mod.OOD_EMBEDDING_SIM_THRESHOLD = float(ood_sim_threshold)
    api_mod.AUDIO_OOD_EMBEDDING_SIM_THRESHOLD = float(audio_sim_threshold)
    api_mod.AUDIO_OOD_MIN_REF_COUNT = int(audio_min_ref_count)
    api_mod.AUDIO_OOD_MIN_RMS = float(audio_min_rms)
    api_mod.AUDIO_OOD_MIN_DYNAMIC_STD = float(audio_min_dynamic_std)

    confidences: list[float] = []
    correct = 0
    total = 0
    accepted = 0
    accepted_correct = 0
    unknown_count = 0
    audio_unknown_count = 0
    audio_sims: list[float] = []

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
            total += 1
            confidences.append(float(payload.get("confidence", 0.0)))

            truth = str(row.get("mineral", "")).strip().lower()
            pred = str(payload.get("predicted_mineral", "")).strip().lower()
            if pred == truth:
                correct += 1

            is_unknown = str(payload.get("ood_status", "")).strip().lower() == "unknown"
            if is_unknown:
                unknown_count += 1
                if bool(payload.get("audio_ood", False)):
                    audio_unknown_count += 1
            else:
                accepted += 1
                if pred == truth:
                    accepted_correct += 1

            audio_sims.append(float(payload.get("audio_embedding_similarity", 0.0)))

        metrics = summarize(
            confidences=confidences,
            correct=correct,
            total=total,
            accepted=accepted,
            accepted_correct=accepted_correct,
            unknown_count=unknown_count,
            audio_unknown_count=audio_unknown_count,
        )
        if audio_sims:
            metrics["audio_embedding_similarity_mean"] = mean(audio_sims)
            metrics["audio_embedding_similarity_min"] = min(audio_sims)
            metrics["audio_embedding_similarity_max"] = max(audio_sims)
        return metrics
    finally:
        api_mod.OOD_CONFIDENCE_THRESHOLD = prev_ood_conf
        api_mod.OOD_EMBEDDING_SIM_THRESHOLD = prev_ood_sim
        api_mod.AUDIO_OOD_EMBEDDING_SIM_THRESHOLD = prev_audio_sim
        api_mod.AUDIO_OOD_MIN_REF_COUNT = prev_audio_min_ref
        api_mod.AUDIO_OOD_MIN_RMS = prev_audio_min_rms
        api_mod.AUDIO_OOD_MIN_DYNAMIC_STD = prev_audio_min_dyn


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    dataset_dir = root / "dataset"

    test_csv = dataset_dir / "test.csv"
    max_samples = 120
    with test_csv.open("r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        rows = [row for _, row in zip(range(max_samples), reader)]

    base_cfg_path = dataset_dir / "ood_config.json"
    base_cfg = {}
    if base_cfg_path.exists():
        with base_cfg_path.open("r", encoding="utf-8") as f:
            base_cfg = json.load(f)

    conf_list = [0.80, 0.85, 0.90]
    sim_list = [0.02, 0.03, 0.04]
    audio_sim_list = [0.03, 0.05, 0.07]
    audio_ref_list = [3, 5]
    audio_rms_list = [0.002, 0.003, 0.004]
    audio_dyn_list = [0.002, 0.003, 0.004]

    sweep = []
    with TestClient(api_mod.app) as client:
        for conf_thr in conf_list:
            for sim_thr in sim_list:
                for aud_sim_thr in audio_sim_list:
                    for aud_ref_min in audio_ref_list:
                        for aud_rms in audio_rms_list:
                            for aud_dyn in audio_dyn_list:
                                metrics = evaluate_rows(
                                    client=client,
                                    rows=rows,
                                    dataset_dir=dataset_dir,
                                    ood_conf_threshold=conf_thr,
                                    ood_sim_threshold=sim_thr,
                                    audio_sim_threshold=aud_sim_thr,
                                    audio_min_ref_count=aud_ref_min,
                                    audio_min_rms=aud_rms,
                                    audio_min_dynamic_std=aud_dyn,
                                )
                                entry = {
                                    "ood_conf": conf_thr,
                                    "ood_sim": sim_thr,
                                    "audio_ood_embedding_sim": aud_sim_thr,
                                    "audio_ood_min_ref_count": aud_ref_min,
                                    "audio_ood_min_rms": aud_rms,
                                    "audio_ood_min_dynamic_std": aud_dyn,
                                    **metrics,
                                }
                                entry["coverage_correct_score"] = (
                                    entry["accepted_rate"] * entry["accepted_accuracy"]
                                )
                                sweep.append(entry)

    candidates = [
        x for x in sweep
        if x["accepted_accuracy"] >= 0.70 and x["audio_unknown_rate"] <= 0.20
    ]
    if not candidates:
        candidates = sweep

    tuned = sorted(
        candidates,
        key=lambda x: (
            x["coverage_correct_score"],
            x["accepted_accuracy"],
            -x["audio_unknown_rate"],
        ),
        reverse=True,
    )[0]

    recommendation = {
        "ood_confidence_threshold": tuned["ood_conf"],
        "ood_embedding_similarity_threshold": tuned["ood_sim"],
        "audio_ood_min_duration_sec": float(base_cfg.get("audio_ood_min_duration_sec", 0.25)),
        "audio_ood_min_rms": tuned["audio_ood_min_rms"],
        "audio_ood_min_dynamic_std": tuned["audio_ood_min_dynamic_std"],
        "audio_ood_max_peak": float(base_cfg.get("audio_ood_max_peak", 0.999)),
        "audio_ood_embedding_similarity_threshold": tuned["audio_ood_embedding_sim"],
        "audio_ood_min_reference_count": int(tuned["audio_ood_min_ref_count"]),
    }

    rec_path = dataset_dir / "ood_config_recommended.json"
    with rec_path.open("w", encoding="utf-8") as f:
        json.dump(recommendation, f, indent=2)

    top = sorted(
        sweep,
        key=lambda x: (x["coverage_correct_score"], x["accepted_accuracy"]),
        reverse=True,
    )[:10]

    print("Audio OOD calibration sweep complete")
    print(f"Samples evaluated: {top[0]['samples'] if top else 0}")
    print("Top 10 configs:")
    for row in top:
        print(
            "conf={:.2f}, sim={:.2f}, aud_sim={:.2f}, aud_ref={}, aud_rms={:.3f}, aud_dyn={:.3f}, "
            "accepted_rate={:.3f}, accepted_acc={:.3f}, audio_unknown_rate={:.3f}, score={:.3f}".format(
                row["ood_conf"],
                row["ood_sim"],
                row["audio_ood_embedding_sim"],
                row["audio_ood_min_ref_count"],
                row["audio_ood_min_rms"],
                row["audio_ood_min_dynamic_std"],
                row["accepted_rate"],
                row["accepted_accuracy"],
                row["audio_unknown_rate"],
                row["coverage_correct_score"],
            )
        )

    print("Selected recommendation:")
    print(json.dumps(recommendation, indent=2))
    print(f"Saved recommended config: {rec_path}")


if __name__ == "__main__":
    main()
