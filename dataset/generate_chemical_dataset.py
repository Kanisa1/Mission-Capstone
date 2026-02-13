import os
import csv

BASE_IMAGE_DIR = "images"

SITES = ["Kapoeta_East", "Central_Equatoria", "Yei_River"]
MINERALS = ["gold", "chalcopyrite", "hematite"]

# Chemical feature template
# Order: Au, Cu, Fe, S, O

CHEMISTRY = {
    "gold":         {"Au": 1, "Cu": 0, "Fe": 0, "S": 0, "O": 0},
    "chalcopyrite": {"Au": 0, "Cu": 1, "Fe": 1, "S": 2, "O": 0},
    "hematite":     {"Au": 0, "Cu": 0, "Fe": 2, "S": 0, "O": 3}
}


def main():

    rows = []

    sample_id = 1

    for site in SITES:
        for mineral in MINERALS:

            folder = os.path.join(BASE_IMAGE_DIR, site, mineral)

            if not os.path.exists(folder):
                continue

            for filename in os.listdir(folder):

                if not filename.lower().endswith((".jpg", ".jpeg", ".png")):
                    continue

                chem = CHEMISTRY[mineral]

                rows.append([
                    f"S{sample_id:05d}",
                    site,
                    mineral,
                    chem["Au"],
                    chem["Cu"],
                    chem["Fe"],
                    chem["S"],
                    chem["O"]
                ])

                sample_id += 1

    with open("chemical.csv", "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow([
            "sample_id",
            "site",
            "mineral",
            "Au",
            "Cu",
            "Fe",
            "S",
            "O"
        ])
        writer.writerows(rows)

    print("chemical.csv created successfully.")
    print("Total samples:", len(rows))


if __name__ == "__main__":
    main()
