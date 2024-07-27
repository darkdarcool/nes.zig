const std = @import("std");

const nes = @import("./nes/nes.zig");

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    const cpu = nes.Cpu.init();
    std.debug.print("Register a: {d}", .{cpu.register_a});
}

test {
    @import("std").testing.refAllDecls(@This());
}
