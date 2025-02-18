const std = @import("std");
const builtin = @import("builtin");
const Build = std.Build;
const CompileStep = Build.Step.Compile;
const utils = @import("build_utils.zig");

pub const SdkOpts = struct {
    use_wayland: bool = false,
    system_jpeg: bool = false,
    system_png: bool = false,
    system_zlib: bool = false,
    use_zig_cc: bool = true,
    use_fltk_config: bool = false,
    fn finalOpts(self: SdkOpts) utils.FinalOpts {
        return utils.FinalOpts{
            .use_wayland = self.use_wayland,
            .system_jpeg = self.system_jpeg,
            .system_png = self.system_png,
            .system_zlib = self.system_zlib,
            .use_zig_cc = self.use_zig_cc,
            .use_fltk_config = self.use_fltk_config,
        };
    }
};

const Sdk = @This();
builder: *Build,
install_prefix: []const u8,
finalize_cfltk: *std.Build.Step,
opts: SdkOpts,

pub fn init(b: *Build, target: Build.ResolvedTarget) !*Sdk {
    return initWithOpts(b, target, .{});
}

pub fn initWithOpts(b: *Build, target: Build.ResolvedTarget, opts: SdkOpts) !*Sdk {
    var final_opts = opts;
    final_opts.use_wayland = b.option(bool, "zfltk-use-wayland", "build zfltk for wayland") orelse opts.use_wayland;
    final_opts.system_jpeg = b.option(bool, "zfltk-system-libjpeg", "link system libjpeg") orelse opts.system_jpeg;
    final_opts.system_png = b.option(bool, "zfltk-system-libpng", "link system libpng") orelse opts.system_png;
    final_opts.system_zlib = b.option(bool, "zfltk-system-zlib", "link system zlib") orelse opts.system_zlib;
    final_opts.use_zig_cc = b.option(bool, "zfltk-use-zigcc", "use zig cc and zig c++ to build FLTK and cfltk") orelse opts.use_zig_cc;
    final_opts.use_fltk_config = b.option(bool, "zfltk-use-fltk-config", "use fltk-config instead of building fltk from source") orelse opts.use_fltk_config;
    const install_prefix = b.install_prefix;
    const finalize_cfltk = b.step("finalize cfltk install", "Installs cfltk");
    try utils.cfltk_build_from_source(b, finalize_cfltk, install_prefix, target, final_opts.finalOpts());
    b.default_step.dependOn(finalize_cfltk);
    const sdk = b.allocator.create(Sdk) catch @panic("out of memory");
    sdk.* = .{
        .builder = b,
        .install_prefix = install_prefix,
        .finalize_cfltk = finalize_cfltk,
        .opts = final_opts,
    };
    return sdk;
}

pub fn getZfltkModule(sdk: *Sdk, b: *Build, target: Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *Build.Module {
    const mod = b.addModule("zfltk", .{
        .root_source_file = .{ .path = utils.thisDir() ++ "/src/zfltk.zig" },
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .link_libcpp = true,
    });

    const install_prefix = sdk.install_prefix;
    utils.cfltk_link_module(mod, install_prefix, sdk.opts.finalOpts()) catch unreachable;

    const nps = std.zig.system.NativePaths.detect(b.allocator, b.host.result) catch unreachable;

    for (nps.include_dirs.items) |dir| {
        mod.addIncludePath(.{
            .path = dir,
        });
    }

    for (nps.lib_dirs.items) |dir| {
        mod.addLibraryPath(.{
            .path = dir,
        });
    }

    return mod;
}

pub fn linkLib(sdk: *Sdk, b: *Build, exe: *CompileStep) !void {
    _ = b;
    exe.step.dependOn(sdk.finalize_cfltk);
    // const install_prefix = sdk.install_prefix;
    // if (sdk.opts.use_fltk_config) {
    //     try utils.link_using_fltk_config(sdk.builder, exe, sdk.finalize_cfltk, sdk.install_prefix);
    // } else {
    //     try utils.cfltk_link(exe, install_prefix, sdk.opts.finalOpts());

    //     const nps = std.zig.system.NativePaths.detect(b.allocator, b.host.result) catch unreachable;

    //     for (nps.include_dirs.items) |dir| {
    //         exe.root_module.addIncludePath(.{
    //             .path = dir,
    //         });
    //     }

    //     for (nps.lib_dirs.items) |dir| {
    //         exe.root_module.addLibraryPath(.{
    //             .path = dir,
    //         });
    //     }
    // }
}

pub fn link(sdk: *Sdk, exe: *CompileStep) !void {
    exe.step.dependOn(sdk.finalize_cfltk);
    const install_prefix = sdk.install_prefix;
    if (sdk.opts.use_fltk_config) {
        try utils.link_using_fltk_config(sdk.builder, exe, sdk.finalize_cfltk, sdk.install_prefix);
    } else {
        try utils.cfltk_link(exe, install_prefix, sdk.opts.finalOpts());
    }
}

pub fn build(b: *Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const sdk = try Sdk.init(b, target);
    const examples_step = b.step("examples", "build the examples");
    b.default_step.dependOn(examples_step);

    const lib = b.addStaticLibrary(.{
        .name = "zfltk",
        .target = target,
        .optimize = optimize,
        .root_source_file = .{
            .path = "src/zfltk.zig",
        },
    });
    try sdk.linkLib(b, lib);

    const zfltk_module = sdk.getZfltkModule(b, target, optimize);
    zfltk_module.linkLibrary(lib);

    for (utils.examples) |example| {
        const exe = b.addExecutable(.{
            .name = example.output,
            .root_source_file = .{ .path = example.input },
            .optimize = optimize,
            .target = target,
        });
        exe.root_module.addImport("zfltk", zfltk_module);

        examples_step.dependOn(&exe.step);
        b.installArtifact(exe);

        const run_cmd = b.addRunArtifact(exe);
        const run_step = b.step(b.fmt("run-{s}", .{example.output}), example.description.?);
        run_step.dependOn(&run_cmd.step);
    }
}
