@echo off
cls
echo ========================================
echo   GarbhSuraksha Backend Server
echo   Developed by Jeet Baidya and Tanziruz Zaman
echo ========================================
echo.

cd /d "%~dp0lib\backend"

echo [1/5] Checking Python installation...
python --version 2>nul
if errorlevel 1 (
    echo [ERROR] Python is not installed or not in PATH
    echo Please install Python from https://www.python.org/
    echo.
    pause
    exit /b 1
)
echo [OK] Python found!
echo.

echo [2/5] Installing/updating dependencies...
echo This may take a moment...
python -m pip install --upgrade pip --quiet
pip install -r requirements.txt --quiet
if errorlevel 1 (
    echo [WARNING] Some packages may have failed to install
    echo Attempting to continue...
)
echo [OK] Dependencies check complete
echo.

echo [3/5] Running diagnostic test...
python test_server_startup.py
echo.

echo [4/5] Checking model file...
if exist "model.onnx" (
    echo [OK] model.onnx found
) else (
    echo [WARNING] model.onnx not found!
    echo The server will start but analysis will fail.
)
echo.

echo [5/5] Starting server...
echo.
echo ========================================
echo   SERVER RUNNING AT:
echo   http://localhost:8000
echo.
echo   For Android Emulator: 10.0.2.2:8000
echo   For iOS Simulator: localhost:8000
echo ========================================
echo.
echo IMPORTANT:
echo - Keep this window OPEN while using the app
echo - Press Ctrl+C to stop the server
echo.
echo ========================================
echo.

python api_server.py

echo.
echo ========================================
echo Server stopped.
echo ========================================
pause

