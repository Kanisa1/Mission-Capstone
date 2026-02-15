"""
Save Chemical Feature Scaler Parameters
This script saves the StandardScaler parameters used during training
so the API can use the same normalization.
"""

import pandas as pd
import pickle
from sklearn.preprocessing import StandardScaler

# Load training data
train_df = pd.read_csv('train.csv')

# Extract chemical features
chem_features = ['Au', 'Cu', 'Fe', 'S', 'O']
chem_data = train_df[chem_features].values

# Fit scaler
scaler = StandardScaler()
scaler.fit(chem_data)

# Save scaler
with open('chemical_scaler.pkl', 'wb') as f:
    pickle.dump(scaler, f)

print("✅ Chemical scaler saved successfully!")
print(f"\n📊 Scaler Statistics:")
print(f"   Mean values: {scaler.mean_}")
print(f"   Std values:  {scaler.scale_}")
print(f"\nFile saved: chemical_scaler.pkl")
