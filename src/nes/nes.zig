pub const Cpu = @import("./Cpu.zig");

test {
    @import("std").testing.refAllDecls(@This());
}
