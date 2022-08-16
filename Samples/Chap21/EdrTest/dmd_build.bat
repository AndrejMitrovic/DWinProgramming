@echo off
dmd -m32omf -H -ofEdrLib.dll -L/IMPLIB -I..\..\..\WindowsAPI ..\..\..\dmd_win32.lib -I. -version=Unicode -version=WindowsXP mydll.d EdrLib.d %*
dmd -m32omf -ofEdrTest.exe -I..\..\..\WindowsAPI ..\..\..\dmd_win32.lib -I. -version=Unicode -version=WindowsXP EdrTest.d EdrLib.lib %*
