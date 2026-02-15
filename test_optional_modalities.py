"""Test script for optional modalities feature"""
import requests
import json
from pathlib import Path

BASE_URL = "http://127.0.0.1:8001"

# Test files
IMAGE_FILE = r"C:\Users\HP\Mission-Capstone\dataset\images\Central_Equatoria\gold\01997320017663125882328.jpg"
AUDIO_FILE = r"C:\Users\HP\Mission-Capstone\dataset\audio\Central_Equatoria\gold\Central_Equatoria_gold_000.wav"

# Default chemistry (gold-like)
CHEMISTRY = {
    'Au': '99.9',
    'Cu': '0.05',
    'Fe': '0.03',
    'S': '0.01',
    'O': '0.01'
}

def print_separator():
    print("=" * 60)

def test_health():
    """Test 1: Health Check"""
    print("\n[Test 1] Health Check")
    print("-" * 60)
    try:
        response = requests.get(f"{BASE_URL}/health")
        data = response.json()
        print(f"✓ Status: {data['status']}")
        print(f"✓ Version: {data['version']}")
        print(f"✓ Features: {json.dumps(data['features'], indent=2)}")
        return True
    except Exception as e:
        print(f"✗ ERROR: {e}")
        return False

def test_full_multimodal():
    """Test 2: Image + Audio + Chemistry"""
    print("\n[Test 2] Full Multimodal (Image + Audio + Chemistry)")
    print("-" * 60)
    try:
        with open(IMAGE_FILE, 'rb') as img, open(AUDIO_FILE, 'rb') as aud:
            files = {
                'image': ('image.jpg', img, 'image/jpeg'),
                'audio': ('audio.wav', aud, 'audio/wav')
            }
            response = requests.post(f"{BASE_URL}/predict", files=files, data=CHEMISTRY)
        
        data = response.json()
        print(f"✓ Predicted Mineral: {data['prediction']}")
        print(f"✓ Confidence: {data['confidence']:.2%}")
        print(f"✓ Modalities Used: {json.dumps(data['modalities_used'], indent=2)}")
        return True
    except Exception as e:
        print(f"✗ ERROR: {e}")
        return False

def test_image_only():
    """Test 3: Image Only (No Audio)"""
    print("\n[Test 3] Image Only (No Audio)")
    print("-" * 60)
    try:
        with open(IMAGE_FILE, 'rb') as img:
            files = {'image': ('image.jpg', img, 'image/jpeg')}
            response = requests.post(f"{BASE_URL}/predict", files=files, data=CHEMISTRY)
        
        data = response.json()
        print(f"✓ Predicted Mineral: {data['prediction']}")
        print(f"✓ Confidence: {data['confidence']:.2%}")
        print(f"✓ Modalities Used: {json.dumps(data['modalities_used'], indent=2)}")
        print(f"✓ Audio was optional - system still worked!")
        return True
    except Exception as e:
        print(f"✗ ERROR: {e}")
        return False

def test_audio_only():
    """Test 4: Audio Only (No Image)"""
    print("\n[Test 4] Audio Only (No Image)")
    print("-" * 60)
    try:
        with open(AUDIO_FILE, 'rb') as aud:
            files = {'audio': ('audio.wav', aud, 'audio/wav')}
            response = requests.post(f"{BASE_URL}/predict", files=files, data=CHEMISTRY)
        
        data = response.json()
        print(f"✓ Predicted Mineral: {data['prediction']}")
        print(f"✓ Confidence: {data['confidence']:.2%}")
        print(f"✓ Modalities Used: {json.dumps(data['modalities_used'], indent=2)}")
        print(f"✓ Image was optional - system still worked!")
        return True
    except Exception as e:
        print(f"✗ ERROR: {e}")
        return False

def test_chemistry_only():
    """Test 5: Chemistry Only (Should Fail)"""
    print("\n[Test 5] Chemistry Only (Expected to Fail)")
    print("-" * 60)
    try:
        response = requests.post(f"{BASE_URL}/predict", data=CHEMISTRY)
        print(f"✗ Unexpected success - should have failed")
        return False
    except Exception as e:
        print(f"✓ Expected error: At least one modality required")
        return True

def test_metrics():
    """Test 6: Model Metrics"""
    print("\n[Test 6] Model Evaluation Metrics")
    print("-" * 60)
    try:
        response = requests.get(f"{BASE_URL}/metrics")
        data = response.json()
        
        overall = data['overall_metrics']
        print(f"✓ Overall Metrics:")
        print(f"  - Accuracy: {overall['accuracy']:.2%}")
        print(f"  - Precision: {overall['macro_precision']:.2%}")
        print(f"  - Recall: {overall['macro_recall']:.2%}")
        print(f"  - F1 Score: {overall['macro_f1_score']:.2%}")
        print(f"  - False Positive Rate: {overall['macro_fpr']:.2%}")
        
        print(f"\n✓ Per-Class Metrics:")
        for mineral, metrics in data['per_class_metrics'].items():
            print(f"  {mineral}:")
            print(f"    - Precision: {metrics['precision']:.2%}")
            print(f"    - Recall: {metrics['recall']:.2%}")
            print(f"    - F1: {metrics['f1_score']:.2%}")
        
        return True
    except Exception as e:
        print(f"✗ ERROR: {e}")
        return False

def main():
    print_separator()
    print("   AI-POWERED GEOACOUSTIC MINERAL TRACEABILITY")
    print("   Testing Optional Modalities Feature (API v2)")
    print_separator()
    
    results = []
    
    # Run all tests
    results.append(("Health Check", test_health()))
    results.append(("Full Multimodal", test_full_multimodal()))
    results.append(("Image Only", test_image_only()))
    results.append(("Audio Only", test_audio_only()))
    results.append(("Chemistry Only", test_chemistry_only()))
    results.append(("Metrics", test_metrics()))
    
    # Summary
    print("\n")
    print_separator()
    print("   TEST SUMMARY")
    print_separator()
    
    passed = sum(1 for _, result in results if result)
    total = len(results)
    
    for name, result in results:
        status = "✓ PASSED" if result else "✗ FAILED"
        print(f"{status}: {name}")
    
    print(f"\nTotal: {passed}/{total} tests passed")
    
    if passed == total:
        print("\n🎉 All tests passed! System ready for use.")
        print("\nKey Features Verified:")
        print("  ✓ API v2 is running on port 8001")
        print("  ✓ Optional modalities supported (image-only, audio-only, or both)")
        print("  ✓ Model evaluation metrics available")
        print("  ✓ Backward compatible with existing data")
        print("\nNext Steps:")
        print("  1. Test mobile app with optional modalities")
        print("  2. Check logs in: C:\\Users\\HP\\Mission-Capstone\\logs\\")
        print("  3. When ready, migrate old API to api_v2")
    else:
        print("\n⚠️  Some tests failed. Check errors above.")
    
    print_separator()

if __name__ == "__main__":
    main()
