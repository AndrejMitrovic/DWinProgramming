/+
 + Copyright (c) Charles Petzold, 1998.
 + Ported to the D Programming Language by Andrej Mitrovic, 2011.
 +/

module Emf8;

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
import core.sys.windows.windef;
import core.sys.windows.winuser;
import core.sys.windows.wingdi;
import core.sys.windows.winbase;
import core.sys.windows.commdlg;

import resource;

string szClass     = "EMF8";
string szTitle     = "EMF8: Enhanced Metafile Demo #8";
string appName     = "EMF";
string description = "EMF8: Enhanced Metafile Demo #8";
HINSTANCE hinst;

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
    hinst = hInstance;
    HACCEL hAccel;
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
                        description.toUTF16z,          // window caption
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

void DrawRuler(HDC hdc, int cx, int cy)
{
    int iAdj, i, iHeight;
    LOGFONT lf;
    TCHAR ch;

    iAdj = GetVersion() & 0x80000000 ? 0 : 1;

    // Black pen with 1-point width
    SelectObject(hdc, CreatePen(PS_SOLID, cx / 72 / 6, 0));

    // Rectangle surrounding entire pen (with adjustment)
    Rectangle(hdc, iAdj, iAdj, cx + iAdj + 1, cy + iAdj + 1);

    // Tick marks
    for (i = 1; i < 96; i++)
    {
        if (i % 16 == 0)
            iHeight = cy / 2;                          // inches
        else if (i % 8 == 0)
            iHeight = cy / 3;                          // half inches
        else if (i % 4 == 0)
            iHeight = cy / 5;                          // quarter inches
        else if (i % 2 == 0)
            iHeight = cy / 8;                          // eighths
        else
            iHeight = cy / 12;                         // sixteenths

        MoveToEx(hdc, i * cx / 96, cy, NULL);
        LineTo(hdc, i * cx / 96, cy - iHeight);
    }

    // Create logical font
    lf.lfHeight     = cy / 2;
    lf.lfFaceName   = 0;
    auto szFaceName = "Times New Roman\0";
    lf.lfFaceName[0..szFaceName.length] = szFaceName.toUTF16;

    SelectObject(hdc, CreateFontIndirect(&lf));
    SetTextAlign(hdc, TA_BOTTOM | TA_CENTER);
    SetBkMode(hdc, TRANSPARENT);

    // Display numbers
    for (i = 1; i <= 5; i++)
    {
        ch = cast(TCHAR)(i + '0');
        TextOut(hdc, i * cx / 6, cy / 2, &ch, 1);
    }

    // Clean up
    DeleteObject(SelectObject(hdc, GetStockObject(SYSTEM_FONT)));
    DeleteObject(SelectObject(hdc, GetStockObject(BLACK_PEN)));
}

void CreateRoutine(HWND hwnd)
{
    HDC hdcEMF;
    HENHMETAFILE hemf;
    int cxMms, cyMms, cxPix, cyPix, xDpi, yDpi;

    hdcEMF = CreateEnhMetaFile(NULL, "emf8.emf", NULL,
                               "EMF8\0EMF Demo #8\0");

    if (hdcEMF == NULL)
        return;

    cxMms = GetDeviceCaps(hdcEMF, HORZSIZE);
    cyMms = GetDeviceCaps(hdcEMF, VERTSIZE);
    cxPix = GetDeviceCaps(hdcEMF, HORZRES);
    cyPix = GetDeviceCaps(hdcEMF, VERTRES);

    xDpi = cxPix * 254 / cxMms / 10;
    yDpi = cyPix * 254 / cyMms / 10;

    DrawRuler(hdcEMF, 6 * xDpi, yDpi);

    hemf = CloseEnhMetaFile(hdcEMF);

    DeleteEnhMetaFile(hemf);
}

void PaintRoutine(HWND hwnd, HDC hdc, int cxArea, int cyArea)
{
    ENHMETAHEADER emh;
    HENHMETAFILE  hemf;
    int  cxImage, cyImage;
    RECT rect;

    hemf = GetEnhMetaFile("emf8.emf");

    GetEnhMetaFileHeader(hemf, emh.sizeof, &emh);

    cxImage = emh.rclBounds.right - emh.rclBounds.left;
    cyImage = emh.rclBounds.bottom - emh.rclBounds.top;

    rect.left   = (cxArea - cxImage) / 2;
    rect.right  = (cxArea + cxImage) / 2;
    rect.top    = (cyArea - cyImage) / 2;
    rect.bottom = (cyArea + cyImage) / 2;

    PlayEnhMetaFile(hdc, hemf, &rect);

    DeleteEnhMetaFile(hemf);
}

BOOL PrintRoutine(HWND hwnd)
{
    static DOCINFO  di;
    static PRINTDLG printdlg = PRINTDLG(PRINTDLG.sizeof);
    static string szMessage;
    BOOL bSuccess = FALSE;
    HDC  hdcPrn;
    int  cxPage, cyPage;

    printdlg.Flags = PD_RETURNDC | PD_NOPAGENUMS | PD_NOSELECTION;

    if (!PrintDlg(&printdlg))
        return TRUE;

    if (NULL == (hdcPrn = printdlg.hDC))
        return FALSE;

    cxPage = GetDeviceCaps(hdcPrn, HORZRES);
    cyPage = GetDeviceCaps(hdcPrn, VERTRES);

    szMessage      = szClass ~ ": Printing";
    di.cbSize      = DOCINFO.sizeof;
    di.lpszDocName = szMessage.toUTF16z;

    if (StartDoc(hdcPrn, &di) > 0)
    {
        if (StartPage(hdcPrn) > 0)
        {
            PaintRoutine(hwnd, hdcPrn, cxPage, cyPage);

            if (EndPage(hdcPrn) > 0)
            {
                EndDoc(hdcPrn);
                bSuccess = TRUE;
            }
        }
    }

    DeleteDC(hdcPrn);

    return bSuccess;
}

extern (Windows)
LRESULT WndProc(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam) nothrow
{
    scope (failure) assert(0);

    BOOL bSuccess;
    static int cxClient, cyClient;
    HDC hdc;
    PAINTSTRUCT ps;

    switch (message)
    {
        case WM_CREATE:
            CreateRoutine(hwnd);
            return 0;

        case WM_COMMAND:

            switch (wParam)
            {
                case IDM_PRINT:
                    SetCursor(LoadCursor(NULL, IDC_WAIT));
                    ShowCursor(TRUE);

                    bSuccess = PrintRoutine(hwnd);

                    ShowCursor(FALSE);
                    SetCursor(LoadCursor(NULL, IDC_ARROW));

                    if (!bSuccess)
                        MessageBox(hwnd,
                                   "Error encountered during printing",
                                   szClass.toUTF16z, MB_ICONASTERISK | MB_OK);

                    return 0;

                case IDM_EXIT:
                    SendMessage(hwnd, WM_CLOSE, 0, 0);
                    return 0;

                case IDM_ABOUT:
                    MessageBox(hwnd, "Enhanced Metafile Demo Program\nCopyright (c) Charles Petzold, 1998",
                               szClass.toUTF16z, MB_ICONINFORMATION | MB_OK);
                    return 0;

                default:
            }

            break;

        case WM_SIZE:
            cxClient = LOWORD(lParam);
            cyClient = HIWORD(lParam);
            return 0;

        case WM_PAINT:
            hdc = BeginPaint(hwnd, &ps);

            PaintRoutine(hwnd, hdc, cxClient, cyClient);

            EndPaint(hwnd, &ps);
            return 0;

        case WM_DESTROY:
            PostQuitMessage(0);
            return 0;

        default:
    }

    return DefWindowProc(hwnd, message, wParam, lParam);
}
