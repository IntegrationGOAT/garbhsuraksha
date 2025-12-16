# 🔌 GarbhSuraksha API Documentation

## 📋 Overview

**GarbhSuraksha** uses a **FastAPI** backend server to analyze fetal heart sound audio files using an **ONNX** machine learning model.

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    GarbhSuraksha App                        │
│                      (Flutter)                              │
└──────────────────────────┬──────────────────────────────────┘
                           │ HTTP/REST API
                           │
┌──────────────────────────▼──────────────────────────────────┐
│                     FastAPI Server                          │
│                   (Python Backend)                          │
│                                                             │
│  • Port: 8000                                              │
│  • Protocol: HTTP                                          │
│  • Format: JSON + Multipart Form Data                     │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│                   ONNX Predictor                            │
│                 (Machine Learning Model)                    │
│                                                             │
│  • Model File: model.onnx                                  │
│  • Framework: ONNX Runtime                                 │
│  • Input: WAV audio files                                  │
│  • Output: Normal/Abnormal prediction                      │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔧 Technology Stack

### Backend API
- **Framework:** [FastAPI](https://fastapi.tiangolo.com/) (Python)
- **Server:** Uvicorn (ASGI server)
- **Version:** Python 3.x
- **Port:** 8000

### Machine Learning
- **Model Format:** ONNX (Open Neural Network Exchange)
- **Runtime:** ONNX Runtime
- **Audio Processing:** Librosa, SoundFile, SciPy
- **Features:** Mel-spectrogram analysis

### Frontend Communication
- **Protocol:** HTTP/REST
- **Client Library:** `http` package (Dart)
- **Data Format:** JSON + Multipart form data
- **CORS:** Enabled for all origins

---

## 📡 API Endpoints

### 1. Root Endpoint
```http
GET http://localhost:8000/
```

**Response:**
```json
{
  "status": "online",
  "service": "GarbhSuraksha API",
  "model_loaded": true
}
```

**Purpose:** Quick status check

---

### 2. Health Check
```http
GET http://localhost:8000/health
```

**Response:**
```json
{
  "status": "healthy",
  "model_loaded": true,
  "model_path": "C:\\...\\model.onnx",
  "model_exists": true
}
```

**Purpose:** Detailed health and model status

**Used By:** 
- App startup to verify server availability
- Server configuration test
- Automated monitoring

---

### 3. Analyze Audio (Main Endpoint)
```http
POST http://localhost:8000/analyze
```

**Content-Type:** `multipart/form-data`

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `audio_file` | File | Yes | WAV audio file of fetal heart sounds |
| `gestation_period` | String | Yes | Gestation period (e.g., "24 weeks") |

**Example Request (cURL):**
```bash
curl -X POST http://localhost:8000/analyze \
  -F "audio_file=@recording.wav" \
  -F "gestation_period=24 weeks"
```

**Example Request (Flutter):**
```dart
var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/analyze'));
request.fields['gestation_period'] = '24 weeks';
request.files.add(await http.MultipartFile.fromPath(
  'audio_file',
  audioFilePath,
  filename: 'recording.wav',
));
final response = await request.send();
```

**Success Response (200 OK):**
```json
{
  "predicted_label": "Normal",
  "confidence": 0.9271,
  "probabilities": {
    "Normal": 0.0729,
    "Abnormal": 0.9271
  },
  "gestation_period": "24 weeks",
  "original_filename": "recording.wav",
  "status": "healthy",
  "message": "Fetal heart sounds appear normal.",
  "recommendation": "Continue regular prenatal checkups."
}
```

**Error Response (400 Bad Request):**
```json
{
  "detail": "Only WAV audio files are supported"
}
```

**Error Response (503 Service Unavailable):**
```json
{
  "detail": "Model not loaded. Please check server logs."
}
```

**Error Response (500 Internal Server Error):**
```json
{
  "detail": "Error processing audio: [error message]"
}
```

---

## 🔐 Security & CORS

### CORS Configuration
```python
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],        # Allows all origins
    allow_credentials=True,     # Allows cookies
    allow_methods=["*"],        # Allows all HTTP methods
    allow_headers=["*"],        # Allows all headers
)
```

**Note:** In production, you should restrict `allow_origins` to specific domains.

### Network Binding
```python
uvicorn.run(app, host="0.0.0.0", port=8000)
```
- **0.0.0.0:** Listens on all network interfaces
- Allows connections from:
  - localhost (127.0.0.1)
  - LAN devices (192.168.x.x)
  - External networks (if router allows)

---

## 📊 API Response Structure

### AnalysisResult Class (Dart)
```dart
class AnalysisResult {
  final String predictedLabel;      // "Normal" or "Abnormal"
  final double confidence;           // 0.0 to 1.0
  final String status;               // "healthy" or "abnormal"
  final String message;              // User-friendly message
  final String recommendation;       // Medical recommendation
  final Map<String, double> probabilities;  // All class probabilities
  final String gestationPeriod;      // Echo back input
}
```

### Prediction Labels
- **"Normal":** Healthy fetal heart sounds
- **"Abnormal":** Potential abnormality detected

### Status Values
- **"healthy":** Normal prediction
- **"abnormal":** Abnormal prediction
- **"unknown":** Error or indeterminate

---

## 🧪 Testing the API

### Method 1: Browser
Visit: `http://localhost:8000/health`

### Method 2: cURL (Command Line)
```bash
# Health check
curl http://localhost:8000/health

# Analyze audio
curl -X POST http://localhost:8000/analyze \
  -F "audio_file=@test.wav" \
  -F "gestation_period=30 weeks"
```

### Method 3: Python
```python
import requests

# Health check
response = requests.get('http://localhost:8000/health')
print(response.json())

# Analyze audio
files = {'audio_file': open('test.wav', 'rb')}
data = {'gestation_period': '30 weeks'}
response = requests.post('http://localhost:8000/analyze', files=files, data=data)
print(response.json())
```

### Method 4: Postman
1. Create new POST request
2. URL: `http://localhost:8000/analyze`
3. Body → form-data
4. Add `audio_file` (File) → Select WAV file
5. Add `gestation_period` (Text) → "24 weeks"
6. Send

---

## 🌐 Server URLs by Platform

### Desktop (Windows/Mac/Linux)
```
http://localhost:8000
```

### Android Emulator
```
http://10.0.2.2:8000
```
*(10.0.2.2 is special emulator alias for host's localhost)*

### iOS Simulator
```
http://localhost:8000
```

### Physical Android/iOS Device
```
http://YOUR_COMPUTER_IP:8000
```
*Example: `http://192.168.1.100:8000`*

### Web (Flutter Web)
```
http://localhost:8000
```

### Production (Cloud Deployment)
```
https://your-app.railway.app
https://your-app.herokuapp.com
https://your-domain.com
```

---

## 🔄 Request/Response Flow

1. **User Action:** Records/uploads audio in Flutter app
2. **Client:** Creates multipart form request
3. **Network:** Sends HTTP POST to `/analyze` endpoint
4. **Server:** Receives request at FastAPI endpoint
5. **Validation:** Checks file format (must be WAV)
6. **Storage:** Saves temp file to disk
7. **Processing:** Loads audio with librosa
8. **Feature Extraction:** Generates mel-spectrogram
9. **Prediction:** Runs ONNX model inference
10. **Response:** Returns JSON with prediction
11. **Client:** Parses JSON to AnalysisResult
12. **UI:** Displays result to user

**Typical Duration:** 3-10 seconds

---

## ⚙️ Configuration

### Model Configuration
```python
config = {
    'in_channel': 3,       # Input channels (RGB)
    'duration': 5,         # Audio duration in seconds
    'delta': True,         # Use delta features
    'norm': True,          # Normalize features
    'mel_bins': 128        # Number of mel bins
}
```

### Server Configuration
- **Host:** `0.0.0.0` (all interfaces)
- **Port:** `8000`
- **Log Level:** `info`
- **Timeout:** 60 seconds (client-side)
- **Max File Size:** No explicit limit (system default)

---

## 📦 Dependencies

### Python (Backend)
```txt
fastapi==0.104.1
uvicorn[standard]==0.24.0
python-multipart==0.0.6
onnxruntime==1.23.2
librosa==0.10.1
soundfile==0.12.1
scipy==1.11.4
numpy>=1.21.6
```

### Dart/Flutter (Frontend)
```yaml
http: ^1.1.0
file_picker: ^6.1.1
record: ^5.0.4
permission_handler: ^11.1.0
path_provider: ^2.1.1
```

---

## 🚨 Error Handling

### Common Errors

#### 1. Connection Refused
**Cause:** Server not running
**Solution:** Start server with `python api_server.py`

#### 2. Timeout
**Cause:** Server too slow or unresponsive
**Solution:** Check server logs, restart server

#### 3. Model Not Loaded (503)
**Cause:** `model.onnx` file missing or invalid
**Solution:** Ensure model file exists in backend folder

#### 4. Invalid File Format (400)
**Cause:** Non-WAV file uploaded
**Solution:** Convert audio to WAV format

#### 5. CORS Error (Web)
**Cause:** CORS misconfiguration
**Solution:** Verify CORS middleware is enabled

---

## 🔍 Monitoring & Debugging

### Server Logs
```bash
# Start server with debug logging
uvicorn api_server:app --host 0.0.0.0 --port 8000 --log-level debug
```

### Client Logs (Flutter)
```dart
print('🔬 Server URL: $baseUrl');
print('📥 Response Status: ${response.statusCode}');
print('📄 Response Body: ${response.body}');
```

### Network Inspection
- **Chrome DevTools:** Network tab (for Flutter Web)
- **Charles Proxy:** Intercept HTTP requests
- **Wireshark:** Low-level packet analysis

---

## 🌍 Deployment Options

### 1. Local Development
```bash
cd lib/backend
python api_server.py
```
**URL:** `http://localhost:8000`

### 2. Railway.app (Free)
```bash
# Add Procfile
web: uvicorn api_server:app --host 0.0.0.0 --port $PORT

# Deploy
railway up
```
**URL:** `https://your-app.railway.app`

### 3. Heroku (Free Tier)
```bash
# Create Procfile
web: uvicorn api_server:app --host 0.0.0.0 --port $PORT

# Deploy
git push heroku main
```
**URL:** `https://your-app.herokuapp.com`

### 4. Docker
```dockerfile
FROM python:3.11
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
CMD ["uvicorn", "api_server:app", "--host", "0.0.0.0", "--port", "8000"]
```

---

## 📚 API Documentation (Auto-Generated)

FastAPI provides automatic interactive documentation:

### Swagger UI
```
http://localhost:8000/docs
```
- Interactive API testing
- Try endpoints directly in browser
- See request/response schemas

### ReDoc
```
http://localhost:8000/redoc
```
- Clean documentation layout
- Detailed endpoint descriptions

### OpenAPI JSON
```
http://localhost:8000/openapi.json
```
- Machine-readable API specification
- Used for code generation

---

## 🎯 Summary

**API Type:** REST API (FastAPI)

**Communication:** HTTP + JSON

**Endpoints:**
- `GET /` - Status
- `GET /health` - Health check
- `POST /analyze` - Main analysis endpoint

**Data Format:** JSON responses, Multipart form requests

**Port:** 8000

**Host:** 0.0.0.0 (all interfaces)

**Purpose:** Analyze fetal heart sound audio files using ONNX ML model

---

## 📞 Support

For API issues:
1. Check server logs in terminal
2. Visit `/docs` for interactive testing
3. Verify model file exists
4. Ensure all dependencies installed
5. Test with simple curl request first

---

*Developed by Jeet Baidya and Tanziruz Zaman*
*GarbhSuraksha - Maternal Health Monitoring System*

