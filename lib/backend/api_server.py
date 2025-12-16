"""
FastAPI server for fetal heart sound analysis
Integrates with ONNX prediction model
"""
from fastapi import FastAPI, File, UploadFile, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import uvicorn
import os
import tempfile
import shutil
from pathlib import Path
from predict_onnx import ONNXPredictor

app = FastAPI(title="GarbhSuraksha API")

# Enable CORS for Flutter web/mobile
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize ONNX predictor
MODEL_PATH = Path(__file__).parent / "model.onnx"
config = {
    'in_channel': 3,
    'duration': 5,
    'delta': True,
    'norm': True,
    'mel_bins': 128
}

predictor = None
try:
    print(f"[INFO] Loading ONNX model from: {MODEL_PATH}")
    print(f"[INFO] Model file exists: {MODEL_PATH.exists()}")
    
    if not MODEL_PATH.exists():
        print(f"[ERROR] Model file not found at: {MODEL_PATH}")
    else:
        predictor = ONNXPredictor(str(MODEL_PATH), config)
        print("[OK] ONNX model loaded successfully")
        
except ImportError as ie:
    print(f"[ERROR] Missing dependency: {ie}")
    print("[ERROR] Please install: pip install onnxruntime librosa soundfile scipy")
except Exception as e:
    print(f"[ERROR] Error loading ONNX model: {e}")
    import traceback
    traceback.print_exc()


@app.get("/")
async def root():
    """Health check endpoint"""
    return {
        "status": "online",
        "service": "GarbhSuraksha API",
        "model_loaded": predictor is not None
    }


@app.post("/analyze")
async def analyze_audio(
    audio_file: UploadFile = File(...),
    gestation_period: str = Form(...)
):
    """
    Analyze fetal heart sound audio file

    Args:
        audio_file: WAV audio file
        gestation_period: Gestation period in weeks (e.g., "24 weeks")

    Returns:
        JSON with prediction results
    """
    if predictor is None:
        raise HTTPException(
            status_code=503,
            detail="Model not loaded. Please check server logs."
        )

    # Validate audio file format
    if not audio_file.filename.lower().endswith('.wav'):
        raise HTTPException(
            status_code=400,
            detail="Only WAV audio files are supported"
        )

    # Create temporary file to save uploaded audio
    temp_dir = tempfile.gettempdir()
    temp_audio_path = os.path.join(
        temp_dir,
        f"audio_{os.urandom(8).hex()}.wav"
    )

    try:
        # Save uploaded file
        with open(temp_audio_path, "wb") as buffer:
            shutil.copyfileobj(audio_file.file, buffer)

        print(f"Processing audio: {audio_file.filename}")
        print(f"Gestation period: {gestation_period}")

        # Run prediction
        result = predictor.predict_file(temp_audio_path)

        # Add gestation period to result
        result['gestation_period'] = gestation_period
        result['original_filename'] = audio_file.filename

        # Determine status message
        if result['predicted_label'] == 'Normal':
            result['status'] = 'healthy'
            result['message'] = 'Fetal heart sounds appear normal.'
            result['recommendation'] = 'Continue regular prenatal checkups.'
        else:
            result['status'] = 'abnormal'
            result['message'] = 'Potential abnormality detected in fetal heart sounds.'
            result['recommendation'] = 'Please consult your healthcare provider immediately for further evaluation.'

        print(f"[OK] Prediction: {result['predicted_label']} ({result['confidence']:.2%})")

        return JSONResponse(content=result)

    except Exception as e:
        print(f"[ERROR] Error processing audio: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Error processing audio: {str(e)}"
        )

    finally:
        # Clean up temporary file
        if os.path.exists(temp_audio_path):
            try:
                os.remove(temp_audio_path)
            except Exception as e:
                print(f"Warning: Could not delete temp file: {e}")


@app.get("/health")
async def health_check():
    """Detailed health check"""
    return {
        "status": "healthy",
        "model_loaded": predictor is not None,
        "model_path": str(MODEL_PATH),
        "model_exists": MODEL_PATH.exists()
    }


if __name__ == "__main__":
    print("=" * 60)
    print("Starting GarbhSuraksha API Server")
    print("=" * 60)
    print(f"Model path: {MODEL_PATH}")
    print(f"Model exists: {MODEL_PATH.exists()}")
    print(f"Model loaded: {predictor is not None}")
    print("=" * 60)

    if predictor is None:
        print("\n⚠️  WARNING: Model not loaded!")
        print("The server will start but /analyze endpoint will not work.")
        print("Please check the error messages above.\n")

    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8000,
        log_level="info"
    )

