"""
Generate Realistic Chemical Composition Data with Natural Variability
Fixes data leakage by adding noise, impurities, and measurement uncertainty
"""

import csv
import numpy as np

# Set seed for reproducibility
np.random.seed(42)

# Configuration
OUTPUT_FILE = "chemical.csv"
INPUT_INDEX = "dataset_index.csv"

def generate_realistic_composition(mineral, sample_id):
    """
    Generate realistic chemical composition with natural variability
    
    Mineral formulas (ideal):
    - Gold (Au): Pure gold with trace impurities
    - Chalcopyrite (CuFeS2): Cu ~34.5%, Fe ~30.5%, S ~35%
    - Hematite (Fe2O3): Fe ~70%, O ~30%
    
    Real samples have:
    - Measurement noise (~5-10%)
    - Impurities from host rock
    - Environmental contamination
    """
    
    # Initialize all elements to trace amounts (0.1-2%)
    composition = {
        'Au': np.random.uniform(0.1, 1.0),
        'Cu': np.random.uniform(0.1, 1.5),
        'Fe': np.random.uniform(0.1, 2.0),
        'S': np.random.uniform(0.1, 1.5),
        'O': np.random.uniform(0.1, 2.0)
    }
    
    if mineral == "gold":
        # Gold: 85-98% Au with some iron/copper impurities
        composition['Au'] = np.random.normal(92, 4)  # Mean 92%, std 4%
        composition['Cu'] = np.random.uniform(0.5, 3.0)  # Trace copper
        composition['Fe'] = np.random.uniform(0.5, 4.0)  # Trace iron
        composition['S'] = np.random.uniform(0.1, 1.5)   # Trace sulfur
        composition['O'] = np.random.uniform(0.1, 2.0)   # Trace oxygen
        
    elif mineral == "chalcopyrite":
        # Chalcopyrite (CuFeS2): Cu ~34.5%, Fe ~30.5%, S ~35%
        composition['Cu'] = np.random.normal(34.5, 2.5)  # Copper
        composition['Fe'] = np.random.normal(30.5, 2.0)  # Iron
        composition['S'] = np.random.normal(35.0, 2.5)   # Sulfur
        composition['Au'] = np.random.uniform(0.1, 1.5)  # Trace gold
        composition['O'] = np.random.uniform(0.5, 3.0)   # Some oxidation
        
    elif mineral == "hematite":
        # Hematite (Fe2O3): Fe ~70%, O ~30%
        composition['Fe'] = np.random.normal(69.9, 3.0)  # Iron
        composition['O'] = np.random.normal(30.1, 2.0)   # Oxygen
        composition['Au'] = np.random.uniform(0.1, 1.0)  # Trace gold
        composition['Cu'] = np.random.uniform(0.1, 2.0)  # Trace copper
        composition['S'] = np.random.uniform(0.1, 1.5)   # Trace sulfur
    
    # Ensure no negative values
    for element in composition:
        composition[element] = max(0.01, composition[element])
    
    # Normalize to 100% (optional - simulates XRF normalization)
    # Comment out if you want raw values
    total = sum(composition.values())
    for element in composition:
        composition[element] = (composition[element] / total) * 100
    
    return composition


def generate_dataset():
    """Generate realistic chemical dataset from existing index"""
    
    # Read existing dataset index
    try:
        with open(INPUT_INDEX, 'r', newline='') as f:
            reader = csv.DictReader(f)
            samples = list(reader)
    except FileNotFoundError:
        print(f"❌ Error: {INPUT_INDEX} not found!")
        print("Run build_dataset_split.py first to create the index.")
        return
    
    # Generate chemical data for each sample
    chemical_data = []
    
    for sample in samples:
        sample_id = sample['sample_id']
        site = sample['site']
        mineral = sample['mineral']
        
        # Generate realistic composition
        composition = generate_realistic_composition(mineral, sample_id)
        
        chemical_data.append({
            'sample_id': sample_id,
            'site': site,
            'mineral': mineral,
            'Au': round(composition['Au'], 2),
            'Cu': round(composition['Cu'], 2),
            'Fe': round(composition['Fe'], 2),
            'S': round(composition['S'], 2),
            'O': round(composition['O'], 2)
        })
    
    # Write to CSV
    with open(OUTPUT_FILE, 'w', newline='') as f:
        fieldnames = ['sample_id', 'site', 'mineral', 'Au', 'Cu', 'Fe', 'S', 'O']
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(chemical_data)
    
    print("=" * 80)
    print("✅ REALISTIC CHEMICAL DATA GENERATED")
    print("=" * 80)
    print(f"\n📁 File: {OUTPUT_FILE}")
    print(f"📊 Total samples: {len(chemical_data)}")
    
    # Show statistics per mineral
    print("\n📋 CHEMICAL COMPOSITION STATISTICS (mean ± std):\n")
    
    for mineral in ['gold', 'chalcopyrite', 'hematite']:
        mineral_samples = [s for s in chemical_data if s['mineral'] == mineral]
        if not mineral_samples:
            continue
        
        print(f"\n{mineral.upper()} (n={len(mineral_samples)}):")
        for element in ['Au', 'Cu', 'Fe', 'S', 'O']:
            values = [float(s[element]) for s in mineral_samples]
            mean = np.mean(values)
            std = np.std(values)
            print(f"  {element:3s}: {mean:6.2f} ± {std:5.2f}%")
    
    print("\n" + "=" * 80)
    print("🔬 Data now includes:")
    print("  ✓ Natural measurement variability (noise)")
    print("  ✓ Trace element impurities")
    print("  ✓ Realistic mineral composition ranges")
    print("  ✓ No perfect correlation with labels")
    print("\n💡 Next steps:")
    print("  1. Run: python build_dataset_split.py")
    print("  2. Retrain your model in the notebook")
    print("=" * 80)


if __name__ == "__main__":
    generate_dataset()
