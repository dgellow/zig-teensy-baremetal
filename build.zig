const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const query = std.Target.Query{
        .cpu_arch = .thumb,
        .cpu_model = .{ .explicit = &std.Target.arm.cpu.cortex_m7 },
        .os_tag = .freestanding,
    };

    const target = b.resolveTargetQuery(query);

    // Teensy compile
    const compile_dep = if (builtin.os.tag == .windows)
        b.dependency("teensy_compile_windows", .{})
    else
        @panic("Unsupported OS");
    var compile_install_dir = if (builtin.os.tag == .windows)
        b.addInstallDirectory(.{
            .source_dir = compile_dep.path(""),
            .install_dir = .bin,
            .install_subdir = "compile",
        })
    else
        b.addInstallDirectory(.{
            .source_dir = compile_dep.path(""),
            .install_dir = .bin,
            .install_subdir = "compile",
        });

    const compile_dir = b.getInstallPath(
        compile_install_dir.options.install_dir,
        compile_install_dir.options.install_subdir,
    );
    const arm_dir = b.pathJoin(&[_][]const u8{ compile_dir, "arm" });
    // const arm_cc_path = b.pathJoin(
    //     &[_][]const u8{ arm_dir, if (builtin.os.tag == .windows) "arm-none-eabi-gcc.exe" else "arm-none-eabi-gcc" },
    // );
    // const arm_cpp_path = b.pathJoin(
    //     &[_][]const u8{ arm_dir, if (builtin.os.tag == .windows) "arm-none-eabi-g++.exe" else "arm-none-eabi-g++" },
    // );
    const arm_objcopy_path = b.pathJoin(
        &[_][]const u8{ arm_dir, "bin", if (builtin.os.tag == .windows) "arm-none-eabi-objcopy.exe" else "arm-none-eabi-objcopy" },
    );

    // Main executable — the actual firmware implementation
    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/_startup.zig"),
        .target = target,
        // Needed to disable compiler runtime, debug info, and others that are causing issues with lld
        .optimize = .ReleaseSmall,
    });

    exe_mod.strip = false;
    exe_mod.addSystemIncludePath(.{ .cwd_relative = b.pathJoin(&[_][]const u8{ arm_dir, "arm-none-eabi", "include" }) });

    const exe = b.addExecutable(.{
        .name = "teensy_zig",
        .root_module = exe_mod,
    });

    exe.setLinkerScript(b.path("linker_script.ld"));
    exe.entry = .{ .symbol_name = "__ivt_start" };
    exe.step.dependOn(&compile_install_dir.step);

    b.installArtifact(exe);

    // Compile to IHEX format
    const objcopy_run = b.addSystemCommand(&[_][]const u8{arm_objcopy_path});
    objcopy_run.addArgs(&[_][]const u8{ "--output-target", "ihex", "--remove-section", ".eeprom" });
    objcopy_run.addFileArg(exe.getEmittedBin());
    _ = objcopy_run.addArg(b.getInstallPath(.bin, "teensy_zig.hex"));

    var hex_step = b.step("hex", "Compile firmware to hex file");
    hex_step.dependOn(b.getInstallStep());
    hex_step.dependOn(&compile_install_dir.step);
    hex_step.dependOn(&objcopy_run.step);

    // Teensy tools
    var tools_step = b.step("tools", "Install teensy tools");
    const tools_dep = if (builtin.os.tag == .windows)
        b.dependency("teensy_tools_windows", .{})
    else
        @panic("Unsupported OS");
    var tools_install_dir = if (builtin.os.tag == .windows)
        b.addInstallDirectory(.{
            .source_dir = tools_dep.path(""),
            .install_dir = .bin,
            .install_subdir = "tools",
            .include_extensions = &[_][]const u8{ "exe", "bat" },
        })
    else
        b.addInstallDirectory(.{
            .source_dir = tools_dep.path(""),
            .install_dir = .bin,
            .install_subdir = "tools",
        });

    tools_step.dependOn(&tools_install_dir.step);
    b.getInstallStep().dependOn(tools_step);

    // Port command
    const port_step = b.step("port", "Get teensy port");
    port_step.dependOn(tools_step);

    const tools_dir = b.getInstallPath(
        tools_install_dir.options.install_dir,
        tools_install_dir.options.install_subdir,
    );
    const teensy_ports_path = b.pathJoin(
        &[_][]const u8{
            tools_dir,
            if (builtin.os.tag == .windows) "teensy_ports.exe" else "teensy_ports",
        },
    );

    const port_run = b.addSystemCommand(&[_][]const u8{teensy_ports_path});
    port_run.addArg("-L");
    port_step.dependOn(&port_run.step);

    // Upload command
    const teensy_post_compile_path = b.pathJoin(
        &[_][]const u8{
            tools_dir,
            if (builtin.os.tag == .windows) "teensy_post_compile.exe" else "teensy_post_compile",
        },
    );

    const upload_run = b.addSystemCommand(&[_][]const u8{teensy_post_compile_path});
    const upload_reboot_option = b.option(bool, "upload-reboot", "Reboot Teensy after upload. Default to true") orelse true;
    if (upload_reboot_option) {
        upload_run.addArg("-reboot");
    }
    upload_run.addArg(b.fmt("-path={s}", .{b.getInstallPath(.bin, "")}));
    upload_run.addArg("-file=teensy_zig");
    upload_run.addArg(b.fmt("-tools={s}", .{tools_dir}));
    upload_run.addArg("-v");

    const upload_step = b.step("upload", "Upload firmware to Teensy board");
    upload_step.dependOn(&upload_run.step);
    upload_step.dependOn(tools_step);
    upload_step.dependOn(hex_step);

    const upload_port_option = b.option([]const u8, "upload-port", "USB port to upload to");
    if (upload_port_option) |port| {
        upload_run.addArg(b.fmt("-port={s}", .{port}));
    }

    // Teensyduino library
    // Note: macros and compiler flags based on deps/teensyduino-lib/teensy4/Makefile
    exe_mod.addCMacro("__IMXRT1062__", "1");
    exe_mod.addCMacro("ARDUINO_TEENSY41", "1");
    exe_mod.addCMacro("ARDUINO", "10813");
    exe_mod.addCMacro("TEENSYDUINO", "159");
    exe_mod.addCMacro("USB_SERIAL", "1");
    exe_mod.addCMacro("LAYOUT_US_ENGLISH", "1");
    exe_mod.addCMacro("NO_ARDUINO", "1");

    exe_mod.addIncludePath(b.path("deps/teensyduino-lib/teensy4"));

    const c_sources = [_][]const u8{
        "deps/teensyduino-lib/teensy4/keylayouts.c",
        "deps/teensyduino-lib/teensy4/usb_desc.c",
        "deps/teensyduino-lib/teensy4/usb_serial.c",
        "deps/teensyduino-lib/teensy4/usb.c",
    };
    exe.addCSourceFiles(.{
        .files = &c_sources,
        .flags = &[_][]const u8{
            "-std=gnu11",
            "-ffunction-sections",
            "-fdata-sections",
            // CPU options
            "-mcpu=cortex-m7",
            "-mfloat-abi=hard",
            "-mfpu=fpv5-d16",
            "-mthumb",
        },
        .language = .c,
    });
}
