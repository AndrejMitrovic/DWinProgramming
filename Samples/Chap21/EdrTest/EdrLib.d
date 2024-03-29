module EdrLib;

pragma(lib, "gdi32.lib");
pragma(lib, "comdlg32.lib");
import core.sys.windows.windef;
import core.sys.windows.wingdi;
import std.utf : count, toUTFz, toUTF16z;

export extern(Windows) BOOL EdrCenterText(HDC hdc, PRECT prc, string pString)
{
    SIZE size;
    GetTextExtentPoint32(hdc, toUTF16z(pString), pString.count, &size);
    return TextOut(hdc, (prc.right - prc.left - size.cx) / 2,
                        (prc.bottom - prc.top - size.cy) / 2, toUTF16z(pString), pString.count);
}
