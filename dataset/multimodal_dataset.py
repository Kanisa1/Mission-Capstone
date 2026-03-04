import torch
from torch.utils.data import Dataset
import pandas as pd
from PIL import Image
import librosa
import numpy as np
from sklearn.preprocessing import StandardScaler


MINERAL_TO_LABEL = {
    "gold": 0,
    "chalcopyrite": 1,
    "hematite": 2
}



class MultiModalDataset(Dataset):

    def __init__(
        self,
        csv_file,
        image_size=224,
        audio_sr=16000,
        n_mfcc=20,
        transform=None,
        chem_scaler=None,
        fit_scaler=True,
    ):
        self.df = pd.read_csv(csv_file)
        self.image_size = image_size
        self.audio_sr = audio_sr
        self.n_mfcc = n_mfcc
        self.transform = transform
        
        # ✅ FIX: Normalize chemical features to handle different scales
        # Au: 0-100, Cu: 0-50, Fe: 0-40, S/O: 0-30
        if chem_scaler is not None:
            self.chem_scaler = chem_scaler
            print(f"✅ Chemical scaler reused for {csv_file}")
        else:
            self.chem_scaler = StandardScaler()
            chem_data = self.df[['Au', 'Cu', 'Fe', 'S', 'O']].values
            if fit_scaler:
                self.chem_scaler.fit(chem_data)
                print(f"✅ Chemical features normalized for {csv_file}")

    def __len__(self):
        return len(self.df)

    def load_image(self, path):
        img = Image.open(path).convert("RGB")

        if self.transform is not None:
            img = self.transform(img)
        else:
            img = img.resize((self.image_size, self.image_size))
            img = torch.from_numpy(np.array(img)).permute(2, 0, 1).float() / 255.0

        return img

    def load_audio(self, path):
        y, sr = librosa.load(path, sr=self.audio_sr, mono=True)

        mfcc = librosa.feature.mfcc(
            y=y,
            sr=sr,
            n_mfcc=self.n_mfcc
        )

        # normalize per sample
        mfcc = (mfcc - mfcc.mean()) / (mfcc.std() + 1e-8)

        return torch.tensor(mfcc, dtype=torch.float32)

    def load_chemical(self, row):
        # Get raw chemical values
        chem = [
            row["Au"],
            row["Cu"],
            row["Fe"],
            row["S"],
            row["O"]
        ]
        
        # ✅ FIX: Normalize using StandardScaler (CRITICAL for accuracy!)
        chem_normalized = self.chem_scaler.transform([chem])[0]
        
        return torch.tensor(chem_normalized, dtype=torch.float32)

    def __getitem__(self, idx):

        row = self.df.iloc[idx]

        image = self.load_image(row["image_path"])
        audio = self.load_audio(row["audio_path"])
        chemical = self.load_chemical(row)

        label = MINERAL_TO_LABEL[row["mineral"]]


        return image, audio, chemical, label
