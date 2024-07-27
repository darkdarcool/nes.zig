const Self = @This();

const std = @import("std");

memory: [0xFFFF]u8 = undefined,

/// Create a memory instance
pub fn init(memory: [0xFFFF]u8) Self {
    return Self{
        .memory = memory,
    };
}

/// Read a byte from memory
pub fn read(self: *Self, address: u16) u8 {
    return self.memory[address];
}

/// Read a u16 from memory
pub fn read_u16(self: *Self, address: u16) u16 {
    const lo: c_uint = @intCast(self.read(address));
    const hi: c_uint = @intCast(self.read(address + 1));

    const res = (hi << 8) | lo;

    return @intCast(res);
}

/// Write a byte to memory
pub fn write(self: *Self, address: u16, value: u8) void {
    self.memory[address] = value;
}

/// Write a u16 to memory
pub fn write_u16(self: *Self, address: u16, value: u16) void {
    const hi = (value >> 8); // orelse unreachable;
    const lo = (value & 0xff); // orelse unreachable;

    const hi_u16: u8 = @intCast(hi);
    const lo_u16: u8 = @intCast(lo);

    self.write(address, lo_u16);
    self.write(address + 1, hi_u16);
}
