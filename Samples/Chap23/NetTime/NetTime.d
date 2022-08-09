/+
 + Copyright (c) Charles Petzold, 1998.
 + Ported to the D Programming Language by Andrej Mitrovic, 2011.
 +/

module NetTIme;

/+
 + Note: Doesn't seem to work. The original C example doesn't work either.
 +/

import core.memory;
import core.runtime;
import core.thread;
import core.stdc.config;
import std.conv;
import std.exception;
import std.math;
import std.range;
import std.string;
import std.utf : count, toUTFz, toUTF16z;

pragma(lib, "gdi32.lib");
pragma(lib, "comdlg32.lib");
pragma(lib, "winmm.lib");
pragma(lib, "Ws2_32.lib");
import core.sys.windows.windef;
import core.sys.windows.winuser;
import core.sys.windows.wingdi;
import core.sys.windows.winbase;
import core.sys.windows.commdlg;
import core.sys.windows.mmsystem;
import core.sys.windows.winnls;
import core.sys.windows.winsock2;

import resource;

string appName     = "NetTime";
string description = "Set System Clock from the Internet";
HINSTANCE hinst;


// wrong prototype in win32.winsock2
extern(Windows) int WSAAsyncSelect(SOCKET, HWND, uint, int) nothrow;

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

HINSTANCE hInst;
HWND hwndModeless;

int myWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int iCmdShow)
{
    hinst = hInstance;
    HACCEL hAccel;
    HWND hwnd;
    MSG  msg;
    WNDCLASS wndclass;
    RECT rect;

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

    hwndModeless = CreateDialog(hInstance, assumeWontThrow(appName.toUTF16z), hwnd, &MainDlg);

    // Size the main parent window to the size of the dialog box.
    // Show both windows.
    GetWindowRect(hwndModeless, &rect);
    AdjustWindowRect(&rect, WS_CAPTION | WS_BORDER, FALSE);

    SetWindowPos(hwnd, NULL, 0, 0, rect.right - rect.left,
                 rect.bottom - rect.top, SWP_NOMOVE);

    ShowWindow(hwndModeless, SW_SHOW);
    ShowWindow(hwnd, iCmdShow);
    UpdateWindow(hwnd);

    while (GetMessage(&msg, NULL, 0, 0))
    {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }

    return msg.wParam;
}

enum WM_SOCKET_NOTIFY = (WM_USER + 1);
enum ID_TIMER         = 1;

extern (Windows)
LRESULT WndProc(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam) nothrow
{
    scope (failure) assert(0);

    switch (message)
    {
        case WM_SETFOCUS:
            SetFocus(hwndModeless);
            return 0;

        case WM_DESTROY:
            PostQuitMessage(0);
            return 0;

        default:
    }

    return DefWindowProc(hwnd, message, wParam, lParam);
}

wstring fromWStringz(const wchar* s)
{
    if (s is null) return null;

    wchar* ptr;
    for (ptr = cast(wchar*)s; *ptr; ++ptr) {}

    return to!wstring(s[0..ptr-s]);
}

TCHAR[32] szOKLabel = 0;

extern (Windows)
BOOL MainDlg(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam) nothrow
{
    static string szIPAddr = "132.163.135.130";
    static HWND hwndButton, hwndEdit;
    static SOCKET sock;
    static SOCKADDR_IN sa;

    int iError, iSize;
    ulong ulTime;
    WORD wEvent, wError;
    WSADATA WSAData;
    WSAData.szDescription = 0;

    switch (message)
    {
        case WM_INITDIALOG:
            hwndButton = GetDlgItem(hwnd, IDOK);
            hwndEdit   = GetDlgItem(hwnd, IDC_TEXTOUT);
            return TRUE;

        case WM_COMMAND:

            switch (LOWORD(wParam))
            {
                case IDC_SERVER:
                    DialogBoxParam(hInst, "Servers", hwnd, &ServerDlg, cast(LPARAM)szIPAddr.toStringz);
                    return TRUE;

                case IDOK:
                    // Call "WSAStartup" and display description text
                    iError = WSAStartup(MAKEWORD(2, 0), &WSAData);
                    if (iError)
                    {
                        EditPrintf(hwndEdit, assumeWontThrow(format("Startup error #%s.\r\n", iError)));
                        return TRUE;
                    }

                    EditPrintf(hwndEdit, assumeWontThrow(format("Started up %s\r\n", WSAData.szDescription)));

                    // Call "socket"
                    sock = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);

                    if (sock == INVALID_SOCKET)
                    {
                        EditPrintf(hwndEdit, assumeWontThrow(format("Socket creation error #%s.\r\n", WSAGetLastError())));
                        WSACleanup();
                        return TRUE;
                    }

                    EditPrintf(hwndEdit, assumeWontThrow(format("Socket %s created.\r\n", sock)));

                    // Call "WSAAsyncSelect"
                    if (SOCKET_ERROR == WSAAsyncSelect(sock, hwnd, WM_SOCKET_NOTIFY,
                                                       FD_CONNECT | FD_READ))
                    {
                        EditPrintf(hwndEdit, assumeWontThrow(format("WSAAsyncSelect error #%s.\r\n", WSAGetLastError())));
                        closesocket(sock);
                        WSACleanup();
                        return TRUE;
                    }

                    // Call "connect" with IP address and time-server port
                    sa.sin_family = AF_INET;
                    sa.sin_port = htons(IPPORT_TIMESERVER);

                    // @BUG@: S_un is not in the bindings
                    //~ sa.sin_addr.S_un.S_addr = inet_addr(szIPAddr.toStringz);
                    sa.sin_addr.s_addr = inet_addr(szIPAddr.toStringz);

                    connect(sock, cast(SOCKADDR*)&sa, sa.sizeof);

                    // "connect" will return SOCKET_ERROR because even if it
                    // succeeds, it will require blocking. The following only
                    // reports unexpected errors.
                    iError = WSAGetLastError();
                    if (WSAEWOULDBLOCK != iError)
                    {
                        EditPrintf(hwndEdit, assumeWontThrow(format("Connect error #%s.\r\n", iError)));
                        closesocket(sock);
                        WSACleanup();
                        return TRUE;
                    }

                    EditPrintf(hwndEdit, assumeWontThrow(format("Connecting to %s...", szIPAddr)));

                    // The result of the "connect" call will be reported
                    // through the WM_SOCKET_NOTIFY message.
                    // Set timer and change the button to "Cancel"
                    SetTimer(hwnd, ID_TIMER, 1000, NULL);
                    GetWindowText(hwndButton, szOKLabel.ptr, szOKLabel.count);
                    SetWindowText(hwndButton, "Cancel");
                    SetWindowLongPtr(hwndButton, GWL_ID, IDCANCEL);
                    return TRUE;

                case IDCANCEL:
                    closesocket(sock);
                    sock = 0;
                    WSACleanup();
                    SetWindowText(hwndButton, szOKLabel.ptr);
                    SetWindowLongPtr(hwndButton, GWL_ID, IDOK);

                    KillTimer(hwnd, ID_TIMER);
                    EditPrintf(hwndEdit, "\r\nSocket closed.\r\n");
                    return TRUE;

                case IDC_CLOSE:

                    if (sock)
                        SendMessage(hwnd, WM_COMMAND, IDCANCEL, 0);

                    DestroyWindow(GetParent(hwnd));
                    return TRUE;

                default:
            }

            return FALSE;

        case WM_TIMER:
            EditPrintf(hwndEdit, ".");
            return TRUE;

        case WM_SOCKET_NOTIFY:
            wEvent = WSAGETSELECTEVENT(lParam);   // ie, LOWORD
            wError = WSAGETSELECTERROR(lParam);   // ie, HIWORD

            // Process two events specified in WSAAsyncSelect
            switch (wEvent)
            {
                // This event occurs as a result of the "connect" call
                case FD_CONNECT:
                    EditPrintf(hwndEdit, "\r\n");

                    if (wError)
                    {
                        EditPrintf(hwndEdit, assumeWontThrow(format("Connect error #%s.", wError)));
                        SendMessage(hwnd, WM_COMMAND, IDCANCEL, 0);
                        return TRUE;
                    }

                    EditPrintf(hwndEdit, assumeWontThrow(format("Connected to %s.\r\n", szIPAddr)));

                    // Try to receive data. The call will generate an error
                    // of WSAEWOULDBLOCK and an event of FD_READ
                    recv(sock, cast(ubyte*)&ulTime, 4, MSG_PEEK);
                    EditPrintf(hwndEdit, "Waiting to receive...");
                    return TRUE;

                // This even occurs when the "recv" call can be made
                case FD_READ:
                    KillTimer(hwnd, ID_TIMER);
                    EditPrintf(hwndEdit, "\r\n");

                    if (wError)
                    {
                        EditPrintf(hwndEdit, assumeWontThrow(format("FD_READ error #%s.", wError)));
                        SendMessage(hwnd, WM_COMMAND, IDCANCEL, 0);
                        return TRUE;
                    }

                    // Get the time and swap the bytes
                    iSize  = recv(sock, cast(ubyte*)&ulTime, 4, 0);
                    ulTime = ntohl(cast(c_ulong)ulTime);
                    EditPrintf(hwndEdit, assumeWontThrow(format("Received current time of %s seconds since Jan. 1 1900.\r\n", ulTime)));

                    // Change the system time
                    ChangeSystemTime(hwndEdit, cast(uint)ulTime);  // downcasting..
                    SendMessage(hwnd, WM_COMMAND, IDCANCEL, 0);
                    return TRUE;

                default:
            }

            return FALSE;

        default:
    }

    return FALSE;
}

extern (Windows)
BOOL ServerDlg(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam) nothrow
{
    static wchar[] szServer;
    static WORD  wServer = IDC_SERVER1;
    wchar[64] szLabel = 0;

    switch (message)
    {
        case WM_INITDIALOG:
            szServer = assumeWontThrow(fromWStringz(cast(wchar*)lParam).dup);
            CheckRadioButton(hwnd, IDC_SERVER1, IDC_SERVER10, wServer);
            return TRUE;

        case WM_COMMAND:

            switch (LOWORD(wParam))
            {
                case IDC_SERVER1:
                case IDC_SERVER2:
                case IDC_SERVER3:
                case IDC_SERVER4:
                case IDC_SERVER5:
                case IDC_SERVER6:
                case IDC_SERVER7:
                case IDC_SERVER8:
                case IDC_SERVER9:
                case IDC_SERVER10:
                    wServer = LOWORD(wParam);
                    return TRUE;

                case IDOK:
                    GetDlgItemText(hwnd, wServer, szLabel.ptr, szLabel.count);

                    szServer = assumeWontThrow(szLabel[szLabel.indexOf("(") .. szLabel.indexOf(")")]);
                    EndDialog(hwnd, TRUE);
                    return TRUE;

                case IDCANCEL:
                    EndDialog(hwnd, FALSE);
                    return TRUE;

                default:
            }

            break;

        default:
    }

    return FALSE;
}

void ChangeSystemTime(HWND hwndEdit, ULONG ulTime) nothrow
{
    FILETIME ftNew;
    LARGE_INTEGER li;
    SYSTEMTIME stOld, stNew;

    GetLocalTime(&stOld);

    stNew.wYear         = 1900;
    stNew.wMonth        = 1;
    stNew.wDay          = 1;
    stNew.wHour         = 0;
    stNew.wMinute       = 0;
    stNew.wSecond       = 0;
    stNew.wMilliseconds = 0;

    SystemTimeToFileTime(&stNew, &ftNew);
    li = *cast(LARGE_INTEGER*)&ftNew;
    li.QuadPart += cast(LONGLONG)10000000 * ulTime;
    ftNew        = *cast(FILETIME*)&li;
    FileTimeToSystemTime(&ftNew, &stNew);

    if (SetSystemTime(&stNew))
    {
        GetLocalTime(&stNew);
        FormatUpdatedTime(hwndEdit, &stOld, &stNew);
    }
    else
        EditPrintf(hwndEdit, "Could NOT set new date and time.");
}

void FormatUpdatedTime(HWND hwndEdit, SYSTEMTIME* pstOld, SYSTEMTIME* pstNew) nothrow
{
    TCHAR[64] szDateOld, szTimeOld, szDateNew, szTimeNew;
    szDateOld = 0;
    szTimeOld = 0;
    szDateNew = 0;
    szTimeNew = 0;


    GetDateFormat(LOCALE_USER_DEFAULT, LOCALE_NOUSEROVERRIDE | DATE_SHORTDATE,
                  pstOld, NULL, szDateOld.ptr, szDateOld.count);

    GetTimeFormat(LOCALE_USER_DEFAULT, LOCALE_NOUSEROVERRIDE |
                  TIME_NOTIMEMARKER | TIME_FORCE24HOURFORMAT,
                  pstOld, NULL, szTimeOld.ptr, szTimeOld.count);

    GetDateFormat(LOCALE_USER_DEFAULT, LOCALE_NOUSEROVERRIDE | DATE_SHORTDATE,
                  pstNew, NULL, szDateNew.ptr, szDateNew.count);

    GetTimeFormat(LOCALE_USER_DEFAULT, LOCALE_NOUSEROVERRIDE |
                  TIME_NOTIMEMARKER | TIME_FORCE24HOURFORMAT,
                  pstNew, NULL, szTimeNew.ptr, szTimeNew.count);

    EditPrintf(hwndEdit,
               assumeWontThrow(format("System date and time successfully changed from\r\n\t%s, %s.%03s to\r\n\t%s, %s.%03s.",
               szDateOld, szTimeOld, pstOld.wMilliseconds,
               szDateNew, szTimeNew, pstNew.wMilliseconds)));
}

//~ void EditPrintf(HWND hwndEdit, TCHAR* szFormat, ...)
void EditPrintf(HWND hwndEdit, string szBuffer) nothrow
{
    SendMessage(hwndEdit, EM_SETSEL, cast(WPARAM)-1, cast(LPARAM)-1);
    SendMessage(hwndEdit, EM_REPLACESEL, FALSE, assumeWontThrow(cast(LPARAM)szBuffer.toUTF16z));
    SendMessage(hwndEdit, EM_SCROLLCARET, 0, 0);
}

// missing druntime definitions
// https://issues.dlang.org/show_bug.cgi?id=23289
enum {
    FD_READ_BIT,
    FD_WRITE_BIT,
    FD_OOB_BIT,
    FD_ACCEPT_BIT,
    FD_CONNECT_BIT,
    FD_CLOSE_BIT,
    FD_QOS_BIT,
    FD_GROUP_QOS_BIT,
    FD_ROUTING_INTERFACE_CHANGE_BIT,
    FD_ADDRESS_LIST_CHANGE_BIT,
    FD_MAX_EVENTS // = 10
}

const int
    FD_READ                     = 1 << FD_READ_BIT,
    FD_WRITE                    = 1 << FD_WRITE_BIT,
    FD_OOB                      = 1 << FD_OOB_BIT,
    FD_ACCEPT                   = 1 << FD_ACCEPT_BIT,
    FD_CONNECT                  = 1 << FD_CONNECT_BIT,
    FD_CLOSE                    = 1 << FD_CLOSE_BIT,
    FD_QOS                      = 1 << FD_QOS_BIT,
    FD_GROUP_QOS                = 1 << FD_GROUP_QOS_BIT,
    FD_ROUTING_INTERFACE_CHANGE = 1 << FD_ROUTING_INTERFACE_CHANGE_BIT,
    FD_ADDRESS_LIST_CHANGE      = 1 << FD_ADDRESS_LIST_CHANGE_BIT,
    FD_ALL_EVENTS               = (1 << FD_MAX_EVENTS) - 1;

enum {
    IPPORT_ECHO        =    7,
    IPPORT_DISCARD     =    9,
    IPPORT_SYSTAT      =   11,
    IPPORT_DAYTIME     =   13,
    IPPORT_NETSTAT     =   15,
    IPPORT_FTP         =   21,
    IPPORT_TELNET      =   23,
    IPPORT_SMTP        =   25,
    IPPORT_TIMESERVER  =   37,
    IPPORT_NAMESERVER  =   42,
    IPPORT_WHOIS       =   43,
    IPPORT_MTP         =   57,
    IPPORT_TFTP        =   69,
    IPPORT_RJE         =   77,
    IPPORT_FINGER      =   79,
    IPPORT_TTYLINK     =   87,
    IPPORT_SUPDUP      =   95,
    IPPORT_EXECSERVER  =  512,
    IPPORT_LOGINSERVER =  513,
    IPPORT_CMDSERVER   =  514,
    IPPORT_EFSSERVER   =  520,
    IPPORT_BIFFUDP     =  512,
    IPPORT_WHOSERVER   =  513,
    IPPORT_ROUTESERVER =  520,
    IPPORT_RESERVED    = 1024
}

alias LOWORD WSAGETASYNCBUFLEN, WSAGETSELECTEVENT;
alias HIWORD WSAGETASYNCERROR, WSAGETSELECTERROR;
