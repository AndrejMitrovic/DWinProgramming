// D import file generated from 'EdrLib.d'
module EdrLib;
pragma (lib, "gdi32.lib");
pragma (lib, "comdlg32.lib");
import core.sys.windows.windef;
import core.sys.windows.wingdi;
import std.utf : count, toUTFz, toUTF16z;
export extern (Windows) BOOL EdrCenterText(HDC hdc, PRECT prc, string pString);
