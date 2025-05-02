const std = @import("std");

pub fn build(b: *std.Build) void {
    const query = std.Target.Query{
        .cpu_arch = .thumb,
        .cpu_model = .{ .explicit = &std.Target.arm.cpu.cortex_m7 },
        .os_tag = .freestanding,
    };

    const target = b.resolveTargetQuery(query);

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/_startup.zig"),
        .target = target,
        // Needed to disable compiler runtime, debug info, and others that are causing issues with lld
        .optimize = .ReleaseSmall,
    });

    exe_mod.strip = false;

    const exe = b.addExecutable(.{
        .name = "teensy_zig",
        .root_module = exe_mod,
    });

    exe.setLinkerScript(b.path("linker_script.ld"));
    exe.entry = .{ .symbol_name = "__ivt_start" };

    b.installArtifact(exe);

    // Teensyduino library
    // Note: macros and compiler flags based on deps/teensyduino-lib/teensy4/Makefile
    exe_mod.addCMacro("__IMXRT1062__", "1");
    exe_mod.addCMacro("ARDUINO_TEENSY41", "1");
    exe_mod.addCMacro("ARDUINO", "10813");
    exe_mod.addCMacro("TEENSYDUINO", "159");
    exe_mod.addCMacro("USB_SERIAL", "1");
    exe_mod.addCMacro("LAYOUT_US_ENGLISH", "1");

    exe_mod.addIncludePath(b.path("deps/teensyduino-lib/teensy4"));

    const c_sources = [_][]const u8{
        "deps/teensyduino-lib/teensy4/keylayouts.c",
        "deps/teensyduino-lib/teensy4/usb_desc.c",
        "deps/teensyduino-lib/teensy4/usb_serial.c",
        "deps/teensyduino-lib/teensy4/usb.c",
    };
    exe.addCSourceFiles(.{
        .files = &c_sources,
        .flags = &[_][]const u8{ "-std=gnu11", "-ffunction-sections", "-fdata-sections" },
        .language = .c,
    });
}
