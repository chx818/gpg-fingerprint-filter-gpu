@echo off
title GPG GPU Fingerprint Batch Miner
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0batch_miner.ps1"
pause
