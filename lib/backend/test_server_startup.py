"""
Test script to diagnose server startup issues
"""
import sys
print(f"Python executable: {sys.executable}")
print(f"Python version: {sys.version}")
print()

print("Testing imports...")
try:
    import fastapi
    print(f"✓ fastapi: {fastapi.__version__}")
except Exception as e:
    print(f"✗ fastapi: {e}")

try:
    import uvicorn
    print(f"✓ uvicorn: {uvicorn.__version__}")
except Exception as e:
    print(f"✗ uvicorn: {e}")

try:
    import onnxruntime as ort
    print(f"✓ onnxruntime: {ort.__version__}")
except Exception as e:
    print(f"✗ onnxruntime: {e}")

try:
    import librosa
    print(f"✓ librosa: {librosa.__version__}")
except Exception as e:
    print(f"✗ librosa: {e}")

try:
    import soundfile
    print(f"✓ soundfile: {soundfile.__version__}")
except Exception as e:
    print(f"✗ soundfile: {e}")

try:
    import scipy
    print(f"✓ scipy: {scipy.__version__}")
except Exception as e:
    print(f"✗ scipy: {e}")

print()
print("Testing model loading...")
try:
    from pathlib import Path
    from predict_onnx import ONNXPredictor

    MODEL_PATH = Path(__file__).parent / "model.onnx"
    print(f"Model path: {MODEL_PATH}")
    print(f"Model exists: {MODEL_PATH.exists()}")

    config = {
        'in_channel': 3,
        'duration': 5,
        'delta': True,
        'norm': True,
        'mel_bins': 128
    }

    predictor = ONNXPredictor(str(MODEL_PATH), config)
    print("✓ Model loaded successfully!")

except Exception as e:
    print(f"✗ Model loading failed: {e}")
    import traceback
    traceback.print_exc()

print()
print("All tests complete!")

