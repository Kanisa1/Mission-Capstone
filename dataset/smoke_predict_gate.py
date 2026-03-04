import csv
import json
import sys
from pathlib import Path

from fastapi.testclient import TestClient

ROOT = Path(__file__).resolve().parents[1]
API_DIR = ROOT / "API"
if str(API_DIR) not in sys.path:
    sys.path.insert(0, str(API_DIR))

import api


def pick_row(csv_path: Path, key: str, value: str) -> dict:
    rows = csv.DictReader(csv_path.open("r", encoding="utf-8", newline=""))
    target = value.strip().lower()
    for row in rows:
        if str(row.get(key, "")).strip().lower() == target:
            return row
    raise RuntimeError(f"No row found where {key}={value}")


def run_predict(image_path: Path, chemistry: dict | None = None) -> dict:
    files = {
        "image": (image_path.name, image_path.read_bytes(), "image/jpeg"),
    }

    with TestClient(api.app) as client:
        resp = client.post("/predict", files=files, data=chemistry or {})
        return {"status": resp.status_code, "body": resp.json()}


def main():
    ds = ROOT / "dataset"

    non_row = pick_row(ds / "gate_test.csv", "label", "non_mineral")
    non_image = ds / str(non_row["image_path"]).replace("\\", "/")

    mineral_row = next(csv.DictReader((ds / "test.csv").open("r", encoding="utf-8", newline="")))
    mineral_image = ds / str(mineral_row["image_path"]).replace("\\", "/")

    non_result = run_predict(non_image)
    mineral_result = run_predict(
        mineral_image,
        chemistry={
            "Au": mineral_row["Au"],
            "Cu": mineral_row["Cu"],
            "Fe": mineral_row["Fe"],
            "S": mineral_row["S"],
            "O": mineral_row["O"],
        },
    )

    print("NON-MINERAL SAMPLE RESULT")
    print(json.dumps(non_result, indent=2)[:1600])
    print("\nMINERAL SAMPLE RESULT")
    print(json.dumps(mineral_result, indent=2)[:1600])


if __name__ == "__main__":
    main()
