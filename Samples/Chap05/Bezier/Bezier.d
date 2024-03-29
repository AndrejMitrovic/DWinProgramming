/+
 + Copyright (c) Charles Petzold, 1998.
 + Ported to the D Programming Language by Andrej Mitrovic, 2011.
 +/

module Bezier;

import core.runtime;
import std.string;
import std.utf;

pragma(lib, "gdi32.lib");
pragma(lib, "winmm.lib");

import core.sys.windows.mmsystem;
import core.sys.windows.windef;
import core.sys.windows.winuser;
import core.sys.windows.wingdi;

extern(Windows)
int WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int iCmdShow)
{
    int result;

    try
    {
        Runtime.initialize();
        result = myWinMain(hInstance, hPrevInstance, lpCmdLine, iCmdShow);
        Runtime.terminate();
    }
    catch(Throwable o)
    {
        MessageBox(null, o.toString().toUTF16z, "Error", MB_OK | MB_ICONEXCLAMATION);
        result = 0;
    }

    return result;
}

int myWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int iCmdShow)
{
    string appName = "Bezier";

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

    if(!RegisterClass(&wndclass))
    {
        MessageBox(NULL, "This program requires Windows NT!", appName.toUTF16z, MB_ICONERROR);
        return 0;
    }

    hwnd = CreateWindow(appName.toUTF16z,     // window class name
                        "Bezier Splines",     // window caption
                        WS_OVERLAPPEDWINDOW,  // window style
                        CW_USEDEFAULT,        // initial x position
                        CW_USEDEFAULT,        // initial y position
                        CW_USEDEFAULT,        // initial x size
                        CW_USEDEFAULT,        // initial y size
                        NULL,                 // parent window handle
                        NULL,                 // window menu handle
                        hInstance,            // program instance handle
                        NULL);                // creation parameters

    ShowWindow(hwnd, iCmdShow);
    UpdateWindow(hwnd);

    while(GetMessage(&msg, NULL, 0, 0))
    {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }

    return msg.wParam;
}

extern(Windows)
LRESULT WndProc(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam) nothrow
{
    scope (failure) assert(0);

    static int cxChar, cxCaps, cyChar, cxClient, cyClient, iMaxWidth;
    HDC hdc;
    int i, x, y, iVertPos, iHorzPos, iPaintStart, iPaintEnd;
    PAINTSTRUCT ps;
    SCROLLINFO  si;
    TEXTMETRIC tm;

    static POINT[4] apt;

    switch(message)
    {
        case WM_CREATE:
        {
            hdc = GetDC(hwnd);
            scope(exit) ReleaseDC(hwnd, hdc);

            GetTextMetrics(hdc, &tm);
            cxChar = tm.tmAveCharWidth;
            cxCaps = (tm.tmPitchAndFamily & 1 ? 3 : 2) * cxChar / 2;
            cyChar = tm.tmHeight + tm.tmExternalLeading;

            // Save the width of the three columns
            iMaxWidth = 40 * cxChar + 22 * cxCaps;

            return 0;
        }

        case WM_SIZE:
        {
            cxClient = LOWORD(lParam);
            cyClient = HIWORD(lParam);

            apt[0].x = cxClient / 4;
            apt[0].y = cyClient / 2;

            apt[1].x = cxClient / 2;
            apt[1].y = cyClient / 4;

            apt[2].x =     cxClient / 2;
            apt[2].y = 3 * cyClient / 4;

            apt[3].x = 3 * cxClient / 4;
            apt[3].y =     cyClient / 2;


            return 0;
        }

        case WM_LBUTTONDOWN:
        case WM_RBUTTONDOWN:
        case WM_MOUSEMOVE:
        {
            if (wParam & MK_LBUTTON || wParam & MK_RBUTTON)
            {
                hdc = GetDC(hwnd);
                scope(exit)
                    ReleaseDC(hwnd, hdc);

                SelectObject(hdc, GetStockObject(WHITE_PEN));
                DrawBezier(hdc, apt);

                if (wParam & MK_LBUTTON)
                {
                    apt[1].x = LOWORD(lParam);
                    apt[1].y = HIWORD(lParam);
                }

                if (wParam & MK_RBUTTON)
                {
                    apt[2].x = LOWORD(lParam);
                    apt[2].y = HIWORD(lParam);
                }

                SelectObject(hdc, GetStockObject(BLACK_PEN));
                DrawBezier(hdc, apt);
            }
            return 0;
        }

        case WM_PAINT:
        {
            hdc = BeginPaint(hwnd, &ps);
            scope(exit) EndPaint(hwnd, &ps);

            DrawBezier(hdc, apt);
            return 0;
        }

        case WM_DESTROY:
            PostQuitMessage(0);
            return 0;

        default:
    }

    return DefWindowProc(hwnd, message, wParam, lParam);
}

void DrawBezier(HDC hdc, POINT[4] apt)
{
    PolyBezier(hdc, apt.ptr, apt.length);

    MoveToEx(hdc, apt[0].x, apt[0].y, NULL);
    LineTo(hdc, apt[1].x, apt[1].y);

    MoveToEx(hdc, apt[2].x, apt[2].y, NULL);
    LineTo(hdc, apt[3].x, apt[3].y);
}
