// Source: https://github.com/ZigEmbeddedGroup/microzig/blob/bb6bcd010052d5e128fb3a592229615444647fd3/core/src/interrupt.zig#L61-L74

// defined for regz
pub const Handler = extern union {
    naked: *const fn () callconv(.naked) void,
    c: *const fn () callconv(.c) void,
};

// defined for regz
pub const unhandled: Handler = .{
    .c = struct {
        pub fn unhandled() callconv(.c) void {
            @panic("unhandled interrupt");
        }
    }.unhandled,
};
