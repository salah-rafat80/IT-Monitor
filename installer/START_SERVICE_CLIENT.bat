@echo off
title IT Network Monitor (Client Mode)
cd /d "%~dp0"
start "" "%~dp0it_network_monitor.exe" --client
exit
