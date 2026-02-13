import os
import numpy as np
from scipy.io.wavfile import write

SAMPLE_RATE = 16000
DURATION = 3.0

BASE_DIR = "audio"

SITES = ["Kapoeta_East", "Central_Equatoria", "Yei_River"]
MINERALS = ["gold", "chalcopyrite", "hematite"]

# simple acoustic profiles per mineral
# (center frequency, decay rate)
MINERAL_PROFILES = {
    "gold":         {"freq": 1800, "decay": 6.0},
    "chalcopyrite": {"freq": 1200, "decay": 4.0},
    "hematite":     {"freq": 800,  "decay": 3.0}
}

SAMPLES_PER_CLASS = 10


def generate_tap(freq, decay):
    t = np.linspace(0, DURATION, int(SAMPLE_RATE * DURATION))

    # damped sinusoid (tap-like sound)
    signal = np.sin(2 * np.pi * freq * t) * np.exp(-decay * t)

    # small noise
    signal += 0.02 * np.random.randn(len(t))

    # normalize
    signal = signal / np.max(np.abs(signal))

    return (signal * 32767).astype(np.int16)


def main():

    for site in SITES:
        for mineral in MINERALS:

            out_dir = os.path.join(BASE_DIR, site, mineral)
            os.makedirs(out_dir, exist_ok=True)

            profile = MINERAL_PROFILES[mineral]

            for i in range(SAMPLES_PER_CLASS):

                audio = generate_tap(
                    profile["freq"],
                    profile["decay"]
                )

                filename = f"{site}_{mineral}_{i:03d}.wav"
                path = os.path.join(out_dir, filename)

                write(path, SAMPLE_RATE, audio)

                print("Generated:", path)


if __name__ == "__main__":
    main()
