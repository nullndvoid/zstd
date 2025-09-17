const std = @import("std");
/// For all use-cases not supported by these bindings, use this as a stop-gap
/// and feel free to contribute upstream.
pub const c = @cImport({
    @cInclude("zstd.h");
});

const Allocator = std.mem.Allocator;

pub const ZstdError = error{
    NoError,
    Generic,
    PrefixUnknown,
    VersionUnsupported,
    FrameParameterUnsupported,
    FrameParameterWindowTooLarge,
    CorruptionDetected,
    ChecksumWrong,
    LiteralsHeaderWrong,
    DictionaryCorrupted,
    DictionaryWrong,
    DictionaryCreationFailed,
    ParameterUnsupported,
    ParameterCombinationUnsupported,
    ParameterOutOfBound,
    TableLogTooLarge,
    MaxSymbolValueTooLarge,
    MaxSymbolValueTooSmall,
    CannotProduceUncompressedBlock,
    StabilityConditionNotRespected,
    StageWrong,
    InitMissing,
    MemoryAllocation,
    WorkspaceTooSmall,
    DstSizeTooSmall,
    SrcSizeWrong,
    DstBufferNull,
    NoForwardProgressDestFull,
    NoForwardProgressInputEmpty,
    FrameIndexTooLarge,
    SeekableIo,
    DstBufferWrong,
    SrcBufferWrong,
    SequenceProducerFailed,
    ExternalSequencesInvalid,
    MaxCode,
};

/// Not being defined by translate-c.
extern fn ZSTD_getErrorCode(code: usize) c.ZSTD_ErrorCode;

/// Called to convert our C error codes to Zig equivalents.
fn toError(err: c.ZSTD_ErrorCode) ZstdError {
    return switch (err) {
        c.ZSTD_error_no_error => ZstdError.NoError,
        c.ZSTD_error_GENERIC => ZstdError.Generic,
        c.ZSTD_error_prefix_unknown => ZstdError.PrefixUnknown,
        c.ZSTD_error_version_unsupported => ZstdError.VersionUnsupported,
        c.ZSTD_error_frameParameter_unsupported => ZstdError.FrameParameterUnsupported,
        c.ZSTD_error_frameParameter_windowTooLarge => ZstdError.FrameParameterWindowTooLarge,
        c.ZSTD_error_corruption_detected => ZstdError.CorruptionDetected,
        c.ZSTD_error_checksum_wrong => ZstdError.ChecksumWrong,
        c.ZSTD_error_literals_headerWrong => ZstdError.LiteralsHeaderWrong,
        c.ZSTD_error_dictionary_corrupted => ZstdError.DictionaryCorrupted,
        c.ZSTD_error_dictionary_wrong => ZstdError.DictionaryWrong,
        c.ZSTD_error_dictionaryCreation_failed => ZstdError.DictionaryCreationFailed,
        c.ZSTD_error_parameter_unsupported => ZstdError.ParameterUnsupported,
        c.ZSTD_error_parameter_combination_unsupported => ZstdError.ParameterCombinationUnsupported,
        c.ZSTD_error_parameter_outOfBound => ZstdError.ParameterOutOfBound,
        c.ZSTD_error_tableLog_tooLarge => ZstdError.TableLogTooLarge,
        c.ZSTD_error_maxSymbolValue_tooLarge => ZstdError.MaxSymbolValueTooLarge,
        c.ZSTD_error_maxSymbolValue_tooSmall => ZstdError.MaxSymbolValueTooSmall,
        c.ZSTD_error_cannotProduce_uncompressedBlock => ZstdError.CannotProduceUncompressedBlock,
        c.ZSTD_error_stabilityCondition_notRespected => ZstdError.StabilityConditionNotRespected,
        c.ZSTD_error_stage_wrong => ZstdError.StageWrong,
        c.ZSTD_error_init_missing => ZstdError.InitMissing,
        c.ZSTD_error_memory_allocation => ZstdError.MemoryAllocation,
        c.ZSTD_error_workSpace_tooSmall => ZstdError.WorkspaceTooSmall,
        c.ZSTD_error_dstSize_tooSmall => ZstdError.DstSizeTooSmall,
        c.ZSTD_error_srcSize_wrong => ZstdError.SrcSizeWrong,
        c.ZSTD_error_dstBuffer_null => ZstdError.DstBufferNull,
        c.ZSTD_error_noForwardProgress_destFull => ZstdError.NoForwardProgressDestFull,
        c.ZSTD_error_noForwardProgress_inputEmpty => ZstdError.NoForwardProgressInputEmpty,
        c.ZSTD_error_frameIndex_tooLarge => ZstdError.FrameIndexTooLarge,
        c.ZSTD_error_seekableIO => ZstdError.SeekableIo,
        c.ZSTD_error_dstBuffer_wrong => ZstdError.DstBufferWrong,
        c.ZSTD_error_srcBuffer_wrong => ZstdError.SrcBufferWrong,
        c.ZSTD_error_sequenceProducer_failed => ZstdError.SequenceProducerFailed,
        c.ZSTD_error_externalSequences_invalid => ZstdError.ExternalSequencesInvalid,
        c.ZSTD_error_maxCode => ZstdError.MaxCode,
        else => unreachable,
    };
}

/// Passed into functions to provide extra error context.
pub const Diagnostics = struct {
    pub const MAX_ERRSTR_LENGTH = 256;

    /// Statically allocated errstr buffer because we don't need the hassle,
    /// string is null terminated.
    errstr: [MAX_ERRSTR_LENGTH:0]u8,
    /// Required (use @src()) to set this.
    source_info: std.builtin.SourceLocation,
    was_set: bool,

    pub fn init() Diagnostics {
        return Diagnostics{
            .errstr = [_:0]u8{0} ** MAX_ERRSTR_LENGTH,
            .source_info = .{
                .line = 0,
                .column = 0,
                .file = "",
                .fn_name = "",
                .module = "",
            },
            .was_set = false,
        };
    }

    pub fn format(
        self: Diagnostics,
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        if (!self.was_set)
            return writer.print("(no errors reported)", .{});

        const s = &self.source_info;
        try writer.print("In {s}/{s}:{d}:{d} (in {s})\n", .{
            s.module,
            s.file,
            s.line,
            s.column,
            s.fn_name,
        });

        try writer.print("\t\"{s}\"", .{
            self.errstr
        });
    }

    /// Sets the diagnostics with an error string and source info.
    pub inline fn set(self: *Diagnostics, errstr: [:0]const u8) void {
        // To prevent garbage piling up.
        @memset(&self.errstr, 0);
        @memcpy(&self.errstr, errstr.ptr);
        self.source_info = @src();
        self.was_set = true;
    }
};

const Self = @This();

/// Holds diagnostics. This is clobbered when new errors occur.
diag: Diagnostics,

pub fn init(diag: Diagnostics) Self {
    return Self{
        .diag = diag,
    };
}

/// Returns a worst-case bound on the compression of some data.
pub fn compressBound(src_size: usize) usize {
    if (src_size >= c.ZSTD_MAX_INPUT_SIZE) return 0;
    const bound = src_size + (src_size >> 8);
    const margin = if (src_size < (128 << 10)) ((128 << 10) - src_size) >> 11 else 0;
    return bound + margin;
}

/// Compressed zstd frame. `diag` must outlive this so the pointer is not
/// invalidated. Use this to decompress data if you know it begins with a
/// `zstd` frame header.
pub const Frame = struct {
    data: []const u8,
    allocated: bool,
    diag: *Diagnostics,

    /// Call if you got the `Frame` from `compress`. Else this is a no-op.
    pub fn deinit(self: Frame, alloc: Allocator) void {
        if (self.allocated) alloc.free(self.data);
    }

    pub fn init(data: []const u8, diag: *Diagnostics) Frame {
        return Frame{
            .data = data,
            .allocated = false,
            .diag = diag,
        };
    }

    /// Currently this is defined as 18, but just to accommodate future
    /// changes, this will be set to 36.
    const MAX_FRAME_HEADER_SIZE = 18 * 2;

    // /// Assumes our data contains one Frame, this is unchecked by `init`.
    pub fn decompress(self: Frame, alloc: Allocator) ZstdError![]const u8 {
        const bound = c.ZSTD_getFrameContentSize(
            self.data.ptr,
            self.data.len,
        );

        // Handle special return values that are NOT errors but special constants
        // These are very large numbers that look like errors but aren't
        if (bound == @as(c_longlong, @bitCast(@as(c_longlong, -1)))) { // ZSTD_CONTENTSIZE_UNKNOWN
            self.diag.set("Frame content size is unknown, use streaming decompression");
            return ZstdError.Generic;
        }

        if (bound == @as(c_longlong, @bitCast(@as(c_longlong, -2)))) { // ZSTD_CONTENTSIZE_ERROR
            self.diag.set("Input is not a valid zstd frame");
            return ZstdError.PrefixUnknown;
        }

        if (c.ZSTD_isError(bound) != 0) {
            self.diag.set(getZstdErrStr(bound));
            return getZstdErr(bound);
        }

        const decompressed = alloc.alloc(u8, bound) catch |err| {
            switch (err) {
                error.OutOfMemory => {
                    self.diag.set("Ran out of memory allocating decompressed data buffer.");
                    return ZstdError.MemoryAllocation;
                },
                else => unreachable,
            }
        };
        errdefer alloc.free(decompressed);

        const bytes = c.ZSTD_decompress(
            decompressed.ptr,
            decompressed.len,
            self.data.ptr,
            self.data.len,
        );

        if (c.ZSTD_isError(bytes) != 0) {
            self.diag.set(getZstdErrStr(bytes));
            return getZstdErr(bytes);
        }

        // On success, we should return a slice of the correct size.
        // The original buffer will be freed by the caller via `alloc.free(data)`.
        return decompressed[0..bytes];
    }
};

/// Compresses data into a single zstd `Frame`.
///
/// # Notes
///
/// * `level` should be between 1 and 22 inclusive.
pub fn compress(
    self: *Self,
    alloc: Allocator,
    data: []const u8,
    level: u8,
) ZstdError!Frame {
    if (level == 0 or level > 22) {
        self.diag.set("Parameter `level` should be between 1 and 22.");

        return ZstdError.ParameterOutOfBound;
    }

    const bound = compressBound(data.len);
    if (bound == 0) {
        self.diag.set("Data was too large, or compressBound returned 0. Consider using streaming.");

        return ZstdError.SrcBufferWrong;
    }

    const compressed = alloc.alloc(u8, bound) catch |err| {
        switch (err) {
            error.OutOfMemory => {
                self.diag.set("Ran out of memory allocating compressed data buffer.");
                return ZstdError.MemoryAllocation;
            },
            else => unreachable,
        }
    };
    errdefer alloc.free(compressed);

    const compressed_size = c.ZSTD_compress(
        compressed.ptr,
        compressed.len,
        data.ptr,
        data.len,
        level,
    );

    if (c.ZSTD_isError(compressed_size) != 0) {
        self.diag.set(getZstdErrStr(compressed_size));
        return getZstdErr(compressed_size);
    }

    const final_data = alloc.dupe(u8, compressed[0..compressed_size]) catch |err| {
        switch (err) {
            error.OutOfMemory => {
                self.diag.set("Ran out of memory allocating final compressed data buffer.");
                return ZstdError.MemoryAllocation;
            },
            else => unreachable,
        }
    };

    alloc.free(compressed);

    // The `compress` function returns a `Frame` that owns the memory.
    // `errdefer` is incorrect here because we need to transfer ownership on success.
    // The caller is now responsible for calling `frame.deinit(alloc)`.
    return Frame{
        .allocated = true,
        .data = final_data,
        .diag = &self.diag,
    };
}

inline fn getZstdErr(code: usize) ZstdError {
    // Use the correct C API to get the enum from the error code.
    const err = ZSTD_getErrorCode(code);

    return toError(err);
}

inline fn getZstdErrStr(code: usize) [:0]const u8 {
    const c_str = c.ZSTD_getErrorName(code);
    return std.mem.span(c_str);
}

const TEST_DATA = @embedFile("root.zig");

test {
    std.testing.refAllDecls(Self);
}

test "compress and decompress" {
    const alloc = std.testing.allocator;
    var zstd = Self.init(Diagnostics.init());

    var frame = zstd.compress(alloc, TEST_DATA, 20) catch |err|
        std.debug.panic("{any}", .{err});
    defer frame.deinit(alloc);

    const data = frame.decompress(alloc) catch |err|
        std.debug.panic("{any}", .{err});
    defer alloc.free(data);

    try std.testing.expectEqualSlices(u8, TEST_DATA, data);
}
