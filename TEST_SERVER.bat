@echo off
echo ============================================
echo   GarbhSuraksha Server Test
echo   Developed by Jeet Baidya and Tanziruz Zaman
echo ============================================
echo.
echo Testing if server starts correctly...
echo.
cd /d "%~dp0lib\backend"

echo Starting server (will auto-stop after 10 seconds)...
start /B python api_server.py

echo Waiting for server to start...
timeout /t 8 /nobreak >nul

echo.
echo Testing /health endpoint...
curl -s http://localhost:8000/health
echo.

echo.
echo Testing /analyze endpoint availability...
echo (Note: This should return error without actual file, but server should respond)
curl -s -X POST http://localhost:8000/analyze
echo.

echo.
echo Stopping test server...
taskkill /F /IM python.exe /FI "MEMUSAGE gt 50000" >nul 2>&1

echo.
echo ============================================
echo Test complete! Check above for any errors.
echo ============================================
pause

