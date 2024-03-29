/+
 + Copyright (c) Charles Petzold, 1998.
 + Ported to the D Programming Language by Andrej Mitrovic, 2011.
 +/

module PopFont;

import core.memory;
import core.runtime;
import core.thread;
import std.conv;
import std.math;
import std.range;
import std.string;
import std.utf;

pragma(lib, "gdi32.lib");
pragma(lib, "comdlg32.lib");
pragma(lib, "winmm.lib");
import core.sys.windows.windef;
import core.sys.windows.winuser;
import core.sys.windows.wingdi;
import core.sys.windows.winbase;
import core.sys.windows.commdlg;
import core.sys.windows.mmsystem;

static LOGFONT logfont;
static HFONT hFont;

BOOL PopFontChooseFont(HWND hwnd)
{
    CHOOSEFONT cf;

    cf.hwndOwner      = hwnd;
    cf.hDC            = NULL;
    cf.lpLogFont      = &logfont;
    cf.iPointSize     = 0;
    cf.Flags          = CF_INITTOLOGFONTSTRUCT | CF_SCREENFONTS | CF_EFFECTS;
    cf.rgbColors      = 0;
    cf.lCustData      = 0;
    cf.lpfnHook       = NULL;
    cf.lpTemplateName = NULL;
    cf.hInstance      = NULL;
    cf.lpszStyle      = NULL;
    cf.nFontType      = 0;                 // Returned from ChooseFont
    cf.nSizeMin       = 0;
    cf.nSizeMax       = 0;

    return ChooseFont(&cf);
}

void PopFontInitialize(HWND hwndEdit)
{
    GetObject(GetStockObject(SYSTEM_FONT), LOGFONT.sizeof, cast(PTSTR)&logfont);

    hFont = CreateFontIndirect(&logfont);
    SendMessage(hwndEdit, WM_SETFONT, cast(WPARAM)hFont, 0);
}

void PopFontSetFont(HWND hwndEdit)
{
    HFONT hFontNew;
    RECT  rect;

    hFontNew = CreateFontIndirect(&logfont);
    SendMessage(hwndEdit, WM_SETFONT, cast(WPARAM)hFontNew, 0);
    DeleteObject(hFont);
    hFont = hFontNew;
    GetClientRect(hwndEdit, &rect);
    InvalidateRect(hwndEdit, &rect, TRUE);
}

void PopFontDeinitialize()
{
    DeleteObject(hFont);
}
