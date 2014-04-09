// D import file generated from 'mydll.d'
module mydll;
import std.c.windows.windows;
version (none)
{
	extern (C) int _tls_callbacks_a;

}
__gshared HINSTANCE g_hInst;

extern (Windows) BOOL DllMain(HINSTANCE hInstance, ULONG ulReason, LPVOID pvReserved);

