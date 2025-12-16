@echo off
echo.
echo ========================================
echo   GarbhSuraksha - Complete Setup
echo   Developed by Jeet Baidya and Tanziruz Zaman
echo ========================================
echo.

echo [1/3] Setting up Python backend...
cd lib\backend

if not exist ".venv" (
    echo Creating virtual environment...
    python -m venv .venv
)

echo Activating virtual environment...
call .venv\Scripts\activate.bat

echo Installing Python dependencies...
pip install -q --upgrade pip
pip install -q -r requirements.txt

echo.
echo [2/3] Setting up Flutter app...
cd ..\..
call flutter pub get

echo.
echo [3/3] Setup complete!
echo.
echo ========================================
echo   Ready to Use!
echo ========================================
echo.
echo To start the app:
echo.
echo   1. Start backend server:
echo      - Open lib\backend folder
echo      - Double-click start_server.bat
echo.
echo   2. Run Flutter app:
echo      - flutter run
echo      (or click Run button in your IDE)
echo.
echo   3. Use the app:
echo      - Enter gestation period
echo      - Record or upload audio
echo      - Click Analyze!
echo.
echo For detailed instructions, see:
echo   - INTEGRATION_GUIDE.md
echo   - INTEGRATION_COMPLETE.md
echo.
pause

