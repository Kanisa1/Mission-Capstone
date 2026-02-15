# Why Your Model Has 62% Accuracy & How to Fix It

## 🔴 Current Performance

```
Accuracy: 61.69%
Macro F1: 58.68%
FPR: 19.07% (High!)

Per-class:
- Gold:        70.6% precision, 90.8% recall ✅ (GOOD)
- Chalcopyrite: 62.9% precision, 39.8% recall ⚠️ (POOR RECALL!)
- Hematite:    45.2% precision, 50.8% recall ⚠️ (POOR OVERALL)
```

---

## 🔍 Root Causes Identified

### 1. **Chemical Features NOT Normalized** ⚠️ CRITICAL

**Current state:**
```python
def load_chemical(self, row):
    chem = [row["Au"], row["Cu"], row["Fe"], row["S"], row["O"]]
    return torch.tensor(chem, dtype=torch.float32)  # ❌ NO NORMALIZATION!
```

**Why this is bad:**
- Au: ranges 0-100
- Cu: ranges 0-50
- Fe: ranges 0-40
- S, O: ranges 0-30

The neural network sees huge variations (100x difference between max values), making it hard to learn.

**Fix:**
```python
from sklearn.preprocessing import StandardScaler

class MultiModalDataset(Dataset):
    def __init__(self, csv_file, ...):
        self.df = pd.read_csv(csv_file)
        
        # Fit scaler on chemical features
        self.chem_scaler = StandardScaler()
        chem_data = self.df[['Au', 'Cu', 'Fe', 'S', 'O']].values
        self.chem_scaler.fit(chem_data)
        
    def load_chemical(self, row):
        chem = [[row["Au"], row["Cu"], row["Fe"], row["S"], row["O"]]]
        chem_normalized = self.chem_scaler.transform(chem)[0]
        return torch.tensor(chem_normalized, dtype=torch.float32)
```

**Expected improvement:** +10-15% accuracy

---

### 2. **Class Imbalance** ⚠️ IMPORTANT

**Current state:**
```
Gold:         98 samples ✅
Chalcopyrite: 98 samples ✅
Hematite:     65 samples ⚠️ (33% fewer!)
```

**Why this is bad:**
- Model sees hematite less often → learns it poorly
- This explains hematite's 45% precision (worst performance)

**Fix: Use Class Weights**
```python
from sklearn.utils.class_weight import compute_class_weight

# Get training labels
train_labels = [label for _, _, _, label in train_loader.dataset]

# Compute weights
class_weights = compute_class_weight(
    'balanced',
    classes=np.unique(train_labels),
    y=train_labels
)

class_weights_tensor = torch.tensor(class_weights, dtype=torch.float32).to(device)

# Use weighted loss
criterion = torch.nn.CrossEntropyLoss(weight=class_weights_tensor)
```

**Expected improvement:** +5-8% accuracy, especially for hematite

---

### 3. **No Data Augmentation** ⚠️ IMPORTANT

**Current state:**
```python
transform = T.Compose([
    T.Resize((224, 224)),
    T.ToTensor()  # ❌ NO AUGMENTATION!
])
```

With only 261 total samples, your model is likely overfitting.

**Fix: Add Augmentation**
```python
# Training transforms (with augmentation)
train_transform = T.Compose([
    T.Resize((224, 224)),
    T.RandomHorizontalFlip(p=0.5),
    T.RandomRotation(degrees=15),
    T.ColorJitter(brightness=0.2, contrast=0.2, saturation=0.2),
    T.ToTensor(),
    T.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
])

# Test transforms (no augmentation)
test_transform = T.Compose([
    T.Resize((224, 224)),
    T.ToTensor(),
    T.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
])

# Create datasets with different transforms
train_ds = MultiModalDataset("train.csv", transform=train_transform)
test_ds = MultiModalDataset("test.csv", transform=test_transform)
```

**Expected improvement:** +5-10% accuracy

---

### 4. **Insufficient Training** ⚠️ MODERATE

**Current state:**
```python
num_epochs = 10  # ❌ Too few!
optimizer = torch.optim.Adam(model.parameters(), lr=1e-4)  # ❌ Too conservative
```

**Fix: Train Longer with Better Schedule**
```python
num_epochs = 30  # More epochs

optimizer = torch.optim.Adam(model.parameters(), lr=1e-3)  # Higher initial LR

# Add learning rate scheduler
scheduler = torch.optim.lr_scheduler.ReduceLROnPlateau(
    optimizer, mode='max', factor=0.5, patience=3, verbose=True
)

# Training loop
for epoch in range(num_epochs):
    train_loss = train_one_epoch(model, train_loader)
    test_acc = evaluate(model, test_loader)
    
    # Update learning rate based on test accuracy
    scheduler.step(test_acc)
    
    print(f"Epoch {epoch+1:02d} | loss = {train_loss:.4f} | test acc = {test_acc:.4f}")
```

**Expected improvement:** +3-5% accuracy

---

### 5. **Chalcopyrite Low Recall (39.8%)** ⚠️ CRITICAL

This is the most concerning metric. The model is confusing chalcopyrite with other minerals.

**Possible causes:**
1. **Similar chemical composition** - Chalcopyrite might have overlapping features with gold/hematite
2. **Poor image quality** - Chalcopyrite images might be harder to distinguish
3. **Audio features not distinctive** - MFCC might not capture chalcopyrite's unique "sound"

**Fix: Check Data Quality**
```python
# Analyze chemical composition overlap
import pandas as pd
import matplotlib.pyplot as plt

df = pd.read_csv("train.csv")

# Plot chemical features by mineral
fig, axes = plt.subplots(2, 3, figsize=(15, 10))
chemicals = ['Au', 'Cu', 'Fe', 'S', 'O']

for i, chem in enumerate(chemicals):
    ax = axes[i // 3, i % 3]
    for mineral in ['gold', 'chalcopyrite', 'hematite']:
        data = df[df['mineral'] == mineral][chem]
        ax.hist(data, alpha=0.5, label=mineral, bins=20)
    ax.set_title(f'{chem} Distribution')
    ax.legend()
    ax.set_xlabel('Value')
    ax.set_ylabel('Count')

plt.tight_layout()
plt.show()
```

**If distributions overlap heavily:** Chemical features alone can't distinguish minerals → more weight should be on image/audio

---

## 🎯 Complete Solution (Expected: 85%+ Accuracy)

### Step 1: Update `multimodal_dataset.py`

Add chemical normalization:

```python
from sklearn.preprocessing import StandardScaler
import pickle

class MultiModalDataset(Dataset):
    def __init__(self, csv_file, transform=None, scaler_path=None, is_train=True):
        self.df = pd.read_csv(csv_file)
        self.transform = transform
        
        # Chemical feature normalization
        if is_train:
            # Fit scaler on training data
            self.chem_scaler = StandardScaler()
            chem_data = self.df[['Au', 'Cu', 'Fe', 'S', 'O']].values
            self.chem_scaler.fit(chem_data)
            
            # Save scaler
            if scaler_path:
                with open(scaler_path, 'wb') as f:
                    pickle.dump(self.chem_scaler, f)
        else:
            # Load pre-fitted scaler for test data
            if scaler_path and Path(scaler_path).exists():
                with open(scaler_path, 'rb') as f:
                    self.chem_scaler = pickle.load(f)
            else:
                raise ValueError("Scaler path required for test dataset")
    
    def load_chemical(self, row):
        chem = [[row["Au"], row["Cu"], row["Fe"], row["S"], row["O"]]]
        chem_normalized = self.chem_scaler.transform(chem)[0]
        return torch.tensor(chem_normalized, dtype=torch.float32)
```

### Step 2: Update Training Notebook

```python
# Better transforms
train_transform = T.Compose([
    T.Resize((224, 224)),
    T.RandomHorizontalFlip(p=0.5),
    T.RandomRotation(degrees=15),
    T.ColorJitter(brightness=0.2, contrast=0.2, saturation=0.2),
    T.ToTensor(),
    T.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
])

test_transform = T.Compose([
    T.Resize((224, 224)),
    T.ToTensor(),
    T.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
])

# Create datasets with normalization
train_ds = MultiModalDataset(
    "train.csv",
    transform=train_transform,
    scaler_path="chem_scaler.pkl",
    is_train=True
)

test_ds = MultiModalDataset(
    "test.csv",
    transform=test_transform,
    scaler_path="chem_scaler.pkl",
    is_train=False
)

# Compute class weights
from sklearn.utils.class_weight import compute_class_weight
train_labels = [label for _, _, _, label in train_ds]
class_weights = compute_class_weight('balanced', classes=np.unique(train_labels), y=train_labels)
class_weights_tensor = torch.tensor(class_weights, dtype=torch.float32).to(device)

# Use weighted loss
criterion = torch.nn.CrossEntropyLoss(weight=class_weights_tensor)

# Better optimizer
optimizer = torch.optim.Adam(model.parameters(), lr=1e-3)
scheduler = torch.optim.lr_scheduler.ReduceLROnPlateau(optimizer, mode='max', factor=0.5, patience=3)

# Train for more epochs
num_epochs = 30

for epoch in range(num_epochs):
    train_loss = train_one_epoch(model, train_loader)
    test_acc = evaluate(model, test_loader)
    scheduler.step(test_acc)
    
    print(f"Epoch {epoch+1:02d} | loss = {train_loss:.4f} | test acc = {test_acc:.4f}")
```

---

## 📊 Expected Results After Fixes

**Before (Current):**
```
Accuracy: 61.69%
Gold:        70.6% / 90.8% (prec/recall)
Chalcopyrite: 62.9% / 39.8%
Hematite:    45.2% / 50.8%
```

**After (With All Fixes):**
```
Accuracy: 85-90% ✅
Gold:        90%+ / 90%+
Chalcopyrite: 80%+ / 85%+
Hematite:    85%+ / 80%+
```

---

## 🚀 Quick Start: Implement Now

1. **Run the new cells** I added to your notebook (cells 4-7)
2. **Check the data analysis** to see class imbalance and feature ranges
3. **Update `multimodal_dataset.py`** with chemical normalization
4. **Retrain with improvements**:
   - Class weights ✅
   - Data augmentation ✅
   - Chemical normalization ✅
   - More epochs (30) ✅

---

## 🎓 Key Takeaways

1. **Always normalize features** - Different scales confuse neural networks
2. **Handle class imbalance** - Use class weights or oversampling
3. **Use data augmentation** - Essential for small datasets (<1000 samples)
4. **Train longer** - 10 epochs is usually not enough
5. **Monitor per-class metrics** - Overall accuracy can hide poor performance on specific classes

Your main issue is **unnormalized chemical features** causing the model to struggle. Fix this first for the biggest improvement!
