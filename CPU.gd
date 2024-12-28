extends Node

class_name CPU

signal cpu_reset
signal illegal_opcode(opcode:int)
signal rom_loaded(bytes:int)
signal rom_unloaded
signal stack_emptied
signal stack_filled
signal status_changed(new_status:status, old_status:status)
signal watched_memory_changed(location:int, new_val:int)

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
	STOPPED, RUNNING, PAUSED, END, THREAD_EXIT
}

var pc_start := 0xFFFF
var sp_start := 0xFF

@export_group("Registers")
@export var A := 0
@export var X := 0
@export var Y := 0
@export var PC := pc_start
@export var SP := sp_start

var _status := status.STOPPED
var flags := 0

@export_group("Memory")
@export var memory := PackedByteArray()
@export var memory_size := 0

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

var watched_ranges := [] # each element: [start,end]

var _thread:Thread
var _semaphore:Semaphore
var _mutex:Mutex

func _setup_specs():
	assert(false, "You must override the _setup_specs function in your CPU subclass to set up the CPU's memory size, stack pointer start address, and initial program counter address.")
	# memory_size = 0x5ff
	# sp_start = 0xff
	# pc_start = 0x600

func _init(threaded = true):
	_setup_specs()
	memory.resize(memory_size)
	_mutex = Mutex.new()
	_semaphore = Semaphore.new()
	_thread = Thread.new()

	if threaded:
		_semaphore.post()
		_thread.start(_thread_loop)

func _ready():
	_setup_specs()
	reset()

func _exit_tree() -> void:
	_status = status.THREAD_EXIT
	if not _thread.is_alive():
		_thread.wait_to_finish()
	_mutex.unlock()


# Thread helper functions
func _cpu_reset_helper():
	cpu_reset.emit()

func _illegal_opcode_helper(opcode:int):
	illegal_opcode.emit(opcode)

func _rom_loaded_helper(size:int):
	rom_loaded.emit(size)

func _rom_unloaded_helper():
	rom_unloaded.emit()

func _stack_emptied_helper():
	stack_emptied.emit()

func _stack_filled_helper():
	stack_filled.emit()

func _status_changed_helper(new_status:status, old_status:status):
	status_changed.emit(new_status, old_status)

func _watched_memory_changed_helper(addr:int, new_value:int):
	watched_memory_changed.emit(addr, new_value)

func _thread_loop():
	while _status != status.THREAD_EXIT:
		_semaphore.wait()
		if _status == status.RUNNING:
			execute()

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
	call_deferred("_status_changed_helper", _status, old)

func load_rom(bytes:PackedByteArray):
	_mutex.lock()
	memory.resize(pc_start + bytes.size())
	memory_size = memory.size()
	for b in range(bytes.size()):
		memory[pc_start + b] = bytes.decode_u8(b)
	_mutex.unlock()
	call_deferred("_rom_loaded_helper", bytes.size())

func unload_rom():
	memory_size = pc_start
	memory.resize(memory_size)
	for b in range(memory_size - pc_start):
		memory[pc_start + b] = 0
	call_deferred("_rom_unloaded_helper")

func reset(reset_status:status = _status):
	A = 0
	X = 0
	Y = 0
	PC = pc_start
	SP = sp_start
	flags = flag_bit.UNUSED | flag_bit.BREAK
	set_status(reset_status, true)
	call_deferred("_cpu_reset_helper")
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
	return memory[addr]

func get_word(pos:int) -> int:
	return (memory[pos] | (memory[(pos+1)] << 8)) & 0xFFFF

func set_byte(addr:int, value:int):
	if addr >= memory_size:
		return
	memory[addr] = value & 0xFF
	for watched in watched_ranges:
		if addr >= watched[0] and addr <= watched[1]:
			call_deferred("_watched_memory_changed_helper", addr, value)

func push_stack(val: int):
	set_byte(0x100 + (SP & 0xFF), val & 0xFF)
	SP -= 1
	if SP < 0:
		call_deferred("_stack_filled_helper")
		SP &= 0xFF

func push_stack_addr(addr: int):
	push_stack((addr & 0xFF00) >> 8)
	push_stack(addr & 0xFF)

func pop_stack() -> int:
	SP += 1
	if SP > 0xFF:
		call_deferred("_stack_emptied_helper")
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

func _update_zero_negative(register:int):
	zero_flag = (register & 0xFF) == 0
	negative_flag = (register & 0x80) > 0

func _update_carry_from_bit_0(val: int):
	carry_flag = (val & 1) == 1

func _update_carry_from_bit_7(val: int):
	carry_flag = (val & 8) == 128

func _branch(relative_pos:int, condition: bool):
	if not condition:
		return
	if relative_pos & 0x80:
		PC -= 0x100 - relative_pos
	else:
		PC += relative_pos

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
	_update_zero_negative(A)

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
	_update_zero_negative(A)

func _compare(val:int, reg:int):
	carry_flag = reg >= val
	zero_flag = val == reg
	negative_flag = val == reg

func _rol(val:int) -> int:
	var carry := flags & flag_bit.CARRY
	flags = (flags & (~flag_bit.CARRY)) | ((val & 0x80) >> 7)
	val = ((val << 1) & 0xFE) | carry
	_update_zero_negative(val)
	return val

func _ror(val:int) -> int:
	var carry := flags & flag_bit.CARRY
	flags = (flags & (~flag_bit.CARRY)) | (val & 1)
	val = (val >> 1) | (carry << 7)
	_update_zero_negative(val)
	return val

func _lsr(val:int) -> int:
	flags = (flags & (~flag_bit.CARRY)) | (val & 1)
	val = val >> 1
	_update_zero_negative(val)
	return val

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
			_update_zero_negative(A)
		0x05: # ORA, zero page
			A |= get_byte(pop_byte())
			_update_zero_negative(A)
		0x06: # ASL, zero page
			var zp := pop_byte()
			var num := get_byte(zp)
			_update_carry_from_bit_0(num)
			num = (num << 1) & 0xFF
			set_byte(zp, num)
			_update_zero_negative(num)
		0x08: # PHP, implied
			push_stack(flags)
		0x09: # ORA, immediate
			A |= pop_byte()
			_update_zero_negative(A)
		0x0A: # ASL, accumulator
			_update_carry_from_bit_7(A)
			A = (A << 1) & 0xFF
			_update_zero_negative(A)
		0x0D: # ORA, absolute
			A |= get_byte(pop_word())
			_update_zero_negative(A)
		0x0E: # ASL, absolute
			var addr := pop_word()
			var num := get_byte(addr)
			_update_carry_from_bit_0(num)
			num = (num << 1) & 0xFF
			set_byte(addr, num)
			_update_zero_negative(num)
		0x10: # BPL, relative
			_branch(pop_byte(), !negative_flag)
		0x11: # ORA, indirect indexed
			A |= get_byte(get_indirect_indexed_addr())
			_update_zero_negative(A)
		0x15: # ORA, zero page, x
			A |= get_byte(get_zpx_addr())
			_update_zero_negative(A)
		0x16: # ASL, zero page, x
			var zp := get_zpx_addr()
			var num := get_byte(zp)
			_update_carry_from_bit_0(num)
			num = (num << 1) & 0xFF
			set_byte(zp, num)
			_update_zero_negative(num)
		0x18: # CLC, implied
			carry_flag = false
		0x19: # ORA, absolute, y
			var addr := (pop_word() + Y) & 0xFFFF
			var num := get_byte(addr)
			A = (A | num) & 0xFF
			_update_zero_negative(A)
		0x1D: # ORA, absolute, x
			var addr := (pop_word() + X) & 0xFFFF
			var num := get_byte(addr)
			A = (A | num) & 0xFF
			_update_zero_negative(A)
		0x1E: # ASL, absolute, x
			var addr := (pop_word() + X) & 0xFFFF
			var num := get_byte(addr)
			_update_carry_from_bit_0(num)
			num = (num << 1) & 0xFF
			set_byte(addr, num)
			_update_zero_negative(num)
		0x20: # JSR, absolute
			push_stack_addr(PC+1)
			PC = pop_word()
		0x21: # AND, indexed indirect
			A &= get_byte(get_indexed_indirect_addr())
			_update_zero_negative(A)
		0x24: # BIT, zero page
			var num := get_byte(pop_byte())
			negative_flag = num & 0x80 == 0x80
			overflow_flag = num & 0x40 == 0x40
			zero_flag = num & A
		0x25: # AND, zero page
			var num := get_byte(pop_byte())
			A &= num
			_update_zero_negative(A)
		0x26: # ROL, zero page
			var zp := pop_byte()
			var val := get_byte(zp)
			set_byte(zp, _rol(val))
		0x28: # PLP, implied
			flags = pop_stack()
		0x29: # AND, immediate
			var imm := pop_byte()
			A = (A & imm) & 0xFF
			_update_zero_negative(A)
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
			_update_zero_negative(A)
		0x2E: # ROL, absolute
			var addr := pop_word()
			var val := get_byte(addr)
			set_byte(addr, _rol(val))
		0x30: # BMI, relative
			_branch(pop_byte(), negative_flag)
		0x31: # AND, indirect indexed
			A &= get_byte(get_indirect_indexed_addr())
			_update_zero_negative(A)
		0x35: # AND, zero page, x
			A &= get_byte(get_zpx_addr())
			_update_zero_negative(A)
		0x36: # ROL, zero page x
			var zp := get_zpx_addr()
			var val := get_byte(zp)
			set_byte(zp, _rol(val))
		0x38: # SEC, implied
			carry_flag = true
		0x39: # AND, absolute y
			var addr := (pop_word() + Y) & 0xFFFF
			A &= get_byte(addr)
			_update_zero_negative(A)
		0x3D: # AND, absolute x
			var addr := (pop_word() + X) & 0xFFFF
			A &= get_byte(addr)
			_update_zero_negative(A)
		0x3E: # ROL, absolute x
			var addr := (pop_word() + X) & 0xFFFF
			var val := get_byte(addr)
			set_byte(addr, _rol(val))
		0x40: # RTI, implied
			flags = pop_stack()
			PC = pop_stack_addr()
		0x41: # EOR, indirect x
			A ^= get_byte(get_indexed_indirect_addr())
			_update_zero_negative(A)
		0x45: # EOR, zero page
			A ^= get_byte(pop_byte())
			_update_zero_negative(A)
		0x46: # LSR, zero page
			var zp := pop_byte()
			var num := get_byte(zp)
			set_byte(zp, _lsr(num))
		0x48: # PHA, implied
			push_stack(A)
		0x49: # EOR, immediate
			A ^= pop_byte()
			_update_zero_negative(A)
		0x4A: # LSR, accumulator
			A = _lsr(A)
		0x4C: # JMP, absolute
			PC = pop_word()
		0x4D: # EOR, absolute
			A ^= get_byte(pop_word())
			_update_zero_negative(A)
		0x4E: # LSR, absolute
			var addr := pop_word()
			var num := get_byte(addr)
			set_byte(addr, _lsr(num))
		0x50: # BVC, relative
			_branch(pop_byte(), !overflow_flag)
		0x51: # EOR, indirect y
			A ^= get_byte(get_indirect_indexed_addr())
			_update_zero_negative(A)
		0x55: # EOR, zero page x
			A ^= get_byte(get_zpx_addr())
			_update_zero_negative(A)
		0x56: # LSR, zero page x
			var zp := get_zpx_addr()
			var num := get_byte(zp)
			set_byte(zp, _lsr(num))
		0x58: # CLI, implied
			interrupt_flag = false
		0x59: # EOR, absolute y
			A ^= get_byte(pop_word() + Y)
			_update_zero_negative(A)
		0x5D: # EOR, absolute x
			A ^= get_byte(pop_word() + X)
			_update_zero_negative(A)
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
		0x70: # BVS, relative
			_branch(pop_byte(), overflow_flag)
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
			_update_zero_negative(Y)
		0x8A: # TXA, implied
			A = X
			_update_zero_negative(A)
		0x8C: # STY, absolute
			set_byte(pop_word(), Y)
		0x8D: # STA, absolute
			set_byte(pop_word(), A)
		0x8E: # STX, absolute
			set_byte(pop_word(), X)
		0x90: # BCC, relative
			_branch(pop_byte(), !carry_flag)
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
			_update_zero_negative(A)
		0x99: # STA, absolute, y
			set_byte(pop_word() + Y, A)
		0x9A: # TXS, implied
			SP = X
		0x9D: # STA, absolute,  x
			set_byte(pop_word() + X, A)
		0xA0: # LDY, immediate
			Y = pop_byte()
			_update_zero_negative(Y)
		0xA1: # LDA, indexed indirect
			A = get_byte(get_indexed_indirect_addr())
			_update_zero_negative(A)
		0xA2: # LDX, immediate
			X = pop_byte()
			_update_zero_negative(X)
		0xA4: # LDY, zero page
			Y = get_byte(pop_byte())
			_update_zero_negative(Y)
		0xA5: # LDA, zero page
			A = get_byte(pop_byte())
			_update_zero_negative(A)
		0xA6: # LDX, zero page
			X = get_byte(pop_byte())
			_update_zero_negative(X)
		0xA8: # TAY, implied
			Y = A
			_update_zero_negative(Y)
		0xA9: # LDA, immediate
			A = pop_byte()
			_update_zero_negative(A)
		0xAA: # TAX, implied
			X = A
			_update_zero_negative(X)
		0xAC: # LDY, absolute
			Y = get_byte(pop_word())
			_update_zero_negative(Y)
		0xAD: # LDA, absolute
			A = get_byte(pop_word())
			_update_zero_negative(A)
		0xAE: # LDX, absolute
			X = get_byte(pop_word())
			_update_zero_negative(X)
		0xB0: # BCS, relative
			_branch(pop_byte(), carry_flag)
		0xB1: # LDA, indirect indexed
			A = get_byte(get_indirect_indexed_addr())
			_update_zero_negative(A)
		0xB4: # LDY, zero page, x
			Y = get_byte(get_zpx_addr())
			_update_zero_negative(Y)
		0xB5: # LDA, zero page, x
			A = get_byte(get_zpx_addr())
			_update_zero_negative(A)
		0xB6: # LDX, zero page, y
			X = get_byte(get_zpy_addr())
			_update_zero_negative(X)
		0xB8: # CLV, implied
			overflow_flag = false
		0xB9: # LDA, absolute, y
			A = get_byte(pop_word() + Y)
			_update_zero_negative(A)
		0xBA: # TSX, implied
			X = SP
		0xBC: # LDY, absolute, x
			Y = get_byte(pop_word() + X)
			_update_zero_negative(Y)
		0xBD: # LDA, absolute, x
			A = get_byte(pop_word() + X)
			_update_zero_negative(A)
		0xBE: # LDX, absolute, y
			X = get_byte(pop_word())
			_update_zero_negative(Y)
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
			_update_zero_negative(new_val)
		0xC8: # INY, implied
			Y = (Y + 1) & 0xFF
			_update_zero_negative(Y)
		0xC9: # CMP, immediate
			_compare(pop_byte(), A)
		0xCA: # DEX, implied
			X = (X - 1) & 0xFF
			_update_zero_negative(X)
		0xCC: # CPY, absolute
			var addr := pop_word()
			_compare(get_byte(addr), Y)
		0xCD: # CMP, absolute
			var addr := pop_word()
			_compare(get_byte(addr), A)
		0xCE: # DEC, absolute
			var addr := pop_word()
			var new_val := (get_byte(addr) - 1) & 0xFF
			set_byte(addr, new_val)
			_update_zero_negative(new_val)
		0xD0: # BNE, relative
			_branch(pop_byte(), !zero_flag)
		0xD1: # CMP, indirect y
			var addr := get_indirect_indexed_addr()
			var val := get_byte(addr)
			_compare(val, A)
		0xD5: # CMP, zero page x
			var zp := get_zpx_addr()
			_compare(get_byte(zp), A)
		0xD6: # DEC, zero page x
			var zp := get_zpx_addr()
			var new_val := (get_byte(zp) - 1) & 0xFF
			set_byte(zp, new_val)
			_update_zero_negative(new_val)
		0xD8: # CLD, implied
			decimal_flag = false
		0xD9: # CMP, absolute y
			var addr := (pop_word() + Y) & 0xFFFF
			_compare(get_byte(addr), A)
		0xDD: # CMP, absolute x
			var addr := (pop_word() + X) & 0xFFFF
			_compare(get_byte(addr), A)
		0xDE: # DEC, absolute x
			var addr := (pop_word() + X) & 0xFFFF
			var new_val := (get_byte(addr) - 1) & 0xFF
			set_byte(addr, new_val)
			_update_zero_negative(new_val)
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
		0xE6: # INC, zero page
			var zp := pop_byte()
			var new_val := (get_byte(zp) + 1) & 0xFF
			set_byte(zp, new_val)
			_update_zero_negative(new_val)
		0xE8: # INX, implied
			X = (X + 1) & 0xFF
			_update_zero_negative(X)
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
		0xEE: # INC, absolute
			var addr := pop_word()
			var new_val := (get_byte(addr) + 1) & 0xFF
			set_byte(addr, new_val)
			_update_zero_negative(new_val)
		0xF0: # BEQ, relative
			_branch(pop_byte(), zero_flag)
		0xF1: # SBC, indirect y
			var addr := get_indirect_indexed_addr()
			_sbc(get_byte(addr))
		0xF5: # SBC, zero page x
			var zp := get_zpx_addr()
			_sbc(get_byte(zp))
		0xF6: # INC, zero page x
			var zp := get_zpx_addr()
			var new_val := (get_byte(zp) + 1) & 0xFF
			set_byte(zp, new_val)
			_update_zero_negative(new_val)
		0xF8: # SED, implied
			decimal_flag = true
		0xF9: # SBC, absolute y
			var addr := pop_word() + Y
			_sbc(get_byte(addr))
		0xFD: # SBC, absolute x
			var addr := pop_word() + X
			_sbc(get_byte(addr))
		0xFE: # INC, absolute x
			var addr := pop_word() + X
			var new_val := (get_byte(addr) + 1) & 0xFF
			set_byte(addr, new_val)
			_update_zero_negative(new_val)
		_:
			call_deferred("_illegal_opcode_helper", current_opcode)

	# post semaphore to allow the thread to continue
	_semaphore.post()
