from multimodal_dataset import MultiModalDataset
from torch.utils.data import DataLoader

train_ds = MultiModalDataset("train.csv")
train_loader = DataLoader(train_ds, batch_size=4, shuffle=True)

images, audios, chems, labels = next(iter(train_loader))

print(images.shape)
print(audios.shape)
print(chems.shape)
print(labels)
