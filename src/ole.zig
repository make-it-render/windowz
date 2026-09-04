//! OLE drag and drop — the bindings a window uses to take drops (`RegisterDragDrop` with an `IDropTarget` of its own) and to hand data out (`DoDragDrop` with an `IDataObject` and an `IDropSource` of its own), plus the shell's `CF_HDROP` reader.
//!
//! Raw bindings in the shape `wasapi.zig` sets: each interface is a vtable in the order the C++ declaration lists its methods, three IUnknown slots first. These three interfaces are ones a program *implements* and hands to Windows, which then calls through the table, so the slot order is the contract in both directions. The `POINTL` argument travels by value, eight bytes, which the winapi convention handles.

const std = @import("std");
const win = @import("win.zig");
const wasapi = @import("wasapi.zig");

pub const Guid = wasapi.Guid;
pub const HResult = win.HResult;
pub const check = wasapi.check;

// ── functions ───────────────────────────────────────────────────────────────

/// COM plus the OLE services drag and drop needs, single-threaded apartment; call on the thread that owns the window, before it is created.
pub extern "ole32" fn OleInitialize(reserved: ?*anyopaque) callconv(.winapi) HResult;
pub extern "ole32" fn OleUninitialize() callconv(.winapi) void;
/// Make `window` a drop target. OLE keeps a reference to `target` until `RevokeDragDrop`. Must run on the window's thread.
pub extern "ole32" fn RegisterDragDrop(window: win.WindowHandle, target: *IDropTarget) callconv(.winapi) HResult;
pub extern "ole32" fn RevokeDragDrop(window: win.WindowHandle) callconv(.winapi) HResult;
/// Run a drag to completion: a modal loop on the calling thread that dispatches its messages, asks `source` whether to go on after every input change, and feeds the drop target under the pointer. Returns `DRAGDROP_S_DROP` with the effect the target performed in `effect`, or `DRAGDROP_S_CANCEL`; both are success codes, so the result is compared rather than passed through `check`.
pub extern "ole32" fn DoDragDrop(data: *IDataObject, source: *IDropSource, allowed_effects: u32, effect: *u32) callconv(.winapi) HResult;
/// Free what a `getData` handed out, by whatever means its `release` says.
pub extern "ole32" fn ReleaseStgMedium(medium: *StgMedium) callconv(.winapi) void;
/// Read the paths in a `CF_HDROP` block: `index` `0xFFFFFFFF` returns the count, otherwise the length in characters of path `index` (with `file` null) or the path itself, copied into `file` up to `capacity` characters.
pub extern "shell32" fn DragQueryFileW(drop: *anyopaque, index: u32, file: ?[*]u16, capacity: u32) callconv(.winapi) u32;
/// The shell's own `IEnumFORMATETC` over a list of formats, so a data object need not implement the enumerator.
pub extern "shell32" fn SHCreateStdEnumFmtEtc(count: u32, formats: [*]const FormatEtc, out: *?*anyopaque) callconv(.winapi) HResult;

// ── types ───────────────────────────────────────────────────────────────────

/// `FORMATETC`: what a data object is asked for. `medium` is a `TYMED_*` mask.
pub const FormatEtc = extern struct {
    format: u16,
    target_device: ?*anyopaque = null,
    aspect: u32 = DVASPECT_CONTENT,
    index: i32 = -1,
    medium: u32 = TYMED_HGLOBAL,
};

/// `STGMEDIUM`: where the data is. The union of handles collapses to one pointer; `release` is the `IUnknown` that frees it, or null for `ReleaseStgMedium` to free it by `medium`'s rule (a global block is `GlobalFree`d).
pub const StgMedium = extern struct {
    medium: u32,
    handle: ?*anyopaque,
    release: ?*anyopaque,
};

/// `POINTL`: a screen position, by value.
pub const PointL = win.Point;

/// `DROPFILES`: the header of a `CF_HDROP` block. The paths follow at `files_offset` as NUL-terminated strings, UTF-16 when `wide` is set, with an empty string closing the list.
pub const DropFiles = extern struct {
    files_offset: u32 = @sizeOf(DropFiles),
    point: win.Point = .{ .x = 0, .y = 0 },
    non_client: i32 = 0,
    wide: i32 = 1,
};

// ── constants ───────────────────────────────────────────────────────────────

pub const CF_HDROP: u16 = 15;
pub const CF_UNICODETEXT: u16 = @intCast(win.CF_UNICODETEXT);
pub const TYMED_HGLOBAL: u32 = 1;
pub const DVASPECT_CONTENT: u32 = 1;
/// `EnumFormatEtc` direction: the formats `GetData` answers.
pub const DATADIR_GET: u32 = 1;

pub const DROPEFFECT_NONE: u32 = 0;
pub const DROPEFFECT_COPY: u32 = 1;
pub const DROPEFFECT_MOVE: u32 = 2;
pub const DROPEFFECT_LINK: u32 = 4;

// The button and modifier bits `IDropTarget` and `IDropSource` see in their key state.
pub const MK_LBUTTON: u32 = 0x0001;
pub const MK_RBUTTON: u32 = 0x0002;
pub const MK_SHIFT: u32 = 0x0004;
pub const MK_CONTROL: u32 = 0x0008;
pub const MK_MBUTTON: u32 = 0x0010;

pub const S_OK: HResult = hresult(0x00000000);
pub const S_FALSE: HResult = hresult(0x00000001);
pub const DRAGDROP_S_DROP: HResult = hresult(0x00040100);
pub const DRAGDROP_S_CANCEL: HResult = hresult(0x00040101);
pub const DRAGDROP_S_USEDEFAULTCURSORS: HResult = hresult(0x00040102);
pub const DATA_S_SAMEFORMATETC: HResult = hresult(0x00040130);
pub const DRAGDROP_E_NOTREGISTERED: HResult = hresult(0x80040100);
pub const DRAGDROP_E_ALREADYREGISTERED: HResult = hresult(0x80040101);
pub const DRAGDROP_E_INVALIDHWND: HResult = hresult(0x80040102);
pub const E_NOTIMPL: HResult = hresult(0x80004001);
pub const E_NOINTERFACE: HResult = hresult(0x80004002);
pub const E_POINTER: HResult = hresult(0x80004003);
pub const E_OUTOFMEMORY: HResult = hresult(0x8007000E);
pub const E_INVALIDARG: HResult = hresult(0x80070057);
pub const DV_E_FORMATETC: HResult = hresult(0x80040064);
pub const DV_E_TYMED: HResult = hresult(0x80040069);
pub const DV_E_DVASPECT: HResult = hresult(0x8004006B);
pub const OLE_E_ADVISENOTSUPPORTED: HResult = hresult(0x80040003);
/// `OleInitialize` on a thread already in the multithreaded apartment.
pub const RPC_E_CHANGED_MODE: HResult = hresult(0x80010106);

/// An `HRESULT` from its hex spelling; failure codes have the sign bit set.
pub fn hresult(code: u32) HResult {
    return @enumFromInt(@as(i32, @bitCast(code)));
}

/// Whether an `HRESULT` reports success (the sign bit clear).
pub fn succeeded(result: HResult) bool {
    return @intFromEnum(result) >= 0;
}

// ── GUIDs ───────────────────────────────────────────────────────────────────

fn guid(a: u32, b: u16, c: u16, d: [8]u8) Guid {
    return .{ .data1 = a, .data2 = b, .data3 = c, .data4 = d };
}

/// {00000000-0000-0000-C000-000000000046}
pub const IID_IUnknown = guid(0x00000000, 0x0000, 0x0000, .{ 0xC0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x46 });
/// {0000010E-0000-0000-C000-000000000046}
pub const IID_IDataObject = guid(0x0000010E, 0x0000, 0x0000, .{ 0xC0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x46 });
/// {00000121-0000-0000-C000-000000000046}
pub const IID_IDropSource = guid(0x00000121, 0x0000, 0x0000, .{ 0xC0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x46 });
/// {00000122-0000-0000-C000-000000000046}
pub const IID_IDropTarget = guid(0x00000122, 0x0000, 0x0000, .{ 0xC0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x46 });

pub fn guidEql(a: *const Guid, b: *const Guid) bool {
    return std.mem.eql(u8, std.mem.asBytes(a), std.mem.asBytes(b));
}

// ── interfaces ──────────────────────────────────────────────────────────────

/// The three methods every COM interface begins with.
pub fn UnknownMethods(comptime Self: type) type {
    return extern struct {
        queryInterface: *const fn (*Self, *const Guid, *?*anyopaque) callconv(.winapi) HResult,
        addRef: *const fn (*Self) callconv(.winapi) u32,
        release: *const fn (*Self) callconv(.winapi) u32,
    };
}

/// What a drag carries. The source implements it; a target calls `queryGetData` to see what is on offer and `getData` to take it.
pub const IDataObject = extern struct {
    vtable: *const VTable,

    pub const VTable = extern struct {
        unknown: UnknownMethods(IDataObject),
        getData: *const fn (*IDataObject, *const FormatEtc, *StgMedium) callconv(.winapi) HResult,
        getDataHere: *const fn (*IDataObject, *const FormatEtc, *StgMedium) callconv(.winapi) HResult,
        queryGetData: *const fn (*IDataObject, *const FormatEtc) callconv(.winapi) HResult,
        getCanonicalFormatEtc: *const fn (*IDataObject, *const FormatEtc, *FormatEtc) callconv(.winapi) HResult,
        setData: *const fn (*IDataObject, *const FormatEtc, *StgMedium, i32) callconv(.winapi) HResult,
        enumFormatEtc: *const fn (*IDataObject, u32, *?*anyopaque) callconv(.winapi) HResult,
        dAdvise: *const fn (*IDataObject, *const FormatEtc, u32, ?*anyopaque, *u32) callconv(.winapi) HResult,
        dUnadvise: *const fn (*IDataObject, u32) callconv(.winapi) HResult,
        enumDAdvise: *const fn (*IDataObject, *?*anyopaque) callconv(.winapi) HResult,
    };

    /// Whether the object can render `format` (a clipboard format, as a global block).
    pub fn hasFormat(self: *@This(), format: u16) bool {
        const asked: FormatEtc = .{ .format = format };
        return succeeded(self.vtable.queryGetData(self, &asked));
    }

    /// Render `format` as a global block; the caller hands the medium to `ReleaseStgMedium` when done.
    pub fn getGlobal(self: *@This(), format: u16) !StgMedium {
        const asked: FormatEtc = .{ .format = format };
        var medium: StgMedium = .{ .medium = 0, .handle = null, .release = null };
        try check(self.vtable.getData(self, &asked, &medium));
        if (medium.medium != TYMED_HGLOBAL or medium.handle == null) {
            ReleaseStgMedium(&medium);
            return error.UnexpectedMedium;
        }
        return medium;
    }

    pub fn addRef(self: *@This()) void {
        _ = self.vtable.unknown.addRef(self);
    }

    pub fn release(self: *@This()) void {
        _ = self.vtable.unknown.release(self);
    }
};

/// What a window registers to take drops; OLE calls it on the window's thread as the pointer moves.
pub const IDropTarget = extern struct {
    vtable: *const VTable,

    pub const VTable = extern struct {
        unknown: UnknownMethods(IDropTarget),
        dragEnter: *const fn (*IDropTarget, *IDataObject, u32, PointL, *u32) callconv(.winapi) HResult,
        dragOver: *const fn (*IDropTarget, u32, PointL, *u32) callconv(.winapi) HResult,
        dragLeave: *const fn (*IDropTarget) callconv(.winapi) HResult,
        drop: *const fn (*IDropTarget, *IDataObject, u32, PointL, *u32) callconv(.winapi) HResult,
    };
};

/// What `DoDragDrop` asks whether the drag goes on; `escape_pressed` is a `BOOL`.
pub const IDropSource = extern struct {
    vtable: *const VTable,

    pub const VTable = extern struct {
        unknown: UnknownMethods(IDropSource),
        queryContinueDrag: *const fn (*IDropSource, i32, u32) callconv(.winapi) HResult,
        giveFeedback: *const fn (*IDropSource, u32) callconv(.winapi) HResult,
    };
};

// ── tests ───────────────────────────────────────────────────────────────────

test "the OLE structs and vtables are laid out as the ABI expects" {
    // objidl.h: a WORD, a pointer, three DWORD/LONG; 32 bytes on x64 with the padding after the WORD.
    try std.testing.expectEqual(@as(usize, if (@sizeOf(usize) == 8) 32 else 20), @sizeOf(FormatEtc));
    try std.testing.expectEqual(@as(usize, 0), @offsetOf(FormatEtc, "format"));
    try std.testing.expectEqual(@as(usize, @sizeOf(usize)), @offsetOf(FormatEtc, "target_device"));
    try std.testing.expectEqual(@as(usize, 2 * @sizeOf(usize)), @offsetOf(FormatEtc, "aspect"));
    try std.testing.expectEqual(@as(usize, 2 * @sizeOf(usize) + 4), @offsetOf(FormatEtc, "index"));
    try std.testing.expectEqual(@as(usize, 2 * @sizeOf(usize) + 8), @offsetOf(FormatEtc, "medium"));
    // A DWORD, the handle union, the release pointer.
    try std.testing.expectEqual(@as(usize, 3 * @sizeOf(usize)), @sizeOf(StgMedium));
    try std.testing.expectEqual(@as(usize, @sizeOf(usize)), @offsetOf(StgMedium, "handle"));
    try std.testing.expectEqual(@as(usize, 2 * @sizeOf(usize)), @offsetOf(StgMedium, "release"));
    // shellapi.h: DWORD, POINT, BOOL, BOOL — no padding anywhere.
    try std.testing.expectEqual(@as(usize, 20), @sizeOf(DropFiles));
    try std.testing.expectEqual(@as(u32, 20), (DropFiles{}).files_offset);
    try std.testing.expectEqual(@as(usize, 16), @offsetOf(DropFiles, "wide"));
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(PointL));

    // The slot counts: three IUnknown entries, then the methods in declaration order.
    try std.testing.expectEqual(12 * @sizeOf(usize), @sizeOf(IDataObject.VTable));
    try std.testing.expectEqual(3 * @sizeOf(usize), @offsetOf(IDataObject.VTable, "getData"));
    try std.testing.expectEqual(5 * @sizeOf(usize), @offsetOf(IDataObject.VTable, "queryGetData"));
    try std.testing.expectEqual(8 * @sizeOf(usize), @offsetOf(IDataObject.VTable, "enumFormatEtc"));
    try std.testing.expectEqual(11 * @sizeOf(usize), @offsetOf(IDataObject.VTable, "enumDAdvise"));
    try std.testing.expectEqual(7 * @sizeOf(usize), @sizeOf(IDropTarget.VTable));
    try std.testing.expectEqual(3 * @sizeOf(usize), @offsetOf(IDropTarget.VTable, "dragEnter"));
    try std.testing.expectEqual(6 * @sizeOf(usize), @offsetOf(IDropTarget.VTable, "drop"));
    try std.testing.expectEqual(5 * @sizeOf(usize), @sizeOf(IDropSource.VTable));
    try std.testing.expectEqual(3 * @sizeOf(usize), @offsetOf(IDropSource.VTable, "queryContinueDrag"));
    try std.testing.expectEqual(4 * @sizeOf(usize), @offsetOf(IDropSource.VTable, "giveFeedback"));
}

test "result codes keep their sign and the IIDs their bytes" {
    try std.testing.expect(succeeded(S_OK));
    try std.testing.expect(succeeded(S_FALSE));
    try std.testing.expect(succeeded(DRAGDROP_S_DROP));
    try std.testing.expect(!succeeded(E_NOINTERFACE));
    try std.testing.expect(!succeeded(DV_E_FORMATETC));
    try std.testing.expectEqual(@as(i32, 0x00040100), @intFromEnum(DRAGDROP_S_DROP));
    try std.testing.expectError(error.NoInterface, check(E_NOINTERFACE));
    try std.testing.expectError(error.NotImplemented, check(E_NOTIMPL));
    // The four IIDs differ only in data1 over the shared COM tail.
    try std.testing.expect(guidEql(&IID_IUnknown, &IID_IUnknown));
    try std.testing.expect(!guidEql(&IID_IUnknown, &IID_IDropTarget));
    try std.testing.expectEqual(@as(u32, 0x122), IID_IDropTarget.data1);
    try std.testing.expectEqual(@as(u32, 0x121), IID_IDropSource.data1);
    try std.testing.expectEqual(@as(u32, 0x10E), IID_IDataObject.data1);
    try std.testing.expectEqualSlices(u8, &IID_IUnknown.data4, &IID_IDataObject.data4);
}
