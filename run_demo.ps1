$ErrorActionPreference = "Stop"
Set-Location -LiteralPath $PSScriptRoot

Write-Host "[1/2] Compiling Functional EDA demo..."
New-Item -ItemType Directory -Force -Path ".\outputs\build" | Out-Null
ghc -isrc -odir outputs\build -hidir outputs\build -o outputs\functional_eda_demo.exe src\Main.hs

Write-Host ""
Write-Host "[2/2] Running bundled examples..."
& .\outputs\functional_eda_demo.exe

Write-Host ""
Write-Host "Demo finished."
