//! WASAPI — Windows audio output.
//!
//! Raw bindings only: this knows how to open a device and hand over a buffer,
//! and nothing about mixing or about mir-audio. The audio library implements its
//! own backend on top, the same way mir-pipewire stays a protocol client and
//! mir-audio bridges it.
//!
//! WASAPI is COM all the way down, which Zig does not speak. A COM interface is
//! a pointer to a vtable, every method takes the interface as its first
//! argument, and **the order of the vtable is the ABI** — a method in the wrong
//! slot calls the wrong code with the wrong arguments. Each vtable below starts
//! with IUnknown's three entries because every COM interface inherits them, and
//! the rest follow the order of the C++ class declaration exactly. Nothing here
//! is stylistic; the layout is the contract.

const std = @import("std");
const HResult = @import("win.zig").HResult;

/// COM's 128-bit identifier. Laid out with the first three fields
/// little-endian and the last as bytes — which is why the canonical text form
/// reverses some groups and not others.
pub const Guid = extern struct {
    data1: u32,
    data2: u16,
    data3: u16,
    data4: [8]u8,
};

/// {BCDE0395-E52F-467C-8E3D-C4579291692E}
pub const CLSID_MMDeviceEnumerator: Guid = .{
    .data1 = 0xBCDE0395,
    .data2 = 0xE52F,
    .data3 = 0x467C,
    .data4 = .{ 0x8E, 0x3D, 0xC4, 0x57, 0x92, 0x91, 0x69, 0x2E },
};

/// {A95664D2-9614-4F35-A746-DE8DB63617E6}
pub const IID_IMMDeviceEnumerator: Guid = .{
    .data1 = 0xA95664D2,
    .data2 = 0x9614,
    .data3 = 0x4F35,
    .data4 = .{ 0xA7, 0x46, 0xDE, 0x8D, 0xB6, 0x36, 0x17, 0xE6 },
};

/// {1CB9AD4C-DBFA-4C32-B178-C2F568A703B2}
pub const IID_IAudioClient: Guid = .{
    .data1 = 0x1CB9AD4C,
    .data2 = 0xDBFA,
    .data3 = 0x4C32,
    .data4 = .{ 0xB1, 0x78, 0xC2, 0xF5, 0x68, 0xA7, 0x03, 0xB2 },
};

/// {F294ACFC-3146-4483-A7BF-ADDCA7C260E2}
pub const IID_IAudioRenderClient: Guid = .{
    .data1 = 0xF294ACFC,
    .data2 = 0x3146,
    .data3 = 0x4483,
    .data4 = .{ 0xA7, 0xBF, 0xAD, 0xDC, 0xA7, 0xC2, 0x60, 0xE2 },
};

/// {726778CD-F60A-4EDA-82DE-E47610CD78AA}
pub const IID_IAudioClient2: Guid = .{
    .data1 = 0x726778CD,
    .data2 = 0xF60A,
    .data3 = 0x4EDA,
    .data4 = .{ 0x82, 0xDE, 0xE4, 0x76, 0x10, 0xCD, 0x78, 0xAA },
};

/// {C8ADBD64-E71E-48A0-A4DE-185C395CD317}
pub const IID_IAudioCaptureClient: Guid = .{
    .data1 = 0xC8ADBD64,
    .data2 = 0xE71E,
    .data3 = 0x48A0,
    .data4 = .{ 0xA4, 0xDE, 0x18, 0x5C, 0x39, 0x5C, 0xD3, 0x17 },
};

/// {00000003-0000-0010-8000-00AA00389B71} — the sub-format an extensible
/// header carries when the samples are 32-bit float.
pub const KSDATAFORMAT_SUBTYPE_IEEE_FLOAT: Guid = .{
    .data1 = 0x00000003,
    .data2 = 0x0000,
    .data3 = 0x0010,
    .data4 = .{ 0x80, 0x00, 0x00, 0xAA, 0x00, 0x38, 0x9B, 0x71 },
};

pub const DataFlow = enum(c_int) { render = 0, capture = 1, all = 2 };
pub const Role = enum(c_int) { console = 0, multimedia = 1, communications = 2 };

pub const ShareMode = enum(c_int) { shared = 0, exclusive = 1 };

/// Ask the device to signal an event when it wants more, rather than polling.
pub const STREAMFLAGS_EVENTCALLBACK: u32 = 0x00040000;
/// Let the client's rate differ from the device's; the engine resamples.
pub const STREAMFLAGS_RATEADJUST: u32 = 0x00100000;
pub const STREAMFLAGS_AUTOCONVERTPCM: u32 = 0x80000000;
pub const STREAMFLAGS_SRC_DEFAULT_QUALITY: u32 = 0x08000000;

pub const CLSCTX_ALL: u32 = 23;
pub const COINIT_MULTITHREADED: u32 = 0;
pub const COINIT_APARTMENTTHREADED: u32 = 2;

pub const WAVE_FORMAT_PCM: u16 = 1;
pub const WAVE_FORMAT_IEEE_FLOAT: u16 = 3;
pub const WAVE_FORMAT_EXTENSIBLE: u16 = 0xFFFE;

/// A captured packet does not follow on from the previous one — the device
/// dropped something in between.
pub const BUFFERFLAGS_DATA_DISCONTINUITY: u32 = 0x1;
/// The buffer this call returns holds no valid data: play silence for it, or
/// on capture, treat it as silence.
pub const BUFFERFLAGS_SILENT: u32 = 0x2;
/// A captured packet's timestamp is not to be trusted.
pub const BUFFERFLAGS_TIMESTAMP_ERROR: u32 = 0x4;

pub const INFINITE: u32 = 0xFFFFFFFF;
pub const WAIT_OBJECT_0: u32 = 0;
pub const WAIT_TIMEOUT: u32 = 0x102;

/// 100-nanosecond units — COM's time unit throughout.
pub const ReferenceTime = i64;
pub const reference_times_per_second: ReferenceTime = 10_000_000;

pub const Handle = *anyopaque;

/// `WAVEFORMATEX`. `cbSize` counts the bytes that follow, which is how an
/// extensible header announces itself.
///
/// Byte-packed, hence the `align(1)` on every field: mmreg.h declares this
/// inside `#pragma pack(1)`, making it 18 bytes rather than the 20 its natural
/// alignment would give. The difference is not academic — an extensible header
/// sets `cbSize = 22`, which is exactly
/// `sizeof(WAVEFORMATEXTENSIBLE) - sizeof(WAVEFORMATEX)` = 40 - 18. Get the
/// size wrong and every format handed to the device is misread from `cbSize`
/// onwards.
pub const WaveFormatEx = extern struct {
    formatTag: u16 align(1),
    channels: u16 align(1),
    samplesPerSec: u32 align(1),
    avgBytesPerSec: u32 align(1),
    blockAlign: u16 align(1),
    bitsPerSample: u16 align(1),
    cbSize: u16 align(1),
};

/// `WAVEFORMATEXTENSIBLE`. A device's mix format is nearly always this, with a
/// float sub-format — `formatTag` alone cannot express a channel mask.
pub const WaveFormatExtensible = extern struct {
    format: WaveFormatEx align(1),
    /// A union of valid-bits / samples-per-block / reserved.
    samples: u16 align(1),
    channelMask: u32 align(1),
    subFormat: Guid align(1),
};

/// What `cbSize` must say for an extensible header: everything past the base.
pub const extensible_cb_size: u16 = @sizeOf(WaveFormatExtensible) - @sizeOf(WaveFormatEx);

/// The three methods every COM interface begins with.
fn UnknownMethods(comptime Self: type) type {
    return extern struct {
        queryInterface: *const fn (*Self, *const Guid, *?*anyopaque) callconv(.winapi) HResult,
        addRef: *const fn (*Self) callconv(.winapi) u32,
        release: *const fn (*Self) callconv(.winapi) u32,
    };
}

pub const IMMDeviceEnumerator = extern struct {
    vtable: *const VTable,

    pub const VTable = extern struct {
        unknown: UnknownMethods(IMMDeviceEnumerator),
        enumAudioEndpoints: *const fn (*IMMDeviceEnumerator, DataFlow, u32, *?*anyopaque) callconv(.winapi) HResult,
        getDefaultAudioEndpoint: *const fn (*IMMDeviceEnumerator, DataFlow, Role, *?*IMMDevice) callconv(.winapi) HResult,
        getDevice: *const fn (*IMMDeviceEnumerator, [*:0]const u16, *?*IMMDevice) callconv(.winapi) HResult,
        registerEndpointNotificationCallback: *const fn (*IMMDeviceEnumerator, *anyopaque) callconv(.winapi) HResult,
        unregisterEndpointNotificationCallback: *const fn (*IMMDeviceEnumerator, *anyopaque) callconv(.winapi) HResult,
    };

    pub fn getDefaultAudioEndpoint(self: *@This(), flow: DataFlow, role: Role) !*IMMDevice {
        var device: ?*IMMDevice = null;
        try check(self.vtable.getDefaultAudioEndpoint(self, flow, role, &device));
        return device orelse error.NoAudioDevice;
    }

    pub fn release(self: *@This()) void {
        _ = self.vtable.unknown.release(self);
    }
};

pub const IMMDevice = extern struct {
    vtable: *const VTable,

    pub const VTable = extern struct {
        unknown: UnknownMethods(IMMDevice),
        activate: *const fn (*IMMDevice, *const Guid, u32, ?*anyopaque, *?*anyopaque) callconv(.winapi) HResult,
        openPropertyStore: *const fn (*IMMDevice, u32, *?*anyopaque) callconv(.winapi) HResult,
        getId: *const fn (*IMMDevice, *?[*:0]u16) callconv(.winapi) HResult,
        getState: *const fn (*IMMDevice, *u32) callconv(.winapi) HResult,
    };

    /// Ask the device for one of its interfaces — this is how an IAudioClient
    /// is obtained.
    pub fn activate(self: *@This(), comptime Interface: type, iid: *const Guid) !*Interface {
        var out: ?*anyopaque = null;
        try check(self.vtable.activate(self, iid, CLSCTX_ALL, null, &out));
        return @ptrCast(@alignCast(out orelse return error.ActivateFailed));
    }

    pub fn release(self: *@This()) void {
        _ = self.vtable.unknown.release(self);
    }
};

pub const IAudioClient = extern struct {
    vtable: *const VTable,

    pub const VTable = extern struct {
        unknown: UnknownMethods(IAudioClient),
        initialize: *const fn (*IAudioClient, ShareMode, u32, ReferenceTime, ReferenceTime, *const WaveFormatEx, ?*const Guid) callconv(.winapi) HResult,
        getBufferSize: *const fn (*IAudioClient, *u32) callconv(.winapi) HResult,
        getStreamLatency: *const fn (*IAudioClient, *ReferenceTime) callconv(.winapi) HResult,
        getCurrentPadding: *const fn (*IAudioClient, *u32) callconv(.winapi) HResult,
        isFormatSupported: *const fn (*IAudioClient, ShareMode, *const WaveFormatEx, ?*?*WaveFormatEx) callconv(.winapi) HResult,
        getMixFormat: *const fn (*IAudioClient, *?*WaveFormatEx) callconv(.winapi) HResult,
        getDevicePeriod: *const fn (*IAudioClient, ?*ReferenceTime, ?*ReferenceTime) callconv(.winapi) HResult,
        start: *const fn (*IAudioClient) callconv(.winapi) HResult,
        stop: *const fn (*IAudioClient) callconv(.winapi) HResult,
        reset: *const fn (*IAudioClient) callconv(.winapi) HResult,
        setEventHandle: *const fn (*IAudioClient, Handle) callconv(.winapi) HResult,
        getService: *const fn (*IAudioClient, *const Guid, *?*anyopaque) callconv(.winapi) HResult,
    };

    /// The format the audio engine is mixing in. In shared mode this is what a
    /// client must produce; the caller frees it with `coTaskMemFree`.
    pub fn getMixFormat(self: *@This()) !*WaveFormatEx {
        var format: ?*WaveFormatEx = null;
        try check(self.vtable.getMixFormat(self, &format));
        return format orelse error.NoMixFormat;
    }

    pub fn initialize(
        self: *@This(),
        share_mode: ShareMode,
        flags: u32,
        buffer_duration: ReferenceTime,
        periodicity: ReferenceTime,
        format: *const WaveFormatEx,
    ) !void {
        try check(self.vtable.initialize(self, share_mode, flags, buffer_duration, periodicity, format, null));
    }

    /// Frames the device's buffer holds in total, not what is free right now.
    pub fn getBufferSize(self: *@This()) !u32 {
        var frames: u32 = 0;
        try check(self.vtable.getBufferSize(self, &frames));
        return frames;
    }

    /// Frames still queued. The room to write is the buffer size minus this.
    pub fn getCurrentPadding(self: *@This()) !u32 {
        var frames: u32 = 0;
        try check(self.vtable.getCurrentPadding(self, &frames));
        return frames;
    }

    /// The engine's own delay between a frame leaving the client's buffer and
    /// reaching the endpoint, in 100ns units. Fixed for the stream's lifetime,
    /// so it is worth reading once.
    pub fn getStreamLatency(self: *@This()) !ReferenceTime {
        var latency: ReferenceTime = 0;
        try check(self.vtable.getStreamLatency(self, &latency));
        return latency;
    }

    pub fn setEventHandle(self: *@This(), handle: Handle) !void {
        try check(self.vtable.setEventHandle(self, handle));
    }

    pub fn getService(self: *@This(), comptime Interface: type, iid: *const Guid) !*Interface {
        var out: ?*anyopaque = null;
        try check(self.vtable.getService(self, iid, &out));
        return @ptrCast(@alignCast(out orelse return error.ServiceUnavailable));
    }

    pub fn start(self: *@This()) !void {
        try check(self.vtable.start(self));
    }

    pub fn stop(self: *@This()) !void {
        try check(self.vtable.stop(self));
    }

    pub fn release(self: *@This()) void {
        _ = self.vtable.unknown.release(self);
    }
};

pub const IAudioRenderClient = extern struct {
    vtable: *const VTable,

    pub const VTable = extern struct {
        unknown: UnknownMethods(IAudioRenderClient),
        getBuffer: *const fn (*IAudioRenderClient, u32, *?[*]u8) callconv(.winapi) HResult,
        releaseBuffer: *const fn (*IAudioRenderClient, u32, u32) callconv(.winapi) HResult,
    };

    /// Claim `frames` of the device's buffer to write into. Every successful
    /// call must be matched by `releaseBuffer`, or the device stalls holding a
    /// buffer the client never gave back.
    pub fn getBuffer(self: *@This(), frames: u32) ![*]u8 {
        var data: ?[*]u8 = null;
        try check(self.vtable.getBuffer(self, frames, &data));
        return data orelse error.BufferUnavailable;
    }

    pub fn releaseBuffer(self: *@This(), frames: u32, flags: u32) !void {
        try check(self.vtable.releaseBuffer(self, frames, flags));
    }

    pub fn release(self: *@This()) void {
        _ = self.vtable.unknown.release(self);
    }
};

/// `AUDIO_STREAM_CATEGORY`: what a stream is for, which decides what
/// processing Windows puts on it. Communications streams get the voice
/// pipeline — echo cancellation, noise suppression and gain control where
/// the driver or OEM provides them as APOs — and duck other audio while
/// active, as the user's Sound settings allow.
///
/// Two caveats a caller relying on `.communications` for echo cancellation
/// must know. The processing is opt-in and driver-dependent, and nothing
/// before Windows 11's `IAudioEffectsManager` says whether any is in place:
/// on an older system the category can be set and verified only by
/// measuring the result. And the category is what triggers "communications
/// ducking" — Windows lowering every other application while the stream is
/// open — unless the user has turned that off in Sound settings.
pub const StreamCategory = enum(c_int) {
    other = 0,
    communications = 3,
    media = 5,
    game_effects = 6,
    game_media = 8,
    game_chat = 9,
    speech = 10,
};

/// `AUDCLNT_STREAMOPTIONS`, a set of flags.
pub const STREAMOPTIONS_NONE: u32 = 0;
/// Ask for the device's raw stream, with no processing at all.
pub const STREAMOPTIONS_RAW: u32 = 1;
/// Initialize in the device's own format rather than the engine's mix
/// format (Windows 10 and later).
pub const STREAMOPTIONS_MATCH_FORMAT: u32 = 2;
/// The stream carries ambisonics (Windows 10 1703 and later).
pub const STREAMOPTIONS_AMBISONICS: u32 = 4;

/// `AudioClientProperties`, handed to `IAudioClient2.setClientProperties`
/// before `initialize`. Sixteen bytes: the layout Windows 8.1 and later
/// read, with `options` on the end — Windows 8's twelve-byte form is not
/// bound.
pub const AudioClientProperties = extern struct {
    cbSize: u32 = @sizeOf(AudioClientProperties),
    bIsOffload: i32 = 0,
    eCategory: StreamCategory = .other,
    options: u32 = STREAMOPTIONS_NONE,
};

/// IAudioClient with the stream-category methods appended. It inherits
/// IAudioClient, so a pointer to it is a pointer to an IAudioClient — the
/// twelve original slots come first. Windows 8 and later; activating it on
/// an older system fails with `error.NoInterface`, and a caller falls back
/// to a plain IAudioClient.
pub const IAudioClient2 = extern struct {
    vtable: *const VTable,

    pub const VTable = extern struct {
        unknown: UnknownMethods(IAudioClient2),
        initialize: *const fn (*IAudioClient2, ShareMode, u32, ReferenceTime, ReferenceTime, *const WaveFormatEx, ?*const Guid) callconv(.winapi) HResult,
        getBufferSize: *const fn (*IAudioClient2, *u32) callconv(.winapi) HResult,
        getStreamLatency: *const fn (*IAudioClient2, *ReferenceTime) callconv(.winapi) HResult,
        getCurrentPadding: *const fn (*IAudioClient2, *u32) callconv(.winapi) HResult,
        isFormatSupported: *const fn (*IAudioClient2, ShareMode, *const WaveFormatEx, ?*?*WaveFormatEx) callconv(.winapi) HResult,
        getMixFormat: *const fn (*IAudioClient2, *?*WaveFormatEx) callconv(.winapi) HResult,
        getDevicePeriod: *const fn (*IAudioClient2, ?*ReferenceTime, ?*ReferenceTime) callconv(.winapi) HResult,
        start: *const fn (*IAudioClient2) callconv(.winapi) HResult,
        stop: *const fn (*IAudioClient2) callconv(.winapi) HResult,
        reset: *const fn (*IAudioClient2) callconv(.winapi) HResult,
        setEventHandle: *const fn (*IAudioClient2, Handle) callconv(.winapi) HResult,
        getService: *const fn (*IAudioClient2, *const Guid, *?*anyopaque) callconv(.winapi) HResult,
        isOffloadCapable: *const fn (*IAudioClient2, StreamCategory, *i32) callconv(.winapi) HResult,
        setClientProperties: *const fn (*IAudioClient2, *const AudioClientProperties) callconv(.winapi) HResult,
        getBufferSizeLimits: *const fn (*IAudioClient2, *const WaveFormatEx, i32, *ReferenceTime, *ReferenceTime) callconv(.winapi) HResult,
    };

    /// Must come before `initialize`; afterwards it is refused.
    pub fn setClientProperties(self: *@This(), properties: *const AudioClientProperties) !void {
        try check(self.vtable.setClientProperties(self, properties));
    }

    /// Whether the device can take a stream of `category` on its hardware
    /// offload path. Informational; the audio library never offloads.
    pub fn isOffloadCapable(self: *@This(), category: StreamCategory) !bool {
        var capable: i32 = 0;
        try check(self.vtable.isOffloadCapable(self, category, &capable));
        return capable != 0;
    }

    /// The same object as an IAudioClient, for everything else.
    pub fn asAudioClient(self: *@This()) *IAudioClient {
        return @ptrCast(self);
    }
};

pub const IAudioCaptureClient = extern struct {
    vtable: *const VTable,

    pub const VTable = extern struct {
        unknown: UnknownMethods(IAudioCaptureClient),
        getBuffer: *const fn (*IAudioCaptureClient, *?[*]u8, *u32, *u32, ?*u64, ?*u64) callconv(.winapi) HResult,
        releaseBuffer: *const fn (*IAudioCaptureClient, u32) callconv(.winapi) HResult,
        getNextPacketSize: *const fn (*IAudioCaptureClient, *u32) callconv(.winapi) HResult,
    };

    /// One packet as the device recorded it.
    pub const Packet = struct {
        data: [*]u8,
        frames: u32,
        /// `BUFFERFLAGS_*`.
        flags: u32,
        /// The performance counter when the packet's first frame was
        /// recorded, in 100ns units — the same clock `QueryPerformanceCounter`
        /// reads, scaled.
        qpc_position: u64,
    };

    /// The next packet, or null when the device has nothing yet. Every packet
    /// must be given back with `releaseBuffer`, or the device stalls holding
    /// a buffer the client never returned.
    pub fn getBuffer(self: *@This()) !?Packet {
        var data: ?[*]u8 = null;
        var frames: u32 = 0;
        var flags: u32 = 0;
        var qpc: u64 = 0;
        try check(self.vtable.getBuffer(self, &data, &frames, &flags, null, &qpc));
        // AUDCLNT_S_BUFFER_EMPTY is a success code with nothing behind it.
        if (frames == 0) return null;
        return .{
            .data = data orelse return error.BufferUnavailable,
            .frames = frames,
            .flags = flags,
            .qpc_position = qpc,
        };
    }

    pub fn releaseBuffer(self: *@This(), frames: u32) !void {
        try check(self.vtable.releaseBuffer(self, frames));
    }

    /// Frames in the next packet, or 0 when there is none. Packets are read
    /// whole: `getBuffer` hands over exactly this many.
    pub fn getNextPacketSize(self: *@This()) !u32 {
        var frames: u32 = 0;
        try check(self.vtable.getNextPacketSize(self, &frames));
        return frames;
    }

    pub fn release(self: *@This()) void {
        _ = self.vtable.unknown.release(self);
    }
};

pub extern "ole32" fn CoInitializeEx(reserved: ?*anyopaque, flags: u32) callconv(.winapi) HResult;
pub extern "ole32" fn CoUninitialize() callconv(.winapi) void;
pub extern "ole32" fn CoCreateInstance(
    clsid: *const Guid,
    outer: ?*anyopaque,
    context: u32,
    iid: *const Guid,
    out: *?*anyopaque,
) callconv(.winapi) HResult;
pub extern "ole32" fn CoTaskMemFree(memory: ?*anyopaque) callconv(.winapi) void;

pub extern "kernel32" fn CreateEventW(
    attributes: ?*anyopaque,
    manual_reset: c_int,
    initial_state: c_int,
    name: ?[*:0]const u16,
) callconv(.winapi) ?Handle;
pub extern "kernel32" fn WaitForSingleObject(handle: Handle, milliseconds: u32) callconv(.winapi) u32;
pub extern "kernel32" fn CloseHandle(handle: Handle) callconv(.winapi) c_int;

/// Turn an HRESULT into an error. COM reports failure in the sign bit and packs
/// the reason into the rest, so anything negative went wrong.
pub fn check(result: HResult) !void {
    const code: i32 = @intFromEnum(result);
    if (code >= 0) return;
    return switch (@as(u32, @bitCast(code))) {
        0x80070005 => error.AccessDenied,
        0x8007000E => error.OutOfMemory,
        0x80004001 => error.NotImplemented,
        0x80004002 => error.NoInterface,
        0x80004005 => error.Unspecified,
        // AUDCLNT_E_*, in their declared order.
        0x88890001 => error.DeviceNotInitialized,
        0x88890002 => error.DeviceAlreadyInitialized,
        0x88890003 => error.WrongEndpointType,
        0x88890004 => error.DeviceInvalidated,
        0x88890005 => error.DeviceNotStopped,
        0x88890006 => error.BufferTooLarge,
        0x88890007 => error.OutOfOrder,
        0x88890008 => error.UnsupportedFormat,
        0x88890009 => error.InvalidSize,
        0x8889000A => error.DeviceInUse,
        0x8889000B => error.BufferOperationPending,
        0x8889000C => error.ThreadNotRegistered,
        0x8889000E => error.ExclusiveModeNotAllowed,
        0x8889000F => error.EndpointCreateFailed,
        0x88890010 => error.ServiceNotRunning,
        0x88890011 => error.EventHandleNotExpected,
        0x88890012 => error.ExclusiveModeOnly,
        0x88890013 => error.BufferDurationPeriodNotEqual,
        0x88890014 => error.EventHandleNotSet,
        0x88890015 => error.IncorrectBufferSize,
        0x88890016 => error.BufferSizeError,
        0x88890017 => error.CpuUsageExceeded,
        0x88890018 => error.BufferError,
        0x88890019 => error.BufferSizeNotAligned,
        else => error.ComCallFailed,
    };
}

/// Open the default render device's enumerator. COM must already be
/// initialized on this thread.
pub fn createDeviceEnumerator() !*IMMDeviceEnumerator {
    var out: ?*anyopaque = null;
    try check(CoCreateInstance(
        &CLSID_MMDeviceEnumerator,
        null,
        CLSCTX_ALL,
        &IID_IMMDeviceEnumerator,
        &out,
    ));
    return @ptrCast(@alignCast(out orelse return error.NoDeviceEnumerator));
}

/// True when a mix format carries 32-bit floats — what a client can write
/// without converting. Shared-mode devices essentially always say yes, but an
/// extensible header hides the answer behind a sub-format GUID.
pub fn isFloat32(format: *const WaveFormatEx) bool {
    if (format.bitsPerSample != 32) return false;
    if (format.formatTag == WAVE_FORMAT_IEEE_FLOAT) return true;
    if (format.formatTag != WAVE_FORMAT_EXTENSIBLE) return false;
    if (format.cbSize < 22) return false;

    const extensible: *const WaveFormatExtensible = @ptrCast(@alignCast(format));
    return std.mem.eql(u8, std.mem.asBytes(&extensible.subFormat), std.mem.asBytes(&KSDATAFORMAT_SUBTYPE_IEEE_FLOAT));
}

test "a float mix format is recognised however it is spelled" {
    var plain: WaveFormatEx = .{
        .formatTag = WAVE_FORMAT_IEEE_FLOAT,
        .channels = 2,
        .samplesPerSec = 48000,
        .avgBytesPerSec = 48000 * 8,
        .blockAlign = 8,
        .bitsPerSample = 32,
        .cbSize = 0,
    };
    try std.testing.expect(isFloat32(&plain));

    // Integer samples are not float however wide they are.
    plain.formatTag = WAVE_FORMAT_PCM;
    try std.testing.expect(!isFloat32(&plain));

    // The shape a real device reports: extensible, with the answer in the GUID.
    var extensible: WaveFormatExtensible = .{
        .format = .{
            .formatTag = WAVE_FORMAT_EXTENSIBLE,
            .channels = 2,
            .samplesPerSec = 48000,
            .avgBytesPerSec = 48000 * 8,
            .blockAlign = 8,
            .bitsPerSample = 32,
            .cbSize = 22,
        },
        .samples = 32,
        .channelMask = 0x3,
        .subFormat = KSDATAFORMAT_SUBTYPE_IEEE_FLOAT,
    };
    try std.testing.expect(isFloat32(&extensible.format));

    // Same width, different sub-format: not float.
    extensible.subFormat.data1 = 0x00000001; // KSDATAFORMAT_SUBTYPE_PCM
    try std.testing.expect(!isFloat32(&extensible.format));
}

test "an extensible header that lies about its size is not trusted" {
    // cbSize under 22 means the sub-format is not really there to read.
    var truncated: WaveFormatExtensible = .{
        .format = .{
            .formatTag = WAVE_FORMAT_EXTENSIBLE,
            .channels = 2,
            .samplesPerSec = 48000,
            .avgBytesPerSec = 48000 * 8,
            .blockAlign = 8,
            .bitsPerSample = 32,
            .cbSize = 0,
        },
        .samples = 32,
        .channelMask = 0x3,
        .subFormat = KSDATAFORMAT_SUBTYPE_IEEE_FLOAT,
    };
    try std.testing.expect(!isFloat32(&truncated.format));
}

test "the COM structs are laid out as the ABI expects" {
    // Not style choices — the audio engine reads these offsets. WAVEFORMATEX is
    // 18, not the 20 natural alignment would give, because it is packed.
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(Guid));
    try std.testing.expectEqual(@as(usize, 18), @sizeOf(WaveFormatEx));
    try std.testing.expectEqual(@as(usize, 40), @sizeOf(WaveFormatExtensible));
    // The number a real extensible header carries in cbSize.
    try std.testing.expectEqual(@as(u16, 22), extensible_cb_size);
    try std.testing.expectEqual(@as(usize, 0), @offsetOf(WaveFormatEx, "formatTag"));
    try std.testing.expectEqual(@as(usize, 2), @offsetOf(WaveFormatEx, "channels"));
    try std.testing.expectEqual(@as(usize, 4), @offsetOf(WaveFormatEx, "samplesPerSec"));
    try std.testing.expectEqual(@as(usize, 16), @offsetOf(WaveFormatEx, "cbSize"));
    // WAVEFORMATEXTENSIBLE follows WAVEFORMATEX immediately; the union sits at
    // 18 and the whole is 40 with the trailing GUID.
    try std.testing.expectEqual(@as(usize, 18), @offsetOf(WaveFormatExtensible, "samples"));
    try std.testing.expectEqual(@as(usize, 20), @offsetOf(WaveFormatExtensible, "channelMask"));
    try std.testing.expectEqual(@as(usize, 24), @offsetOf(WaveFormatExtensible, "subFormat"));

    // Four 32-bit fields; the engine checks cbSize against it.
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(AudioClientProperties));
    try std.testing.expectEqual(@as(u32, 16), (AudioClientProperties{}).cbSize);
    try std.testing.expectEqual(@as(usize, 4), @offsetOf(AudioClientProperties, "bIsOffload"));
    try std.testing.expectEqual(@as(usize, 8), @offsetOf(AudioClientProperties, "eCategory"));
    try std.testing.expectEqual(@as(usize, 12), @offsetOf(AudioClientProperties, "options"));
    try std.testing.expectEqual(@as(usize, 4), @sizeOf(StreamCategory));
    try std.testing.expectEqual(@as(c_int, 3), @intFromEnum(StreamCategory.communications));
    // IAudioClient2's table is IAudioClient's plus three: the inheritance the
    // pointer cast in `asAudioClient` relies on. The three sit in the order
    // audioclient.h declares them — a call through the wrong slot would
    // land in GetBufferSizeLimits with a properties pointer for a format.
    try std.testing.expectEqual(@sizeOf(IAudioClient.VTable) + 3 * @sizeOf(usize), @sizeOf(IAudioClient2.VTable));
    try std.testing.expectEqual(15 * @sizeOf(usize), @offsetOf(IAudioClient2.VTable, "isOffloadCapable"));
    try std.testing.expectEqual(16 * @sizeOf(usize), @offsetOf(IAudioClient2.VTable, "setClientProperties"));
    try std.testing.expectEqual(17 * @sizeOf(usize), @offsetOf(IAudioClient2.VTable, "getBufferSizeLimits"));
    // The twelve IAudioClient slots line up between the two tables.
    try std.testing.expectEqual(@offsetOf(IAudioClient.VTable, "getService"), @offsetOf(IAudioClient2.VTable, "getService"));
    try std.testing.expectEqual(@offsetOf(IAudioClient.VTable, "initialize"), @offsetOf(IAudioClient2.VTable, "initialize"));
}

test "a failed HRESULT becomes an error and a successful one does not" {
    try check(@enumFromInt(0));
    try check(@enumFromInt(1)); // S_FALSE is still success

    const fail = struct {
        fn code(value: u32) HResult {
            return @enumFromInt(@as(i32, @bitCast(value)));
        }
    }.code;

    try std.testing.expectError(error.DeviceInvalidated, check(fail(0x88890004)));
    try std.testing.expectError(error.UnsupportedFormat, check(fail(0x88890008)));
    try std.testing.expectError(error.EventHandleNotSet, check(fail(0x88890014)));
    try std.testing.expectError(error.AccessDenied, check(fail(0x80070005)));
    try std.testing.expectError(error.ComCallFailed, check(fail(0x80000000)));
}
