# GD6502
A [6502](https://en.wikipedia.org/wiki/MOS_Technology_6502) emulator in the Godot game engine designed to be usable in emulators of 6502-based platforms.

To add GD6502 to your project (assuming you're using Git), add it as a submodule by running `git submodule add https://github.com/eggbertx/GD6502 addons/GD6502` from the root directory of your project.

To limit dependences, unit tests for this project are stored in the [GD6502-IDE](https://github.com/Eggbertx/GD6502-IDE) repository.

## Opcode table
* Empty table cells represent addressing modes that do not exist for their respective instructions.
* Y indicates an implemented opcode.
* N indicates an opcode that hasn't been implemented yet

Instruction | IMP | ACC | ABS |  ZP | IMM | ABSX | ABSY | INDX | INDY | ZPX | ZPY | REL | IND
------------|-----|-----|-----|-----|-----|------|------|------|------|-----|-----|-----|------
ADC         |     |     |  Y  |  Y  |  Y  |  Y   |  Y   |  Y   |  Y   |  Y  |     |     |    
AND         |     |     |  Y  |  Y  |  Y  |  Y   |  Y   |  Y   |  Y   |  Y  |     |     |    
ASL         |     |  Y  |  Y  |  Y  |     |  Y   |      |      |      |  Y  |     |     |    
BCC         |     |     |     |     |     |      |      |      |      |     |     |  Y  |    
BCS         |     |     |     |     |     |      |      |      |      |     |     |  Y  |    
BEQ         |     |     |     |     |     |      |      |      |      |     |     |  Y  |    
BIT         |     |     |  Y  |  Y  |     |      |      |      |      |     |     |     |    
BMI         |     |     |     |     |     |      |      |      |      |     |     |  Y  |    
BNE         |     |     |     |     |     |      |      |      |      |     |     |  Y  |    
BPL         |     |     |     |     |     |      |      |      |      |     |     |  Y  |    
BRK         |  Y  |     |     |     |     |      |      |      |      |     |     |     |    
BVC         |     |     |     |     |     |      |      |      |      |     |     |  Y  |    
BVS         |     |     |     |     |     |      |      |      |      |     |     |  Y  |    
CLC         |  Y  |     |     |     |     |      |      |      |      |     |     |     |    
CLD         |  Y  |     |     |     |     |      |      |      |      |     |     |     |    
CLI         |  Y  |     |     |     |     |      |      |      |      |     |     |     |    
CLV         |  Y  |     |     |     |     |      |      |      |      |     |     |     |    
CMP         |     |     |  Y  |  Y  |  Y  |  Y   |  Y   |  Y   |  Y   |  Y  |     |     |    
CPX         |     |     |  Y  |  Y  |  Y  |      |      |      |      |     |     |     |    
CPY         |     |     |  Y  |  Y  |  Y  |      |      |      |      |     |     |     |    
DEC         |     |     |  Y  |  Y  |     |  Y   |      |      |      |  Y  |     |     |    
DEX         |  Y  |     |     |     |     |      |      |      |      |     |     |     |    
DEY         |  Y  |     |     |     |     |      |      |      |      |     |     |     |    
EOR         |     |     |  Y  |  Y  |  Y  |  Y   |  Y   |  Y   |  Y   |  Y  |     |     |    
INC         |     |     |  N  |  N  |     |  N   |      |      |      |  N  |     |     |    
INX         |  Y  |     |     |     |     |      |      |      |      |     |     |     |    
INY         |  Y  |     |     |     |     |      |      |      |      |     |     |     |    
JMP         |     |     |  Y  |     |     |      |      |      |      |     |     |     |  Y 
JSR         |     |     |  Y  |     |     |      |      |      |      |     |     |     |    
LDA         |     |     |  Y  |  Y  |  Y  |  Y   |  Y   |  Y   |  Y   |  Y  |     |     |    
LDX         |     |     |  Y  |  Y  |  Y  |      |  Y   |      |      |     |  Y  |     |    
LDY         |     |     |  Y  |  Y  |  Y  |  Y   |      |      |      |  N  |     |     |    
LSR         |     |  Y  |  Y  |  Y  |     |  Y   |      |      |      |  Y  |     |     |    
NOP         |  Y  |     |     |     |     |      |      |      |      |     |     |     |    
ORA         |     |     |  Y  |  Y  |  Y  |  Y   |  Y   |  Y   |  Y   |  Y  |     |     |    
PHA         |  Y  |     |     |     |     |      |      |      |      |     |     |     |    
PHP         |  Y  |     |     |     |     |      |      |      |      |     |     |     |    
PLA         |  Y  |     |     |     |     |      |      |      |      |     |     |     |    
PLP         |  Y  |     |     |     |     |      |      |      |      |     |     |     |    
ROL         |     |  Y  |  Y  |  Y  |     |  Y   |      |      |      |  Y  |     |     |    
ROR         |     |  Y  |  Y  |  Y  |     |  Y   |      |      |      |  Y  |     |     |    
RTI         |  N  |     |     |     |     |      |      |      |      |     |     |     |    
RTS         |  Y  |     |     |     |     |      |      |      |      |     |     |     |    
SBC         |     |     |  Y  |  Y  |  Y  |  Y   |  Y   |  Y   |  Y   |  Y  |     |     |    
SEC         |  Y  |     |     |     |     |      |      |      |      |     |     |     |    
SED         |  Y  |     |     |     |     |      |      |      |      |     |     |     |    
SEI         |  Y  |     |     |     |     |      |      |      |      |     |     |     |    
STA         |     |     |  Y  |  Y  |     |  Y   |  Y   |  Y   |  Y   |  Y  |     |     |    
STX         |     |     |  Y  |  Y  |     |      |      |      |      |     |  Y  |     |    
STY         |     |     |  Y  |  Y  |     |      |      |      |      |  Y  |     |     |    
TAX         |  Y  |     |     |     |     |      |      |      |      |     |     |     |    
TAY         |  Y  |     |     |     |     |      |      |      |      |     |     |     |    
TSX         |  Y  |     |     |     |     |      |      |      |      |     |     |     |    
TXA         |  Y  |     |     |     |     |      |      |      |      |     |     |     |    
TXS         |  Y  |     |     |     |     |      |      |      |      |     |     |     |    
TYA         |  Y  |     |     |     |     |      |      |      |      |     |     |     |    
