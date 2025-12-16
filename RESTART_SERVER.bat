@echo off
echo ============================================
echo   Restarting GarbhSuraksha Server
echo   Developed by Jeet Baidya and Tanziruz Zaman
echo ============================================
echo.
echo [1/2] Stopping any running Python servers...
taskkill /F /IM python.exe /FI "WINDOWTITLE eq *GarbhSuraksha*" 2>nul
taskkill /F /IM python.exe /FI "MEMUSAGE gt 50000" 2>nul
timeout /t 2 /nobreak >nul
echo [OK] Previous instances stopped
echo.

echo [2/2] Starting fresh server...
call START_SERVER.bat

