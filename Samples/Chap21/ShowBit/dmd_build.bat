@echo off
dmd -m32omf -ofBitLib.dll -I..\..\..\WindowsAPI ..\..\..\dmd_win32.lib -I. -version=Unicode -version=WindowsXP BitLib.d BitLib.res %*
dmd -m32omf -ofShowBit.exe -I..\..\..\WindowsAPI ..\..\..\dmd_win32.lib -I. -version=Unicode -version=WindowsXP ShowBit.d %*
