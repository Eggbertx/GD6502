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
	UNUSED = 32,
	OVERFLOW = 64,
	NEGATIVE = 128
}

enum status {
	STOPPED, RUNNING, PAUSED, END
}
@export_group("Registers")
@export var A := 0
@export var X := 0
@export var Y := 0
@export var PC := CPUOptions.DEFAULT_INITIAL_PC
@export var SP := CPUOptions.DEFAULT_INITIAL_SP

var _status := status.STOPPED
var flags := 0

@export_group("Memory")
@export var memory := PackedByteArray()
@export var memory_size := CPUOptions.DEFAULT_RAM_END

@export_group("Processor status")
@export var carry_flag: bool:
	get:
		return get_flag_state(flag_bit.CARRY)
	set(c):
		set_flag(flag_bit.CARRY, c)

@export var zero_flag: bool:
	get:
		return get_flag_state(flag_bit.ZERO)
	set(z):
		set_flag(flag_bit.ZERO, z)

@export var interrupt_flag: bool:
	get:
		return get_flag_state(flag_bit.INTERRUPT)
	set(i):
		set_flag(flag_bit.INTERRUPT, i)

@export var decimal_flag: bool:
	get:
		return get_flag_state(flag_bit.BCD)
	set(d):
		set_flag(flag_bit.BCD, d)

@export var break_flag: bool:
	get:
		return get_flag_state(flag_bit.BREAK)
	set(b):
		set_flag(flag_bit.BREAK, b)

@export var overflow_flag: bool:
	get:
		return get_flag_state(flag_bit.OVERFLOW)
	set(o):
		set_flag(flag_bit.OVERFLOW, o)

@export var negative_flag: bool:
	get:
		return get_flag_state(flag_bit.NEGATIVE)
	set(n):
		set_flag(flag_bit.NEGATIVE, n)

@export_group("")

@export var current_opcode := 0

var pc_start := CPUOptions.DEFAULT_INITIAL_PC
var sp_start := CPUOptions.DEFAULT_INITIAL_SP

var watched_ranges := [] # each element: [start,end]

func setup_opts(opts: CPUOptions):
	memory_size = opts.ram_end
	sp_start = opts.sp_start
	pc_start = opts.pc_start
	memory.resize(memory_size)

func _init(opts: CPUOptions = CPUOptions.new()):
	setup_opts(opts)

func _ready():
	setup_opts(CPUOptions.new())
	reset()

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
	var old := _status
	_status = new_status
	status_changed.emit(_status, old)

func load_rom(bytes:PackedByteArray):
	memory.resize(pc_start + bytes.size())
	memory_size = memory.size()
	for b in range(bytes.size()):
		memory[pc_start + b] = bytes.decode_u8(b)
	rom_loaded.emit(bytes.size())

func unload_rom():
	memory_size = pc_start
	memory.resize(memory_size)
	for b in range(memory_size - pc_start):
		memory[pc_start + b] = 0
	rom_unloaded.emit()

func reset(reset_status:status = _status):
	A = 0
	X = 0
	Y = 0
	PC = pc_start
	SP = sp_start
	flags = flag_bit.UNUSED | flag_bit.BREAK
	set_status(reset_status, true)
	cpu_reset.emit()
	var reset_range := pc_start if pc_start < memory_size else memory_size
	for i in range(reset_range):
		memory[i] = 0

# basic memory operations
func pop_byte() -> int:
	if PC >= memory.size():
		return 0
	var popped := memory[PC] & 0xFF
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
	if addr >= memory_size or addr < 0:
		return 0
	elif addr == 0xfe:
		return randi_range(0, 255)
	return memory[addr]

func get_word(pos:int) -> int:
	return (memory[pos] | (memory[(pos+1)] << 8)) & 0xFFFF

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

func get_zpx_addr() -> int:
	return (pop_byte() + X) & 0xFF

func get_zpy_addr() -> int:
	return (pop_byte() + Y) & 0xFF

func get_indexed_indirect_addr() -> int:
	var zp := (pop_byte() + X) & 0xFF
	return get_word(zp)

func get_indirect_indexed_addr() -> int:
	var zp := pop_byte()
	return (get_word(zp) + Y) & 0xFFFF

func _update_zero(register: int):
	zero_flag = (register & 0xFF) == 0

func _update_negative(register: int):
	negative_flag = (register & 0x80) > 0

func _update_carry_from_bit_0(val: int):
	carry_flag = (val & 1) == 1

func _update_carry_from_bit_7(val: int):
	carry_flag = (val & 8) == 128

func _adc(val:int):
	if decimal_flag:
		var low_nibble := (A & 0x0F) + (val & 0x0F) + (flags & flag_bit.CARRY)
		var high_nibble := (A & 0xF0) + (val & 0xF0)
		if low_nibble > 0x09:
			high_nibble += 0x10
			low_nibble += 0x06
		overflow_flag = ~(A ^ val) & (A ^ high_nibble) & 0x80
		if high_nibble > 0x90:
			high_nibble += 0x60;
		carry_flag = high_nibble & 0xFF00
		A = (low_nibble & 0x0F) + (high_nibble & 0xF0)
	else:
		var sum := A + val + (flags & flag_bit.CARRY)
		overflow_flag = ~(A ^ val) & (A ^ sum) & 0x80
		carry_flag = sum & 0xFF00 > 0
		A = sum & 0xFF
	_update_negative(A)
	_update_zero(A)

func _sbc(val:int):
	var diff := A - val - (1 - flags & flag_bit.CARRY)
	overflow_flag = (A ^ val) & (A ^ diff) & 0x80

	if decimal_flag:
		var low_nibble := (A & 0x0F) - (val & 0x0F) - (1 - flags & flag_bit.CARRY)
		var high_nibble := (A & 0xF0) - (val & 0xF0)
		if low_nibble & 0x10 > 0:
			low_nibble -= 6
			high_nibble -= 1
		if high_nibble & 0x0100 > 0:
			high_nibble -= 0x60;
		A = (low_nibble & 0x0F) + (high_nibble & 0xF0)
	else:
		A = diff & 0xFF
	carry_flag = (diff & 0xFF00) == 0
	_update_negative(A)
	_update_zero(A)

func _compare(val:int, reg:int):
	carry_flag = reg >= val
	zero_flag = val == reg
	negative_flag = val == reg

func _rol(val:int) -> int:
	var carry := flags & flag_bit.CARRY
	flags = (flags & (~flag_bit.CARRY)) | ((val & 0x80) >> 7)
	val = ((val << 1) & 0xFE) | carry
	_update_negative(val)
	_update_zero(val)
	return val

func _ror(val:int) -> int:
	var carry := flags & flag_bit.CARRY
	flags = (flags & (~flag_bit.CARRY)) | (val & 1)
	val = (val >> 1) | (carry << 7)
	_update_negative(val)
	_update_zero(val)
	return val

func _lsr(val:int) -> int:
	flags = (flags & (~flag_bit.CARRY)) | (val & 1)
	val = val >> 1
	_update_negative(val)
	_update_zero(val)
	return val

### This function can be overridden to handle non-standard opcodes. Child classes should NOT call the base class function.
func unhandled_opcode(opcode:int):
	assert(false, "Unhandled opcode: %02X" % opcode)

### This function can be overridden to handle opcodes differently than the standard implementation. Child classes
### that override this function should return true if the given function is handled by the override, and false otherwise.
func override_opcode(opcode:int):
	return false

func execute(force = false, new_PC = -1):
	if _status != status.RUNNING and !force:
		return
	if new_PC > -1:
		PC = new_PC

	if PC >= memory.size():
		set_status(status.END)
		return

	if break_flag:
		current_opcode = pop_byte()
	else:
		current_opcode = 0
	
	if override_opcode(current_opcode):
		return

	match current_opcode:
		0x00: # BRK, implied
			set_status(status.STOPPED, true)
		0x01: # ORA, indexed indirect
			A |= get_byte(get_indexed_indirect_addr())
			_update_negative(A)
			_update_zero(A)
		0x05: # ORA, zero page
			A |= get_byte(pop_byte())
			_update_negative(A)
			_update_zero(A)
		0x06: # ASL, zero page
			var zp := pop_byte()
			var num := get_byte(zp)
			_update_carry_from_bit_0(num)
			num = (num << 1) & 0xFF
			set_byte(zp, num)
			_update_negative(num)
			_update_zero(num)
		0x08: # PHP, implied
			push_stack(flags)
		0x09: # ORA, immediate
			A |= pop_byte()
			_update_negative(A)
			_update_zero(A)
		0x0A: # ASL, accumulator
			_update_carry_from_bit_7(A)
			A = (A << 1) & 0xFF
			_update_negative(A)
			_update_zero(A)
		0x0D: # ORA, absolute
			A |= get_byte(pop_word())
			_update_negative(A)
			_update_zero(A)
		0x0E: # ASL, absolute
			var addr := pop_word()
			var num := get_byte(addr)
			_update_carry_from_bit_0(num)
			num = (num << 1) & 0xFF
			set_byte(addr, num)
			_update_negative(num)
			_update_zero(num)
		0x10:
			assert(false, "Opcode $10 not implemented yet")
		0x11: # ORA, indirect indexed
			A |= get_byte(get_indirect_indexed_addr())
			_update_negative(A)
			_update_zero(A)
		0x15: # ORA, zero page, x
			A |= get_byte(get_zpx_addr())
			_update_negative(A)
			_update_zero(A)
		0x16: # ASL, zero page, x
			var zp := get_zpx_addr()
			var num := get_byte(zp)
			_update_carry_from_bit_0(num)
			num = (num << 1) & 0xFF
			set_byte(zp, num)
			_update_negative(num)
			_update_zero(num)
		0x18: # CLC, implied
			carry_flag = false
		0x19: # ORA, absolute, y
			var addr := (pop_word() + Y) & 0xFFFF
			var num := get_byte(addr)
			A = (A | num) & 0xFF
			_update_negative(A)
			_update_zero(A)
		0x1D: # ORA, absolute, x
			var addr := (pop_word() + X) & 0xFFFF
			var num := get_byte(addr)
			A = (A | num) & 0xFF
			_update_negative(A)
			_update_zero(A)
		0x1E: # ASL, absolute, x
			var addr := (pop_word() + X) & 0xFFFF
			var num := get_byte(addr)
			_update_carry_from_bit_0(num)
			num = (num << 1) & 0xFF
			set_byte(addr, num)
			_update_negative(num)
			_update_zero(num)
		0x20: # JSR, absolute
			push_stack_addr(PC+1)
			PC = pop_word()
		0x21: # AND, indexed indirect
			A &= get_byte(get_indexed_indirect_addr())
			_update_negative(A)
			_update_zero(A)
		0x24: # BIT, zero page
			var num := get_byte(pop_byte())
			negative_flag = num & 0x80 == 0x80
			overflow_flag = num & 0x40 == 0x40
			zero_flag = num & A
		0x25: # AND, zero page
			var num := get_byte(pop_byte())
			A &= num
			_update_negative(A)
			_update_zero(A)
		0x26: # ROL, zero page
			var zp := pop_byte()
			var val := get_byte(zp)
			set_byte(zp, _rol(val))
		0x28: # PLP, implied
			flags = pop_stack()
		0x29: # AND, immediate
			var imm := pop_byte()
			A = (A & imm) & 0xFF
			_update_negative(A)
			_update_zero(A)
		0x2A: # ROL, accumulator
			A = _rol(A)
		0x2C: # BIT, absolute
			var num := get_byte(pop_word())
			negative_flag = num & 0x80 == 0x80
			overflow_flag = num & 0x40 == 0x40
			zero_flag = num & A
		0x2D: # AND, absolute
			var num := get_byte(pop_word())
			A &= num
			_update_negative(A)
			_update_zero(A)
		0x2E: # ROL, absolute
			var addr := pop_word()
			var val := get_byte(addr)
			set_byte(addr, _rol(val))
		0x30:
			assert(false, "Opcode $30 not implemented yet")
		0x31: # AND, indirect indexed
			A &= get_byte(get_indirect_indexed_addr())
			_update_negative(A)
			_update_zero(A)
		0x35: # AND, zero page, x
			A &= get_byte(get_zpx_addr())
			_update_negative(A)
			_update_zero(A)
		0x36: # ROL, zero page x
			var zpx := get_zpx_addr()
			var val := get_byte(zpx)
			set_byte(zpx, _rol(val))
		0x38: # SEC, implied
			carry_flag = true
		0x39: # AND, absolute y
			var addr := (pop_word() + Y) & 0xFFFF
			A &= get_byte(addr)
			_update_negative(A)
			_update_zero(A)
		0x3D: # AND, absolute x
			var addr := (pop_word() + X) & 0xFFFF
			A &= get_byte(addr)
			_update_negative(A)
			_update_zero(A)
		0x3E: # ROL, absolute x
			var addr := (pop_word() + X) & 0xFFFF
			var val := get_byte(addr)
			set_byte(addr, _rol(val))
		0x40:
			assert(false, "Opcode $40 not implemented yet")
		0x41:
			assert(false, "Opcode $41 not implemented yet")
		0x45:
			assert(false, "Opcode $45 not implemented yet")
		0x46: # LSR, zero page
			var zp := pop_byte()
			var num := get_byte(zp)
			set_byte(zp, _lsr(num))
		0x48: # PHA, implied
			push_stack(A)
		0x49:
			assert(false, "Opcode $49 not implemented yet")
		0x4A: # LSR, accumulator
			A = _lsr(A)
		0x4A:
			assert(false, "Opcode $4A not implemented yet")
		0x4C: # JMP, absolute
			PC = pop_word()
		0x4D:
			assert(false, "Opcode $4D not implemented yet")
		0x4E: # LSR, absolute
			var addr := pop_word()
			var num := get_byte(addr)
			set_byte(addr, _lsr(num))
		0x50:
			assert(false, "Opcode $50 not implemented yet")
		0x51:
			assert(false, "Opcode $51 not implemented yet")
		0x55:
			assert(false, "Opcode $55 not implemented yet")
		0x56: # LSR, zero page x
			var zp := get_zpx_addr()
			var num := get_byte(zp)
			set_byte(zp, _lsr(num))
		0x58: # CLI, implied
			interrupt_flag = false
		0x59:
			assert(false, "Opcode $59 not implemented yet")
		0x5D:
			assert(false, "Opcode $5D not implemented yet")
		0x5E: # LSR, absolute x
			var addr := pop_word() + X
			var num := get_byte(addr)
			set_byte(addr, _lsr(num))
		0x60: # RTS, implied
			PC = pop_stack_addr()
		0x61: # ADC, indexed indirect
			var num := get_byte(get_indexed_indirect_addr())
			_adc(num)
		0x65: # ADC, zero page
			var num := get_byte(pop_byte())
			_adc(num)
		0x66: # ROR, zero page
			var zp := pop_byte()
			var num := get_byte(zp)
			set_byte(zp, _ror(num))
		0x68: # PLA, implied
			A = pop_stack()
		0x69: # ADC, immediate
			var num := pop_byte()
			_adc(num)
		0x6A: # ROR, accumulator
			A = _ror(A)
		0x6C: # JMP, indirect
			var addr := pop_word()
			var ind_addr := get_word(addr)
			PC = ind_addr
		0x6D: # ADC, absolute
			var num := get_byte(pop_word())
			_adc(num)
		0x6E: # ROR, absolute
			var addr := pop_word()
			var num := get_byte(addr)
			set_byte(addr, _ror(num))
		0x70:
			assert(false, "Opcode $70 not implemented yet")
		0x71: # ADC, zero page, y
			var num := get_byte(get_zpy_addr())
			_adc(num)
		0x75: # ADC, zero page, x
			var num := get_byte(get_zpx_addr())
			_adc(num)
		0x76: # ROR, zero page x
			var zp := get_zpx_addr()
			var num := get_byte(zp)
			set_byte(zp, _ror(num))
		0x78: # SEI, implied
			interrupt_flag = true
		0x79: # ADC, absolute, y
			var num := get_byte(pop_word() + Y)
			_adc(num)
		0x7D: # ADC, absolute, x
			var num := get_byte(pop_word() + X)
			_adc(num)
		0x7E: # ROR, absolute x
			var addr := pop_word() + X
			var num := get_byte(addr)
			set_byte(addr, _ror(num))
		0x81: # STA, indexed indirect
			set_byte(get_indexed_indirect_addr(), A)
		0x84: # STY, zero page
			set_byte(pop_byte(), Y)
		0x85: # STA, zero page
			set_byte(pop_byte(), A)
		0x86: # STX, zero page
			set_byte(pop_byte(), X)
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
			set_byte(get_indirect_indexed_addr(), A)
		0x94: # STY, zero page, x
			set_byte(get_zpx_addr(), Y)
		0x95: # STA, zero page, x
			set_byte(get_zpx_addr(), A)
		0x96: # STX, zero page, y
			set_byte(get_zpy_addr(), X)
		0x98: # TYA, implied
			A = Y
			_update_zero(A)
			_update_negative(A)
		0x99: # STA, absolute, y
			set_byte(pop_word() + Y, A)
		0x9A: # TXS, implied
			SP = X
		0x9D: # STA, absolute,  x
			set_byte(pop_word() + X, A)
		0xA0: # LDY, immediate
			Y = pop_byte()
			_update_zero(Y)
			_update_negative(Y)
		0xA1: # LDA, indexed indirect
			A = get_byte(get_indexed_indirect_addr())
			_update_zero(A)
			_update_negative(A)
		0xA2: # LDX, immediate
			X = pop_byte()
			_update_zero(X)
			_update_negative(X)
		0xA4: # LDY, zero page
			Y = get_byte(pop_byte())
			_update_zero(Y)
			_update_negative(Y)
		0xA5: # LDA, zero page
			A = get_byte(pop_byte())
			_update_zero(A)
			_update_negative(A)
		0xA6: # LDX, zero page
			X = get_byte(pop_byte())
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
			Y = get_byte(pop_word())
			_update_zero(Y)
			_update_negative(Y)
		0xAD: # LDA, absolute
			A = get_byte(pop_word())
			_update_zero(A)
			_update_negative(A)
		0xAE: # LDX, absolute
			X = get_byte(pop_word())
			_update_zero(X)
			_update_negative(X)
		0xB0:
			assert(false, "Opcode $B0 not implemented yet")
		0xB1: # LDA, indirect indexed
			A = get_byte(get_indirect_indexed_addr())
			_update_zero(A)
			_update_negative(A)
		0xB4: # LDY, zero page, x
			Y = get_byte(get_zpx_addr())
			_update_zero(Y)
			_update_negative(Y)
		0xB5: # LDA, zero page, x
			A = get_byte(get_zpx_addr())
			_update_zero(A)
			_update_negative(A)
		0xB6: # LDX, zero page, y
			X = get_byte(get_zpy_addr())
			_update_zero(X)
			_update_negative(X)
		0xB8: # CLV, implied
			overflow_flag = false
		0xB9: # LDA, absolute, y
			A = get_byte(pop_word() + Y)
			_update_zero(A)
			_update_negative(A)
		0xBA: # TSX, implied
			X = SP
		0xBC: # LDY, absolute, x
			Y = get_byte(pop_word() + X)
			_update_zero(Y)
			_update_negative(Y)
		0xBD: # LDA, absolute, x
			A = get_byte(pop_word() + X)
			_update_zero(A)
			_update_negative(A)
		0xBE: # LDX, absolute, y
			X = get_byte(pop_word())
			_update_zero(Y)
			_update_negative(Y)
		0xC0: # CPY, immediate
			_compare(pop_byte(), Y)
		0xC1: # CMP, indirect x
			var addr := get_indexed_indirect_addr()
			_compare(get_byte(addr), A)
		0xC4: # CPY, zero page
			var zp := pop_byte()
			_compare(get_byte(zp), Y)
		0xC5: # CMP, zero page
			var zp := pop_byte()
			_compare(get_byte(zp), A)
		0xC6: #DEC, zero page
			var zp := pop_byte()
			var new_val := (get_byte(zp) - 1) & 0xFF
			
			set_byte(zp, new_val)
			_update_zero(new_val)
			_update_negative(new_val)
		0xC8: # INY, implied
			Y = (Y + 1) & 0xFF
			_update_zero(Y)
			_update_negative(Y)
		0xC9: # CMP, immediate
			_compare(pop_byte(), A)
		0xCA: # DEX, implied
			X = (X - 1) & 0xFF
			_update_zero(X)
			_update_negative(X)
		0xCC: # CPY, absolute
			var addr := pop_word()
			_compare(get_byte(addr), Y)
		0xCD: # CMP, absolute
			var addr := pop_word()
			_compare(get_byte(addr), A)
		0xCE:
			assert(false, "Opcode $CE not implemented yet")
		0xD0:
			assert(false, "Opcode $D0 not implemented yet")
		0xD1: # CMP, indirect y
			var addr := get_indirect_indexed_addr()
			var val := get_byte(addr)
			_compare(val, A)
		0xD5: # CMP, zero page x
			var zp := get_zpx_addr()
			_compare(get_byte(zp), A)
		0xD6:
			assert(false, "Opcode $D6 not implemented yet")
		0xD8: # CLD, implied
			decimal_flag = false
		0xD9: # CMP, absolute y
			var addr := (pop_word() + Y) & 0xFFFF
			_compare(get_byte(addr), A)
		0xDD: # CMP, absolute x
			var addr := (pop_word() + X) & 0xFFFF
			_compare(get_byte(addr), A)
		0xDE:
			assert(false, "Opcode $DE not implemented yet")
		0xE0: # CPX, immediate
			_compare(pop_byte(), X)
		0xE1: # SBC, indirect x
			var addr := get_indexed_indirect_addr()
			_sbc(get_byte(addr))
		0xE4: # CPX, zero page
			var zp := pop_byte()
			_compare(get_byte(zp), X)
		0xE5: # SBC, zero page
			var zp := pop_byte()
			_sbc(get_byte(zp))
		0xE6:
			assert(false, "Opcode $E6 not implemented yet")
		0xE8: # INX, implied
			X = (X + 1) & 0xFF
			_update_zero(X)
			_update_negative(X)
		0xE9: # SBC, immediate
			_sbc(pop_byte())
		0xEA: # NOP, implied
			pass
		0xEC: # CPX, absolute
			var addr := pop_word()
			_compare(get_byte(addr), X)
		0xED: # SBC, absolute
			var addr := pop_word()
			_sbc(get_byte(addr))
		0xEE:
			assert(false, "Opcode $EE not implemented yet")
		0xF0:
			assert(false, "Opcode $F0 not implemented yet")
		0xF1: # SBC, indirect y
			var addr := get_indirect_indexed_addr()
			_sbc(get_byte(addr))
		0xF5:
			var zpx := get_zpx_addr()
			_sbc(get_byte(zpx))
		0xF6:
			assert(false, "Opcode $F6 not implemented yet")
		0xF8: # SED, implied
			decimal_flag = true
		0xF9: # SBC, absolute y
			var addr := pop_word() + Y
			_sbc(get_byte(addr))
		0xFD: # SBC, absolute x
			var addr := pop_word() + X
			_sbc(get_byte(addr))
		0xFE:
			assert(false, "Opcode $FE not implemented yet")
		_:
			unhandled_opcode(current_opcode)


func step(steps:int = 1):
	_status = status.PAUSED
	for s in range(steps):
		execute(true)
