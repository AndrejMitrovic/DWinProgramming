/+
 + Copyright (c) Charles Petzold, 1998.
 + Ported to the D Programming Language by Andrej Mitrovic, 2011.
 +/

module Environ;

import core.runtime;
import core.thread;
import std.algorithm;
import std.conv;
import std.math;
import std.range;
import std.string;
import std.utf;
import std.traits;

pragma(lib, "gdi32.lib");

import core.sys.windows.windef;
import core.sys.windows.winuser;
import core.sys.windows.wingdi;
import core.sys.windows.winbase;

enum ID_SMALLER =    1;     // button window unique id
enum ID_LARGER  =    2;     // same
enum ID_LIST    =    1;
enum ID_TEXT    =    2;
enum BTN_WIDTH  =    "(8 * cxChar)";
enum BTN_HEIGHT =    "(4 * cyChar)";
int idFocus;
WNDPROC[3] OldScroll;
HINSTANCE hInst;

extern (Windows)
int WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int iCmdShow)
{
    int result;

    try
    {
        Runtime.initialize();
        result = myWinMain(hInstance, hPrevInstance, lpCmdLine, iCmdShow);
        Runtime.terminate();
    }
    catch (Throwable o)
    {
        MessageBox(null, o.toString().toUTF16z, "Error", MB_OK | MB_ICONEXCLAMATION);
        result = 0;
    }

    return result;
}

int myWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int iCmdShow)
{
    hInst = hInstance;
    string appName = "Environ";

    HWND hwnd;
    MSG  msg;
    WNDCLASS wndclass;

    wndclass.style         = CS_HREDRAW | CS_VREDRAW;
    wndclass.lpfnWndProc   = &WndProc;
    wndclass.cbClsExtra    = 0;
    wndclass.cbWndExtra    = 0;
    wndclass.hInstance     = hInstance;
    wndclass.hIcon         = LoadIcon(NULL, IDI_APPLICATION);
    wndclass.hCursor       = LoadCursor(NULL, IDC_ARROW);
    wndclass.hbrBackground = cast(HBRUSH) GetStockObject(WHITE_BRUSH);

    wndclass.lpszMenuName  = NULL;
    wndclass.lpszClassName = appName.toUTF16z;

    if (!RegisterClass(&wndclass))
    {
        MessageBox(NULL, "This program requires Windows NT!", appName.toUTF16z, MB_ICONERROR);
        return 0;
    }

    hwnd = CreateWindow(appName.toUTF16z,              // window class name
                        "Environment List Box",        // window caption
                        WS_OVERLAPPEDWINDOW,           // window style
                        CW_USEDEFAULT,                 // initial x position
                        CW_USEDEFAULT,                 // initial y position
                        CW_USEDEFAULT,                 // initial x size
                        CW_USEDEFAULT,                 // initial y size
                        NULL,                          // parent window handle
                        NULL,                          // window menu handle
                        hInstance,                     // program instance handle
                        NULL);                         // creation parameters

    ShowWindow(hwnd, iCmdShow);
    UpdateWindow(hwnd);

    while (GetMessage(&msg, NULL, 0, 0))
    {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }

    return msg.wParam;
}

wstring fromWStringz(const wchar* s)
{
    if (s is null) return null;

    wchar* ptr;
    for (ptr = cast(wchar*)s; *ptr; ++ptr) {}

    return to!wstring(s[0..ptr-s]);
}


// Note: this is a raw translation from C code.
// It's completely unsafe to handle wide strings this way,
// so don't use this in production code.
void FillListBox(HWND hwndList)
{
    wchar* l_EnvStr;
    l_EnvStr = GetEnvironmentStringsW();

    LPTSTR l_str = l_EnvStr;

    int count = 0;

    while (true)
    {
        if (*l_str == 0)
            break;

        while (*l_str != 0)
            l_str++;

        l_str++;
        count++;
    }

    for (int i = 0; i < count; i++)
    {
        auto str = fromWStringz(l_EnvStr);
        str.length = str.countUntil("=");

        if (str.length)
            SendMessage(hwndList, LB_ADDSTRING, 0, cast(LPARAM)((str ~ "\0").ptr));

        while (*l_EnvStr != '\0')
            l_EnvStr++;

        l_EnvStr++;
    }

    FreeEnvironmentStrings(l_EnvStr);
}

extern (Windows)
LRESULT WndProc(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam) nothrow
{
    scope (failure) assert(0);

    static HWND hwndList, hwndText;
    int iIndex, iLength, cxChar, cyChar;
    wchar[] pVarName, pVarValue;

    switch (message)
    {
        case WM_CREATE:
            cxChar = LOWORD(GetDialogBaseUnits());
            cyChar = HIWORD(GetDialogBaseUnits());

            // Create listbox
            hwndList = CreateWindow("listbox", NULL,
                                    WS_CHILD | WS_VISIBLE | LBS_STANDARD,
                                    cxChar, cyChar * 6,
                                    cxChar * 48 + GetSystemMetrics(SM_CXVSCROLL),
                                    cyChar * 24,
                                    hwnd, cast(HMENU)ID_LIST,
                                    cast(HINSTANCE)GetWindowLongPtr(hwnd, GWL_HINSTANCE),
                                    NULL);

            // static text window with word wrapping
            hwndText = CreateWindow("static", NULL,
                                    WS_CHILD | WS_VISIBLE | SS_LEFT,
                                    cxChar, cyChar,
                                    GetSystemMetrics(SM_CXSCREEN), cyChar * 4,
                                    hwnd, cast(HMENU)ID_TEXT,
                                    cast(HINSTANCE)GetWindowLongPtr(hwnd, GWL_HINSTANCE),
                                    NULL);

            FillListBox(hwndList);
            return 0;

        case WM_SETFOCUS:
            SetFocus(hwndList);
            return 0;

        case WM_COMMAND:

            if (LOWORD(wParam) == ID_LIST && HIWORD(wParam) == LBN_SELCHANGE)
            {
                // Get current selection.
                iIndex          = SendMessage(hwndList, LB_GETCURSEL, 0, 0);
                iLength         = SendMessage(hwndList, LB_GETTEXTLEN, iIndex, 0) + 1;
                pVarName.length = iLength;

                // could use D strings here
                SendMessage(hwndList, LB_GETTEXT, iIndex, cast(LPARAM)pVarName.ptr);

                // Get environment string.
                iLength = GetEnvironmentVariable(pVarName.ptr, NULL, 0);
                pVarValue.length = iLength;
                GetEnvironmentVariable((pVarName ~ "\0").ptr, pVarValue.ptr, iLength);

                // Show it in window.
                SetWindowText(hwndText, pVarValue.ptr);
            }

            return 0;

        case WM_DESTROY:
            PostQuitMessage(0);
            return 0;

        default:
    }

    return DefWindowProc(hwnd, message, wParam, lParam);
}
