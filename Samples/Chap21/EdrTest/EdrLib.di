// D import file generated from 'EdrLib.d'
module EdrLib;
pragma (lib, "gdi32.lib");
pragma (lib, "comdlg32.lib");
import win32.windef;
import win32.wingdi;
import std.utf : count, toUTFz;
auto toUTF16z(S)(S s)
{
	return toUTFz!(const(wchar)*)(s);
}
export extern (Windows) BOOL EdrCenterText(HDC hdc, PRECT prc, string pString);


