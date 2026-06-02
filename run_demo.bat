@echo off
setlocal
cd /d "%~dp0"

echo [1/2] Compiling Functional EDA demo...
if not exist outputs\build mkdir outputs\build
ghc -isrc -odir outputs\build -hidir outputs\build -o outputs\functional_eda_demo.exe src\Main.hs
if errorlevel 1 (
  echo Build failed.
  exit /b 1
)

echo.
echo [2/2] Running bundled examples...
outputs\functional_eda_demo.exe

echo.
echo Demo finished.
endlocal
