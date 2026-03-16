# mir-win32

Low-level Win32 API bindings for Zig.

Provides direct access to Win32 window management, GDI rendering, and input handling with dynamic DLL loading -- no build-time Windows SDK dependency.

> **Note:** Most users should prefer [mir-anywindow](../mir-anywindow) for cross-platform window management. Use mir-win32 directly only when you need low-level Win32 API access.

## Features

- Window creation and management (`CreateWindowExW`, `RegisterClassExW`, message pump)
- GDI rendering (`BitBlt`, `StretchDIBits`, `CreateDIBSection`)
- Keyboard and mouse input with virtual key codes and keystroke flags
- Cursor and icon management
- DPI awareness (`GetDpiForWindow`, `SetProcessDPIAware`)
- Fullscreen support (`MonitorFromWindow`, `SetWindowPos`)
- UTF-8 to UTF-16 string conversion helpers (`W`, `W2`)
- Dynamic system DLL loading -- no Windows SDK needed at build time

## Usage

### Install

```sh
zig fetch --save git+https://github.com/make-it-render/mir-win32
```

### build.zig

```zig
const windowz_dep = b.dependency("windowz", .{ .target = target, .optimize = optimize });
exe.root_module.addImport("windows", windowz_dep.module("windows"));
```

### Example

```zig
const std = @import("std");
const win = @import("windows");

var frame_handle: ?win.DeviceContext = null;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() != .leak);
    const allocator = gpa.allocator();

    const instance = win.GetModuleHandleW(null);
    if (instance == null) return error.InitError;

    const class_name = try win.W(allocator, "HelloClass");
    defer allocator.free(class_name);

    const title = win.W2("Hello world!");
    const cursor = win.LoadCursorW(null, .Arrow);

    var window_class: win.WindowClass = .{
        .style = @intFromEnum(win.ClassStyle.HREDRAW) | @intFromEnum(win.ClassStyle.VREDRAW),
        .window_procedure = windowProc,
        .instance = instance,
        .class_name = class_name,
        .cursor = cursor,
        .background = win.CreateSolidBrush(0x00000000),
    };
    _ = win.RegisterClassExW(&window_class);

    frame_handle = win.CreateCompatibleDC(null);

    const window_handle = win.CreateWindowExW(
        win.ExtendedWindowStyle.OverlappedWindow,
        class_name,
        title,
        win.WindowStyle.OverlappedWindow,
        win.UseDefault, win.UseDefault, // x, y
        win.UseDefault, win.UseDefault, // width, height
        null, null, instance, null,
    );
    if (window_handle == null) return error.CreateWindowError;

    _ = win.ShowWindow(window_handle, 10);

    var msg: win.Message = undefined;
    while (win.GetMessageW(&msg, null, 0, 0) > 0) {
        _ = win.TranslateMessage(&msg);
        _ = win.DispatchMessageW(&msg);
        _ = win.InvalidateRect(window_handle, null, false);
        _ = win.UpdateWindow(window_handle);
    }
}

fn windowProc(
    window_handle: win.WindowHandle,
    message_type: win.MessageType,
    wparam: usize,
    lparam: isize,
) callconv(.winapi) isize {
    switch (message_type) {
        .WM_CLOSE => win.PostQuitMessage(0),
        .WM_PAINT => {
            var paint = std.mem.zeroes(win.Paint);
            const display_handle = win.BeginPaint(window_handle, &paint);
            defer _ = win.EndPaint(window_handle, &paint);
            _ = win.BitBlt(
                display_handle,
                paint.rect.left, paint.rect.top,
                paint.rect.right - paint.rect.left,
                paint.rect.bottom - paint.rect.top,
                frame_handle,
                paint.rect.left, paint.rect.top,
                .SRCCOPY,
            );
        },
        .WM_KEYDOWN => {
            const key: win.VirtualKeys = @enumFromInt(wparam);
            const keyFlags: win.KeystrokeFlags = @bitCast(lparam);
            _ = .{ key, keyFlags };
        },
        .WM_MOUSEMOVE => {
            const x = win.loword(lparam);
            const y = win.hiword(lparam);
            _ = .{ x, y };
        },
        else => return win.DefWindowProcW(window_handle, message_type, wparam, lparam),
    }
    return 0;
}
```

For a complete working example with bitmap creation, pixel drawing, and mouse/keyboard handling, see [src/demo.zig](src/demo.zig).

## API

### String helpers

```zig
// Runtime-known strings (allocates)
const name = try win.W(allocator, "MyWindow");
defer allocator.free(name);

// Comptime-known string literals
const title = win.W2("Hello!");
```

### Window creation

| Type / Function | Description |
|-----------------|-------------|
| `WindowClass` | Window class configuration (style, procedure, instance, cursor, etc.) |
| `RegisterClassExW` | Register a window class |
| `CreateWindowExW` | Create a window with extended styles |
| `ShowWindow` | Show or hide a window |
| `WindowStyle` | Window styles (`OverlappedWindow`, `Border`, `Caption`, etc.) |
| `ExtendedWindowStyle` | Extended styles (`OverlappedWindow`, `ClientEdge`, `WindowEdge`) |
| `UseDefault` | Default position/size sentinel for `CreateWindowExW` |

### Message loop

| Type / Function | Description |
|-----------------|-------------|
| `GetMessageW` | Block until a message is available |
| `TranslateMessage` | Translate virtual-key messages into character messages |
| `DispatchMessageW` | Dispatch a message to the window procedure |
| `DefWindowProcW` | Default handler for unprocessed messages |
| `PostQuitMessage` | Post a quit message to end the message loop |
| `MessageType` | Message types (`WM_PAINT`, `WM_KEYDOWN`, `WM_CLOSE`, etc.) |

### Drawing (GDI)

| Type / Function | Description |
|-----------------|-------------|
| `BeginPaint` / `EndPaint` | Begin and end a paint operation |
| `CreateDIBSection` | Create a device-independent bitmap with direct pixel access |
| `BitBlt` | Copy pixel data between device contexts |
| `StretchDIBits` | Draw stretched DIB to a device context |
| `CreateCompatibleDC` | Create an off-screen device context |
| `SelectObject` | Select a bitmap into a device context |
| `InvalidateRect` | Mark a region for repainting |
| `DwmFlush` | Wait for vsync |
| `BitmapInfo` | Bitmap format description (dimensions, bit depth, color info) |

### Input

| Type / Function | Description |
|-----------------|-------------|
| `VirtualKeys` | Virtual key code enumeration |
| `KeystrokeFlags` | Packed struct with scan code, repeat count, extended key flag |
| `ControlKeys` | Modifier key masks (`MK_SHIFT`, `MK_CONTROL`, etc.) |
| `mouseWheelDelta` | Extract wheel delta from `WM_MOUSEWHEEL` wParam |
| `loword` / `hiword` | Extract mouse x/y from lParam |

### Other

| Type / Function | Description |
|-----------------|-------------|
| `LoadCursorW` / `SetCursor` / `ShowCursor` | Cursor management |
| `CreateIconIndirect` / `DestroyIcon` | Icon creation and cleanup |
| `GetDpiForWindow` / `SetProcessDPIAware` | DPI awareness |
| `MonitorFromWindow` / `GetMonitorInfoW` | Monitor and fullscreen support |
| `SetWindowPos` / `GetWindowLongPtrW` / `SetWindowLongPtrW` | Window positioning and style manipulation |

## License

MIT License

Copyright (c) Diogo Souza da Silva
