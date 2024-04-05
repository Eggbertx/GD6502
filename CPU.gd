extends Node

class_name CPU

signal status_changed
signal cpu_reset
signal rom_loaded
signal rom_unloaded
signal watched_memory_changed(location:int, new_val:int)
signal stack_filled
signal stack_emptied

# status register bits
enum flag_bit {
	CARRY = 1,
	ZERO = 2,
	INTERRUPT = 4,
	BCD = 8,
	BREAK = 16,
	# no flag in 6th bit
	OVERFLOW = 64,
	NEGATIVE = 128
}

enum status {
	STOPPED, RUNNING, PAUSED, END
}

const RAM_END := 0x05FF # TODO: make this configurable somehow
const PC_START := 0x0600 # TODO: make this configurable somehow

# registers
var A := 0
var X := 0
var Y := 0
var PC := PC_START
var SP := 0xFF
var _status := status.STOPPED
var memory := PackedByteArray()
var memory_size := 0
var _init_ram_size := 0
var opcode := 0
var flags := 0
var logger: Node
var watched_ranges := [] # each element: [start,end]

func _init(memsize = RAM_END):
	memory_size = memsize
	_init_ram_size = memsize
	memory.resize(memory_size)

func _ready():
	reset()
	logger = null

func get_status() -> status:
	return _status

func get_flag_state(flag: flag_bit) -> bool:
	return (flags & flag) == flag

func set_flag(flag: flag_bit, state: bool):
	if state:
		flags |= flag
	else:
		flags &= (~flag)

func set_status(new_status: status, no_reset = false):
	if new_status == status.STOPPED and !no_reset:
		reset()
	if _status == new_status:
		return
	var old = _status
	_status = new_status
	status_changed.emit(_status, old)

func load_rom(bytes:PackedByteArray):
	memory.resize(PC_START + bytes.size())
	memory_size = memory.size()
	for b in range(bytes.size()):
		memory[PC_START + b] = bytes.decode_u8(b)
	rom_loaded.emit(bytes.size())

func unload_rom():
	memory_size = _init_ram_size if _init_ram_size > PC_START else PC_START
	memory.resize(_init_ram_size)
	memory_size = _init_ram_size
	for b in range(memory_size - PC_START):
		memory[PC_START + b] = 0
	rom_unloaded.emit()

func set_logger(newlogger):
	logger = newlogger

func reset(reset_status:status = _status):
	A = 0
	X = 0
	Y = 0
	PC = PC_START
	SP = 0xFF
	flags = 0
	set_status(reset_status, true)
	cpu_reset.emit()
	var reset_range = PC_START if PC_START < memory_size else memory_size
	for i in range(reset_range):
		memory[i] = 0

# basic memory operations
func pop_byte() -> int:
	if PC >= memory.size():
		return 0
	var popped = memory[PC] & 0xFF
	PC += 1
	return popped

func push_byte(byte:int):
	if PC < memory.size():
		memory[PC] = byte & 0xFF
		PC += 1

func pop_word() -> int:
	return pop_byte() + (pop_byte() << 8)

func push_word(byte:int):
	push_byte(byte & 0xFF)
	push_byte((byte >> 8) & 0xFF)

func get_byte(addr:int) -> int:
	if addr >= memory_size:
		return 0
	elif addr == 0xfe:
		return randi_range(0, 255)
	return memory[addr]

func get_word(pos:int) -> int:
	return memory[pos&0xFF] | (memory[(pos+1)&0xFF] << 8)

func set_byte(addr:int, value:int):
	if addr >= memory_size:
		return
	memory[addr] = value & 0xFF
	for watched in watched_ranges:
		if addr >= watched[0] and addr <= watched[1]:
			watched_memory_changed.emit(addr, value)

func push_stack(val: int):
	set_byte(0x100 + (SP & 0xFF), val & 0xFF)
	SP -= 1
	if SP < 0:
		stack_filled.emit()
		SP &= 0xFF

func push_stack_addr(addr: int):
	push_stack((addr & 0xFF00) >> 8)
	push_stack(addr & 0xFF)

func pop_stack() -> int:
	SP += 1
	if SP > 0xFF:
		stack_emptied.emit()
		SP &= 0xFF
	return get_byte(0x100 + SP)

func pop_stack_addr() -> int:
	return (pop_stack() | (pop_stack() << 8)) + 1

func _update_zero(register: int):
	set_flag(flag_bit.ZERO, register == 0)

func _update_negative(register: int):
	set_flag(flag_bit.NEGATIVE, (register & 0x80) > 0)

func _update_carry_from_bit_0(val: int):
	set_flag(flag_bit.CARRY, (val & 1) == 0)

func execute(force = false, new_PC = -1):
	if _status != status.RUNNING and !force:
		return
	if new_PC > -1:
		PC = new_PC

	if PC >= memory.size():
		set_status(status.END)
		return

	opcode = pop_byte()
	match opcode:
		0x00: # BRK, implied
			set_status(status.STOPPED, true)
			set_flag(flag_bit.BREAK, true)
		0x01:
			assert(false, "Not implemented: ORA zero page, x")
		0x05: # ORA, zero page
			var zp := pop_byte()
			A |= memory[zp]
			_update_negative(A)
			_update_zero(A)
		0x06:
			assert(false, "Not implemented: ASL zero page")
		0x08:
			assert(false, "Not implemented: PHP implied")
		0x09: # ORA, immediate
			var num := pop_byte()
			A |= num
			_update_negative(A)
			_update_zero(A)
		0x0A:
			assert(false, "Not implemented: ASL accumulator")
		0x0D: # ORA, absolute
			A |= memory[pop_word()]
			_update_negative(A)
			_update_zero(A)
		0x0E:
			assert(false, "Opcode $0E not implemented yet")
		0x10:
			assert(false, "Opcode $10 not implemented yet")
		0x11:
			assert(false, "Opcode $11 not implemented yet")
		0x15: # ORA, zero page, x
			var zp := (pop_byte() + X) % 0xFF
			A |= memory[zp]
			_update_negative(A)
			_update_zero(A)
		0x16:
			assert(false, "Opcode not implemented yet")
		0x18: # CLC, implied
			set_flag(flag_bit.CARRY, false)
		0x19:
			assert(false, "Opcode $19 not implemented yet")
		0x1D:
			assert(false, "Opcode $1D not implemented yet")
		0x1E:
			assert(false, "Opcode $1E not implemented yet")
		0x20: # JSR, absolute
			push_stack_addr(PC+1)
			PC = pop_word()
		0x21:
			assert(false, "Opcode not implemented yet")
		0x24:
			assert(false, "Opcode not implemented yet")
		0x25: # AND, zero page
			var num := memory[pop_byte()]
			A &= num
			_update_negative(A)
			_update_zero(A)
		0x26:
			assert(false, "Opcode $26 not implemented yet")
		0x28:
			assert(false, "Opcode $28 not implemented yet")
		0x29: # AND, immediate
			var imm := pop_byte()
			A &= imm
			_update_negative(A)
			_update_zero(A)
		0x2A:
			assert(false, "Opcode $2A not implemented yet")
		0x2C:
			assert(false, "Opcode $2C not implemented yet")
		0x2D:
			assert(false, "Opcode $2D not implemented yet")
		0x2E:
			assert(false, "Opcode $2E not implemented yet")
		0x30:
			assert(false, "Opcode $30 not implemented yet")
		0x31:
			assert(false, "Opcode $31 not implemented yet")
		0x35: # AND, zero page, x
			var zp := (pop_byte() + X) % 0xFF
			A &= memory[zp]
			_update_negative(A)
			_update_zero(A)
		0x36:
			assert(false, "Opcode $36 not implemented yet")
		0x38: # SEC, implied
			set_flag(flag_bit.CARRY, true)
		0x39:
			assert(false, "Opcode $39 not implemented yet")
		0x3D:
			assert(false, "Opcode $3D not implemented yet")
		0x3E:
			assert(false, "Opcode $3E not implemented yet")
		0x40:
			assert(false, "Opcode $40 not implemented yet")
		0x41:
			assert(false, "Opcode $41 not implemented yet")
		0x45:
			assert(false, "Opcode $45 not implemented yet")
		0x46: # LSR, zero page
			var zp := pop_byte()
			var num := get_byte(zp)
			_update_carry_from_bit_0(num)
			var mask7 := (num & 1) << 7
			num = ((num >> 1) & 0xFF) | mask7
			set_byte(zp, num)
			_update_negative(num)
			_update_zero(num)
		0x48:
			assert(false, "Opcode $48 not implemented yet")
		0x49:
			assert(false, "Opcode $49 not implemented yet")
		0x4A: # LSR, accumulator
			_update_carry_from_bit_0(A)
			var mask7 := (A & 1) << 7
			A = ((A >> 1) & 0xFF) | mask7
			_update_negative(A)
			_update_zero(A)
		0x4A:
			assert(false, "Opcode $4A not implemented yet")
		0x4C: # JMP, absolute
			PC = pop_word()
		0x4D:
			assert(false, "Opcode $4D not implemented yet")
		0x4E:
			assert(false, "Opcode $4E not implemented yet")
		0x50:
			assert(false, "Opcode $50 not implemented yet")
		0x51:
			assert(false, "Opcode $51 not implemented yet")
		0x55:
			assert(false, "Opcode $55 not implemented yet")
		0x56:
			assert(false, "Opcode $56 not implemented yet")
		0x58: # CLI, implied
			set_flag(flag_bit.INTERRUPT, false)
		0x59:
			assert(false, "Opcode $59 not implemented yet")
		0x5D:
			assert(false, "Opcode $5D not implemented yet")
		0x5E:
			assert(false, "Opcode $5E not implemented yet")
		0x60: # RTS, implied
			PC = pop_stack_addr()
		0x61:
			assert(false, "Opcode $61 not implemented yet")
		0x65:
			assert(false, "Opcode $65 not implemented yet")
		0x66:
			assert(false, "Opcode $66 not implemented yet")
		0x68:
			assert(false, "Opcode $68 not implemented yet")
		0x69:
			assert(false, "Opcode $69 not implemented yet")
		0x6A:
			assert(false, "Opcode $6A not implemented yet")
		0x6C:
			assert(false, "Opcode $6C not implemented yet")
		0x6D:
			assert(false, "Opcode $6D not implemented yet")
		0x6E:
			assert(false, "Opcode $6E not implemented yet")
		0x70:
			assert(false, "Opcode $70 not implemented yet")
		0x71:
			assert(false, "Opcode $71 not implemented yet")
		0x75:
			assert(false, "Opcode $75 not implemented yet")
		0x76:
			assert(false, "Opcode $76 not implemented yet")
		0x78: # SEI, implied
			set_flag(flag_bit.INTERRUPT, true)
		0x79:
			assert(false, "Opcode $79 not implemented yet")
		0x7D:
			assert(false, "Opcode $7D not implemented yet")
		0x7E:
			assert(false, "Opcode $7E not implemented yet")
		0x81: # STA, indexed indirect
			var zp := (pop_byte() + X) % 0xFF
			var addr := get_word(zp)
			set_byte(addr, A)
		0x84: # STY, zero page
			var zp = pop_byte()
			set_byte(zp, Y)
		0x85: # STA, zero page
			var zp = pop_byte()
			set_byte(zp, A)
		0x86: # STX, zero page
			var zp := pop_byte() % 0xFF
			set_byte(zp, X)
		0x88: # DEY, implied
			Y = (Y - 1) & 0xFF
			_update_negative(Y)
			_update_zero(Y)
		0x8A: # TXA, implied
			A = X
			_update_negative(A)
			_update_zero(A)
		0x8C: # STY, absolute
			set_byte(pop_word(), Y)
		0x8D: # STA, absolute
			set_byte(pop_word(), A)
		0x8E: # STX, absolute
			set_byte(pop_word(), X)
		0x90:
			assert(false, "Opcode $90 not implemented yet")
		0x91: # STA, indirect indexed
			var zp = pop_byte()
			var addr = get_word(zp)
			set_byte(addr+Y, A)
		0x94: # STY, zero page, x
			var zp = (pop_byte() + X) % 0xFF
			set_byte(zp, Y)
		0x95: # STA, zero page, x
			var zp = (pop_byte() + X) % 0xFF
			set_byte(zp, A)
		0x96: # STX, zero page, y
			var zp := (pop_byte() + Y) % 0xFF
			set_byte(zp, X)
		0x98: # TYA, implied
			A = Y
			_update_zero(A)
			_update_negative(A)
		0x99: # STA, absolute, y
			set_byte(pop_word() + Y, A)
		0x9A:
			assert(false, "Opcode $9A not implemented yet")
		0x9D: # STA, absolute,  x
			set_byte(pop_word() + X, A)
		0xA0: # LDY, immediate
			Y = pop_byte()
			_update_zero(Y)
			_update_negative(Y)
		0xA1: # LDA, indexed indirect
			var zp = (pop_byte() + X) % 0xFF
			var addr = get_word(zp)
			A = memory[addr]
			_update_zero(A)
			_update_negative(A)
		0xA2: # LDX, immediate
			X = pop_byte()
			_update_zero(X)
			_update_negative(X)
		0xA4: # LDY, zero page
			Y = memory[pop_byte()]
			_update_zero(Y)
			_update_negative(Y)
		0xA5: # LDA, zero page
			A = memory[pop_byte()]
			_update_zero(A)
			_update_negative(A)
		0xA6: # LDX, zero page
			X = memory[pop_byte()]
			_update_zero(X)
			_update_negative(X)
		0xA8: # TAY, implied
			Y = A
			_update_zero(Y)
			_update_negative(Y)
		0xA9: # LDA, immediate
			A = pop_byte()
			_update_zero(A)
			_update_negative(A)
		0xAA: # TAX, implied
			X = A
			_update_zero(X)
			_update_negative(X)
		0xAC: # LDY, absolute
			Y = memory[pop_word()]
			_update_zero(Y)
			_update_negative(Y)
		0xAD: # LDA, absolute
			A = memory[pop_word()]
			_update_zero(A)
			_update_negative(A)
		0xAE: # LDX, absolute
			X = memory[pop_word()]
			_update_zero(X)
			_update_negative(X)
		0xB0:
			assert(false, "Opcode $B0 not implemented yet")
		0xB1: # LDA, indirect indexed
			var zp := pop_byte()
			var addr := get_word(zp)
			A = memory[addr+Y]
			_update_zero(A)
			_update_negative(A)
		0xB4: # LDY, zero page, x
			var zp := (pop_byte() + X) % 0xFF
			Y = memory[zp]
			_update_zero(Y)
			_update_negative(Y)
		0xB5: # LDA, zero page, x
			var zp := (pop_byte() + X) % 0xFF
			A = memory[zp]
			_update_zero(A)
			_update_negative(A)
		0xB6: # LDX, zero page, y
			var zp := (pop_byte() + Y) % 0xFF
			X = memory[zp]
			_update_zero(X)
			_update_negative(X)
		0xB8: # CLV, implied
			set_flag(flag_bit.OVERFLOW, false)
		0xB9: # LDA, absolute, y
			A = memory[pop_word() + Y]
			_update_zero(A)
			_update_negative(A)
		0xBA:
			assert(false, "Opcode $BA not implemented yet")
		0xBC: # LDY, absolute, x
			Y = memory[pop_word() + X]
			_update_zero(Y)
			_update_negative(Y)
		0xBD: # LDA, absolute, x
			A = memory[pop_word() + X]
			_update_zero(A)
			_update_negative(A)
		0xBE: # LDX, absolute, y
			X = memory[pop_word()]
			_update_zero(Y)
			_update_negative(Y)
		0xC0:
			assert(false, "Opcode $C0 not implemented yet")
		0xC1:
			assert(false, "Opcode $C1 not implemented yet")
		0xC4:
			assert(false, "Opcode $C4 not implemented yet")
		0xC5:
			assert(false, "Opcode $C5 not implemented yet")
		0xC6: #DEC, zero page
			var zp := pop_byte()
			set_byte(memory[zp], (memory[zp] - 1) & 0xFF)
			_update_zero(memory[zp])
			_update_negative(memory[zp])
		0xC8: # INY, implied
			Y = (Y + 1) & 0xFF
			_update_zero(Y)
			_update_negative(Y)
		0xC9:
			assert(false, "Opcode $C9 not implemented yet")
		0xCA: # DEX, implied
			X = (X - 1) & 0xFF
			_update_zero(X)
			_update_negative(X)
		0xCC:
			assert(false, "Opcode $CC not implemented yet")
		0xCD:
			assert(false, "Opcode $CD not implemented yet")
		0xCE:
			assert(false, "Opcode $CE not implemented yet")
		0xD0:
			assert(false, "Opcode $D0 not implemented yet")
		0xD1:
			assert(false, "Opcode $D1 not implemented yet")
		0xD5:
			assert(false, "Opcode $D5 not implemented yet")
		0xD6:
			assert(false, "Opcode $D6 not implemented yet")
		0xD8: # CLD, implied
			set_flag(flag_bit.BCD, false)
		0xD9:
			assert(false, "Opcode $D9 not implemented yet")
		0xDD:
			assert(false, "Opcode $DD not implemented yet")
		0xDE:
			assert(false, "Opcode $DE not implemented yet")
		0xE0:
			assert(false, "Opcode $E0 not implemented yet")
		0xE1:
			assert(false, "Opcode $E1 not implemented yet")
		0xE4:
			assert(false, "Opcode $E4 not implemented yet")
		0xE5:
			assert(false, "Opcode $E5 not implemented yet")
		0xE6:
			assert(false, "Opcode $E6 not implemented yet")
		0xE8: # INX, implied
			X = (X + 1) & 0xFF
			_update_zero(X)
			_update_negative(X)
		0xE9:
			assert(false, "Opcode $E9 not implemented yet")
		0xEA: # NOP, implied
			pass
		0xEC:
			assert(false, "Opcode $EC not implemented yet")
		0xED:
			assert(false, "Opcode $ED not implemented yet")
		0xEE:
			assert(false, "Opcode $EE not implemented yet")
		0xF0:
			assert(false, "Opcode $F0 not implemented yet")
		0xF1:
			assert(false, "Opcode $F1 not implemented yet")
		0xF5:
			assert(false, "Opcode $F5 not implemented yet")
		0xF6:
			assert(false, "Opcode $F6 not implemented yet")
		0xF8:
			assert(false, "Opcode $F7 not implemented yet")
		0xF9:
			assert(false, "Opcode $F9 not implemented yet")
		0xFD:
			assert(false, "Opcode $FD not implemented yet")
		0xFE:
			assert(false, "Opcode $FE not implemented yet")

func step(steps:int = 1):
	_status = status.PAUSED
	for s in range(steps):
		execute(true)
