const std = @import("std");
const builtin = @import("builtin");
const Build = std.Build;
const CompileStep = Build.Step.Compile;

pub const FinalOpts = struct {
    use_wayland: bool = false,
    system_jpeg: bool = false,
    system_png: bool = false,
    system_zlib: bool = false,
    use_zig_cc: bool = false,
    use_fltk_config: bool = false,
};

pub inline fn thisDir() []const u8 {
    return comptime std.fs.path.dirname(@src().file) orelse @panic("error");
}

const Example = struct {
    description: ?[]const u8,
    output: []const u8,
    input: []const u8,

    pub fn init(output: []const u8, input: []const u8, desc: ?[]const u8) Example {
        return Example{
            .description = desc,
            .output = output,
            .input = input,
        };
    }
};

pub const examples = &[_]Example{
    Example.init("simple", "examples/simple.zig", "A simple hello world app"),
    Example.init("capi", "examples/capi.zig", "Using the C-api directly"),
    Example.init("customwidget", "examples/customwidget.zig", "Custom widget example"),
    Example.init("image", "examples/image.zig", "Simple image example"),
    Example.init("input", "examples/input.zig", "Simple input example"),
    Example.init("mixed", "examples/mixed.zig", "Mixing both c and zig apis"),
    Example.init("editor", "examples/editor.zig", "More complex example"),
    Example.init("layout", "examples/layout.zig", "Layout example"),
    Example.init("valuators", "examples/valuators.zig", "valuators example"),
    Example.init("channels", "examples/channels.zig", "Use messages to handle events"),
    Example.init("editormsgs", "examples/editormsgs.zig", "Use messages in the editor example"),
    Example.init("browser", "examples/browser.zig", "Browser example"),
    Example.init("flex", "examples/flex.zig", "Flex example"),
    Example.init("threadawake", "examples/threadawake.zig", "Thread awake example"),
    Example.init("handle", "examples/handle.zig", "Handle example"),
    Example.init("flutterlike", "examples/flutterlike.zig", "Flutter-like example"),
    Example.init("glwin", "examples/glwin.zig", "OpenGL window example"),
    Example.init("tile", "examples/tile.zig", "Tile group example"),
};

pub fn cfltk_build_from_source(b: *Build, finalize_cfltk: *Build.Step, install_prefix: []const u8, target: Build.ResolvedTarget, opts: FinalOpts) !void {
    var buf: [1024]u8 = undefined;
    const sdk_lib_dir = try std.fmt.bufPrint(buf[0..], "{s}/cfltk/lib", .{install_prefix});
    _ = std.fs.cwd().openDir(sdk_lib_dir, .{}) catch |err| {
        std.debug.print("Warning: {!}. The cfltk library will be rebuilt from source!\n", .{err});

        var zig_exe_buf: [2048]u8 = [_]u8{0} ** 2048;
        _ = std.mem.replace(u8, b.graph.zig_exe, "\\", "/", zig_exe_buf[0..b.graph.zig_exe.len]);
        const zig_exe = zig_exe_buf[0..b.graph.zig_exe.len];
        var zig_cache_root_buf: [2048]u8 = [_]u8{0} ** 2048;
        _ = std.mem.replace(u8, b.cache_root.path.?, "\\", "/", zig_cache_root_buf[0..b.cache_root.path.?.len]);
        const zig_cache_root = zig_cache_root_buf[0..b.cache_root.path.?.len];
        var zig_cc_buf: [4096]u8 = undefined;
        var zig_cpp_buf: [4096]u8 = undefined;
        var zig_ar_buf: [4096]u8 = undefined;
        var zig_ranlib_buf: [4096]u8 = undefined;

        const zig_cc_script_name = switch (builtin.os.tag) {
            .windows => "zig-cc.bat",
            else => "zig-cc",
        };

        const zig_cpp_script_name = switch (builtin.os.tag) {
            .windows => "zig-cpp.bat",
            else => "zig-cpp",
        };

        const zig_ar_script_name = switch (builtin.os.tag) {
            .windows => "zig-ar.bat",
            else => "zig-ar",
        };

        const zig_ranlib_script_name = switch (builtin.os.tag) {
            .windows => "zig-ranlib.bat",
            else => "zig-ranlib",
        };

        if (opts.use_zig_cc) {
            std.debug.print("zig cc and c++ will be used\n", .{});

            var dir = try std.fs.openDirAbsolute(b.cache_root.path.?, .{});

            const ccFile = try dir.createFile(zig_cc_script_name, .{
                .read = true,
                .mode = switch (builtin.os.tag) {
                    .windows => 0,
                    .wasi => 0,
                    else => 0o755,
                },
            });

            if (builtin.os.tag == .windows) {
                try ccFile.writer().print("{s} cc %*", .{zig_exe});
            } else {
                try ccFile.writer().print("#!/usr/bin/env bash\n\n{s} cc $@", .{zig_exe});
            }
            ccFile.close();

            const cppFile = try dir.createFile(zig_cpp_script_name, .{
                .read = true,
                .mode = switch (builtin.os.tag) {
                    .windows => 0,
                    .wasi => 0,
                    else => 0o755,
                },
            });

            if (builtin.os.tag == .windows) {
                try cppFile.writer().print("{s} c++ %*", .{zig_exe});
            } else {
                try cppFile.writer().print("#!/usr/bin/env bash\n\n{s} c++ $@", .{zig_exe});
            }
            cppFile.close();

            const arFile = try dir.createFile(zig_ar_script_name, .{
                .read = true,
                .mode = switch (builtin.os.tag) {
                    .windows => 0,
                    .wasi => 0,
                    else => 0o755,
                },
            });

            if (builtin.os.tag == .windows) {
                try arFile.writer().print("{s} ar %*", .{zig_exe});
            } else {
                try arFile.writer().print("#!/usr/bin/env bash\n\n{s} ar $@", .{zig_exe});
            }
            arFile.close();

            const ranlibFile = try dir.createFile(zig_ranlib_script_name, .{
                .read = true,
                .mode = switch (builtin.os.tag) {
                    .windows => 0,
                    .wasi => 0,
                    else => 0o755,
                },
            });

            if (builtin.os.tag == .windows) {
                try ranlibFile.writer().print("{s} ranlib %*", .{zig_exe});
            } else {
                try ranlibFile.writer().print("#!/usr/bin/env bash\n\n{s} ranlib $@", .{zig_exe});
            }
            ranlibFile.close();

            dir.close();
        }

        const use_zig_cc = switch (opts.use_zig_cc) {
            false => "",
            true => try std.fmt.bufPrint(zig_cc_buf[0..], "-DCMAKE_C_COMPILER={s}/{s}", .{ zig_cache_root, zig_cc_script_name }),
        };
        const use_zig_cpp = switch (opts.use_zig_cc) {
            false => "",
            true => try std.fmt.bufPrint(zig_cpp_buf[0..], "-DCMAKE_CXX_COMPILER={s}/{s}", .{ zig_cache_root, zig_cpp_script_name }),
        };

        const use_zig_ar = switch (opts.use_zig_cc) {
            false => "",
            true => try std.fmt.bufPrint(zig_ar_buf[0..], "-DCMAKE_AR={s}/{s}", .{ zig_cache_root, zig_ar_script_name }),
        };
        const use_zig_ranlib = switch (opts.use_zig_cc) {
            false => "",
            true => try std.fmt.bufPrint(zig_ranlib_buf[0..], "-DCMAKE_RANLIB={s}/{s}", .{ zig_cache_root, zig_ranlib_script_name }),
        };

        var bin_buf: [250]u8 = undefined;
        var src_buf: [250]u8 = undefined;
        var inst_buf: [250]u8 = undefined;
        const cmake_bin_path = try std.fmt.bufPrint(bin_buf[0..], "{s}/cfltk/bin", .{install_prefix});
        const cmake_src_path = try std.fmt.bufPrint(src_buf[0..], "{s}/cfltk", .{install_prefix});
        const cmake_inst_path = try std.fmt.bufPrint(inst_buf[0..], "-DCMAKE_INSTALL_PREFIX={s}/cfltk/lib", .{install_prefix});
        var zfltk_config: *std.Build.Step.Run = undefined;
        const which_png = switch (opts.system_png) {
            false => "-DFLTK_USE_SYSTEM_LIBPNG=OFF",
            true => "-DFLTK_USE_SYSTEM_LIBPNG=ON",
        };
        const which_jpeg = switch (opts.system_jpeg) {
            false => "-DFLTK_USE_SYSTEM_LIBJPEG=OFF",
            true => "-DFLTK_USE_SYSTEM_LIBJPEG=ON",
        };
        const which_zlib = switch (opts.system_zlib) {
            false => "-DFLTK_USE_SYSTEM_ZLIB=OFF",
            true => "-DFLTK_USE_SYSTEM_ZLIB=ON",
        };

        // const triple = try target.result.zigTriple(b.allocator);
        // var c_triple_buf: [250]u8 = undefined;
        // var cpp_triple_buf: [250]u8 = undefined;
        // const cmake_c_triple = switch (opts.use_zig_cc) {
        //     true => try std.fmt.bufPrint(c_triple_buf[0..], "-DCMAKE_C_COMPILER_TARGET={s}", .{triple}),
        //     else => "",
        // };
        // const cmake_cpp_triple = switch (opts.use_zig_cc) {
        //     true => try std.fmt.bufPrint(cpp_triple_buf[0..], "-DCMAKE_CXX_COMPILER_TARGET={s}", .{triple}),
        //     else => "",
        // };

        if (target.result.os.tag == .windows) {
            zfltk_config = b.addSystemCommand(&[_][]const u8{
                "cmake",
                "-B",
                cmake_bin_path,
                "-S",
                cmake_src_path,
                "-GNinja",
                "-DCMAKE_BUILD_TYPE=Release",
                use_zig_cc,
                use_zig_cpp,
                use_zig_ar,
                use_zig_ranlib,
                // cmake_c_triple,
                // cmake_cpp_triple,
                cmake_inst_path,
                "-DFLTK_BUILD_TEST=OFF",
                which_png,
                which_jpeg,
                which_zlib,
                "-DFLTK_USE_GL=ON",
                "-DCFLTK_USE_OPENGL=ON",
                "-DFLTK_BUILD_FLUID=OFF",
                "-DFLTK_BUILD_FLTK_OPTIONS=OFF",
                // "-DZIG_TARGET_MCPU=baseline",
            });
        } else if (target.result.isDarwin()) {
            zfltk_config = b.addSystemCommand(&[_][]const u8{
                "cmake",
                "-B",
                cmake_bin_path,
                "-S",
                cmake_src_path,
                "-DCMAKE_BUILD_TYPE=Release",
                use_zig_cc,
                use_zig_cpp,
                use_zig_ar,
                use_zig_ranlib,
                // cmake_c_triple,
                // cmake_cpp_triple,
                cmake_inst_path,
                "-DFLTK_BUILD_TEST=OFF",
                which_png,
                which_jpeg,
                which_zlib,
                "-DFLTK_USE_GL=ON",
                "-DCFLTK_USE_OPENGL=ON",
                "-DFLTK_BUILD_FLUID=OFF",
                "-DFLTK_BUILD_FLTK_OPTIONS=OFF",
                // "-DZIG_TARGET_MCPU=baseline",
            });
        } else {
            if (opts.use_wayland) {
                zfltk_config = b.addSystemCommand(&[_][]const u8{
                    "cmake",
                    "-B",
                    cmake_bin_path,
                    "-S",
                    cmake_src_path,
                    "-DCMAKE_BUILD_TYPE=Release",
                    use_zig_cc,
                    use_zig_cpp,
                    use_zig_ar,
                    use_zig_ranlib,
                    // cmake_c_triple,
                    // cmake_cpp_triple,
                    cmake_inst_path,
                    "-DFLTK_BUILD_TEST=OFF",
                    which_png,
                    which_jpeg,
                    which_zlib,
                    "-DFLTK_USE_GL=ON",
                    "-DCFLTK_USE_OPENGL=ON",
                    "-DFLTK_BACKEND_WAYLAND=ON",
                    "-DFLTK_BUILD_FLUID=OFF",
                    "-DFLTK_BUILD_FLTK_OPTIONS=OFF",
                    // "-DZIG_TARGET_MCPU=baseline",
                });
            } else {
                zfltk_config = b.addSystemCommand(&[_][]const u8{
                    "cmake",
                    "-B",
                    cmake_bin_path,
                    "-S",
                    cmake_src_path,
                    "-DCMAKE_BUILD_TYPE=Release",
                    use_zig_cc,
                    use_zig_cpp,
                    use_zig_ar,
                    use_zig_ranlib,
                    // cmake_c_triple,
                    // cmake_cpp_triple,
                    cmake_inst_path,
                    "-DFLTK_BUILD_TEST=OFF",
                    which_png,
                    which_jpeg,
                    which_zlib,
                    "-DFLTK_USE_PANGO=ON", // enable if rtl/cjk font support is needed
                    "-DFLTK_USE_GL=ON",
                    "-DCFLTK_USE_OPENGL=ON",
                    "-DFLTK_BACKEND_WAYLAND=OFF",
                    "-DFLTK_USE_CAIRO=ON",
                    "-DFLTK_BUILD_FLUID=OFF",
                    "-DFLTK_BUILD_FLTK_OPTIONS=OFF",
                    // "-DZIG_TARGET_MCPU=baseline",
                });
            }
        }
        _ = std.fs.cwd().openDir(cmake_src_path, .{}) catch |git_err| {
            std.debug.print("Warning: {!}. The cfltk library will be grabbed!\n", .{git_err});
            const cfltk_fetch = b.addSystemCommand(&[_][]const u8{ "git", "clone", "https://github.com/MoAlyousef/cfltk", cmake_src_path, "--depth=1", "--recurse-submodules" });
            zfltk_config.step.dependOn(&cfltk_fetch.step);
        };
        const cpu_count = try std.Thread.getCpuCount();
        const jobs = try std.fmt.allocPrint(b.allocator, "{d}", .{cpu_count});
        defer b.allocator.free(jobs);
        const zfltk_build = b.addSystemCommand(&[_][]const u8{
            "cmake",
            "--build",
            cmake_bin_path,
            "--config",
            "Release",
            "--parallel",
            jobs,
            // "--",
            // "VERBOSE=1",
        });
        zfltk_build.step.dependOn(&zfltk_config.step);

        // This only needs to run once!
        const zfltk_install = b.addSystemCommand(&[_][]const u8{
            "cmake",
            "--install",
            cmake_bin_path,
        });
        zfltk_install.step.dependOn(&zfltk_build.step);

        if (builtin.os.tag != .windows) {
            const zfltk_delete_tmp_files = b.addSystemCommand(&[_][]const u8{
                "rm",
                "-rf",
                try std.fmt.bufPrint(zig_cc_buf[0..], "{s}/{s}", .{ b.cache_root.path.?, zig_cc_script_name }),
                try std.fmt.bufPrint(zig_cpp_buf[0..], "{s}/{s}", .{ b.cache_root.path.?, zig_cpp_script_name }),
                try std.fmt.bufPrint(zig_ar_buf[0..], "{s}/{s}", .{ b.cache_root.path.?, zig_ar_script_name }),
                try std.fmt.bufPrint(zig_ranlib_buf[0..], "{s}/{s}", .{ b.cache_root.path.?, zig_ranlib_script_name }),
            });

            zfltk_delete_tmp_files.step.dependOn(&zfltk_install.step);

            finalize_cfltk.dependOn(&zfltk_delete_tmp_files.step);
        } else {
            finalize_cfltk.dependOn(&zfltk_install.step);
        }
    };
}

pub fn cfltk_link(exe: *CompileStep, install_prefix: []const u8, opts: FinalOpts) !void {
    var buf: [1024]u8 = undefined;
    const target = exe.rootModuleTarget();
    const inc_dir = try std.fmt.bufPrint(buf[0..], "{s}/cfltk/include", .{install_prefix});
    exe.addIncludePath(Build.LazyPath{ .path = inc_dir });
    const lib_dir = try std.fmt.bufPrint(buf[0..], "{s}/cfltk/lib/lib", .{install_prefix});
    exe.addLibraryPath(Build.LazyPath{ .path = lib_dir });
    exe.linkSystemLibrary("cfltk");
    exe.linkSystemLibrary("fltk");
    exe.linkSystemLibrary("fltk_images");
    if (opts.system_png) {
        exe.linkSystemLibrary("png");
    } else {
        exe.linkSystemLibrary("fltk_png");
    }
    if (opts.system_jpeg) {
        exe.linkSystemLibrary("jpeg");
    } else {
        exe.linkSystemLibrary("fltk_jpeg");
    }
    if (opts.system_zlib) {
        exe.linkSystemLibrary("z");
    } else {
        exe.linkSystemLibrary("fltk_z");
    }
    exe.linkSystemLibrary("fltk_gl");
    exe.linkLibC();
    exe.linkLibCpp();
    if (target.os.tag == .windows) {
        exe.linkSystemLibrary("ws2_32");
        exe.linkSystemLibrary("comctl32");
        exe.linkSystemLibrary("gdi32");
        exe.linkSystemLibrary("oleaut32");
        exe.linkSystemLibrary("ole32");
        exe.linkSystemLibrary("uuid");
        exe.linkSystemLibrary("shell32");
        exe.linkSystemLibrary("advapi32");
        exe.linkSystemLibrary("comdlg32");
        exe.linkSystemLibrary("winspool");
        exe.linkSystemLibrary("user32");
        exe.linkSystemLibrary("kernel32");
        exe.linkSystemLibrary("odbc32");
        exe.linkSystemLibrary("gdiplus");
        exe.linkSystemLibrary("opengl32");
        exe.linkSystemLibrary("glu32");
    } else if (target.isDarwin()) {
        exe.linkFramework("Carbon");
        exe.linkFramework("Cocoa");
        exe.linkFramework("ApplicationServices");
        exe.linkFramework("OpenGL");
    } else {
        if (opts.use_wayland) {
            exe.linkSystemLibrary("wayland-client");
            exe.linkSystemLibrary("wayland-cursor");
            exe.linkSystemLibrary("xkbcommon");
            exe.linkSystemLibrary("dbus-1");
            exe.linkSystemLibrary("EGL");
            exe.linkSystemLibrary("wayland-egl");
        }
        exe.linkSystemLibrary("GL");
        exe.linkSystemLibrary("GLU");
        exe.linkSystemLibrary("pthread");
        exe.linkSystemLibrary("X11");
        exe.linkSystemLibrary("Xext");
        exe.linkSystemLibrary("Xinerama");
        exe.linkSystemLibrary("Xcursor");
        exe.linkSystemLibrary("Xrender");
        exe.linkSystemLibrary("Xfixes");
        exe.linkSystemLibrary("Xft");
        exe.linkSystemLibrary("fontconfig");
        exe.linkSystemLibrary("pango-1.0");
        exe.linkSystemLibrary("pangoxft-1.0");
        exe.linkSystemLibrary("gobject-2.0");
        exe.linkSystemLibrary("cairo");
        exe.linkSystemLibrary("pangocairo-1.0");
    }
}

pub fn cfltk_link_module(module: *Build.Module, install_prefix: []const u8, opts: FinalOpts) !void {
    var buf: [1024]u8 = undefined;
    const target = module.resolved_target.?.result;
    const inc_dir = try std.fmt.bufPrint(buf[0..], "{s}/cfltk/include", .{install_prefix});
    module.addIncludePath(Build.LazyPath{ .path = inc_dir });
    const lib_dir = try std.fmt.bufPrint(buf[0..], "{s}/cfltk/lib/lib", .{install_prefix});
    module.addLibraryPath(Build.LazyPath{ .path = lib_dir });
    module.linkSystemLibrary("cfltk", .{});
    module.linkSystemLibrary("fltk", .{});
    module.linkSystemLibrary("fltk_images", .{});
    if (opts.system_png) {
        module.linkSystemLibrary("png", .{});
    } else {
        module.linkSystemLibrary("fltk_png", .{});
    }
    if (opts.system_jpeg) {
        module.linkSystemLibrary("jpeg", .{});
    } else {
        module.linkSystemLibrary("fltk_jpeg", .{});
    }
    if (opts.system_zlib) {
        module.linkSystemLibrary("z", .{});
    } else {
        module.linkSystemLibrary("fltk_z", .{});
    }
    module.linkSystemLibrary("fltk_gl", .{});
    if (target.os.tag == .windows) {
        module.linkSystemLibrary("ws2_32", .{});
        module.linkSystemLibrary("comctl32", .{});
        module.linkSystemLibrary("gdi32", .{});
        module.linkSystemLibrary("oleaut32", .{});
        module.linkSystemLibrary("ole32", .{});
        module.linkSystemLibrary("uuid", .{});
        module.linkSystemLibrary("shell32", .{});
        module.linkSystemLibrary("advapi32", .{});
        module.linkSystemLibrary("comdlg32", .{});
        module.linkSystemLibrary("winspool", .{});
        module.linkSystemLibrary("user32", .{});
        module.linkSystemLibrary("kernel32", .{});
        module.linkSystemLibrary("odbc32", .{});
        module.linkSystemLibrary("gdiplus", .{});
        module.linkSystemLibrary("opengl32", .{});
        module.linkSystemLibrary("glu32", .{});
    } else if (target.isDarwin()) {
        module.linkFramework("Carbon", .{});
        module.linkFramework("Cocoa", .{});
        module.linkFramework("ApplicationServices", .{});
        module.linkFramework("OpenGL", .{});
    } else {
        if (opts.use_wayland) {
            module.linkSystemLibrary("wayland-client", .{});
            module.linkSystemLibrary("wayland-cursor", .{});
            module.linkSystemLibrary("xkbcommon", .{});
            module.linkSystemLibrary("dbus-1", .{});
            module.linkSystemLibrary("EGL", .{});
            module.linkSystemLibrary("wayland-egl", .{});
        }
        module.linkSystemLibrary("GL", .{});
        module.linkSystemLibrary("GLU", .{});
        module.linkSystemLibrary("pthread", .{});
        module.linkSystemLibrary("X11", .{});
        module.linkSystemLibrary("Xext", .{});
        module.linkSystemLibrary("Xinerama", .{});
        module.linkSystemLibrary("Xcursor", .{});
        module.linkSystemLibrary("Xrender", .{});
        module.linkSystemLibrary("Xfixes", .{});
        module.linkSystemLibrary("Xft", .{});
        module.linkSystemLibrary("fontconfig", .{});
        module.linkSystemLibrary("pango-1.0", .{});
        module.linkSystemLibrary("pangoxft-1.0", .{});
        module.linkSystemLibrary("gobject-2.0", .{});
        module.linkSystemLibrary("cairo", .{});
        module.linkSystemLibrary("pangocairo-1.0", .{});
    }
}

pub fn link_using_fltk_config(b: *Build, exe: *CompileStep, finalize_cfltk: *Build.Step, install_prefix: []const u8) !void {
    const target = exe.rootModuleTarget();
    exe.linkLibC();
    exe.linkLibCpp();
    var buf: [1024]u8 = undefined;
    const inc_dir = try std.fmt.bufPrint(buf[0..], "{s}/cfltk/include", .{install_prefix});
    exe.addIncludePath(Build.LazyPath{ .path = inc_dir });
    const cmake_src_path = try std.fmt.allocPrint(b.allocator, "{s}/cfltk", .{install_prefix});
    _ = std.fs.cwd().openDir(cmake_src_path, .{}) catch |git_err| {
        std.debug.print("Warning: {!}. The cfltk library will be grabbed!\n", .{git_err});
        const cfltk_fetch = b.addSystemCommand(&[_][]const u8{ "git", "clone", "https://github.com/MoAlyousef/cfltk", cmake_src_path, "--depth=1" });
        finalize_cfltk.dependOn(&cfltk_fetch.step);
    };
    var lib = b.addStaticLibrary(.{
        .name = "cfltk",
        .target = exe.root_module.resolved_target.?,
        .optimize = exe.root_module.optimize.?,
    });
    const proc = try std.ChildProcess.run(.{
        .allocator = b.allocator,
        .argv = &[_][]const u8{ "fltk-config", "--use-images", "--use-gl", "--cflags" },
    });
    const out = proc.stdout;
    var cflags = std.ArrayList([]const u8).init(b.allocator);
    var it = std.mem.tokenize(u8, out, " ");
    while (it.next()) |x| {
        try cflags.append(x);
    }
    cflags.clearAndFree(); // why does the above not work?!
    try cflags.append("-I/usr/local/include");
    try cflags.append(try std.fmt.allocPrint(b.allocator, "-I{s}", .{inc_dir}));
    try cflags.append("-DCFLTK_USE_GL");
    lib.addCSourceFiles(.{
        .files = &[_][]const u8{
            try std.fmt.allocPrint(b.allocator, "{s}/cfltk/src/cfl_new.cpp", .{install_prefix}),
            try std.fmt.allocPrint(b.allocator, "{s}/cfltk/src/cfl_lock.cpp", .{install_prefix}),
            try std.fmt.allocPrint(b.allocator, "{s}/cfltk/src/cfl.cpp", .{install_prefix}),
            try std.fmt.allocPrint(b.allocator, "{s}/cfltk/src/cfl_window.cpp", .{install_prefix}),
            try std.fmt.allocPrint(b.allocator, "{s}/cfltk/src/cfl_button.cpp", .{install_prefix}),
            try std.fmt.allocPrint(b.allocator, "{s}/cfltk/src/cfl_widget.cpp", .{install_prefix}),
            try std.fmt.allocPrint(b.allocator, "{s}/cfltk/src/cfl_group.cpp", .{install_prefix}),
            try std.fmt.allocPrint(b.allocator, "{s}/cfltk/src/cfl_text.cpp", .{install_prefix}),
            try std.fmt.allocPrint(b.allocator, "{s}/cfltk/src/cfl_box.cpp", .{install_prefix}),
            try std.fmt.allocPrint(b.allocator, "{s}/cfltk/src/cfl_input.cpp", .{install_prefix}),
            try std.fmt.allocPrint(b.allocator, "{s}/cfltk/src/cfl_menu.cpp", .{install_prefix}),
            try std.fmt.allocPrint(b.allocator, "{s}/cfltk/src/cfl_dialog.cpp", .{install_prefix}),
            try std.fmt.allocPrint(b.allocator, "{s}/cfltk/src/cfl_valuator.cpp", .{install_prefix}),
            try std.fmt.allocPrint(b.allocator, "{s}/cfltk/src/cfl_browser.cpp", .{install_prefix}),
            try std.fmt.allocPrint(b.allocator, "{s}/cfltk/src/cfl_misc.cpp", .{install_prefix}),
            try std.fmt.allocPrint(b.allocator, "{s}/cfltk/src/cfl_image.cpp", .{install_prefix}),
            try std.fmt.allocPrint(b.allocator, "{s}/cfltk/src/cfl_draw.cpp", .{install_prefix}),
            try std.fmt.allocPrint(b.allocator, "{s}/cfltk/src/cfl_table.cpp", .{install_prefix}),
            try std.fmt.allocPrint(b.allocator, "{s}/cfltk/src/cfl_tree.cpp", .{install_prefix}),
            try std.fmt.allocPrint(b.allocator, "{s}/cfltk/src/cfl_surface.cpp", .{install_prefix}),
            try std.fmt.allocPrint(b.allocator, "{s}/cfltk/src/cfl_font.cpp", .{install_prefix}),
            try std.fmt.allocPrint(b.allocator, "{s}/cfltk/src/cfl_utils.cpp", .{install_prefix}),
            try std.fmt.allocPrint(b.allocator, "{s}/cfltk/src/cfl_printer.cpp", .{install_prefix}),
        },
        .flags = cflags.items,
    });
    if (target.isDarwin()) {
        lib.addCSourceFile(Build.Module.CSourceFile{ .file = Build.LazyPath{ .path = try std.fmt.allocPrint(b.allocator, "{s}/cfltk/src/cfl_nswindow.m", .{install_prefix}) }, .flags = cflags.items });
    }
    const proc2 = try std.ChildProcess.run(.{
        .allocator = b.allocator,
        .argv = &[_][]const u8{ "fltk-config", "--use-images", "--use-gl", "--ldflags" },
    });
    const out2 = proc2.stdout;
    var lflags = std.ArrayList([]const u8).init(b.allocator);
    var Lflags = std.ArrayList([]const u8).init(b.allocator);
    var it2 = std.mem.tokenize(u8, out2, " ");
    while (it2.next()) |x| {
        if (std.mem.startsWith(u8, x, "-l") and !std.mem.startsWith(u8, x, "-ldl")) try lflags.append(x[2..]);
        if (std.mem.startsWith(u8, x, "-L")) try Lflags.append(x[2..]);
    }
    for (Lflags.items) |f| {
        lib.addLibraryPath(Build.LazyPath{ .path = f });
    }
    for (lflags.items) |f| {
        lib.linkSystemLibrary(f);
    }
    lib.linkLibC();
    lib.linkLibCpp();
    lib.step.dependOn(finalize_cfltk);
    exe.step.dependOn(&lib.step);
    exe.linkLibrary(lib);
}
