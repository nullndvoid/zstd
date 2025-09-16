const std = @import("std");
const c = @cImport({
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

/// Called to convert our C error codes to Zig equivalents.
fn toError(self: c.ZSTD_ErrorCode) ZstdError {
    return switch (self) {
        c.ZSTD_error_no_error => .NoError,
        c.ZSTD_error_GENERIC => .Generic,
        c.ZSTD_error_prefix_unknown => .PrefixUnknown,
        c.ZSTD_error_version_unsupported => .VersionUnsupported,
        c.ZSTD_error_frameParameter_unsupported => .FrameParameterUnsupported,
        c.ZSTD_error_frameParameter_windowTooLarge => .FrameParameterWindowTooLarge,
        c.ZSTD_error_corruption_detected => .CorruptionDetected,
        c.ZSTD_error_checksum_wrong => .ChecksumWrong,
        c.ZSTD_error_literals_headerWrong => .LiteralsHeaderWrong,
        c.ZSTD_error_dictionary_corrupted => .DictionaryCorrupted,
        c.ZSTD_error_dictionary_wrong => .DictionaryWrong,
        c.ZSTD_error_dictionaryCreation_failed => .DictionaryCreationFailed,
        c.ZSTD_error_parameter_unsupported => .ParameterUnsupported,
        c.ZSTD_error_parameter_combination_unsupported => .ParameterCombinationUnsupported,
        c.ZSTD_error_parameter_outOfBound => .ParameterOutOfBound,
        c.ZSTD_error_tableLog_tooLarge => .TableLogTooLarge,
        c.ZSTD_error_maxSymbolValue_tooLarge => .MaxSymbolValueTooLarge,
        c.ZSTD_error_maxSymbolValue_tooSmall => .MaxSymbolValueTooSmall,
        c.ZSTD_error_cannotProduce_uncompressedBlock => .CannotProduceUncompressedBlock,
        c.ZSTD_error_stabilityCondition_notRespected => .StabilityConditionNotRespected,
        c.ZSTD_error_stage_wrong => .StageWrong,
        c.ZSTD_error_init_missing => .InitMissing,
        c.ZSTD_error_memory_allocation => .MemoryAllocation,
        c.ZSTD_error_workSpace_tooSmall => .WorkspaceTooSmall,
        c.ZSTD_error_dstSize_tooSmall => .DstSizeTooSmall,
        c.ZSTD_error_srcSize_wrong => .SrcSizeWrong,
        c.ZSTD_error_dstBuffer_null => .DstBufferNull,
        c.ZSTD_error_noForwardProgress_destFull => .NoForwardProgressDestFull,
        c.ZSTD_error_noForwardProgress_inputEmpty => .NoForwardProgressInputEmpty,
        c.ZSTD_error_frameIndex_tooLarge => .FrameIndexTooLarge,
        c.ZSTD_error_seekableIO => .SeekableIo,
        c.ZSTD_error_dstBuffer_wrong => .DstBufferWrong,
        c.ZSTD_error_srcBuffer_wrong => .SrcBufferWrong,
        c.ZSTD_error_sequenceProducer_failed => .SequenceProducerFailed,
        c.ZSTD_error_externalSequences_invalid => .ExternalSequencesInvalid,
        c.ZSTD_error_maxCode => .MaxCode,
    };
}

/// Compile errors when we don't pass in a Zig error, or we haven't expressed
/// the error in the Zstd error set. This is just here to coerce errors into
/// Zstd errors.
fn toZstdError(err: anyerror) ZstdError {
    return switch (err) {
        error.OutOfMemory => ZstdError.MemoryAllocation,
        else => @compileError("Unhandled error: " ++ @errorName(err) ++ "!"),
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
            .errstr = [_]u8{0 ** MAX_ERRSTR_LENGTH},
            .source_info = .{
                .line = 0,
                .column = 0,
                .file = "",
                .fn_name = "",
                .module = "",
                .was_set = false,
            },
        };
    }

    pub fn format(
        self: Diagnostics,
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        if (!self.was_set)
            return writer.print("(no errors reported)", .{});

        const s = &self.source_info;
        try writer.print("In {s}/{s}:{d}:{d} (in {s})", .{
            s.module,
            s.file,
            s.line,
            s.column,
            s.fn_name,
        });

        try writer.print("\t\"{s}\"", .{self.errstr});
    }

    /// Sets the diagnostics with an error string and source info.
    pub inline fn set(self: *Diagnostics, errstr: [:0]const u8) void {
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

    // /// Assumes our data contains one Frame, this is unchecked by `init`.
    pub fn decompress(self: Frame, alloc: Allocator) ZstdError![]const u8 {
        const bound = c.ZSTD_getFrameContentSize(
            self.data.ptr,
            c.ZSTD_FRAMEHEADERSIZE_MAX,
        );

        if (c.ZSTD_isError(bound) != 0) {
            self.diag.set(getZstdErrStr(bound));
            return getZstdErrStr(bound);
        }

        const decompressed = alloc.alloc(u8, bound) catch |err| {
            self.diag.set("Ran out of memory allocating decompressed data buffer.");

            return toZstdError(err);
        };

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
        self.diag.set("Ran out of memory allocating compressed data buffer.");

        return toZstdError(err);
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

    return Frame{
        .allocated = true,
        .data = compressed,
        .diag = &self.diag,
    };
}

inline fn getZstdErr(code: usize) ZstdError {
    const enum_err = @as(c.ZSTD_ErrorCode, @bitCast(code));

    return toError(enum_err);
}

inline fn getZstdErrStr(code: usize) [:0]u8 {
    return c.ZSTD_getErrorString(
        @intCast(code),
    );
}

const TEST_DATA = @embedFile("root.zig");

test {
    std.testing.refAllDecls(Self);
}

test "compress" {
    // const alloc = std.testing.allocator;
}
