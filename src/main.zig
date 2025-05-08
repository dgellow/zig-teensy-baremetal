const chip = @import("imxrt1062.zig");
const peripherals = chip.devices.MIMXRT1062.peripherals;

const c = @cImport({
    @cInclude("usb_serial.h");
});

pub export fn main() void {
    // c.usb_serial_configure();
    // busyDelay(100_000_000);

    // _ = c.usb_serial_write("Hello from Teensy 4.1!\n", 24);
    // _ = c.usb_serial_write_buffer_free();

    // Configure B0_03 (PIN #13) for output
    peripherals.IOMUXC.SW_MUX_CTL_PAD_GPIO_B0_03.modify(.{
        .MUX_MODE = .ALT5, // set to GPIO
        .SION = .DISABLED, // disable input
    });

    // Configure pad control settings
    peripherals.IOMUXC.SW_PAD_CTL_PAD_GPIO_B0_03.raw = (7 & 0x07) << 3;

    // Configure general purpose register
    peripherals.IOMUXC_GPR.GPR27.raw = 0xFFFFFFFF;

    // Set GPIO direction to output
    peripherals.GPIO7.GDIR.raw |= (1 << 3);

    // SOS LED signal
    while (true) {
        // Short signals (...)
        for (0..3) |_| {
            peripherals.GPIO7.DR_SET.raw = (1 << 3);
            busyDelay(20_000_000);
            peripherals.GPIO7.DR_CLEAR.raw = (1 << 3);
            busyDelay(20_000_000);
        }

        busyDelay(20_000_000);

        // Long signals (---)
        for (0..3) |_| {
            peripherals.GPIO7.DR_SET.raw = (1 << 3);
            busyDelay(60_000_000);
            peripherals.GPIO7.DR_CLEAR.raw = (1 << 3);
            busyDelay(20_000_000);
        }

        busyDelay(20_000_000);

        // Short signals (...)
        for (0..3) |_| {
            peripherals.GPIO7.DR_SET.raw = (1 << 3);
            busyDelay(20_000_000);
            peripherals.GPIO7.DR_CLEAR.raw = (1 << 3);
            busyDelay(20_000_000);
        }

        busyDelay(100_000_000);
    }
}

inline fn busyDelay(count: u32) void {
    var i: u32 = 0;
    while (i < count) : (i += 1) {
        asm volatile (""
            :
            : [val] "rm" (i),
            : "memory"
        );
    }
}
