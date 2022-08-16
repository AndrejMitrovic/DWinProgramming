@echo off
dmd -m32omf -H -ofStrLib.dll -L/IMPLIB -I..\..\..\WindowsAPI ..\..\..\dmd_win32.lib -I. -version=Unicode -version=WindowsXP StrLib.d dllmodule.d %*
dmd -m32omf -ofStrProg.exe -I..\..\..\WindowsAPI ..\..\..\dmd_win32.lib -I. -version=Unicode -version=WindowsXP StrProg.d StrLib.lib StrProg.res %*
