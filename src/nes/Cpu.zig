const Self = @This();

const std = @import("std");

const expect = std.testing.expect;

register_a: u8 = 0,
// register_b: u8 = 0;
status: u8 = 0,
program_counter: u8 = 0,

pub fn init() Self {
    return Self{
        .register_a = 0,
        // .register_b = 0,
        .status = 0,
        .program_counter = 0,
    };
}

pub fn interpret(self: *Self, program: []u8) void {
    self.program_counter = 0;

    while (true) {
        const opscode = program[self.program_counter];
        self.program_counter += 1;

        switch (opscode) {
            0xA9 => {
                const param = program[self.program_counter];
                self.program_counter += 1;
                self.register_a = param;

                if (self.register_a == 0) {
                    self.status = self.status | 0b0000_0010;
                } else {
                    self.status = self.status | 0b1111_1101;
                }

                if (self.register_a & 0b1000_0000 != 0) {
                    self.status = self.status | 0b1000_0000;
                } else {
                    self.status = self.status & 0b0111_1111;
                }
            },
            0x00 => {
                return;
            },
            else => {
                std.debug.print("TODO\n", .{});
                break;
            },
        }
    }
}

test "0xA9 lda immediate load data" {
    var cpu = Self.init();

    const instructions = &[_]u8{ 0xA9, 0x05, 0x00 };

    cpu.interpret(@ptrCast(@constCast(instructions)));

    try expect(cpu.register_a == 0x05);
    try expect(cpu.status & 0b0000_0010 == 0b00);
    try expect(cpu.status & 0b1000_0000 == 0);
}
