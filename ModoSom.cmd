@echo off
rem Modo Som HX
rem   ModoSom.cmd            -> abre o painel
rem   ModoSom.cmd jogo       -> perfis de jogo em todas as saidas (sem painel)
rem   ModoSom.cmd trabalho   -> perfis de trabalho
set PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe
start "" /b "%PS%" -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "%~dp0ModoSom.ps1" %*
