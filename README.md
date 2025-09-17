[![CI](https://github.com/allyourcodebase/zstd/actions/workflows/ci.yaml/badge.svg)](https://github.com/allyourcodebase/zstd/actions)

# zstd

This is [zstd](https://github.com/facebook/zstd), packaged for [Zig](https://ziglang.org/).

## Zig Bindings

I took the liberty to write some very simple (compression and decompression w/o context types etc.) Zig FFI bindings for this static library.
To use them, first update your `build.zig.zon` as below in [installation](#installation), then add this to your `build.zig`:

```zig
const zstd = b.dependency("zstd", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("zstd", zstd.module("zstd"));
```

This should do the job of compiling and statically linking `zstd` but if not, add the line containing `linkLibrary` as below.

## Installation

First, update your `build.zig.zon`:

```
# Initialize a `zig build` project if you haven't already
zig init
zig fetch --save git+https://github.com/allyourcodebase/zstd.git#1.5.7
```

You can then import `zstd` in your `build.zig` with:

```zig
const zstd_dependency = b.dependency("zstd", .{
    .target = target,
    .optimize = optimize,
});
your_exe.linkLibrary(zstd_dependency.artifact("zstd"));
```
