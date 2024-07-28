const std = @import("std");

const Allocator = std.mem.Allocator;
const GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator;

const nes = @import("./nes/nes.zig");

pub fn main() !void {
    var cpu = nes.Cpu.init();

    const instructions = &[_]u8{ 0xA9, 0x55, 0x00 };

    cpu.load(@ptrCast(@constCast(instructions)));
    cpu.reset();
    cpu.run();

    std.debug.print("Register a: {d}\n", .{cpu.register_a});

    // loop over memory, print every value and its index when value is not 0
    //var i: c_int = 0;
    //for (cpu.mem.memory) |value| {
    //    if (value != 0) {
    //        std.debug.print("Memory[{d}] = {d}\n", .{ i, value });
    //    }
    //    i += 1;
    //}
}

test {
    _ = nes;
}
