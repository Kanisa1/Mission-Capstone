import os
import csv
import random

IMAGE_DIR = "images"
AUDIO_DIR = "audio"
CHEM_FILE = "chemical.csv"

SITES = ["Kapoeta_East", "Central_Equatoria", "Yei_River"]
MINERALS = ["gold", "chalcopyrite", "hematite"]

TRAIN_SITES = ["Kapoeta_East", "Central_Equatoria"]
TEST_SITES  = ["Yei_River"]


def load_chemical_data():
    chem = {}
    with open(CHEM_FILE, newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            chem[row["sample_id"]] = row
    return chem


def main():

    chemical = load_chemical_data()

    all_rows = []

    sample_counter = 1

    for site in SITES:
        for mineral in MINERALS:

            img_dir = os.path.join(IMAGE_DIR, site, mineral)
            aud_dir = os.path.join(AUDIO_DIR, site, mineral)

            if not os.path.exists(img_dir):
                continue

            images = sorted([
                f for f in os.listdir(img_dir)
                if f.lower().endswith((".jpg", ".png", ".jpeg"))
            ])

            audios = []
            if os.path.exists(aud_dir):
                audios = sorted([
                    f for f in os.listdir(aud_dir)
                    if f.lower().endswith(".wav")
                ])

            for img in images:

                # randomly assign an audio from same site+mineral
                audio_path = ""
                if len(audios) > 0:
                    audio_file = random.choice(audios)
                    audio_path = os.path.join(aud_dir, audio_file)

                image_path = os.path.join(img_dir, img)

                sample_id = f"S{sample_counter:05d}"

                # find any chemical row of same mineral
                # (your chemical vectors are mineral-level)
                chem_row = None
                for r in chemical.values():
                    if r["mineral"] == mineral:
                        chem_row = r
                        break

                if chem_row is None:
                    continue

                all_rows.append({
                    "sample_id": sample_id,
                    "site": site,
                    "mineral": mineral,
                    "image_path": image_path,
                    "audio_path": audio_path,
                    "Au": chem_row["Au"],
                    "Cu": chem_row["Cu"],
                    "Fe": chem_row["Fe"],
                    "S": chem_row["S"],
                    "O": chem_row["O"]
                })

                sample_counter += 1

    if len(all_rows) == 0:
        print("No samples found. Check your images/audio folders and chemical.csv location.")
        return

    # save full index
    with open("dataset_index.csv", "w", newline="") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=list(all_rows[0].keys())
        )
        writer.writeheader()
        writer.writerows(all_rows)

    # site-wise split
    train_rows = [r for r in all_rows if r["site"] in TRAIN_SITES]
    test_rows  = [r for r in all_rows if r["site"] in TEST_SITES]

    with open("train.csv", "w", newline="") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=list(train_rows[0].keys())
        )
        writer.writeheader()
        writer.writerows(train_rows)

    with open("test.csv", "w", newline="") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=list(test_rows[0].keys())
        )
        writer.writeheader()
        writer.writerows(test_rows)

    print("Done.")
    print("Total samples:", len(all_rows))
    print("Train samples:", len(train_rows))
    print("Test samples :", len(test_rows))


if __name__ == "__main__":
    main()
