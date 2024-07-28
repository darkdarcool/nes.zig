const Self = @This();

const std = @import("std");

const Memory = @import("./Memory.zig");

const Allocator = std.mem.Allocator;

/// Different addressing modes for the 6502 CPU
const AddressingMode = enum {
    /// Operand is given explicitly in the instruction
    ///
    /// See https://www.nesdev.org/obelisk-6502-guide/addressing.html#IMM
    immediate,

    /// Operand is a byte located in the first page of memory
    /// (i.e., it has a 16 bit address of which the high byte is zero)
    ///
    /// See https://www.nesdev.org/obelisk-6502-guide/addressing.html#ZPG
    zero_page,

    /// Operand is the result of taking an 8-bit zero page address
    /// and adding the current value of the X register to it
    ///
    /// See https://www.nesdev.org/obelisk-6502-guide/addressing.html#ZPX
    zero_page_x,

    /// Operand is the result of taking an 8-bit zero page address
    /// and adding the current value of the Y register to it
    ///
    /// See https://www.nesdev.org/obelisk-6502-guide/addressing.html#ZPY
    zero_page_y,

    /// Operand is a full 16-bit address
    ///
    /// See https://www.nesdev.org/obelisk-6502-guide/addressing.html#ABS
    absolute,

    /// Operand is the result of adding the X register to a full 16-bit address
    ///
    /// See https://www.nesdev.org/obelisk-6502-guide/addressing.html#ABX
    absolute_x,

    /// Operand is the result of adding the Y register to a full 16-bit address
    ///
    /// See https://www.nesdev.org/obelisk-6502-guide/addressing.html#ABY
    absolute_y,

    /// Operand is a full 16-bit address which is found by taking an 8-bit base,
    /// adding the X register to it, and looing up the 16-bit address stored
    /// at that location
    ///
    /// See https://www.nesdev.org/obelisk-6502-guide/addressing.html#IDX
    indirect_x,

    /// Operand is a full 16-bit address which is found by taking an 8-bit base,
    /// adding the Y register to it, and looing up the 16-bit address stored
    /// at that location
    ///
    /// See https://www.nesdev.org/obelisk-6502-guide/addressing.html#IDY
    indirect_y,

    /// No addressing mode
    none_addressing,
};

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

/// Load a program into memory
pub fn load(self: *Self, program: []u8) void {
    std.mem.copyForwards(u8, &self.mem.memory[0x8000..].*, program);

    // self.program_counter = 0x8000;
    self.mem.write_u16(0xFFFC, 0x8000);
}

/// Reset the CPU
pub fn reset(self: *Self) void {
    self.register_x = 0;
    self.register_y = 0;
    self.register_a = 0;
    self.status = 0;

    self.program_counter = self.mem.read_u16(0xFFFC);
}

/// Calculates the operand address based on the provided addressing mode
///
/// Returns the 16-bit unsigned integer representing the operand address
fn get_operand_address(self: *Self, mode: AddressingMode) u16 {
    return switch (mode) {
        .immediate => self.program_counter,
        .zero_page => @intCast(self.mem.read(self.program_counter)),
        .absolute => self.mem.read_u16(self.program_counter),
        .zero_page_x => {
            const pos = self.mem.read(self.program_counter);
            const addr = @addWithOverflow(pos, self.register_x).@"0";
            return @intCast(addr);
        },
        .zero_page_y => {
            const pos = self.mem.read(self.program_counter);
            const addr = @addWithOverflow(pos, self.register_y).@"0";
            return @intCast(addr);
        },
        .absolute_x => {
            const base = self.mem.read_u16(self.program_counter);
            const addr = @addWithOverflow(base, self.register_x).@"0";
            return @intCast(addr);
        },
        .absolute_y => {
            const base = self.mem.read_u16(self.program_counter);
            const addr = @addWithOverflow(base, self.register_y).@"0";

            return @intCast(addr);
        },
        .indirect_x => {
            const base = self.mem.read(self.program_counter);

            const ptr = @addWithOverflow(base, self.register_x).@"0";
            const lo: u16 = @intCast(self.mem.read(ptr));
            const hi: u16 = @intCast(self.mem.read(@addWithOverflow(ptr, 1).@"0"));

            return (hi << 8) | lo;
        },
        .indirect_y => {
            const base = self.mem.read(self.program_counter);

            const lo: u16 = @intCast(self.mem.read(base));
            const hi: u16 = @intCast(self.mem.read(@addWithOverflow(base, 1).@"0"));

            const deref_base = (hi << 8) | lo;
            const deref = @addWithOverflow(deref_base, self.register_y).@"0";

            return deref;
        },
        .none_addressing => {
            std.debug.panic("Invalid addressing mode\n", .{});
        },
    };
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
fn lda(self: *Self, mode: AddressingMode) void {
    const addr = self.get_operand_address(mode);
    const value = self.mem.read(addr);

    self.register_a = value;
    self.update_status(self.register_a);
}

/// LDX - Load X Register
///
/// [6502 CPU LDX](https://www.nesdev.org/obelisk-6502-guide/reference.html#LDX)
fn ldx(self: *Self, mode: AddressingMode) void {
    const addr = self.get_operand_address(mode);
    const value = self.mem.read(addr);

    self.register_x = value;
    self.update_status(self.register_x);
}

/// STA - Store Accumulator
///
/// [6502 CPU STA](https://www.nesdev.org/obelisk-6502-guide/reference.html#STA)
fn sta(self: *Self, mode: AddressingMode) void {
    const addr = self.get_operand_address(mode);
    self.mem.write(addr, self.register_a);
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

/// Shorthand for executing an instruction with parameters and
/// multiple addressing modes
///
/// (Basically a macro)
inline fn instruction_with_params(self: *Self, handler: *const fn (
    *Self,
    AddressingMode,
) void, addressing_mode: AddressingMode, params: u8) void {
    handler(self, addressing_mode);
    self.program_counter += params;
}

/// Run the program loaded into memory
pub fn run(self: *Self) void {
    // Loop through the program
    while (true) {
        // Get the current instruction
        const opscode = self.mem.read(self.program_counter);
        // Move past the opscode
        self.program_counter += 1;

        switch (opscode) {
            // === INX ===
            0xE8 => self.inx(),

            // === LDA ===
            0xA9 => self.instruction_with_params(Self.lda, AddressingMode.immediate, 1),
            0xA5 => self.instruction_with_params(Self.lda, AddressingMode.zero_page, 1),
            0xB5 => self.instruction_with_params(Self.lda, AddressingMode.zero_page_x, 1),
            0xAD => self.instruction_with_params(Self.lda, AddressingMode.absolute, 2),
            0xBD => self.instruction_with_params(Self.lda, AddressingMode.absolute_x, 2),
            0xB9 => self.instruction_with_params(Self.lda, AddressingMode.absolute_y, 2),
            0xA1 => self.instruction_with_params(Self.lda, AddressingMode.indirect_x, 1),
            0xB1 => self.instruction_with_params(Self.lda, AddressingMode.indirect_y, 1),

            // === LDX ===
            0xA2 => self.instruction_with_params(Self.ldx, AddressingMode.immediate, 1),
            0xA6 => self.instruction_with_params(Self.ldx, AddressingMode.zero_page, 1),
            0xB6 => self.instruction_with_params(Self.ldx, AddressingMode.zero_page_y, 1),
            0xAE => self.instruction_with_params(Self.ldx, AddressingMode.absolute, 2),
            0xBE => self.instruction_with_params(Self.ldx, AddressingMode.absolute_y, 2),

            // === STA ===
            0x85 => self.instruction_with_params(Self.sta, AddressingMode.zero_page, 1),
            0x95 => self.instruction_with_params(Self.sta, AddressingMode.zero_page_x, 1),
            0x8D => self.instruction_with_params(Self.sta, AddressingMode.absolute, 2),
            0x9D => self.instruction_with_params(Self.sta, AddressingMode.absolute_x, 2),
            0x99 => self.instruction_with_params(Self.sta, AddressingMode.absolute_y, 2),
            0x81 => self.instruction_with_params(Self.sta, AddressingMode.indirect_x, 1),
            0x91 => self.instruction_with_params(Self.sta, AddressingMode.indirect_y, 1),

            // === TAX ===
            0xAA => self.tax(),

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

test "0xA9 lda from memory" {
    var cpu = Self.init();
    cpu.mem.write(0x10, 0x55);

    const instructions = &[_]u8{ 0xA5, 0x10, 0x00 };

    cpu.load(@ptrCast(@constCast(instructions)));
    cpu.reset();
    cpu.run();

    try expect(cpu.register_a == 0x55);
}

// === STA (0x85) ===

test "0x85 sta sets memory correctly" {
    var cpu = Self.init();

    const instructions = &[_]u8{ 0xA9, 0x55, 0x85, 0x10, 0x00 };

    cpu.load(@ptrCast(@constCast(instructions)));
    cpu.reset();
    cpu.run();

    try expect(cpu.mem.read(0x10) == 0x55);
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
