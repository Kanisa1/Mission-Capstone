"""
Enhanced Multimodal Model with Optional Modalities Support
Supports: Image only, Audio only, Image+Audio, or all three modalities
"""

import torch
import torch.nn as nn
import torchvision.models as models
import logging

logger = logging.getLogger(__name__)


class ImageEncoder(nn.Module):
    def __init__(self, out_dim=128):
        super().__init__()

        base = models.resnet18(weights=models.ResNet18_Weights.DEFAULT)

        self.features = nn.Sequential(*list(base.children())[:-1])
        self.fc = nn.Linear(512, out_dim)
        self.out_dim = out_dim

    def forward(self, x):
        if x is None:
            # Return zero embedding if image is missing
            return torch.zeros(1, self.out_dim, device=next(self.parameters()).device)
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
        self.out_dim = out_dim

    def forward(self, x):
        if x is None:
            # Return zero embedding if audio is missing
            return torch.zeros(1, self.out_dim, device=next(self.parameters()).device)
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
        self.out_dim = out_dim
        self.in_dim = in_dim

    def forward(self, x):
        if x is None:
            # Return zero embedding if chemistry is missing
            return torch.zeros(1, self.out_dim, device=next(self.parameters()).device)
        return self.net(x)


class MultiModalNet(nn.Module):
    """
    Enhanced multimodal network that supports missing modalities
    Maintains backward compatibility with old API (image, audio, chemical as required args)
    New API supports optional parameters (image=None, audio=None, chemical=None)
    """
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

    def forward(self, image=None, audio=None, chemical=None):
        """
        Forward pass with optional modalities
        
        Args:
            image: Optional[Tensor] - Image tensor or None
            audio: Optional[Tensor] - Audio tensor or None
            chemical: Optional[Tensor] - Chemical tensor or None
            
        Returns:
            Tensor: Classification logits
        """
        # Encode each modality (or use zeros if missing)
        f_img = self.image_enc(image)
        f_aud = self.audio_enc(audio)
        f_chem = self.chem_enc(chemical)

        # Concatenate all features (including zero embeddings for missing modalities)
        fused = torch.cat([f_img, f_aud, f_chem], dim=1)

        # Classify
        out = self.classifier(fused)

        return out

    def extract_fingerprint(self, image=None, audio=None, chemical=None):
        """
        Extract fingerprint embedding without classification
        
        Returns:
            Tuple[Tensor, dict]: (fingerprint, modalities_used)
        """
        with torch.no_grad():
            modalities_used = {
                'image': image is not None,
                'audio': audio is not None,
                'chemical': chemical is not None
            }
            
            # Encode each modality
            f_img = self.image_enc(image)
            f_aud = self.audio_enc(audio)
            f_chem = self.chem_enc(chemical)
            
            # Concatenate to create fingerprint
            fingerprint = torch.cat([f_img, f_aud, f_chem], dim=1)
            
            return fingerprint, modalities_used


def load_model_with_compatibility(model_path, device='cpu'):
    """
    Load model with backward compatibility
    Handles both old and new model architectures
    """
    try:
        model = MultiModalNet(num_classes=3)
        state_dict = torch.load(model_path, map_location=device)
        model.load_state_dict(state_dict)
        logger.info(f"Loaded model from {model_path} successfully")
    except Exception as e:
        logger.error(f"Failed to load model: {e}")
        raise
    
    model.to(device)
    model.eval()
    return model
