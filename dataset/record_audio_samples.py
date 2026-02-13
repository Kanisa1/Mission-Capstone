import os
import sounddevice as sd
from scipy.io.wavfile import write

SAMPLE_RATE = 16000
DURATION = 3   # seconds

BASE_DIR = "dataset/audio"

SITES = ["Kapoeta_East", "Central_Equatoria", "Yei_River"]
MINERALS = ["gold", "chalcopyrite", "hematite"]


def create_audio_folders():
    for site in SITES:
        for mineral in MINERALS:
            path = os.path.join(BASE_DIR, site, mineral)
            os.makedirs(path, exist_ok=True)


def main():

    # create full folder structure first
    create_audio_folders()

    print("\nAvailable sites:")
    for s in SITES:
        print("-", s)

    site = input("\nSelect site: ").strip()

    print("\nAvailable minerals:")
    for m in MINERALS:
        print("-", m)

    mineral = input("\nSelect mineral: ").strip()

    if site not in SITES or mineral not in MINERALS:
        print("Invalid site or mineral")
        return

    out_dir = os.path.join(BASE_DIR, site, mineral)

    # count only wav files
    existing = [
        f for f in os.listdir(out_dir)
        if f.lower().endswith(".wav")
    ]

    index = len(existing)

    print("\nRecording will start when you press Enter.")
    input()

    print("Recording for", DURATION, "seconds... Tap your sample now!")

    audio = sd.rec(
        int(DURATION * SAMPLE_RATE),
        samplerate=SAMPLE_RATE,
        channels=1,
        dtype="int16"
    )
    sd.wait()

    filename = f"{site}_{mineral}_{index:03d}.wav"
    path = os.path.join(out_dir, filename)

    write(path, SAMPLE_RATE, audio)

    print("\nSaved:", path)


if __name__ == "__main__":
    main()
