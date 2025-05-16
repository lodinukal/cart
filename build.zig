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

    const is_wasm = in_target.result.ofmt == .wasm;

    const target = if (in_target.result.ofmt == .wasm) wasm_target else in_target;

    const shared_luau = b.option(
        bool,
        "shared-luau",
        "Build a shared library luau instead of a static library. This allows for dynamic luau libraries to be opened.",
    ) orelse false;
    const shared_cart = b.option(
        bool,
        "shared",
        "Build a shared library cart instead of a static library.",
    ) orelse false;
    const bundle_luau = b.option(
        bool,
        "bundle",
        "Bundle luau into the executable. This is useful for distributing a single executable.",
    ) orelse false;
    if (is_wasm and shared_luau) {
        std.debug.panic("Cannot build shared library for wasm target; pass -Dshared=false or change target.", .{});
    }
    if (is_wasm and bundle_luau) {
        std.debug.panic("Cannot bundle luau for wasm target; pass -Dbundle=false or change target.", .{});
    }

    const config = b.addOptions();
    config.addOption(bool, "shared_luau", shared_luau);
    config.addOption(bool, "bundle_luau", bundle_luau);
    const version = try Version.init(b);
    config.addOption(std.SemanticVersion, "version", version.version);

    const has_ffi = blk: {
        if (is_wasm) break :blk false;
        if (target.result.os.tag == .windows and target.result.cpu.arch == .aarch64) break :blk false;
        break :blk true;
    };
    config.addOption(bool, "has_ffi", has_ffi);

    const cart_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    cart_mod.addImport("config", config.createModule());

    const luau_dep = b.dependency("luau", .{
        .target = target,
        .optimize = std.builtin.OptimizeMode.ReleaseFast,
        .@"use 4 vector" = true,
        .build_shared = shared_luau,
    });
    cart_mod.addImport("luau", luau_dep.module("luau"));

    if (has_ffi) {
        // dynlib
        const ffi_dep = b.dependency("ffi", .{
            .target = target,
            .optimize = optimize,
        });
        cart_mod.addImport("ffi", ffi_dep.module("ffi"));
        if (b.systemIntegrationOption("ffi", .{})) {
            cart_mod.linkSystemLibrary("ffi", .{});
        } else {
            cart_mod.linkLibrary(ffi_dep.artifact("ffi"));
        }
    }
    
    // Now, we will create a static library based on the module we created above.
    // This creates a `std.Build.Step.Compile`, which is the build step responsible
    // for actually invoking the compiler.
    const lib = b.addLibrary(.{
        .name = "cart",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/c_root.zig"),
            .target = target,
            .optimize = optimize,
        }),
        .linkage = if (shared_cart) .dynamic else .static,
    });
    lib.root_module.addImport("cart", cart_mod);
    lib.root_module.addImport("luau", luau_dep.module("luau"));

    // if we are linking shared library then we need to install the shared library
    if (shared_luau) {
        b.installArtifact(luau_dep.artifact("luau"));
    }
    b.installArtifact(lib);

    const cli_exe = b.addExecutable(.{
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .root_source_file = b.path("src/cli.zig"),
        }),
        .name = "cart",
    });
    cli_exe.root_module.addImport("cart", cart_mod);

    b.installArtifact(cli_exe);
    const run_cmd = b.addRunArtifact(cli_exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the cart cli");
    run_step.dependOn(&run_cmd.step);

    if (is_wasm) {
        // const cart_symbols = &[_][]const u8{};
        // cart_mod.export_symbol_names = cart_symbols ++ lua_symbols;
        // @import("luau").addModuleExportSymbols(b, cart_mod);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    // const run_step = b.step("run", "Run the app");

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const cart_unit_tests = b.addTest(.{
        .root_module = cart_mod,
    });

    const run_cart_unit_tests = b.addRunArtifact(cart_unit_tests);

    // golden file tests
    const golden_file_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .root_source_file = b.path("tests/main.zig"),
        }),
    });
    golden_file_tests.root_module.addImport("cart", cart_mod);
    const run_golden_file_tests = b.addRunArtifact(golden_file_tests);
    run_golden_file_tests.setCwd(b.path("tests"));

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_cart_unit_tests.step);
    test_step.dependOn(&run_golden_file_tests.step);

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

const lua_symbols = &[_][]const u8{
    "lua_newstate",
    "lua_close",
    "lua_newthread",
    "lua_mainthread",
    "lua_resetthread",
    "lua_isthreadreset",
    "lua_absindex",
    "lua_gettop",
    "lua_settop",
    "lua_pushvalue",
    "lua_remove",
    "lua_insert",
    "lua_replace",
    "lua_checkstack",
    "lua_rawcheckstack",
    "lua_xmove",
    "lua_xpush",
    "lua_isnumber",
    "lua_isstring",
    "lua_iscfunction",
    "lua_isLfunction",
    "lua_isuserdata",
    "lua_type",
    "lua_typename",
    "lua_equal",
    "lua_rawequal",
    "lua_lessthan",
    "lua_tonumberx",
    "lua_tointegerx",
    "lua_tounsignedx",
    "lua_tovector",
    "lua_toboolean",
    "lua_tolstring",
    "lua_tostringatom",
    "lua_namecallatom",
    "lua_objlen",
    "lua_tocfunction",
    "lua_tolightuserdata",
    "lua_tolightuserdatatagged",
    "lua_touserdata",
    "lua_touserdatatagged",
    "lua_userdatatag",
    "lua_lightuserdatatag",
    "lua_tothread",
    "lua_tobuffer",
    "lua_topointer",
    "lua_pushnil",
    "lua_pushnumber",
    "lua_pushinteger",
    "lua_pushunsigned",
    "lua_pushvector",
    "lua_pushlstring",
    "lua_pushstring",
    "lua_pushvfstring",
    "lua_pushfstringL",
    "lua_pushcclosurek",
    "lua_pushboolean",
    "lua_pushthread",
    "lua_pushlightuserdatatagged",
    "lua_newuserdatatagged",
    "lua_newuserdatataggedwithmetatable",
    "lua_newuserdatadtor",
    "lua_newbuffer",
    "lua_gettable",
    "lua_getfield",
    "lua_rawgetfield",
    "lua_rawget",
    "lua_rawgeti",
    "lua_createtable",
    "lua_setreadonly",
    "lua_getreadonly",
    "lua_setsafeenv",
    "lua_getmetatable",
    "lua_getfenv",
    "lua_settable",
    "lua_setfield",
    "lua_rawsetfield",
    "lua_rawset",
    "lua_rawseti",
    "lua_setmetatable",
    "lua_setfenv",
    "luau_load",
    "lua_call",
    "lua_pcall",
    "lua_yield",
    "lua_break",
    "lua_resume",
    "lua_resumeerror",
    "lua_status",
    "lua_isyieldable",
    "lua_getthreaddata",
    "lua_setthreaddata",
    "lua_costatus",
    "lua_gc",
    "lua_setmemcat",
    "lua_totalbytes",
    "lua_error",
    "lua_next",
    "lua_rawiter",
    "lua_concat",
    "lua_encodepointer",
    "lua_clock",
    "lua_setuserdatatag",
    "lua_setuserdatadtor",
    "lua_getuserdatadtor",
    "lua_setuserdatametatable",
    "lua_getuserdatametatable",
    "lua_setlightuserdataname",
    "lua_getlightuserdataname",
    "lua_clonefunction",
    "lua_cleartable",
    "lua_getallocf",
    "lua_ref",
    "lua_unref",
    "lua_stackdepth",
    "lua_getinfo",
    "lua_getargument",
    "lua_getlocal",
    "lua_setlocal",
    "lua_getupvalue",
    "lua_setupvalue",
    "lua_singlestep",
    "lua_breakpoint",
    "luaL_register",
    "luaL_getmetafield",
    "luaL_callmeta",
    "luaL_typeerrorL",
    "luaL_argerrorL",
    "luaL_checklstring",
    "luaL_optlstring",
    "luaL_checknumber",
    "luaL_optnumber",
    "luaL_checkboolean",
    "luaL_optboolean",
    "luaL_checkinteger",
    "luaL_optinteger",
    "luaL_checkunsigned",
    "luaL_optunsigned",
    "luaL_checkvector",
    "luaL_optvector",
    "luaL_checkstack",
    "luaL_checktype",
    "luaL_checkany",
    "luaL_newmetatable",
    "luaL_checkudata",
    "luaL_checkbuffer",
    "luaL_where",
    "luaL_errorL",
    "luaL_checkoption",
    "luaL_tolstring",
    "luaL_newstate",
    "luaL_findtable",
    "luaL_typename",
    "luaL_buffinit",
    "luaL_buffinitsize",
    "luaL_prepbuffsize",
    "luaL_addlstring",
    "luaL_addvalue",
    "luaL_addvalueany",
    "luaL_pushresult",
    "luaL_pushresultsize",
    "luaopen_base",
    "luaopen_coroutine",
    "luaopen_table",
    "luaopen_os",
    "luaopen_string",
    "luaopen_bit32",
    "luaopen_buffer",
    "luaopen_utf8",
    "luaopen_math",
    "luaopen_debug",
    "luaopen_vector",
    "luaL_openlibs",
    "luaL_sandbox",
    "luaL_sandboxthread",
};
