import torch
import torch.nn as nn
import torchvision.models as models


class ImageEncoder(nn.Module):
    def __init__(self, out_dim=128):
        super().__init__()

        base = models.resnet18(weights=models.ResNet18_Weights.DEFAULT)

        self.features = nn.Sequential(*list(base.children())[:-1])
        self.fc = nn.Linear(512, out_dim)

    def forward(self, x):
        x = self.features(x)
        x = x.flatten(1)
        x = self.fc(x)
        return x


class AudioEncoder(nn.Module):
    def __init__(self, n_mfcc=20, out_dim=64):
        super().__init__()

        self.net = nn.Sequential(
            nn.Conv2d(1, 16, 3, padding=1),
            nn.ReLU(),
            nn.MaxPool2d(2),

            nn.Conv2d(16, 32, 3, padding=1),
            nn.ReLU(),
            nn.AdaptiveAvgPool2d((1, 1))
        )

        self.fc = nn.Linear(32, out_dim)

    def forward(self, x):
        # x: [B, n_mfcc, T]
        x = x.unsqueeze(1)
        x = self.net(x)
        x = x.flatten(1)
        x = self.fc(x)
        return x


class ChemicalEncoder(nn.Module):
    def __init__(self, in_dim=5, out_dim=32):
        super().__init__()

        self.net = nn.Sequential(
            nn.Linear(in_dim, 32),
            nn.ReLU(),
            nn.Linear(32, out_dim)
        )

    def forward(self, x):
        return self.net(x)


class MultiModalNet(nn.Module):
    def __init__(self, num_classes=3):
        super().__init__()

        self.image_enc = ImageEncoder(128)
        self.audio_enc = AudioEncoder(20, 64)
        self.chem_enc  = ChemicalEncoder(5, 32)

        self.classifier = nn.Sequential(
            nn.Linear(128 + 64 + 32, 128),
            nn.ReLU(),
            nn.Dropout(0.3),
            nn.Linear(128, num_classes)
        )

    def forward(self, image, audio, chemical):

        f_img = self.image_enc(image)
        f_aud = self.audio_enc(audio)
        f_chem = self.chem_enc(chemical)

        fused = torch.cat([f_img, f_aud, f_chem], dim=1)

        out = self.classifier(fused)

        return out
