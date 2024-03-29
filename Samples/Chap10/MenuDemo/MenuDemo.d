/+
 + Copyright (c) Charles Petzold, 1998.
 + Ported to the D Programming Language by Andrej Mitrovic, 2011.
 +/

module MenuDemo;

import core.runtime;
import core.thread;
import std.conv;
import std.math;
import std.range;
import std.string;
import std.stdio;
import std.utf;

pragma(lib, "gdi32.lib");

import core.sys.windows.windef;
import core.sys.windows.winuser;
import core.sys.windows.wingdi;
import core.sys.windows.winbase;

import resource;

HINSTANCE hInst;
enum ID_TIMER = 1;
string appName = "MenuDemo";

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

    wndclass.lpszMenuName  = appName.toUTF16z;
    wndclass.lpszClassName = appName.toUTF16z;

    if (!RegisterClass(&wndclass))
    {
        MessageBox(NULL, "This program requires Windows NT!", appName.toUTF16z, MB_ICONERROR);
        return 0;
    }

    hwnd = CreateWindow(appName.toUTF16z,              // window class name
                        "Menu Demo",                   // window caption
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

extern (Windows)
LRESULT WndProc(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam) nothrow
{
    scope (failure) assert(0);

    static HMENU hMenu;
    enum idColor = [WHITE_BRUSH,  LTGRAY_BRUSH, GRAY_BRUSH, DKGRAY_BRUSH, BLACK_BRUSH];
    static int iSelection = IDM_BKGND_WHITE;
    POINT point;

    switch (message)
    {
        case WM_CREATE:
            hMenu = LoadMenu(hInst, appName.toUTF16z);
            hMenu = GetSubMenu(hMenu, 0);
            return 0;

        case WM_RBUTTONUP:
            point.x = LOWORD(lParam);
            point.y = HIWORD(lParam);
            ClientToScreen(hwnd, &point);

            TrackPopupMenu(hMenu, TPM_RIGHTBUTTON, point.x, point.y, 0, hwnd, NULL);
            return 0;

        case WM_COMMAND:
        {
            hMenu = GetMenu(hwnd);
            switch (LOWORD(wParam))
            {
                case IDM_FILE_NEW:
                case IDM_FILE_OPEN:
                case IDM_FILE_SAVE:
                case IDM_FILE_SAVE_AS:
                case IDM_EDIT_UNDO:
                case IDM_EDIT_CUT:
                case IDM_EDIT_COPY:
                case IDM_EDIT_PASTE:
                case IDM_EDIT_CLEAR:
                    MessageBeep(0);
                    return 0;

                case IDM_APP_EXIT:
                    SendMessage(hwnd, WM_CLOSE, 0, 0);
                    return 0;

                case IDM_BKGND_WHITE:   // Note: Logic below assumes that IDM_WHITE
                case IDM_BKGND_LTGRAY:  // through IDM_BLACK are consecutive numbers in
                case IDM_BKGND_GRAY:    // the order shown here.
                case IDM_BKGND_DKGRAY:
                case IDM_BKGND_BLACK:
                    CheckMenuItem(hMenu, iSelection, MF_UNCHECKED);
                    iSelection = LOWORD(wParam);
                    CheckMenuItem(hMenu, iSelection, MF_CHECKED);

                    SetClassLong(hwnd, GCL_HBRBACKGROUND,
                                 cast(LONG)GetStockObject(idColor [LOWORD(wParam) - IDM_BKGND_WHITE]));

                    InvalidateRect(hwnd, NULL, TRUE);
                    return 0;

                case IDM_TIMER_START:

                    if (SetTimer(hwnd, ID_TIMER, 1000, NULL))
                    {
                        EnableMenuItem(hMenu, IDM_TIMER_START, MF_GRAYED);
                        EnableMenuItem(hMenu, IDM_TIMER_STOP,  MF_ENABLED);
                    }

                    return 0;

                case IDM_TIMER_STOP:
                    KillTimer(hwnd, ID_TIMER);
                    EnableMenuItem(hMenu, IDM_TIMER_START, MF_ENABLED);
                    EnableMenuItem(hMenu, IDM_TIMER_STOP,  MF_GRAYED);
                    return 0;

                case IDM_APP_HELP:
                    MessageBox(hwnd, "Help not yet implemented!",
                               appName.toUTF16z, MB_ICONEXCLAMATION | MB_OK);
                    return 0;

                case IDM_APP_ABOUT:
                    MessageBox(hwnd, "Menu Demonstration Program\n (c) Charles Petzold, 1998",
                               appName.toUTF16z, MB_ICONINFORMATION | MB_OK);
                    return 0;

                default:
            }

            break;
        }

        case WM_DESTROY:
            PostQuitMessage(0);
            return 0;

        default:
    }

    return DefWindowProc(hwnd, message, wParam, lParam);
}
