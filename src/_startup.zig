const chip = @import("imxrt1062.zig");
const peripherals = chip.devices.MIMXRT1062.peripherals;

const main = @import("main.zig").main;

extern var _flexram_bank_config: u32;
extern var _estack: u32;

extern var _stext: u32;
extern var _stextload: u32;
extern var _etext: u32;

extern var _sdata: u32;
extern var _sdataload: u32;
extern var _edata: u32;

extern var _sbss: u32;
extern var _ebss: u32;

pub export fn startup() linksection(".startup") callconv(.C) void {
    // Configure FlexRAM - essential for i.MX RT1062
    peripherals.IOMUXC_GPR.GPR17.raw = @intCast(@intFromPtr(&_flexram_bank_config));
    peripherals.IOMUXC_GPR.GPR16.raw = 0x00000007;
    peripherals.IOMUXC_GPR.GPR14.raw = 0x00AA0000;

    // Set up stack pointer - must happen early!
    asm volatile ("mov sp, %[arg1]"
        : // no output
        : [arg1] "{r0}" (@intFromPtr(&_estack)),
    );

    // Now we can use normal function calls with C calling convention
    _startup_memcpy(&_stext, &_stextload, &_etext);
    _startup_memcpy(&_sdata, &_sdataload, &_edata);
    _startup_memclr(&_sbss, &_ebss);

    // Call our main function
    main();

    // In case main returns (which it shouldn't)
    while (true) {}
}

fn _startup_memcpy(dst: *u32, src: *u32, dstEnd: *u32) linksection(".startup") void {
    if (dst == src) return;

    const len = @intFromPtr(dstEnd) - @intFromPtr(dst);
    const srcMany: [*]u32 = @ptrCast(src);
    const dstSlice = @as([*]u32, @ptrCast(dst))[0..len];
    for (dstSlice, 0..) |*data, i| {
        data.* = srcMany[i];
    }
}

fn _startup_memclr(dst: *u32, dstEnd: *u32) linksection(".startup") void {
    for (@as([*]u32, @ptrCast(dst))[0..(@intFromPtr(dstEnd) - @intFromPtr(dst))]) |*data| {
        data.* = 0;
    }
}
