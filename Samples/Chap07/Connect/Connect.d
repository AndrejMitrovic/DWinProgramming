/+
 + Copyright (c) Charles Petzold, 1998.
 + Ported to the D Programming Language by Andrej Mitrovic, 2011.
 +/

module Connect;

import core.runtime;
import core.thread;
import std.conv;
import std.math;
import std.range;
import std.string;
import std.utf;

pragma(lib, "gdi32.lib");

import core.sys.windows.windef;
import core.sys.windows.winuser;
import core.sys.windows.wingdi;

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
    string appName = "Connect";

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

    hwnd = CreateWindow(appName.toUTF16z,                 // window class name
                        "Connect-the-Points Mouse Demo",  // window caption
                        WS_OVERLAPPEDWINDOW,              // window style
                        CW_USEDEFAULT,                    // initial x position
                        CW_USEDEFAULT,                    // initial y position
                        CW_USEDEFAULT,                    // initial x size
                        CW_USEDEFAULT,                    // initial y size
                        NULL,                             // parent window handle
                        NULL,                             // window menu handle
                        hInstance,                        // program instance handle
                        NULL);                            // creation parameters

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

    enum MAXPOINTS = 1000;
    static POINT[MAXPOINTS] pt;
    static int iCount;
    HDC hdc;
    int i, j;
    PAINTSTRUCT ps;

    switch (message)
    {
        case WM_LBUTTONDOWN:
            iCount = 0;
            InvalidateRect(hwnd, NULL, TRUE);
            return 0;

        case WM_MOUSEMOVE:
        {
            if (wParam & MK_LBUTTON && iCount < 1000)
            {
                pt[iCount].x = LOWORD(lParam);
                pt[iCount].y = HIWORD(lParam);
                iCount++;

                hdc = GetDC(hwnd);
                SetPixel(hdc, LOWORD(lParam), HIWORD(lParam), 0);
                ReleaseDC(hwnd, hdc);
            }

            return 0;
        }

        case WM_LBUTTONUP:
            InvalidateRect(hwnd, NULL, FALSE);
            return 0;

        case WM_PAINT:
        {
            hdc = BeginPaint(hwnd, &ps);

            SetCursor(LoadCursor(NULL, IDC_WAIT));
            ShowCursor(TRUE);

            for (i = 0; i < iCount - 1; i++)
            {
                for (j = i + 1; j < iCount; j++)
                {
                    MoveToEx(hdc, pt[i].x, pt[i].y, NULL);
                    LineTo(hdc, pt[j].x, pt[j].y);
                }
            }

            ShowCursor(FALSE);
            SetCursor(LoadCursor(NULL, IDC_ARROW));
            EndPaint(hwnd, &ps);
            return 0;
        }

        case WM_DESTROY:
            PostQuitMessage(0);
            return 0;

        default:
    }

    return DefWindowProc(hwnd, message, wParam, lParam);
}
