// === Base functions

/// An Instance of your module, you program. Retrieve it with GetModuleHandleW.
pub const Instance = *anyopaque;

/// String definition on Windows.
pub const String = [*:0]const u16;

/// For allocated (non comptime known) Strings
pub const W = @import("std").unicode.utf8ToUtf16LeAllocZ;
/// For comptime known Strings
pub const W2 = @import("std").unicode.utf8ToUtf16LeStringLiteral;

/// Return your program module Instance.
pub extern "kernel32" fn GetModuleHandleW(moduleName: ?String) callconv(.winapi) ?Instance;
/// Return the last error number, check on MS documentation what the code means.
pub extern "kernel32" fn GetLastError() callconv(.winapi) u32;

pub const HResult = enum(c_int) {
    ok = 0,
    _,
};

pub const Bool = enum(c_int) {
    not_ok = 0,
    ok = 1,
    _,
};

pub fn loword(lParam: isize) u16 {
    const value: usize = @bitCast(lParam);
    return @intCast(0xffff & value);
}

pub fn hiword(lParam: isize) u16 {
    const value: usize = @bitCast(lParam);
    return @intCast(0xffff & (value >> 16));
}

pub fn loword2(wParam: usize) u16 {
    return @intCast(0xffff & wParam);
}

pub fn hiword2(wParam: usize) u16 {
    return @intCast(0xffff & (wParam >> 16));
}

pub fn lobyte(val: u16) u8 {
    const bits: [2]u8 = @bitCast(val);
    return switch (comptime @import("builtin").cpu.arch.endian()) {
        .big => return bits[1],
        .little => return bits[0],
    };
}

pub fn hibyte(val: u16) u8 {
    const bits: [2]u8 = @bitCast(val);
    return switch (comptime @import("builtin").cpu.arch.endian()) {
        .Big => return bits[0],
        .Little => return bits[1],
    };
}

// === Window & messages

pub extern "user32" fn RegisterClassExW(
    window_class: ?*const WindowClass,
) callconv(.winapi) WindowClassAtom;

pub extern "user32" fn CreateWindowExW(
    ex_style: ExtendedWindowStyle,
    class_name: ?String,
    title: ?String,
    style: WindowStyle,
    x: i32,
    y: i32,
    width: i32,
    height: i32,
    parent: ?WindowHandle,
    menu: ?MenuHandler,
    instance: ?Instance,
    lpParam: ?*anyopaque,
) callconv(.winapi) ?WindowHandle;

pub extern "user32" fn ShowWindow(
    window_handle: ?WindowHandle,
    display: u32,
) callconv(.winapi) ?WindowHandle;

pub extern "user32" fn GetMessageW(
    message: ?*Message,
    window_handle: ?WindowHandle,
    filter_min: u32,
    filter_max: u32,
) callconv(.winapi) i32;

pub extern "user32" fn TranslateMessage(
    message: ?*const Message,
) callconv(.winapi) c_int;

pub extern "user32" fn DispatchMessageW(
    lpMsg: ?*const Message,
) callconv(.winapi) isize;

/// End the program.
pub extern "user32" fn PostQuitMessage(
    val: i32,
) callconv(.winapi) void;

pub extern "user32" fn PostMessageW(
    hWnd: ?WindowHandle,
    Msg: u32,
    wParam: usize,
    lParam: isize,
) callconv(.winapi) Bool;

pub extern "user32" fn PostThreadMessageW(
    idThread: u32,
    Msg: u32,
    wParam: usize,
    lParam: isize,
) callconv(.winapi) bool;
pub extern "kernel32" fn GetCurrentThreadId() callconv(.winapi) u32;

/// WindowProcedure is the function signature to handle window messages.
pub const WindowProcedure = switch (@import("builtin").zig_backend) {
    .stage1 => fn (
        window_handle: WindowHandle,
        message_type: MessageType,
        wParam: usize,
        lParam: isize,
    ) callconv(.winapi) isize,
    else => *const fn (
        window_handle: WindowHandle,
        message_type: MessageType,
        wParam: usize,
        lParam: isize,
    ) callconv(.winapi) isize,
};

/// This is the default handler for windows procedures/messages.
/// Use it to handle messages that your application will not handle,
/// to ensure all messages are handled.
pub extern "user32" fn DefWindowProcW(
    window_handle: WindowHandle,
    message_type: MessageType,
    wParam: usize,
    lParam: isize,
) callconv(.winapi) isize;

pub const WindowHandle = *anyopaque;
pub const WindowClassAtom = u16;

pub const IconHandler = *anyopaque;
pub const BrushHandler = *anyopaque;
pub const MenuHandler = *anyopaque;

pub const CursorName = enum(u32) {
    Arrow = 32512,
    Beam = 32513,
    Wait = 32514,
    Cross = 32515,
    SizeNWSE = 32642,
    SizeNESW = 32643,
    SizeWE = 32644,
    SizeNS = 32645,
    SizeAll = 32646,
    No = 32648,
    Hand = 32649,
};

pub const WindowClass = extern struct {
    size: u32 = @sizeOf(@This()),
    style: u32 = @intFromEnum(ClassStyle.HREDRAW) | @intFromEnum(ClassStyle.VREDRAW),
    window_procedure: ?WindowProcedure = DefWindowProcW,
    class_extra: i32 = 0,
    window_extra: i32 = 0,
    instance: ?Instance,
    icon: ?IconHandler = null,
    cursor: ?CursorHandler = null,
    background: ?BrushHandler = null,
    menu_name: ?String = null,
    class_name: ?String,
    icon_small: ?IconHandler = null,
};

pub const ExtendedWindowStyle = enum(u32) {
    None = 0x00000000,
    OverlappedWindow = 0x00000300,
    ClientEdge = 0x00000200,
    WindowEdge = 0x00000100,
    _,
};

pub const WindowStyle = enum(u32) {
    Border = 0x00800000,
    Caption = 0x00C00000,
    Maximize = 0x01000000,
    MaximizeBox = 0x00010000,
    Minimize = 0x20000000,
    MinimizeBox = 0x00020000,
    SysMenu = 0x00080000,
    ThickFrame = 0x00040000,
    OverlappedWindow = 0x00CF0000,
    Overlapped = 0x00000000,
    _,
};

pub const ClassStyle = enum(u32) {
    VREDRAW = 1,
    HREDRAW = 2,
    DBLCLKS = 8,
    OWNDC = 32,
    CLASSDC = 64,
    PARENTDC = 128,
    NOCLOSE = 512,
    SAVEBITS = 2048,
    BYTEALIGNCLIENT = 4096,
    BYTEALIGNWINDOW = 8192,
    GLOBALCLASS = 16384,
    IME = 65536,
    DROPSHADOW = 131072,
};

pub const UseDefault = @as(i32, -2147483648);

pub const Message = extern struct {
    hwnd: ?WindowHandle,
    message: MessageType,
    wParam: usize,
    lParam: isize,
    time: u32,
    pt: Point,
};

pub const Point = extern struct {
    x: i32,
    y: i32,
};

pub const MessageType = enum(u32) {
    WM_CREATE = 0x0001,
    WM_DESTROY = 0x0002,
    WM_SIZE = 0x0005,
    WM_CLOSE = 0x0010,
    WM_QUIT = 0x0012,
    WM_PAINT = 0x000F, //15,
    WM_KEYDOWN = 0x0100,
    WM_KEYUP = 0x0101,
    WM_CHAR = 0x0102,
    WM_DEADCHAR = 0x0103,
    WM_SYSKEYDOWN = 0x0104,
    WM_SYSKEYUP = 0x0105,
    WM_LBUTTONDOWN = 0x0201,
    WM_LBUTTONUP = 0x0202,
    WM_LBUTTONDBLCLK = 0x0203,
    WM_RBUTTONDOWN = 0x0204,
    WM_RBUTTONUP = 0x0205,
    WM_RBUTTONDBLCLK = 0x0206,
    WM_MBUTTONDOWN = 0x0207,
    WM_MBUTTONUP = 0x0208,
    WM_MBUTTONDBLCLK = 0x0209,
    WM_MOUSEMOVE = 0x0200,
    WM_MOUSEWHEEL = 0x020A,
    WM_XBUTTONDOWN = 0x020B,
    WM_XBUTTONUP = 0x020C,
    WM_XBUTTONDBLCLK = 0x02D,
    WM_MOUSEHWHEEL = 0x020E,
    WM_SETCURSOR = 0x0020,
    WM_ERASEBKGND = 0x0014,
    WM_DPICHANGED = 0x02E0,
    /// The clipboard's contents changed; sent to every window registered with
    /// AddClipboardFormatListener, whoever changed it.
    WM_CLIPBOARDUPDATE = 0x031D,
    _,
};

// === Input controls

/// Used to check wParam from messages, as a mask(?).
pub const ControlKeys = enum(u32) {
    MK_LBUTTON = 0x0001,
    MK_RBUTTON = 0x0002,
    MK_SHIFT = 0x0004,
    MK_CONTROL = 0x0008,
    MK_MBUTTON = 0x0010,
    MK_XBUTTON1 = 0x0020,
    MK_XBUTTON2 = 0x0040,
};

pub const VirtualKeys = @import("vk.zig").VirtualKeys;

/// Used to check details about keyboard input
pub const KeystrokeFlags = packed struct {
    count: u16,
    scanCode: u8,
    extended: u1,
    reserved: u4,
    context: u1,
    previousState: u1,
    transitionState: u1,
    pad: u32,
};

pub fn mouseWheelDelta(wparam: usize) i16 {
    return @bitCast(hiword2(wparam));
}

// === Cursors

pub extern "user32" fn LoadCursorW(
    instance: ?Instance,
    cursor: CursorName,
) callconv(.winapi) ?CursorHandler;

pub extern "user32" fn ShowCursor(
    show: bool,
) callconv(.winapi) i32;

pub extern "user32" fn SetCursor(
    cursor: ?CursorHandler,
) callconv(.winapi) ?CursorHandler;

pub const CursorHandler = *anyopaque;

// === Clipboard
//
// The clipboard is a global store the system serializes: open it (any thread), replace or
// read its contents, close it. Text goes in as CF_UNICODETEXT in a movable global block
// that the system owns once SetClipboardData succeeds.

pub extern "user32" fn OpenClipboard(hWndNewOwner: ?WindowHandle) callconv(.winapi) i32;
pub extern "user32" fn CloseClipboard() callconv(.winapi) i32;
pub extern "user32" fn EmptyClipboard() callconv(.winapi) i32;
pub extern "user32" fn SetClipboardData(uFormat: u32, hMem: ?*anyopaque) callconv(.winapi) ?*anyopaque;
pub extern "user32" fn GetClipboardData(uFormat: u32) callconv(.winapi) ?*anyopaque;
pub extern "user32" fn IsClipboardFormatAvailable(format: u32) callconv(.winapi) i32;
pub extern "kernel32" fn GlobalAlloc(uFlags: u32, dwBytes: usize) callconv(.winapi) ?*anyopaque;
pub extern "kernel32" fn GlobalLock(hMem: *anyopaque) callconv(.winapi) ?[*]u8;
pub extern "kernel32" fn GlobalUnlock(hMem: *anyopaque) callconv(.winapi) i32;
pub extern "kernel32" fn GlobalFree(hMem: *anyopaque) callconv(.winapi) ?*anyopaque;
pub extern "kernel32" fn GlobalSize(hMem: *anyopaque) callconv(.winapi) usize;

/// Ask for WM_CLIPBOARDUPDATE on `hwnd` whenever the clipboard changes. The system drops the
/// registration with the window; RemoveClipboardFormatListener is for dropping it earlier.
pub extern "user32" fn AddClipboardFormatListener(hwnd: WindowHandle) callconv(.winapi) i32;
pub extern "user32" fn RemoveClipboardFormatListener(hwnd: WindowHandle) callconv(.winapi) i32;
/// A counter the system bumps on every clipboard change (0 when the caller may not see the
/// clipboard): what tells one change from another, and our own from somebody else's.
pub extern "user32" fn GetClipboardSequenceNumber() callconv(.winapi) u32;

pub const CF_UNICODETEXT: u32 = 13;
pub const GMEM_MOVEABLE: u32 = 0x0002;

// === Icons

pub extern "user32" fn CreateIconIndirect(piconinfo: *IconInfo) callconv(.winapi) ?IconHandler;
pub extern "user32" fn DestroyIcon(hIcon: ?IconHandler) callconv(.winapi) bool;
pub extern "user32" fn SendMessageW(hWnd: ?WindowHandle, Msg: u32, wParam: usize, lParam: isize) callconv(.winapi) isize;
pub extern "gdi32" fn CreateBitmap(nWidth: i32, nHeight: i32, nPlanes: u32, nBitCount: u32, lpBits: ?*const anyopaque) callconv(.winapi) ?Bitmap;

pub const IconInfo = extern struct {
    fIcon: i32 = 1,
    xHotspot: u32 = 0,
    yHotspot: u32 = 0,
    hbmMask: ?Bitmap = null,
    hbmColor: ?Bitmap = null,
};

pub const WM_SETICON: u32 = 0x0080;
pub const ICON_BIG: usize = 1;
pub const ICON_SMALL: usize = 0;

// === Drawing

pub extern "user32" fn UpdateWindow(
    window_handle: ?WindowHandle,
) callconv(.winapi) bool;

pub extern "dwmapi" fn DwmFlush() callconv(.winapi) isize;
pub extern "gdi32" fn GdiFlush() callconv(.winapi) Bool;

pub extern "gdi32" fn InvalidateRect(
    window_handle: ?WindowHandle,
    rect: ?*Rect,
    erase: bool,
) callconv(.winapi) bool;

pub extern "gdi32" fn GetUpdateRect(
    window_handle: ?WindowHandle,
    rect: ?*Rect,
    erase: bool,
) callconv(.winapi) bool;

pub extern "user32" fn BeginPaint(
    window_handle: WindowHandle,
    paint: *Paint,
) callconv(.winapi) ?DeviceContext;

pub extern "user32" fn EndPaint(
    window_handle: WindowHandle,
    lpPaint: *Paint,
) callconv(.winapi) bool;

pub extern "user32" fn GetDC(
    handle: ?WindowHandle,
) callconv(.winapi) ?DeviceContext;

pub extern "user32" fn ReleaseDC(
    window: ?WindowHandle,
    handle: ?DeviceContext,
) callconv(.winapi) c_int;

pub extern "gdi32" fn BitBlt(
    dstHDC: ?DeviceContext,
    dstX: i32,
    dstY: i32,
    dstWidth: i32,
    dstHeight: i32,
    srcHdc: ?DeviceContext,
    srcX: i32,
    srcY: i32,
    op: RasterOperation,
) callconv(.winapi) bool;

pub extern "gdi32" fn CreateCompatibleDC(
    handle: ?DeviceContext,
) callconv(.winapi) ?DeviceContext;

pub extern "gdi32" fn GetWindowDC(
    handle: ?WindowHandle,
) callconv(.winapi) ?DeviceContext;

pub extern "user32" fn SelectObject(
    handle0: ?DeviceContext,
    handle1: ?Bitmap,
) callconv(.winapi) DeviceContext;

pub extern "gdi32" fn DeleteObject(
    handle: ?Bitmap,
) callconv(.winapi) bool;

pub extern "gdi32" fn StretchDIBits(
    hdc: ?DeviceContext,
    xDest: i32,
    yDest: i32,
    DestWidth: i32,
    DestHeight: i32,
    xSrc: i32,
    ySrc: i32,
    SrcWidth: i32,
    SrcHeight: i32,
    lpBits: [*]const u8,
    lpbmi: *const BitmapInfo,
    iUsage: DIBUsage,
    rop: RasterOperation,
) callconv(.winapi) i32;

pub extern "gdi32" fn CreateDIBSection(
    handle: ?DeviceContext,
    pbmi: ?*const BitmapInfo,
    usage: DIBUsage,
    ppvBits: *[*]u8,
    hSection: ?*anyopaque,
    offset: u32,
) callconv(.winapi) ?Bitmap;

pub extern "user32" fn GetSysColorBrush(
    index: i32,
) callconv(.winapi) ?BrushHandler;

pub extern "gdi32" fn CreateSolidBrush(
    color: u32,
) callconv(.winapi) ?BrushHandler;

pub extern "user32" fn FillRect(
    handle: ?DeviceContext,
    rect: ?*Rect,
    brush: ?BrushHandler,
) callconv(.winapi) i32;

pub extern "user32" fn GetWindowRect(
    handle: ?DeviceContext,
    rect: ?*Rect,
) callconv(.winapi) i32;

pub extern "user32" fn GetClientRect(
    handle: ?WindowHandle,
    rect: ?*Rect,
) callconv(.winapi) i32;

pub extern "gdi32" fn CreateCompatibleBitmap(
    hdc: ?DeviceContext,
    cx: i32,
    cy: i32,
) callconv(.winapi) ?Bitmap;

pub extern "gdi32" fn DeleteDC(
    hdc: ?DeviceContext,
) callconv(.winapi) bool;

pub extern "user32" fn GetDpiForWindow(
    hwnd: ?*anyopaque,
) callconv(.winapi) u32;

pub extern "user32" fn ClipCursor(
    rect: ?*const Rect,
) callconv(.winapi) i32;

pub extern "user32" fn ScreenToClient(
    hwnd: ?WindowHandle,
    point: *Point,
) callconv(.winapi) i32;

pub extern "user32" fn ClientToScreen(
    hwnd: ?WindowHandle,
    point: *Point,
) callconv(.winapi) i32;

pub const HTCLIENT: isize = 1;
pub const WHEEL_DELTA: i32 = 120;

pub extern "user32" fn GetKeyState(nVirtKey: c_int) callconv(.winapi) i16;

pub extern "user32" fn SetProcessDPIAware() callconv(.winapi) Bool;
pub extern "user32" fn GetDpiForSystem() callconv(.winapi) u32;

// Fullscreen support
pub extern "user32" fn GetWindowLongPtrW(hWnd: ?WindowHandle, nIndex: c_int) callconv(.winapi) isize;
pub extern "user32" fn SetWindowLongPtrW(hWnd: ?WindowHandle, nIndex: c_int, dwNewLong: isize) callconv(.winapi) isize;
pub extern "user32" fn SetWindowPos(hWnd: ?WindowHandle, hWndInsertAfter: ?WindowHandle, x: c_int, y: c_int, cx: c_int, cy: c_int, uFlags: u32) callconv(.winapi) bool;
pub extern "user32" fn MonitorFromWindow(hwnd: ?WindowHandle, dwFlags: u32) callconv(.winapi) ?Monitor;
pub extern "user32" fn GetMonitorInfoW(hMonitor: ?Monitor, lpmi: *MonitorInfo) callconv(.winapi) bool;

pub const GWL_STYLE: c_int = -16;
pub const GWLP_USERDATA: c_int = -21;
pub const HWND_TOP: ?WindowHandle = null;
pub const SWP_FRAMECHANGED: u32 = 0x0020;
pub const SWP_NOOWNERZORDER: u32 = 0x0200;
pub const SWP_NOZORDER: u32 = 0x0004;
pub const MONITOR_DEFAULTTOPRIMARY: u32 = 1;

pub const MonitorInfo = extern struct {
    cbSize: u32 = @sizeOf(MonitorInfo),
    rcMonitor: Rect = .{},
    rcWork: Rect = .{},
    dwFlags: u32 = 0,
};

pub const DeviceContext = *anyopaque;
pub const Bitmap = *anyopaque;
pub const Monitor = *anyopaque;

pub const Paint = extern struct {
    device_context: usize,
    erase: bool = false,
    rect: Rect = Rect{},
    restore: bool = false,
    incUpdate: bool = false,
    rgbReserved: [32]u8 = undefined,
};

pub const Rect = extern struct {
    left: i32 = 0,
    top: i32 = 0,
    right: i32 = 0,
    bottom: i32 = 0,
};

pub const BitmapInfo = extern struct {
    header: BitmapInfoHeader = .{},
    colors: extern struct {
        blue: u8 = 0,
        green: u8 = 0,
        red: u8 = 0,
        reserved: u8 = 0,
    } = .{},
};

pub const BitmapInfoHeader = extern struct {
    size: u32 = @sizeOf(@This()),
    width: i32 = 0,
    height: i32 = 0,
    planes: u16 = 1,
    bitCount: u16 = 32,
    compression: u32 = 0,
    sizeImage: u32 = 0,
    xPelsPerMeter: i32 = 0,
    yPelsPerMeter: i32 = 0,
    clrUsed: u32 = 0,
    clrImportant: u32 = 0,
};

pub const DIBUsage = enum(u32) {
    RGB_COLORS = 0,
    PAL_COLORS = 1,
};

pub const RasterOperation = enum(u32) {
    BLACKNESS = 0b100001,
    CAPTUREBLT,
    DSTINVER,
    MERGECOPY,
    MERGEPAINT,
    NOMIRRORBITMAP,
    NOTSRCOPY,
    NOTSRCEARE,
    PATCOPY,
    PATINVERT,
    PATPAINT,
    SRCAND,
    SRCCOPY = 13369376,
    SRCERASE,
    SRCINVERT,
    SRCPAINT,
    WHITENESS,
};

// === System tray (Shell_NotifyIcon)
//
// The tray is driven by sending NOTIFYICONDATAW structs to
// Shell_NotifyIconW(NIM_ADD/MODIFY/DELETE). Callbacks come back as
// window messages with `uCallbackMessage` (typically WM_USER+1) on the
// hidden HWND_MESSAGE-parented window we created. The lParam of those
// messages carries the actual mouse-button event.

pub extern "shell32" fn Shell_NotifyIconW(
    dwMessage: u32,
    lpData: *NotifyIconData,
) callconv(.winapi) Bool;

pub const NIM_ADD: u32 = 0x00000000;
pub const NIM_MODIFY: u32 = 0x00000001;
pub const NIM_DELETE: u32 = 0x00000002;
pub const NIM_SETFOCUS: u32 = 0x00000003;
pub const NIM_SETVERSION: u32 = 0x00000004;

pub const NIF_MESSAGE: u32 = 0x00000001;
pub const NIF_ICON: u32 = 0x00000002;
pub const NIF_TIP: u32 = 0x00000004;
pub const NIF_STATE: u32 = 0x00000008;
pub const NIF_INFO: u32 = 0x00000010;
pub const NIF_GUID: u32 = 0x00000020;
pub const NIF_REALTIME: u32 = 0x00000040;
pub const NIF_SHOWTIP: u32 = 0x00000080;

/// The version 4 notification protocol — packs (x, y) in lParam and
/// sends WM_CONTEXTMENU for right-clicks.
pub const NOTIFYICON_VERSION_4: u32 = 4;

pub const NotifyIconData = extern struct {
    cbSize: u32 = @sizeOf(@This()),
    hWnd: ?WindowHandle,
    uID: u32,
    uFlags: u32,
    uCallbackMessage: u32 = 0,
    hIcon: ?IconHandler = null,
    /// Wide-string tooltip (NUL-terminated, max 128 chars including NUL).
    szTip: [128]u16 = [_]u16{0} ** 128,
    dwState: u32 = 0,
    dwStateMask: u32 = 0,
    /// Balloon tip body (rarely used by us).
    szInfo: [256]u16 = [_]u16{0} ** 256,
    /// Either uTimeout or uVersion depending on context. We use uVersion.
    uVersion: u32 = 0,
    szInfoTitle: [64]u16 = [_]u16{0} ** 64,
    dwInfoFlags: u32 = 0,
    guidItem: [16]u8 = [_]u8{0} ** 16,
    hBalloonIcon: ?IconHandler = null,
};

/// Special parent value for message-only windows (no painting / focus,
/// receive messages only). C: `((HWND)-3)`.
pub const HWND_MESSAGE: ?WindowHandle = @ptrFromInt(@as(usize, @bitCast(@as(isize, -3))));

// === Popup menus (right-click context menu support)

pub extern "user32" fn CreatePopupMenu() callconv(.winapi) ?MenuHandler;
pub extern "user32" fn DestroyMenu(hMenu: ?MenuHandler) callconv(.winapi) Bool;

pub extern "user32" fn AppendMenuW(
    hMenu: ?MenuHandler,
    uFlags: u32,
    uIDNewItem: usize,
    lpNewItem: ?String,
) callconv(.winapi) Bool;

pub extern "user32" fn TrackPopupMenu(
    hMenu: ?MenuHandler,
    uFlags: u32,
    x: i32,
    y: i32,
    nReserved: i32,
    hWnd: ?WindowHandle,
    prcRect: ?*const Rect,
) callconv(.winapi) Bool;

pub const MF_STRING: u32 = 0x00000000;
pub const MF_BITMAP: u32 = 0x00000004;
pub const MF_GRAYED: u32 = 0x00000001;
pub const MF_DISABLED: u32 = 0x00000002;
pub const MF_CHECKED: u32 = 0x00000008;
pub const MF_POPUP: u32 = 0x00000010;
pub const MF_SEPARATOR: u32 = 0x00000800;

pub const TPM_LEFTBUTTON: u32 = 0x0000;
pub const TPM_RIGHTBUTTON: u32 = 0x0002;
pub const TPM_LEFTALIGN: u32 = 0x0000;
pub const TPM_RETURNCMD: u32 = 0x0100;
pub const TPM_NONOTIFY: u32 = 0x0080;

// === Foreground / cursor

pub extern "user32" fn SetForegroundWindow(hWnd: ?WindowHandle) callconv(.winapi) Bool;
pub extern "user32" fn GetCursorPos(point: *Point) callconv(.winapi) Bool;

// === Tray-related message constants

pub const WM_USER: u32 = 0x0400;
pub const WM_COMMAND: u32 = 0x0111;
pub const WM_CONTEXTMENU: u32 = 0x007B;
pub const WM_NULL: u32 = 0x0000;

// === Registry and system parameters
//
// `RegGetValueW` opens, reads and closes a key in one call and checks the value's
// type against `flags`. The set and delete calls exist so a read can be verified
// against a value this process wrote.

pub const RegistryKey = *opaque {};
pub const HKEY_CURRENT_USER: RegistryKey = @ptrFromInt(0x80000001);
pub const HKEY_LOCAL_MACHINE: RegistryKey = @ptrFromInt(0x80000002);

pub const REG_DWORD: u32 = 4;
pub const RRF_RT_REG_DWORD: u32 = 0x10;
pub const ERROR_SUCCESS: i32 = 0;
pub const ERROR_FILE_NOT_FOUND: i32 = 2;

pub extern "advapi32" fn RegGetValueW(
    key: RegistryKey,
    subkey: ?String,
    value: ?String,
    flags: u32,
    value_type: ?*u32,
    data: ?*anyopaque,
    data_size: ?*u32,
) callconv(.winapi) i32;
pub extern "advapi32" fn RegSetKeyValueW(
    key: RegistryKey,
    subkey: ?String,
    value: ?String,
    value_type: u32,
    data: ?*const anyopaque,
    data_size: u32,
) callconv(.winapi) i32;
pub extern "advapi32" fn RegDeleteKeyValueW(key: RegistryKey, subkey: ?String, value: ?String) callconv(.winapi) i32;
pub extern "advapi32" fn RegDeleteKeyW(key: RegistryKey, subkey: String) callconv(.winapi) i32;

/// The DWORD at `subkey\value` under `key`, or null when the value is missing or not a DWORD.
pub fn registryDword(key: RegistryKey, subkey: String, value: String) ?u32 {
    var data: u32 = 0;
    var size: u32 = @sizeOf(u32);
    if (RegGetValueW(key, subkey, value, RRF_RT_REG_DWORD, null, &data, &size) != ERROR_SUCCESS) return null;
    return data;
}

pub extern "user32" fn SystemParametersInfoW(action: u32, param: u32, data: ?*anyopaque, update: u32) callconv(.winapi) Bool;

/// Whether client-area animations (fades, slides) are enabled in the accessibility settings.
pub const SPI_GETCLIENTAREAANIMATION: u32 = 0x1042;

/// The system's client-area animation setting; null when the query fails.
pub fn clientAreaAnimation() ?bool {
    var enabled: Bool = .not_ok;
    if (SystemParametersInfoW(SPI_GETCLIENTAREAANIMATION, 0, &enabled, 0) != .ok) return null;
    return enabled != .not_ok;
}

/// WASAPI audio output. Raw COM bindings — playback policy belongs to whoever
/// uses them.
pub const wasapi = @import("wasapi.zig");
pub const mf = @import("mf.zig");

test {
    _ = wasapi;
    _ = mf;
}

// A live round trip through the system clipboard; runs under Wine with
// `zig build test -Dtarget=x86_64-windows -fwine`.
test "clipboard round trip" {
    if (@import("builtin").os.tag != .windows) return error.SkipZigTest;
    const std = @import("std");
    const text = W2("mir clipboard round trip");
    const bytes = (text.len + 1) * @sizeOf(u16);

    try std.testing.expect(OpenClipboard(null) != 0);
    try std.testing.expect(EmptyClipboard() != 0);
    const block = GlobalAlloc(GMEM_MOVEABLE, bytes) orelse return error.OutOfMemory;
    const memory = GlobalLock(block) orelse return error.LockFailed;
    @memcpy(memory[0..bytes], std.mem.sliceAsBytes(text[0 .. text.len + 1]));
    _ = GlobalUnlock(block);
    try std.testing.expect(SetClipboardData(CF_UNICODETEXT, block) != null);
    try std.testing.expect(CloseClipboard() != 0);

    try std.testing.expect(OpenClipboard(null) != 0);
    defer _ = CloseClipboard();
    try std.testing.expect(IsClipboardFormatAvailable(CF_UNICODETEXT) != 0);
    const read_block = GetClipboardData(CF_UNICODETEXT) orelse return error.NoData;
    const read_memory = GlobalLock(read_block) orelse return error.LockFailed;
    defer _ = GlobalUnlock(read_block);
    try std.testing.expect(GlobalSize(read_block) >= bytes);
    const units: []const u16 = @alignCast(std.mem.bytesAsSlice(u16, read_memory[0..bytes]));
    try std.testing.expectEqualSlices(u16, text[0 .. text.len + 1], units);
}

// A DWORD written under HKCU comes back through `registryDword`; a missing value is null. Runs under Wine like the clipboard test.
test "registry DWORD round trip" {
    if (@import("builtin").os.tag != .windows) return error.SkipZigTest;
    const std = @import("std");
    const subkey = W2("Software\\mir-windowz-test");
    const value = W2("Answer");
    const written: u32 = 42;

    try std.testing.expectEqual(ERROR_SUCCESS, RegSetKeyValueW(HKEY_CURRENT_USER, subkey, value, REG_DWORD, &written, @sizeOf(u32)));
    defer _ = RegDeleteKeyW(HKEY_CURRENT_USER, subkey);
    try std.testing.expectEqual(@as(?u32, written), registryDword(HKEY_CURRENT_USER, subkey, value));

    try std.testing.expectEqual(ERROR_SUCCESS, RegDeleteKeyValueW(HKEY_CURRENT_USER, subkey, value));
    try std.testing.expectEqual(@as(?u32, null), registryDword(HKEY_CURRENT_USER, subkey, value));
    try std.testing.expectEqual(@as(?u32, null), registryDword(HKEY_CURRENT_USER, subkey, W2("Missing")));
}

test "client-area animation setting is readable" {
    if (@import("builtin").os.tag != .windows) return error.SkipZigTest;
    try @import("std").testing.expect(clientAreaAnimation() != null);
}
