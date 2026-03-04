import csv
import random
import hashlib
from pathlib import Path
from typing import Dict, List

BASE_DIR = Path(__file__).resolve().parent
IMAGES_DIR = BASE_DIR / "images"

MINERALS = ["gold", "chalcopyrite", "hematite"]
LABEL_TO_ID = {"gold": 0, "chalcopyrite": 1, "hematite": 2}

TRAIN_SITES = ["Kapoeta_East", "Central_Equatoria"]
TEST_SITES = ["Yei_River"]

VAL_RATIO = 0.20
SEED = 42


def _is_image_file(path: Path) -> bool:
    return path.suffix.lower() in {".jpg", ".jpeg", ".png", ".bmp", ".webp"}


def _relative_posix(path: Path) -> str:
    return path.relative_to(BASE_DIR).as_posix()


def _file_md5(path: Path) -> str:
    hasher = hashlib.md5()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            hasher.update(chunk)
    return hasher.hexdigest()


def collect_mineral_records() -> List[Dict[str, str]]:
    rows: List[Dict[str, str]] = []

    for site in TRAIN_SITES + TEST_SITES:
        for mineral in MINERALS:
            folder = IMAGES_DIR / site / mineral
            if not folder.exists():
                continue

            for file_path in sorted(folder.iterdir()):
                if not file_path.is_file() or not _is_image_file(file_path):
                    continue

                rows.append(
                    {
                        "image_path": _relative_posix(file_path),
                        "site": site,
                        "mineral": mineral,
                        "hash": _file_md5(file_path),
                    }
                )

    return rows


def collect_non_mineral_paths() -> List[str]:
    folder = IMAGES_DIR / "non-minerals"
    if not folder.exists():
        return []

    paths: List[str] = []
    seen_hashes = set()
    for file_path in sorted(folder.iterdir()):
        if not file_path.is_file() or not _is_image_file(file_path):
            continue

        digest = _file_md5(file_path)
        if digest in seen_hashes:
            continue

        seen_hashes.add(digest)
        paths.append(_relative_posix(file_path))

    return paths


def split_mineral_records(records: List[Dict[str, str]], rng: random.Random):
    train_records: List[Dict[str, str]] = []
    val_records: List[Dict[str, str]] = []
    test_records: List[Dict[str, str]] = []

    test_records.extend([r for r in records if r["site"] in TEST_SITES])

    train_pool = [r for r in records if r["site"] in TRAIN_SITES]

    by_mineral: Dict[str, List[Dict[str, str]]] = {m: [] for m in MINERALS}
    for row in train_pool:
        by_mineral[row["mineral"]].append(row)

    for mineral, items in by_mineral.items():
        rng.shuffle(items)
        if not items:
            continue

        val_count = max(1, int(len(items) * VAL_RATIO))
        val_records.extend(items[:val_count])
        train_records.extend(items[val_count:])

    return train_records, val_records, test_records


def clean_mineral_records(records: List[Dict[str, str]]) -> List[Dict[str, str]]:
    hash_to_minerals: Dict[str, set] = {}
    for row in records:
        digest = row["hash"]
        hash_to_minerals.setdefault(digest, set()).add(row["mineral"])

    conflicting_hashes = {h for h, minerals in hash_to_minerals.items() if len(minerals) > 1}

    cleaned: List[Dict[str, str]] = []
    seen_hashes = set()
    for row in records:
        digest = row["hash"]
        if digest in conflicting_hashes:
            continue
        if digest in seen_hashes:
            continue
        seen_hashes.add(digest)
        cleaned.append(row)

    return cleaned


def non_mineral_without_overlap(non_mineral_paths: List[str], mineral_hashes: set) -> List[str]:
    filtered: List[str] = []
    for rel_path in non_mineral_paths:
        digest = _file_md5(BASE_DIR / rel_path)
        if digest in mineral_hashes:
            continue
        filtered.append(rel_path)
    return filtered


def build_gate_rows(mineral_rows: List[Dict[str, str]], non_mineral_paths: List[str], split_name: str):
    rows: List[Dict[str, str]] = []

    for row in mineral_rows:
        rows.append(
            {
                "image_path": row["image_path"],
                "label": "mineral",
                "label_id": "1",
                "split": split_name,
                "site": row["site"],
                "mineral": row["mineral"],
                "source": "field_mineral",
            }
        )

    for path in non_mineral_paths:
        rows.append(
            {
                "image_path": path,
                "label": "non_mineral",
                "label_id": "0",
                "split": split_name,
                "site": "non-minerals",
                "mineral": "",
                "source": "non_mineral_collection",
            }
        )

    return rows


def build_multiclass_rows(mineral_rows: List[Dict[str, str]], split_name: str):
    rows: List[Dict[str, str]] = []

    for row in mineral_rows:
        rows.append(
            {
                "image_path": row["image_path"],
                "mineral": row["mineral"],
                "label_id": str(LABEL_TO_ID[row["mineral"]]),
                "split": split_name,
                "site": row["site"],
            }
        )

    return rows


def write_csv(path: Path, rows: List[Dict[str, str]], fieldnames: List[str]):
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def main():
    rng = random.Random(SEED)

    mineral_records_raw = collect_mineral_records()
    mineral_records = clean_mineral_records(mineral_records_raw)
    mineral_hashes = {row["hash"] for row in mineral_records}
    non_mineral_paths_raw = collect_non_mineral_paths()
    non_mineral_paths = non_mineral_without_overlap(non_mineral_paths_raw, mineral_hashes)

    if not mineral_records:
        print("No mineral images found. Check dataset/images/<site>/<mineral> folders.")
        return

    if not non_mineral_paths:
        print("No non-mineral images found. Check dataset/images/non-minerals folder.")
        return

    train_m, val_m, test_m = split_mineral_records(mineral_records, rng)

    # Balanced gate sampling: sample non-minerals to match mineral count per split
    rng.shuffle(non_mineral_paths)
    required = len(train_m) + len(val_m) + len(test_m)
    if len(non_mineral_paths) < required:
        print(
            f"Warning: non-mineral images ({len(non_mineral_paths)}) are fewer than required ({required}) for exact balancing."
        )

    non_train = non_mineral_paths[: len(train_m)]
    non_val = non_mineral_paths[len(train_m): len(train_m) + len(val_m)]
    non_test = non_mineral_paths[len(train_m) + len(val_m): len(train_m) + len(val_m) + len(test_m)]

    gate_train = build_gate_rows(train_m, non_train, "train")
    gate_val = build_gate_rows(val_m, non_val, "val")
    gate_test = build_gate_rows(test_m, non_test, "test")

    # Shuffle within each split to avoid label order bias
    rng.shuffle(gate_train)
    rng.shuffle(gate_val)
    rng.shuffle(gate_test)

    multiclass_train = build_multiclass_rows(train_m, "train")
    multiclass_val = build_multiclass_rows(val_m, "val")
    multiclass_test = build_multiclass_rows(test_m, "test")

    rng.shuffle(multiclass_train)
    rng.shuffle(multiclass_val)
    rng.shuffle(multiclass_test)

    write_csv(
        BASE_DIR / "gate_train.csv",
        gate_train,
        ["image_path", "label", "label_id", "split", "site", "mineral", "source"],
    )
    write_csv(
        BASE_DIR / "gate_val.csv",
        gate_val,
        ["image_path", "label", "label_id", "split", "site", "mineral", "source"],
    )
    write_csv(
        BASE_DIR / "gate_test.csv",
        gate_test,
        ["image_path", "label", "label_id", "split", "site", "mineral", "source"],
    )

    write_csv(
        BASE_DIR / "mineral_train.csv",
        multiclass_train,
        ["image_path", "mineral", "label_id", "split", "site"],
    )
    write_csv(
        BASE_DIR / "mineral_val.csv",
        multiclass_val,
        ["image_path", "mineral", "label_id", "split", "site"],
    )
    write_csv(
        BASE_DIR / "mineral_test.csv",
        multiclass_test,
        ["image_path", "mineral", "label_id", "split", "site"],
    )

    summary = {
        "mineral_total_raw": len(mineral_records_raw),
        "mineral_total_clean": len(mineral_records),
        "mineral_train": len(train_m),
        "mineral_val": len(val_m),
        "mineral_test": len(test_m),
        "non_mineral_total_raw": len(non_mineral_paths_raw),
        "non_mineral_total_clean": len(non_mineral_paths),
        "gate_train_total": len(gate_train),
        "gate_val_total": len(gate_val),
        "gate_test_total": len(gate_test),
    }

    write_csv(
        BASE_DIR / "dataset_split_summary.csv",
        [{"metric": k, "value": v} for k, v in summary.items()],
        ["metric", "value"],
    )

    print("Created gate dataset CSVs: gate_train.csv, gate_val.csv, gate_test.csv")
    print("Created mineral dataset CSVs: mineral_train.csv, mineral_val.csv, mineral_test.csv")
    print("Created summary: dataset_split_summary.csv")
    print("---")
    for key, value in summary.items():
        print(f"{key}: {value}")


if __name__ == "__main__":
    main()
