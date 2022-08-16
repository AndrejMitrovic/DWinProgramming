// D import file generated from 'mydll.d'
module mydll;
pragma (lib, "gdi32.lib");
pragma (lib, "comdlg32.lib");
pragma (lib, "winmm.lib");
import core.sys.windows.windef;
import core.sys.windows.winuser;
import core.sys.windows.wingdi;
import core.sys.windows.winbase;
import core.sys.windows.commdlg;
import core.sys.windows.mmsystem;
version (none)
{
	extern (C) int _tls_callbacks_a;
}
__gshared HINSTANCE g_hInst;
extern (Windows) BOOL DllMain(HINSTANCE hInstance, ULONG ulReason, LPVOID pvReserved);
