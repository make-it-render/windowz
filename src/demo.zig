//! Example usage of Windows APIs to create an window, get input events and draw to it.

const std = @import("std");
const win = @import("windows");

const log = std.log.scoped(.main);

var frame_handle: ?win.DeviceContext = null;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() != .leak);
    const allocator = gpa.allocator();

    // Get our own program instance handle.
    const instance = win.GetModuleHandleW(null);
    if (instance == null) {
        const e = win.GetLastError();
        log.err("Error getting instance {d}", .{e});
        return error.InitError;
    }

    // Convert our string to one Windows can use.
    const class_name = try win.W(allocator, "HelloClass"); // for runtime known strings
    defer allocator.free(class_name);

    const title = win.W2("Hello world!"); // For string literals, comptime known

    const cursor = win.LoadCursorW(null, .Arrow);
    if (cursor == null) {
        const err = win.GetLastError();
        log.err("LoadCursor error: {any}", .{err});
    }

    // Configure our windows class with typical options
    var window_class: win.WindowClass = .{
        .style = @intFromEnum(win.ClassStyle.HREDRAW) | @intFromEnum(win.ClassStyle.VREDRAW),
        .window_procedure = windowProc,
        .instance = instance,
        .class_name = class_name,
        .cursor = cursor,
        .background = win.CreateSolidBrush(0x00000000),
    };

    // Register the class to use later to create the window.
    _ = win.RegisterClassExW(&window_class);

    // Create a DeviceContext, used for part of drawing phase.
    // Must be done before create window be cause we might be messages right as the window is created.
    frame_handle = win.CreateCompatibleDC(null);
    if (frame_handle == null) {
        const err = win.GetLastError();
        log.err("CreateCompatibleDC error: {any}", .{err});
        return error.NoCompatibleDC;
    }

    // Create our window.
    const window_handle = win.CreateWindowExW(
        win.ExtendedWindowStyle.OverlappedWindow,
        class_name,
        title,
        win.WindowStyle.OverlappedWindow,
        win.UseDefault, // x
        win.UseDefault, // y
        win.UseDefault, // width
        win.UseDefault, // height
        null, // parent
        null, // menu
        instance,
        null,
    );
    if (window_handle == null) {
        const err = win.GetLastError();
        log.err("Create window error: {any}", .{err});
        return error.CreateWindowError;
    }

    // Show the window.
    const show_result = win.ShowWindow(window_handle, 10);
    if (show_result != null) {
        const err = win.GetLastError();
        log.err("ShowWindow error: {any}", .{err});
        return error.ShowWindowError;
    }

    while (win.ShowCursor(true) < 1) {}

    // Request the first window update, not really needed.
    _ = win.UpdateWindow(window_handle);

    // The main loop to process events and draw.
    var msg: win.Message = undefined;
    while (win.GetMessageW(&msg, null, 0, 0) > 0) {
        _ = win.TranslateMessage(&msg);
        _ = win.DispatchMessageW(&msg);

        _ = win.InvalidateRect(window_handle, null, false); // to force full screen redraw
        _ = win.UpdateWindow(window_handle); // request a WM_PAINT
    }
}

var pixels: [*]u8 = undefined;
var bitmap: ?win.Bitmap = null;

/// Function to process messages, input and draw.
pub fn windowProc(
    window_handle: win.WindowHandle,
    message_type: win.MessageType,
    wparam: usize,
    lparam: isize,
) callconv(.winapi) isize {
    switch (message_type) {
        .WM_CREATE => {
            // recrete our frame when the window resizes
            const bitmap_info = win.BitmapInfo{
                .header = .{
                    .width = 50,
                    .height = 50,
                },
            };

            // create a new frame
            bitmap = win.CreateDIBSection(
                null,
                &bitmap_info,
                .RGB_COLORS,
                &pixels,
                null,
                0,
            );
            if (bitmap == null) {
                const err = win.GetLastError();
                log.err("CreateDIBSection error: {any}", .{err});
                return 0;
            }

            // select this bitmap on our frame_handle
            _ = win.SelectObject(frame_handle, bitmap);
        },
        .WM_CLOSE => {
            win.PostQuitMessage(0);
        },
        .WM_PAINT => {
            while (win.ShowCursor(true) < 1) {}
            var timer = std.time.Timer.start() catch unreachable;

            // The paint struct will receive paint specs from BeginPaint.
            var paint = std.mem.zeroes(win.Paint);
            // BeginPain will fill in Paint struct and give us somewhere to draw to.
            const display_handle = win.BeginPaint(window_handle, &paint);
            if (display_handle == null) {
                const err = win.GetLastError();
                log.err("Beginpaint error: {any}", .{err});
                return 0;
            }
            defer _ = win.EndPaint(window_handle, &paint);

            // Paint it red.
            // BGRA
            var i: usize = 0;
            const h: usize = 50;
            const w: usize = 50;
            while (i < (h * w) * 4) : (i += 4) {
                pixels[i] = 0;
                pixels[i + 1] = 0;
                pixels[i + 2] = 255;
                pixels[i + 3] = 0;
            }

            // BitBlt operate data from one handle to another.
            // in this case it just copies.
            const bitBltResult = win.BitBlt(
                display_handle,
                paint.rect.left,
                paint.rect.top,
                paint.rect.right - paint.rect.left,
                paint.rect.bottom - paint.rect.top,
                frame_handle,
                paint.rect.left,
                paint.rect.top,
                .SRCCOPY,
            );
            if (!bitBltResult) {
                const err = win.GetLastError();
                log.err("BitBlt error: {any}", .{err});
                return 0;
            }

            _ = win.DwmFlush(); // wait for vsync, kinda
            log.debug("PAINT TIME {d}ms", .{timer.lap() / std.time.ns_per_ms});
        },
        .WM_SIZE => {},
        .WM_MOUSEMOVE => {
            // probably wrong for multimonitor it seems
            const x = win.loword(lparam);
            const y = win.hiword(lparam);
            log.debug("Mouse at {d}x{d}", .{ x, y });
            _ = win.UpdateWindow(window_handle);
        },
        .WM_LBUTTONDOWN => {
            const x = win.loword(lparam);
            const y = win.hiword(lparam);
            log.debug("M1 down at {d}x{d}", .{ x, y });
        },
        .WM_MOUSEWHEEL => {
            const delta: i16 = win.mouseWheelDelta(wparam);
            log.debug("mouse wheel {any}", .{delta});
        },
        .WM_KEYDOWN => {
            const key: win.VirtualKeys = @enumFromInt((wparam));
            const keyFlags: win.KeystrokeFlags = @bitCast(lparam);
            log.debug("keystroke {any} {any}", .{ key, keyFlags });
        },
        else => {
            // let default proc handle other messages
            return win.DefWindowProcW(window_handle, message_type, wparam, lparam);
        },
    }
    return 0;
}
