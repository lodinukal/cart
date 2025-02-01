const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) !void {
    var wasm_cpu_set: std.Target.Cpu.Feature.Set = .empty;
    wasm_cpu_set.addFeature(@intFromEnum(std.Target.wasm.Feature.atomics));
    wasm_cpu_set.addFeatureSet(std.Target.wasm.cpu.bleeding_edge.features);
    const wasm_target = b.resolveTargetQuery(.{
        .abi = .musl,
        .cpu_arch = .wasm32,
        .ofmt = .wasm,
        .os_tag = .wasi,
        .cpu_features_add = wasm_cpu_set,
    });

    const in_target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const target = if (in_target.result.isWasm()) wasm_target else in_target;

    const shared_luau = b.option(
        bool,
        "shared",
        "Build a shared library luau instead of a static library. This allows for dynamic luau libraries to be opened.",
    ) orelse !target.result.isWasm();
    if (target.result.isWasm() and shared_luau) {
        std.debug.panic("Cannot build shared library for wasm target; pass -Dshared=false or change target.", .{});
    }

    const config = b.addOptions();
    config.addOption(bool, "shared_luau", shared_luau);
    const version = try Version.init(b);
    config.addOption(std.SemanticVersion, "version", version.version);

    const has_ffi = blk: {
        if (target.result.isWasm()) break :blk false;
        if (target.result.os.tag == .windows and target.result.cpu.arch == .aarch64) break :blk false;
        break :blk true;
    };
    config.addOption(bool, "has_ffi", has_ffi);

    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib_mod.addImport("config", config.createModule());

    const luau_dep = b.dependency("luau", .{
        .target = target,
        .optimize = std.builtin.OptimizeMode.ReleaseFast,
        .use_4_vector = true,
        .shared = shared_luau,
    });
    lib_mod.addImport("luau", luau_dep.module("luau"));

    if (has_ffi) {
        // dynlib
        const ffi_dep = b.dependency("ffi", .{
            .target = target,
            .optimize = optimize,
        });
        lib_mod.addImport("ffi", ffi_dep.module("ffi"));
        if (b.systemIntegrationOption("ffi", .{})) {
            lib_mod.linkSystemLibrary("ffi", .{});
        } else {
            lib_mod.linkLibrary(ffi_dep.artifact("ffi"));
        }
    }

    // We will also create a module for our other entry point, 'main.zig'.
    const cli_mod = b.createModule(.{
        // `root_source_file` is the Zig "entry point" of the module. If a module
        // only contains e.g. external object files, you can make this `null`.
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = if (target.result.isWasm()) b.path("src/wasm.zig") else b.path("src/cli.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Modules can depend on one another using the `std.Build.Module.addImport` function.
    // This is what allows Zig source code to use `@import("foo")` where 'foo' is not a
    // file path. In this case, we set up `cli_mod` to import `lib_mod`.
    cli_mod.addImport("cart_lib", lib_mod);
    cli_mod.addImport("luau", luau_dep.module("luau"));

    // Now, we will create a static library based on the module we created above.
    // This creates a `std.Build.Step.Compile`, which is the build step responsible
    // for actually invoking the compiler.
    const lib = b.addStaticLibrary(.{
        .name = "cart",
        .root_module = lib_mod,
    });

    if (!target.result.isWasm()) {
        const shared_test = b.addSharedLibrary(.{
            .name = "shared_test",
            .root_source_file = b.path("src/shared_test.zig"),
            .target = target,
            .optimize = optimize,
        });
        shared_test.root_module.addImport("luau", luau_dep.module("luau"));
        b.installArtifact(shared_test);
    }

    // if we are linking shared library then we need to install the shared library
    if (shared_luau) {
        b.installArtifact(luau_dep.artifact("luau"));
    }
    b.installArtifact(lib);

    // This creates another `std.Build.Step.Compile`, but this one builds an executable
    // rather than a static library.
    const cli = b.addExecutable(.{
        .name = "cart",
        .root_module = cli_mod,
    });
    if (target.result.isWasm()) {
        lib_mod.export_symbol_names = &.{
            "cart_alloc",
            "cart_free",
            "cart_popLastError",
            "cart_loadThreadFromFile",
            "cart_loadThreadFromString",
            "cart_closeThread",
            "cart_executeThread",
            "cart_threadStatus",
            "cart_threadIsScheduled",
            "cart_step",
            "cart_end",
            "cart_callFunction",
            "cart_destroyFunction",
        };
        @import("luau").addModuleExportSymbols(b, lib_mod);
    }

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(cli);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(cli);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const lib_unit_tests = b.addTest(.{
        .root_module = lib_mod,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const exe_unit_tests = b.addTest(.{
        .root_module = cli_mod,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);

    const version_step = b.step("version", "Get build version");
    version_step.dependOn(&version.step);
}

const Version = struct {
    step: std.Build.Step,
    version: std.SemanticVersion,

    pub fn init(b: *std.Build) !*Version {
        var tree = try std.zig.Ast.parse(b.allocator, @embedFile("build.zig.zon"), .zon);
        defer tree.deinit(b.allocator);

        const version = tree.tokenSlice(tree.nodes.items(.main_token)[2]);
        const semantic_version = try std.SemanticVersion.parse(version[1 .. version.len - 1]);

        const self = b.allocator.create(Version) catch @panic("OOM");
        self.step = std.Build.Step.init(.{
            .name = "version",
            .id = .custom,
            .owner = b,
            .makeFn = Version.make,
        });
        self.version = semantic_version;
        if (self.version.pre) |pre| {
            if (std.mem.eql(u8, pre, "dev")) {
                const hash = b.run(&.{ "git", "rev-parse", "--short", "HEAD" });
                const trimmed = std.mem.trim(u8, hash, "\r\n ");
                self.version.pre = b.allocator.dupe(u8, trimmed) catch @panic("OOM");
            }
        }
        return self;
    }

    pub fn make(step: *std.Build.Step, _: std.Build.Step.MakeOptions) anyerror!void {
        const self: *Version = @fieldParentPtr("step", step);
        try std.io.getStdOut().writer().print("{}\n", .{self.version});
    }
};
