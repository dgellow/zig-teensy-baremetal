const std = @import("std");
const chip = @import("imxrt1062.zig");
const peripherals = chip.devices.MIMXRT1062.peripherals;
const main = @import("main.zig").main;
const c = @cImport({
    @cInclude("avr_functions.h");
});

// Convert unsigned long to ASCII string in given base (radix)
export fn ultoa(val: c_ulong, buf: [*c]u8, radix: c_int) [*c]u8 {
    var value = val;
    var i: usize = 0;

    // Convert to the specified base
    while (true) {
        const digit = @as(u8, @intCast(value % @as(c_ulong, @intCast(radix))));
        buf[i] = if (digit < 10) '0' + digit else 'A' + (digit - 10);
        value /= @as(c_ulong, @intCast(radix));
        if (value == 0) break;
        i += 1;
    }

    // Null terminate
    buf[i + 1] = 0;

    // Reverse the string in-place
    var j: usize = 0;
    while (j < i) : ({
        j += 1;
        i -= 1;
    }) {
        const t = buf[j];
        buf[j] = buf[i];
        buf[i] = t;
    }

    return buf;
}

// Convert long to ASCII string in given base (radix)
export fn ltoa(val: c_long, buf: [*c]u8, radix: c_int) [*c]u8 {
    if (val >= 0) {
        return ultoa(@as(c_ulong, @intCast(val)), buf, radix);
    } else {
        buf[0] = '-';
        _ = ultoa(@as(c_ulong, @intCast(-val)), buf + 1, radix);
        return buf;
    }
}

// Convert unsigned long long to ASCII string in given base (radix)
export fn ulltoa(val: c_ulonglong, buf: [*c]u8, radix: c_int) [*c]u8 {
    var value = val;
    var i: usize = 0;

    // Convert to the specified base
    while (true) {
        const digit = @as(u8, @intCast(value % @as(c_ulonglong, @intCast(radix))));
        buf[i] = if (digit < 10) '0' + digit else 'A' + (digit - 10);
        value /= @as(c_ulonglong, @intCast(radix));
        if (value == 0) break;
        i += 1;
    }

    // Null terminate
    buf[i + 1] = 0;

    // Reverse the string in-place
    var j: usize = 0;
    while (j < i) : ({
        j += 1;
        i -= 1;
    }) {
        const t = buf[j];
        buf[j] = buf[i];
        buf[i] = t;
    }

    return buf;
}

// Convert long long to ASCII string in given base (radix)
export fn lltoa(val: c_longlong, buf: [*c]u8, radix: c_int) [*c]u8 {
    if (val >= 0) {
        return ulltoa(@as(c_ulonglong, @intCast(val)), buf, radix);
    } else {
        buf[0] = '-';
        _ = ulltoa(@as(c_ulonglong, @intCast(-val)), buf + 1, radix);
        return buf;
    }
}

// Implement standard C library functions needed by nonstd.c

// Integer absolute value
export fn abs(x: c_int) c_int {
    return if (x < 0) -x else x;
}

// String length
export fn strlen(s: [*c]const u8) usize {
    var count: usize = 0;
    while (s[count] != 0) {
        count += 1;
    }
    return count;
}

// Check if float is NaN
export fn isnanf(x: f32) c_int {
    return if (std.math.isNan(x)) 1 else 0;
}

// Check if float is infinite
export fn isinff(x: f32) c_int {
    return if (std.math.isInf(x)) 1 else 0;
}

// Static buffer for fcvtf - must persist after function returns
var fcvtf_buffer: [128]u8 = undefined;

export fn fcvtf(value: f32, digits: c_int, decpt: [*c]c_int, sign: [*c]c_int) [*c]u8 {
    _ = value;
    _ = digits;

    // Set default values for decpt and sign
    if (decpt != null) decpt.* = 0;
    if (sign != null) sign.* = 0;

    // Initialize with "0" and null terminator
    fcvtf_buffer[0] = '0';
    fcvtf_buffer[1] = 0;

    // Return our static buffer
    return &fcvtf_buffer;
}

// Convert float to string with specified precision
export fn dtostrf(value: f32, width: c_int, precision: c_uint, buf: [*c]u8) [*c]u8 {
    // Handle special cases: NaN
    if (std.math.isNan(value)) {
        var pos: usize = 0;
        const is_negative = std.math.signbit(value);
        const nan_text = "NAN";

        // Calculate padding
        var text_width: c_int = 3; // "NAN"
        if (is_negative) text_width += 1; // "-NAN"

        var padding: c_int = 0;
        if (width > text_width) padding = width - text_width;

        // Add padding before if right-aligned
        if (width > 0) {
            var i: c_int = 0;
            while (i < padding) : (i += 1) {
                buf[pos] = ' ';
                pos += 1;
            }
        }

        // Add sign if negative
        if (is_negative) {
            buf[pos] = '-';
            pos += 1;
        }

        // Add NAN text
        for (nan_text) |char| {
            buf[pos] = char;
            pos += 1;
        }

        // Add padding after if left-aligned
        if (width < 0) {
            var i: c_int = 0;
            while (i < padding) : (i += 1) {
                buf[pos] = ' ';
                pos += 1;
            }
        }

        // Null terminate
        buf[pos] = 0;
        return buf;
    }

    // Handle special cases: Infinity
    if (std.math.isInf(value)) {
        var pos: usize = 0;
        const is_negative = value < 0;
        const inf_text = "INF";

        // Calculate padding
        var text_width: c_int = 3; // "INF"
        if (is_negative) text_width += 1; // "-INF"

        var padding: c_int = 0;
        if (width > text_width) padding = width - text_width;

        // Add padding before if right-aligned
        if (width > 0) {
            var i: c_int = 0;
            while (i < padding) : (i += 1) {
                buf[pos] = ' ';
                pos += 1;
            }
        }

        // Add sign if negative
        if (is_negative) {
            buf[pos] = '-';
            pos += 1;
        }

        // Add INF text
        for (inf_text) |char| {
            buf[pos] = char;
            pos += 1;
        }

        // Add padding after if left-aligned
        if (width < 0) {
            var i: c_int = 0;
            while (i < padding) : (i += 1) {
                buf[pos] = ' ';
                pos += 1;
            }
        }

        // Null terminate
        buf[pos] = 0;
        return buf;
    }

    // Regular case: normal float
    var pos: usize = 0;
    const is_negative = value < 0;
    const abs_value = if (is_negative) -value else value;

    // Determine number of digits before decimal point
    var int_part_width: usize = 1; // At least one digit
    const int_part = @as(c_ulong, @intFromFloat(abs_value));
    var tmp = int_part;
    while (tmp >= 10) : (tmp /= 10) {
        int_part_width += 1;
    }

    // Calculate total content width: [sign] + int_part + '.' + precision
    var content_width: usize = int_part_width; // Start with integer part width

    // Add sign width if negative
    if (is_negative) {
        content_width += 1;
    }

    // Add decimal point and precision if precision > 0
    if (precision > 0) {
        content_width += 1; // For decimal point
        content_width += precision;
    }

    // Calculate padding
    var padding: c_int = 0;
    const abs_width = if (width < 0) -width else width;
    if (@as(c_int, @intCast(content_width)) < abs_width) {
        padding = abs_width - @as(c_int, @intCast(content_width));
    }

    // Add padding before if right-aligned
    if (width > 0) {
        var i: c_int = 0;
        while (i < padding) : (i += 1) {
            buf[pos] = ' ';
            pos += 1;
        }
    }

    // Add sign if negative
    if (is_negative) {
        buf[pos] = '-';
        pos += 1;
    }

    // Add integer part
    var int_buffer: [32]u8 = undefined;
    const num_buf = ultoa(int_part, &int_buffer, 10);
    var int_str_index: usize = 0;
    while (num_buf[int_str_index] != 0) : (int_str_index += 1) {
        buf[pos] = num_buf[int_str_index];
        pos += 1;
    }

    // Add decimal point and fractional part if precision > 0
    if (precision > 0) {
        buf[pos] = '.';
        pos += 1;

        // Calculate fractional part
        var frac_value = abs_value - @as(f32, @floatFromInt(int_part));
        var p: c_uint = 0;
        while (p < precision) : (p += 1) {
            frac_value *= 10;
            const digit = @as(u8, @intFromFloat(frac_value));
            buf[pos] = '0' + digit;
            pos += 1;
            frac_value -= @as(f32, @floatFromInt(digit));
        }
    }

    // Add padding after if left-aligned
    if (width < 0) {
        var i: c_int = 0;
        while (i < padding) : (i += 1) {
            buf[pos] = ' ';
            pos += 1;
        }
    }

    // Null terminate
    buf[pos] = 0;
    return buf;
}

// Add this near the top of your file
// comptime {
//     asm (
//         \\.section .ARM.exidx,"a",%progbits
//         \\.align 4
//         \\__exidx_start:
//         \\.long 0xFFFFFFFF
//         \\.long 0x1
//         \\__exidx_end:
//     );
// }
// In _startup.zig
// comptime {
// asm (
// \\.section .ARM.exidx,"a"
// );
// }

pub export var __exidx_start: [1]u32 align(4) linksection(".ARM.exidx.ram") = [_]u32{0xFFFFFFFF};
pub export var __exidx_end: [1]u32 align(4) linksection(".ARM.exidx.ram") = [_]u32{0x1};

// Flash configuration block - required by Teensy bootloader
comptime {
    asm (
        \\.section .flashconfig,"a"
        \\.long 0xFFFFFFFF
        \\.long 0xFFFFFFFF
        \\.long 0xFFFFFFFF
        \\.long 0xFFFFFFFF
    );
}

// IVT and bootdata structures - define as RAM variables we'll set up at runtime
pub export var __ivt: [8]u32 linksection(".ivt") = [_]u32{0} ** 8;
pub export var __bootdata: [3]u32 linksection(".bootdata") = [_]u32{0} ** 3;

// Number of interrupts for Teensy 4.1
const NVIC_NUM_INTERRUPTS = 160;

// Default interrupt handler
export fn unused_interrupt_vector() callconv(.C) void {
    while (true) {} // Trap
}

// Vector table declaration
pub export var _VectorsRam: [NVIC_NUM_INTERRUPTS + 16]?*const fn () callconv(.C) void = undefined;

// External variables from linker script
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

// Main entry point - must match linker script ENTRY(ImageVectorTable)
pub export fn ImageVectorTable() linksection(".flashmem") callconv(.C) void {
    // Set up IVT structure at runtime
    __ivt[0] = 0x402000D1; // Header
    __ivt[1] = @intFromPtr(&ImageVectorTable); // Entry function pointer
    __ivt[2] = 0; // Reserved
    __ivt[3] = 0; // Reserved
    __ivt[4] = @intFromPtr(&__bootdata); // Boot data pointer
    __ivt[5] = @intFromPtr(&__ivt); // Self reference
    __ivt[6] = 0; // CSF pointer
    __ivt[7] = 0; // Reserved

    // Set up boot data
    __bootdata[0] = 0x60000000; // FLASH base address
    __bootdata[1] = 0; // FLASH size - filled at runtime
    __bootdata[2] = 0; // Plugin flag

    // Configure FlexRAM - essential for i.MX RT1062
    peripherals.IOMUXC_GPR.GPR17.raw = @intCast(@intFromPtr(&_flexram_bank_config));
    peripherals.IOMUXC_GPR.GPR16.raw = 0x00000007;
    peripherals.IOMUXC_GPR.GPR14.raw = 0x00AA0000;

    // Set up stack pointer - must happen early!
    asm volatile ("mov sp, %[arg1]"
        :
        : [arg1] "{r0}" (@intFromPtr(&_estack)),
    );

    // Initialize memory
    _startup_memcpy(&_stext, &_stextload, &_etext);
    _startup_memcpy(&_sdata, &_sdataload, &_edata);
    _startup_memclr(&_sbss, &_ebss);

    // Initialize vector table
    for (&_VectorsRam) |*vector| {
        vector.* = unused_interrupt_vector;
    }

    // Enable FPU
    peripherals.SystemControl.CPACR.modify(.{
        .CP10 = .CP10_3, // Full access to FPU
        .CP11 = .CP11_3, // Full access to FPU
    });

    // Set up vector table address
    peripherals.SystemControl.VTOR.modify(.{
        .TBLOFF = @as(u25, @truncate(@intFromPtr(&_VectorsRam) >> 7)),
    });

    // Enable exception handling
    peripherals.SystemControl.SHCSR.modify(.{
        .MEMFAULTENA = .MEMFAULTENA_1, // Enable MemManage exception
        .BUSFAULTENA = .BUSFAULTENA_1, // Enable BusFault exception
        .USGFAULTENA = .USGFAULTENA_1, // Enable UsageFault exception
    });

    // USB yield support
    yield_active_check_flags = 0;

    // Call main function
    main();

    // In case main returns (which it shouldn't)
    while (true) {}
}

// Memory copy function
fn _startup_memcpy(dst: *u32, src: *u32, dstEnd: *u32) linksection(".flashmem") void {
    if (dst == src) return;

    const len = (@intFromPtr(dstEnd) - @intFromPtr(dst)) / 4;
    const srcMany: [*]u32 = @ptrCast(src);
    const dstSlice = @as([*]u32, @ptrCast(dst))[0..len];
    for (dstSlice, 0..) |*data, i| {
        data.* = srcMany[i];
    }
}

// Memory clear function
fn _startup_memclr(dst: *u32, dstEnd: *u32) linksection(".flashmem") void {
    const len = (@intFromPtr(dstEnd) - @intFromPtr(dst)) / 4;
    for (@as([*]u32, @ptrCast(dst))[0..len]) |*data| {
        data.* = 0;
    }
}

// Export yield_active_check_flags for USB to use
pub export var yield_active_check_flags: u8 = 0;

// Export yield function for USB to call
export fn yield() void {
    // Minimal implementation
}
