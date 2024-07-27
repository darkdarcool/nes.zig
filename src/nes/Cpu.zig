const Self = @This();

const std = @import("std");

const Memory = @import("./Memory.zig");

const Allocator = std.mem.Allocator;

/// STD testing function
///
/// [std.testing.expect](https://ziglang.org/documentation/0.13.0/std/#std.testing.expect)
const expect = std.testing.expect;

/// Value of register A (accumulator)
///
/// [6502 CPU Accumulator](https://www.nesdev.org/wiki/CPU_registers#Accumulator)
register_a: u8 = 0,

/// Value of register X (index)
///
/// [6502 CPU Index](https://www.nesdev.org/wiki/CPU_registers#Indexes)
register_x: u8 = 0,

/// Value of register Y (index)
///
/// [6502 CPU Index](https://www.nesdev.org/wiki/CPU_registers#Indexes)
register_y: u8 = 0,

/// Program counter
///
/// [6502 CPU Program Counter](https://www.nesdev.org/wiki/CPU_registers#Program_Counter)
program_counter: u16 = 0,

/// Value of the status register
///
/// [6502 CPU Status](https://www.nesdev.org/wiki/CPU_registers#Status_Register)
status: u8 = 0,

/// Allocator (heap? never heard of her)
//alloc: Allocator,

/// Memory
mem: Memory,

/// Create a 6502 CPU instance
pub fn init() Self {
    return Self{
        .register_a = 0,
        .register_x = 0,
        .register_y = 0,

        .status = 0,
        .program_counter = 0,

        //.alloc = alloc,
        .mem = Memory.init(undefined),
    };
}

pub fn load(self: *Self, program: []u8) void {
    //         self.memory[0x8000 .. (0x8000 + program.len())].copy_from_slice(&program[..]);
    //var array = self.mem.memory[0x8000..].*;
    std.mem.copyForwards(u8, &self.mem.memory[0x8000..].*, program);

    // self.program_counter = 0x8000;
    self.mem.write_u16(0xFFFC, 0x8000);

    // print value at 0xFFFC
    //std.debug.print("0xFFFC: {d}\n", .{self.mem.read_u16(0xFFFC)});
}

pub fn reset(self: *Self) void {
    self.register_x = 0;
    self.register_y = 0;
    self.register_a = 0;
    self.status = 0;

    self.program_counter = self.mem.read_u16(0xFFFC);
}

/// INX - Increment X Register
///
/// [6502 CPU INX](https://www.nesdev.org/obelisk-6502-guide/reference.html#INX)
fn inx(self: *Self) void {
    // Add 1 to the X register with overflow
    // See [`@addWithOverflow`](https://ziglang.org/documentation/0.13.0/#addWithOverflow)
    self.register_x = @addWithOverflow(self.register_x, 1).@"0";
    self.update_status(self.register_x);
}

/// LDA - Load Accumulator
///
/// [6502 CPU LDA](https://www.nesdev.org/obelisk-6502-guide/reference.html#LDA)
fn lda(self: *Self, value: u8) void {
    self.register_a = value;
    self.update_status(self.register_a);
}

/// TAX - Transfer Accumulator to (Index) X
///
/// [6502 CPU TAX](https://www.nesdev.org/obelisk-6502-guide/reference.html#TAX)
fn tax(self: *Self) void {
    self.register_x = self.register_a;
    self.update_status(self.register_x);
}

/// Shorthand for [`update_zero_and_negative_flags`](#update_zero_and_negative_flags)
fn update_status(self: *Self, value: u8) void {
    self.update_zero_and_negative_flags(value);
}

/// Update the zero and negative flags in the status register
///
/// [6502 CPU Status](https://www.nesdev.org/wiki/Status_flags)
fn update_zero_and_negative_flags(self: *Self, result: u8) void {
    if (result == 0) {
        self.status = self.status | 0b0000_0010;
    } else {
        self.status = self.status & 0b1111_1101;
    }

    if (result & 0b1000_0000 != 0) {
        self.status = self.status | 0b1000_0000;
    } else {
        self.status = self.status & 0b0111_1111;
    }
}

pub fn run(self: *Self) void {
    // Loop through the program
    while (true) {
        const opscode = self.mem.read(self.program_counter); // program[self.program_counter];
        self.program_counter += 1;

        switch (opscode) {
            0xA9 => {
                const param = self.mem.read(self.program_counter); // program[self.program_counter];
                self.program_counter += 1;

                self.lda(param);
            },
            0xAA => self.tax(),
            0xE8 => self.inx(),
            0x00 => {
                return;
            },
            else => {
                std.debug.print("TODO: {d}\n", .{opscode});
                break;
            },
        }
    }
}

// === TESTS ===

// === INX (0xE8) ===
test "5 ops working together" {
    var cpu = Self.init();

    const instructions = &[_]u8{ 0xA9, 0xC0, 0xAA, 0xE8, 0x00 };

    cpu.load(@ptrCast(@constCast(instructions)));
    cpu.reset();
    cpu.run();

    try expect(cpu.register_x == 0xC1);
}

test "0xE8 INX overflow" {
    var cpu = Self.init();
    cpu.register_x = 0xFF;

    const instructions = &[_]u8{ 0xE8, 0xE8, 0x00 };

    cpu.load(@ptrCast(@constCast(instructions)));
    cpu.reset();

    cpu.register_x = 0xFF;

    cpu.run();

    try expect(cpu.register_x == 1);
}

// === LDA (0xA9) ===

test "0xA9 lda immediate load data" {
    var cpu = Self.init();

    const instructions = &[_]u8{ 0xA9, 0x05, 0x00 };

    //cpu.interpret(@ptrCast(@constCast(instructions)));
    cpu.load(@ptrCast(@constCast(instructions)));
    cpu.reset();
    cpu.run();

    try expect(cpu.register_a == 0x05);
    try expect(cpu.status & 0b0000_0010 == 0b00);
    try expect(cpu.status & 0b1000_0000 == 0);
}

test "0xA9 lda zero flag set" {
    var cpu = Self.init();

    const instructions = &[_]u8{ 0xA9, 0x00, 0x00 };

    cpu.load(@ptrCast(@constCast(instructions)));
    cpu.reset();
    cpu.run();

    try expect(cpu.status & 0b0000_0010 == 0b10);
}

// === TAX (0xAA) ===

test "0xAA tax transfer a to x" {
    var cpu = Self.init();
    cpu.register_a = 10;

    const instructions = &[_]u8{ 0xAA, 0x00 };

    cpu.load(@ptrCast(@constCast(instructions)));
    cpu.reset();

    cpu.register_a = 10;

    cpu.run();

    try expect(cpu.register_x == 10);
}
