@echo off
echo ========================================
echo GarbhSuraksha - Server Diagnostic Tool
echo ========================================
echo.

echo [1/3] Testing Railway Server Health...
curl -X GET "https://garbhsurakhsha.up.railway.app/health" -s -w "\nHTTP Status: %%{http_code}\nTime: %%{time_total}s\n"
echo.

echo [2/3] Testing Root Endpoint...
curl -X GET "https://garbhsurakhsha.up.railway.app/" -s -w "\nHTTP Status: %%{http_code}\nTime: %%{time_total}s\n"
echo.

echo [3/3] Running Dart Test Script...
dart test_server.dart
echo.

echo ========================================
echo Diagnostic Complete!
echo.
echo If all tests passed, the server is working fine.
echo Run the Flutter app with: flutter run -d chrome
echo ========================================
pause

