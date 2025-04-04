@echo off
cd %~dp0
SET "PowerShellScriptPath=%~dp0shell.ps1"
PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& {Start-Process PowerShell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%PowerShellScriptPath%\"' -Verb RunAs}"
