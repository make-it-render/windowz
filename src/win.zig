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
    OverlappedWindow = 0x00000300,
    ClientEdge = 0x00000200,
    WindowEdge = 0x00000100,
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
    WM_ERASEBKGND = 0x0014,
    WM_DPICHANGED = 0x02E0,
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
