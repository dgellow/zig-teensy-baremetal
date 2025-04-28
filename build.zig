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
}
