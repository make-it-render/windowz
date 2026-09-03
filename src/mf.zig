//! Media Foundation — Windows video capture.
//!
//! Raw bindings only, in the shape `wasapi.zig` sets: each COM interface is a
//! vtable in the order the C++ declaration lists its methods, three IUnknown
//! slots first, with thin wrappers that turn HRESULTs into errors. Enough of
//! Media Foundation to enumerate capture devices, pick a native media type,
//! and read samples through a source reader; nothing about playback.
//!
//! The GUIDs are transcribed from the SDK headers (`mfapi.h`, `mfidl.h`,
//! `mfobjects.h`, `mfreadwrite.h`). A wrong one fails at run time with
//! `E_NOINTERFACE` or an attribute not found — verifiable only against a
//! real camera on real Windows.

const std = @import("std");
const wasapi = @import("wasapi.zig");
const HResult = @import("win.zig").HResult;

pub const Guid = wasapi.Guid;
pub const check = wasapi.check;

// ── functions ───────────────────────────────────────────────────────────────

/// `MF_SDK_VERSION << 16 | MF_API_VERSION`, what `MFStartup` is told.
pub const MF_VERSION: u32 = 0x0002_0070;
pub const MFSTARTUP_NOSOCKET: u32 = 0x1;

pub extern "mfplat" fn MFStartup(version: u32, flags: u32) callconv(.winapi) HResult;
pub extern "mfplat" fn MFShutdown() callconv(.winapi) HResult;
pub extern "mfplat" fn MFCreateAttributes(out: *?*IMFAttributes, initial_size: u32) callconv(.winapi) HResult;
pub extern "mf" fn MFEnumDeviceSources(attributes: *IMFAttributes, out: *?[*]*IMFActivate, count: *u32) callconv(.winapi) HResult;
pub extern "mfreadwrite" fn MFCreateSourceReaderFromMediaSource(source: *IMFMediaSource, attributes: ?*IMFAttributes, out: *?*IMFSourceReader) callconv(.winapi) HResult;

pub const CoTaskMemFree = wasapi.CoTaskMemFree;

// ── GUIDs ───────────────────────────────────────────────────────────────────

fn guid(a: u32, b: u16, c: u16, d: [8]u8) Guid {
    return .{ .data1 = a, .data2 = b, .data3 = c, .data4 = d };
}

/// {C60AC5FE-252A-478F-A0EF-BC8FA5F7CAD3}
pub const MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE = guid(0xC60AC5FE, 0x252A, 0x478F, .{ 0xA0, 0xEF, 0xBC, 0x8F, 0xA5, 0xF7, 0xCA, 0xD3 });
/// {8AC3587A-4AE7-42D8-99E0-0A6013EEF90F}
pub const MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_VIDCAP_GUID = guid(0x8AC3587A, 0x4AE7, 0x42D8, .{ 0x99, 0xE0, 0x0A, 0x60, 0x13, 0xEE, 0xF9, 0x0F });
/// {60D0E559-52F8-4FA2-BBCE-ACDB34A8EC01}
pub const MF_DEVSOURCE_ATTRIBUTE_FRIENDLY_NAME = guid(0x60D0E559, 0x52F8, 0x4FA2, .{ 0xBB, 0xCE, 0xAC, 0xDB, 0x34, 0xA8, 0xEC, 0x01 });
/// {58F0AAD8-22BF-4F8A-BB3D-D2C4978C6E2F}
pub const MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_VIDCAP_SYMBOLIC_LINK = guid(0x58F0AAD8, 0x22BF, 0x4F8A, .{ 0xBB, 0x3D, 0xD2, 0xC4, 0x97, 0x8C, 0x6E, 0x2F });
/// {48EBA18E-F8C9-4687-BF11-0A74C9F96A8F}
pub const MF_MT_MAJOR_TYPE = guid(0x48EBA18E, 0xF8C9, 0x4687, .{ 0xBF, 0x11, 0x0A, 0x74, 0xC9, 0xF9, 0x6A, 0x8F });
/// {F7E34C9A-42E8-4714-B74B-CB29D72C35E5}
pub const MF_MT_SUBTYPE = guid(0xF7E34C9A, 0x42E8, 0x4714, .{ 0xB7, 0x4B, 0xCB, 0x29, 0xD7, 0x2C, 0x35, 0xE5 });
/// {1652C33D-D6B2-4012-B834-72030849A37D} — `width << 32 | height`.
pub const MF_MT_FRAME_SIZE = guid(0x1652C33D, 0xD6B2, 0x4012, .{ 0xB8, 0x34, 0x72, 0x03, 0x08, 0x49, 0xA3, 0x7D });
/// {C459A2E8-3D2C-4E44-B132-FEE5156C7BB0} — `numerator << 32 | denominator`.
pub const MF_MT_FRAME_RATE = guid(0xC459A2E8, 0x3D2C, 0x4E44, .{ 0xB1, 0x32, 0xFE, 0xE5, 0x15, 0x6C, 0x7B, 0xB0 });
/// {644B4E48-1E02-4516-B0EB-C01CA9D49AC6} — a signed stride; negative is bottom-up.
pub const MF_MT_DEFAULT_STRIDE = guid(0x644B4E48, 0x1E02, 0x4516, .{ 0xB0, 0xEB, 0xC0, 0x1C, 0xA9, 0xD4, 0x9A, 0xC6 });
/// {73646976-0000-0010-8000-00AA00389B71} — 'vids'.
pub const MFMediaType_Video = guid(0x73646976, 0x0000, 0x0010, .{ 0x80, 0x00, 0x00, 0xAA, 0x00, 0x38, 0x9B, 0x71 });

/// Video subtypes are the FOURCC in `data1` over a fixed tail.
pub fn videoFormat(fourcc: [4]u8) Guid {
    return guid(std.mem.readInt(u32, &fourcc, .little), 0x0000, 0x0010, .{ 0x80, 0x00, 0x00, 0xAA, 0x00, 0x38, 0x9B, 0x71 });
}

pub const MFVideoFormat_NV12 = videoFormat("NV12".*);
pub const MFVideoFormat_YUY2 = videoFormat("YUY2".*);
pub const MFVideoFormat_I420 = videoFormat("I420".*);
pub const MFVideoFormat_MJPG = videoFormat("MJPG".*);

/// {2CD2D921-C447-44A7-A13C-4ADABFC247E3}
pub const IID_IMFAttributes = guid(0x2CD2D921, 0xC447, 0x44A7, .{ 0xA1, 0x3C, 0x4A, 0xDA, 0xBF, 0xC2, 0x47, 0xE3 });
/// {7FEE9E9A-4A89-47A6-899C-B6A53A70FB67}
pub const IID_IMFActivate = guid(0x7FEE9E9A, 0x4A89, 0x47A6, .{ 0x89, 0x9C, 0xB6, 0xA5, 0x3A, 0x70, 0xFB, 0x67 });
/// {279A808D-AEC7-40C8-9C6B-A6B492C78A66}
pub const IID_IMFMediaSource = guid(0x279A808D, 0xAEC7, 0x40C8, .{ 0x9C, 0x6B, 0xA6, 0xB4, 0x92, 0xC7, 0x8A, 0x66 });
/// {70AE66F2-C809-4E4F-8915-BDCB406B7993}
pub const IID_IMFSourceReader = guid(0x70AE66F2, 0xC809, 0x4E4F, .{ 0x89, 0x15, 0xBD, 0xCB, 0x40, 0x6B, 0x79, 0x93 });
/// {44AE0FA8-EA31-4109-8D2E-4CAE4997C555}
pub const IID_IMFMediaType = guid(0x44AE0FA8, 0xEA31, 0x4109, .{ 0x8D, 0x2E, 0x4C, 0xAE, 0x49, 0x97, 0xC5, 0x55 });
/// {C40A00F2-B93A-4D80-AE8C-5A1C634F58E4}
pub const IID_IMFSample = guid(0xC40A00F2, 0xB93A, 0x4D80, .{ 0xAE, 0x8C, 0x5A, 0x1C, 0x63, 0x4F, 0x58, 0xE4 });
/// {045FA593-8799-42B8-BC8D-8968C6453507}
pub const IID_IMFMediaBuffer = guid(0x045FA593, 0x8799, 0x42B8, .{ 0xBC, 0x8D, 0x89, 0x68, 0xC6, 0x45, 0x35, 0x07 });

// ── constants ───────────────────────────────────────────────────────────────

pub const MF_SOURCE_READER_FIRST_VIDEO_STREAM: u32 = 0xFFFFFFFC;
pub const MF_SOURCE_READERF_ERROR: u32 = 0x1;
pub const MF_SOURCE_READERF_ENDOFSTREAM: u32 = 0x2;
pub const MF_SOURCE_READERF_NEWSTREAM: u32 = 0x4;
pub const MF_SOURCE_READERF_NATIVEMEDIATYPECHANGED: u32 = 0x10;
pub const MF_SOURCE_READERF_CURRENTMEDIATYPECHANGED: u32 = 0x20;
pub const MF_SOURCE_READERF_STREAMTICK: u32 = 0x100;

/// The three methods every COM interface begins with.
fn UnknownMethods(comptime Self: type) type {
    return extern struct {
        queryInterface: *const fn (*Self, *const Guid, *?*anyopaque) callconv(.winapi) HResult,
        addRef: *const fn (*Self) callconv(.winapi) u32,
        release: *const fn (*Self) callconv(.winapi) u32,
    };
}

/// IMFAttributes' thirty methods, in declaration order, over `Self`. Every
/// interface that inherits IMFAttributes embeds this after IUnknown.
fn AttributeMethods(comptime Self: type) type {
    return extern struct {
        getItem: *const anyopaque,
        getItemType: *const anyopaque,
        compareItem: *const anyopaque,
        compare: *const anyopaque,
        getUINT32: *const fn (*Self, *const Guid, *u32) callconv(.winapi) HResult,
        getUINT64: *const fn (*Self, *const Guid, *u64) callconv(.winapi) HResult,
        getDouble: *const anyopaque,
        getGUID: *const fn (*Self, *const Guid, *Guid) callconv(.winapi) HResult,
        getStringLength: *const anyopaque,
        getString: *const anyopaque,
        getAllocatedString: *const fn (*Self, *const Guid, *?[*:0]u16, *u32) callconv(.winapi) HResult,
        getBlobSize: *const anyopaque,
        getBlob: *const anyopaque,
        getAllocatedBlob: *const anyopaque,
        getUnknown: *const anyopaque,
        setItem: *const anyopaque,
        deleteItem: *const anyopaque,
        deleteAllItems: *const anyopaque,
        setUINT32: *const fn (*Self, *const Guid, u32) callconv(.winapi) HResult,
        setUINT64: *const fn (*Self, *const Guid, u64) callconv(.winapi) HResult,
        setDouble: *const anyopaque,
        setGUID: *const fn (*Self, *const Guid, *const Guid) callconv(.winapi) HResult,
        setString: *const anyopaque,
        setBlob: *const anyopaque,
        setUnknown: *const anyopaque,
        lockStore: *const anyopaque,
        unlockStore: *const anyopaque,
        getCount: *const anyopaque,
        getItemByIndex: *const anyopaque,
        copyAllItems: *const anyopaque,
    };
}

// Attribute access shared by every interface that inherits IMFAttributes —
// any object whose vtable has an `attributes` table. Free functions rather
// than methods, since Zig has no way to mix one set of methods into several
// structs.

pub fn getUINT32(object: anytype, key: *const Guid) !u32 {
    var value: u32 = 0;
    try check(object.vtable.attributes.getUINT32(object, key, &value));
    return value;
}

pub fn getUINT64(object: anytype, key: *const Guid) !u64 {
    var value: u64 = 0;
    try check(object.vtable.attributes.getUINT64(object, key, &value));
    return value;
}

pub fn getGUID(object: anytype, key: *const Guid) !Guid {
    var value: Guid = undefined;
    try check(object.vtable.attributes.getGUID(object, key, &value));
    return value;
}

/// A string the caller frees with `CoTaskMemFree`.
pub fn getAllocatedString(object: anytype, key: *const Guid) ![:0]u16 {
    var text: ?[*:0]u16 = null;
    var length: u32 = 0;
    try check(object.vtable.attributes.getAllocatedString(object, key, &text, &length));
    const pointer = text orelse return error.NoString;
    return pointer[0..length :0];
}

pub fn setUINT32(object: anytype, key: *const Guid, value: u32) !void {
    try check(object.vtable.attributes.setUINT32(object, key, value));
}

pub fn setUINT64(object: anytype, key: *const Guid, value: u64) !void {
    try check(object.vtable.attributes.setUINT64(object, key, value));
}

pub fn setGUID(object: anytype, key: *const Guid, value: *const Guid) !void {
    try check(object.vtable.attributes.setGUID(object, key, value));
}

pub const IMFAttributes = extern struct {
    vtable: *const VTable,

    pub const VTable = extern struct {
        unknown: UnknownMethods(IMFAttributes),
        attributes: AttributeMethods(IMFAttributes),
    };

    pub fn release(self: *@This()) void {
        _ = self.vtable.unknown.release(self);
    }
};

pub const IMFActivate = extern struct {
    vtable: *const VTable,

    pub const VTable = extern struct {
        unknown: UnknownMethods(IMFActivate),
        attributes: AttributeMethods(IMFActivate),
        activateObject: *const fn (*IMFActivate, *const Guid, *?*anyopaque) callconv(.winapi) HResult,
        shutdownObject: *const fn (*IMFActivate) callconv(.winapi) HResult,
        detachObject: *const fn (*IMFActivate) callconv(.winapi) HResult,
    };

    pub fn release(self: *@This()) void {
        _ = self.vtable.unknown.release(self);
    }

    pub fn activateObject(self: *@This(), comptime Interface: type, iid: *const Guid) !*Interface {
        var out: ?*anyopaque = null;
        try check(self.vtable.activateObject(self, iid, &out));
        return @ptrCast(@alignCast(out orelse return error.ActivateFailed));
    }
};

pub const IMFMediaType = extern struct {
    vtable: *const VTable,

    pub const VTable = extern struct {
        unknown: UnknownMethods(IMFMediaType),
        attributes: AttributeMethods(IMFMediaType),
        getMajorType: *const fn (*IMFMediaType, *Guid) callconv(.winapi) HResult,
        isCompressedFormat: *const fn (*IMFMediaType, *i32) callconv(.winapi) HResult,
        isEqual: *const anyopaque,
        getRepresentation: *const anyopaque,
        freeRepresentation: *const anyopaque,
    };

    pub fn release(self: *@This()) void {
        _ = self.vtable.unknown.release(self);
    }

    pub const FrameSize = struct { width: u32, height: u32 };
    pub const FrameRate = struct { numerator: u32, denominator: u32 };

    /// `MF_MT_FRAME_SIZE`, unpacked.
    pub fn frameSize(self: *@This()) !FrameSize {
        const packed_size = try getUINT64(self, &MF_MT_FRAME_SIZE);
        return .{ .width = @intCast(packed_size >> 32), .height = @intCast(packed_size & 0xFFFFFFFF) };
    }

    /// `MF_MT_FRAME_RATE`, unpacked.
    pub fn frameRate(self: *@This()) !FrameRate {
        const packed_rate = try getUINT64(self, &MF_MT_FRAME_RATE);
        return .{ .numerator = @intCast(packed_rate >> 32), .denominator = @intCast(packed_rate & 0xFFFFFFFF) };
    }
};

/// Only ever passed along and shut down; its event-generator methods and
/// the rest stay opaque, slots counted.
pub const IMFMediaSource = extern struct {
    vtable: *const VTable,

    pub const VTable = extern struct {
        unknown: UnknownMethods(IMFMediaSource),
        getEvent: *const anyopaque,
        beginGetEvent: *const anyopaque,
        endGetEvent: *const anyopaque,
        queueEvent: *const anyopaque,
        getCharacteristics: *const anyopaque,
        createPresentationDescriptor: *const anyopaque,
        start: *const anyopaque,
        stop: *const anyopaque,
        pause: *const anyopaque,
        shutdown: *const fn (*IMFMediaSource) callconv(.winapi) HResult,
    };

    pub fn shutdown(self: *@This()) void {
        _ = self.vtable.shutdown(self);
    }

    pub fn release(self: *@This()) void {
        _ = self.vtable.unknown.release(self);
    }

    /// Another of the source's interfaces — `IAMCameraControl`, say — or
    /// null when it has none such. The caller releases the result.
    pub fn queryInterface(self: *@This(), comptime Interface: type, iid: *const Guid) !?*Interface {
        var out: ?*anyopaque = null;
        check(self.vtable.unknown.queryInterface(self, iid, &out)) catch |err| switch (err) {
            error.NoInterface => return null,
            else => return err,
        };
        return @ptrCast(@alignCast(out orelse return null));
    }
};

pub const IMFSourceReader = extern struct {
    vtable: *const VTable,

    pub const VTable = extern struct {
        unknown: UnknownMethods(IMFSourceReader),
        getStreamSelection: *const anyopaque,
        setStreamSelection: *const fn (*IMFSourceReader, u32, i32) callconv(.winapi) HResult,
        getNativeMediaType: *const fn (*IMFSourceReader, u32, u32, *?*IMFMediaType) callconv(.winapi) HResult,
        getCurrentMediaType: *const fn (*IMFSourceReader, u32, *?*IMFMediaType) callconv(.winapi) HResult,
        setCurrentMediaType: *const fn (*IMFSourceReader, u32, ?*u32, *IMFMediaType) callconv(.winapi) HResult,
        setCurrentPosition: *const anyopaque,
        readSample: *const fn (*IMFSourceReader, u32, u32, ?*u32, ?*u32, ?*i64, *?*IMFSample) callconv(.winapi) HResult,
        flush: *const fn (*IMFSourceReader, u32) callconv(.winapi) HResult,
        getServiceForStream: *const anyopaque,
        getPresentationAttribute: *const anyopaque,
    };

    /// The `index`th format the device offers on `stream`, or null past the
    /// last. The caller releases it.
    pub fn getNativeMediaType(self: *@This(), stream: u32, index: u32) !?*IMFMediaType {
        var out: ?*IMFMediaType = null;
        const result = self.vtable.getNativeMediaType(self, stream, index, &out);
        // MF_E_NO_MORE_TYPES ends the walk.
        if (@as(u32, @bitCast(@intFromEnum(result))) == 0xC00D36B9) return null;
        try check(result);
        return out;
    }

    pub fn getCurrentMediaType(self: *@This(), stream: u32) !*IMFMediaType {
        var out: ?*IMFMediaType = null;
        try check(self.vtable.getCurrentMediaType(self, stream, &out));
        return out orelse error.NoMediaType;
    }

    pub fn setCurrentMediaType(self: *@This(), stream: u32, media_type: *IMFMediaType) !void {
        try check(self.vtable.setCurrentMediaType(self, stream, null, media_type));
    }

    pub fn setStreamSelection(self: *@This(), stream: u32, selected: bool) !void {
        try check(self.vtable.setStreamSelection(self, stream, if (selected) 1 else 0));
    }

    pub const Sample = struct {
        /// Null on a stream tick or a gap; `flags` says which.
        sample: ?*IMFSample,
        flags: u32,
        /// 100ns units.
        timestamp: i64,
    };

    /// Blocks until the next sample. Synchronous mode: no callback object.
    pub fn readSample(self: *@This(), stream: u32) !Sample {
        var actual_stream: u32 = 0;
        var flags: u32 = 0;
        var timestamp: i64 = 0;
        var sample: ?*IMFSample = null;
        try check(self.vtable.readSample(self, stream, 0, &actual_stream, &flags, &timestamp, &sample));
        return .{ .sample = sample, .flags = flags, .timestamp = timestamp };
    }

    pub fn flush(self: *@This(), stream: u32) void {
        _ = self.vtable.flush(self, stream);
    }

    pub fn release(self: *@This()) void {
        _ = self.vtable.unknown.release(self);
    }
};

pub const IMFSample = extern struct {
    vtable: *const VTable,

    pub const VTable = extern struct {
        unknown: UnknownMethods(IMFSample),
        attributes: AttributeMethods(IMFSample),
        getSampleFlags: *const anyopaque,
        setSampleFlags: *const anyopaque,
        getSampleTime: *const anyopaque,
        setSampleTime: *const anyopaque,
        getSampleDuration: *const anyopaque,
        setSampleDuration: *const anyopaque,
        getBufferCount: *const anyopaque,
        getBufferByIndex: *const anyopaque,
        convertToContiguousBuffer: *const fn (*IMFSample, *?*IMFMediaBuffer) callconv(.winapi) HResult,
        addBuffer: *const anyopaque,
        removeAllBuffers: *const anyopaque,
        getTotalLength: *const anyopaque,
        copyToBuffer: *const anyopaque,
    };

    pub fn release(self: *@This()) void {
        _ = self.vtable.unknown.release(self);
    }

    /// One buffer holding the whole frame, copied together if the sample
    /// had several. The caller releases it.
    pub fn convertToContiguousBuffer(self: *@This()) !*IMFMediaBuffer {
        var out: ?*IMFMediaBuffer = null;
        try check(self.vtable.convertToContiguousBuffer(self, &out));
        return out orelse error.NoBuffer;
    }
};

pub const IMFMediaBuffer = extern struct {
    vtable: *const VTable,

    pub const VTable = extern struct {
        unknown: UnknownMethods(IMFMediaBuffer),
        lock: *const fn (*IMFMediaBuffer, *?[*]u8, ?*u32, ?*u32) callconv(.winapi) HResult,
        unlock: *const fn (*IMFMediaBuffer) callconv(.winapi) HResult,
        getCurrentLength: *const fn (*IMFMediaBuffer, *u32) callconv(.winapi) HResult,
        setCurrentLength: *const anyopaque,
        getMaxLength: *const anyopaque,
    };

    /// The frame's bytes, valid until `unlock`.
    pub fn lock(self: *@This()) ![]u8 {
        var data: ?[*]u8 = null;
        var length: u32 = 0;
        try check(self.vtable.lock(self, &data, null, &length));
        const pointer = data orelse return error.BufferUnavailable;
        return pointer[0..length];
    }

    pub fn unlock(self: *@This()) void {
        _ = self.vtable.unlock(self);
    }

    pub fn release(self: *@This()) void {
        _ = self.vtable.unknown.release(self);
    }
};

// ── camera controls ─────────────────────────────────────────────────────────
//
// `IAMCameraControl` and `IAMVideoProcAmp` are DirectShow interfaces
// (`strmif.h`), but a capture device's Media Foundation source implements
// them as well: `IMFMediaSource.queryInterface` is how a caller reaches a
// webcam's exposure, focus, brightness and the rest. Each property carries its
// own automatic/manual flag; there is no list to walk, only `getRange` to ask
// whether the device has a given property.

/// {C6E13370-30AC-11D0-A18C-00A0C9118956}
pub const IID_IAMCameraControl = guid(0xC6E13370, 0x30AC, 0x11D0, .{ 0xA1, 0x8C, 0x00, 0xA0, 0xC9, 0x11, 0x89, 0x56 });
/// {C6E13360-30AC-11D0-A18C-00A0C9118956}
pub const IID_IAMVideoProcAmp = guid(0xC6E13360, 0x30AC, 0x11D0, .{ 0xA1, 0x8C, 0x00, 0xA0, 0xC9, 0x11, 0x89, 0x56 });

/// `CameraControlProperty`. Exposure is in log2 seconds (−3 is 1/8 s), the
/// motor properties in the device's own units.
pub const CameraControlProperty = enum(i32) {
    pan = 0,
    tilt = 1,
    roll = 2,
    zoom = 3,
    exposure = 4,
    iris = 5,
    focus = 6,
};

/// `VideoProcAmpProperty`.
pub const VideoProcAmpProperty = enum(i32) {
    brightness = 0,
    contrast = 1,
    hue = 2,
    saturation = 3,
    sharpness = 4,
    gamma = 5,
    color_enable = 6,
    white_balance = 7,
    backlight_compensation = 8,
    gain = 9,
};

/// `CameraControl_Flags` and `VideoProcAmp_Flags` share their two bits: in
/// `getRange`'s capabilities, which modes a property offers; in `get` and
/// `set`, which mode it is in.
pub const CONTROL_FLAGS_AUTO: i32 = 0x1;
pub const CONTROL_FLAGS_MANUAL: i32 = 0x2;

/// `E_PROP_ID_UNSUPPORTED` — the device has no such property, which is how
/// `GetRange` answers for every property a camera lacks.
pub const E_PROP_ID_UNSUPPORTED: u32 = 0x80070490;
/// `E_PROP_SET_UNSUPPORTED` — the device has no such interface at all.
pub const E_PROP_SET_UNSUPPORTED: u32 = 0x80070492;
/// `E_INVALIDARG` — a value the property cannot take.
pub const E_INVALIDARG: u32 = 0x80070057;

pub const ControlRange = struct {
    min: i32,
    max: i32,
    step: i32,
    default: i32,
    /// `CONTROL_FLAGS_*`: the modes the property offers.
    capabilities: i32,
};

pub const ControlValue = struct {
    value: i32,
    /// `CONTROL_FLAGS_*`: the mode the property is in.
    flags: i32,
};

/// The three methods both control interfaces declare, in order, over `Self`.
fn ControlMethods(comptime Self: type) type {
    return extern struct {
        getRange: *const fn (*Self, i32, *i32, *i32, *i32, *i32, *i32) callconv(.winapi) HResult,
        set: *const fn (*Self, i32, i32, i32) callconv(.winapi) HResult,
        get: *const fn (*Self, i32, *i32, *i32) callconv(.winapi) HResult,
    };
}

pub const ControlInterfaceKind = enum { camera_control, video_proc_amp };

/// The two control interfaces have the same shape, so one definition serves
/// both; `which` keeps them distinct types, since each answers to its own IID.
fn ControlInterface(comptime which: ControlInterfaceKind) type {
    return extern struct {
        vtable: *const VTable,

        pub const kind = which;
        const Self = @This();

        pub const VTable = extern struct {
            unknown: UnknownMethods(Self),
            control: ControlMethods(Self),
        };

        /// A property's bounds and the modes it offers, or null when the
        /// device has no such property.
        pub fn getRange(self: *Self, property: i32) !?ControlRange {
            var range: ControlRange = undefined;
            const result = self.vtable.control.getRange(self, property, &range.min, &range.max, &range.step, &range.default, &range.capabilities);
            if (isUnsupportedProperty(result)) return null;
            try check(result);
            return range;
        }

        pub fn get(self: *Self, property: i32) !ControlValue {
            var value: ControlValue = undefined;
            const result = self.vtable.control.get(self, property, &value.value, &value.flags);
            if (isUnsupportedProperty(result)) return error.UnknownProperty;
            try check(result);
            return value;
        }

        /// `flags` is `CONTROL_FLAGS_AUTO` or `CONTROL_FLAGS_MANUAL`; the
        /// value only matters in manual mode.
        pub fn set(self: *Self, property: i32, value: i32, flags: i32) !void {
            const result = self.vtable.control.set(self, property, value, flags);
            if (isUnsupportedProperty(result)) return error.UnknownProperty;
            if (@as(u32, @bitCast(@intFromEnum(result))) == E_INVALIDARG) return error.InvalidArgument;
            try check(result);
        }

        pub fn release(self: *Self) void {
            _ = self.vtable.unknown.release(self);
        }
    };
}

fn isUnsupportedProperty(result: HResult) bool {
    const code: u32 = @bitCast(@intFromEnum(result));
    return code == E_PROP_ID_UNSUPPORTED or code == E_PROP_SET_UNSUPPORTED;
}

pub const IAMCameraControl = ControlInterface(.camera_control);
pub const IAMVideoProcAmp = ControlInterface(.video_proc_amp);

/// `MFCreateAttributes` plus the one attribute device enumeration needs.
pub fn createVideoCaptureAttributes() !*IMFAttributes {
    var out: ?*IMFAttributes = null;
    try check(MFCreateAttributes(&out, 1));
    const attributes = out orelse return error.NoAttributes;
    errdefer attributes.release();
    try setGUID(attributes, &MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE, &MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_VIDCAP_GUID);
    return attributes;
}

/// The capture devices, as activation objects the caller releases one by
/// one, then frees the array with `CoTaskMemFree`.
pub fn enumDeviceSources(attributes: *IMFAttributes) ![]*IMFActivate {
    var devices: ?[*]*IMFActivate = null;
    var count: u32 = 0;
    try check(MFEnumDeviceSources(attributes, &devices, &count));
    if (count == 0) return &.{};
    return (devices orelse return &.{})[0..count];
}

pub fn createSourceReader(source: *IMFMediaSource) !*IMFSourceReader {
    var out: ?*IMFSourceReader = null;
    try check(MFCreateSourceReaderFromMediaSource(source, null, &out));
    return out orelse error.NoSourceReader;
}

test "the vtables have the slot counts the C++ declarations do" {
    const slot = @sizeOf(usize);
    // IUnknown 3 + IMFAttributes 30.
    try std.testing.expectEqual(33 * slot, @sizeOf(IMFAttributes.VTable));
    try std.testing.expectEqual(36 * slot, @sizeOf(IMFActivate.VTable));
    try std.testing.expectEqual(38 * slot, @sizeOf(IMFMediaType.VTable));
    try std.testing.expectEqual(46 * slot, @sizeOf(IMFSample.VTable));
    // IUnknown 3 + IMFMediaEventGenerator 4 + IMFMediaSource 6.
    try std.testing.expectEqual(13 * slot, @sizeOf(IMFMediaSource.VTable));
    try std.testing.expectEqual(13 * slot, @sizeOf(IMFSourceReader.VTable));
    try std.testing.expectEqual(8 * slot, @sizeOf(IMFMediaBuffer.VTable));
    // IUnknown 3 + GetRange, Set, Get.
    try std.testing.expectEqual(6 * slot, @sizeOf(IAMCameraControl.VTable));
    try std.testing.expectEqual(6 * slot, @sizeOf(IAMVideoProcAmp.VTable));
    try std.testing.expect(IAMCameraControl != IAMVideoProcAmp);
    // A subtype is its FOURCC over the fixed tail.
    try std.testing.expectEqual(@as(u32, 0x3231564E), MFVideoFormat_NV12.data1);
    try std.testing.expectEqual(MFMediaType_Video.data4, MFVideoFormat_NV12.data4);
}

test "control properties and flags carry strmif.h's values" {
    try std.testing.expectEqual(@as(i32, 4), @intFromEnum(CameraControlProperty.exposure));
    try std.testing.expectEqual(@as(i32, 6), @intFromEnum(CameraControlProperty.focus));
    try std.testing.expectEqual(@as(i32, 7), @intFromEnum(VideoProcAmpProperty.white_balance));
    try std.testing.expectEqual(@as(i32, 9), @intFromEnum(VideoProcAmpProperty.gain));
    try std.testing.expectEqual(@as(i32, 3), CONTROL_FLAGS_AUTO | CONTROL_FLAGS_MANUAL);
    // The two IIDs differ only in their first word.
    try std.testing.expectEqual(IID_IAMCameraControl.data4, IID_IAMVideoProcAmp.data4);
    try std.testing.expect(isUnsupportedProperty(@enumFromInt(@as(i32, @bitCast(E_PROP_ID_UNSUPPORTED)))));
    try std.testing.expect(!isUnsupportedProperty(.ok));
}
