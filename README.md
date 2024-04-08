# GD6502
A [6502](https://en.wikipedia.org/wiki/MOS_Technology_6502) emulator in the Godot game engine designed to be usable in emulators of 6502-based platforms.

To add GD6502 to your project (assuming you're using Git), add it as a submodule by running `git submodule add https://github.com/eggbertx/GD6502 addons/GD6502` from the root directory of your project.

To limit dependences, unit tests for this project are stored in the [GD6502-IDE](https://github.com/Eggbertx/GD6502-IDE) repository.

## Opcodes
Here is a table of the implemented opcodes. An empty checkbox means that it hasn't been implemented yet.
A table cell with no checkbox represents an addressing mode that does not exist for the respective instruction.

Instruction | IMP | ACC | ABS |  ZP | IMM | ABSX | ABSY | INDX | INDY | ZPX | ZPY | REL | IND
------------|-----|-----|-----|-----|-----|------|------|------|------|-----|-----|-----|------
ADC         |     |     |  ☐  |  ☐  |  ☐  |  ☐   |  ☐   |  ☐   |  ☐   |  ☐  |     |     |    
AND         |     |     |  ☐  |  ☑  |  ☑  |  ☐   |  ☐   |  ☐   |  ☐   |  ☑  |     |     |    
ASL         |     |  ☐  |  ☐  |  ☐  |     |  ☐   |      |      |      |  ☐  |     |     |    
BCC         |     |     |     |     |     |      |      |      |      |     |     |  ☐  |    
BCS         |     |     |     |     |     |      |      |      |      |     |     |  ☐  |    
BEQ         |     |     |     |     |     |      |      |      |      |     |     |  ☐  |    
BIT         |     |     |  ☐  |  ☐  |     |      |      |      |      |     |     |     |    
BMI         |     |     |     |     |     |      |      |      |      |     |     |  ☐  |    
BNE         |     |     |     |     |     |      |      |      |      |     |     |  ☐  |    
BPL         |     |     |     |     |     |      |      |      |      |     |     |  ☐  |    
BRK         |  ☑  |     |     |     |     |      |      |      |      |     |     |     |    
BVC         |     |     |     |     |     |      |      |      |      |     |     |  ☐  |    
BVS         |     |     |     |     |     |      |      |      |      |     |     |  ☐  |    
CLC         |  ☑  |     |     |     |     |      |      |      |      |     |     |     |    
CLD         |  ☑  |     |     |     |     |      |      |      |      |     |     |     |    
CLI         |  ☑  |     |     |     |     |      |      |      |      |     |     |     |    
CLV         |  ☑  |     |     |     |     |      |      |      |      |     |     |     |    
CMP         |     |     |  ☐  |  ☐  |  ☐  |  ☐   |  ☐   |  ☐   |  ☐   |  ☐  |     |     |    
CPX         |     |     |  ☐  |  ☐  |  ☐  |      |      |      |      |     |     |     |    
CPY         |     |     |  ☐  |  ☐  |  ☐  |      |      |      |      |     |     |     |    
DEC         |     |     |  ☐  |  ☑  |     |  ☐   |      |      |      |  ☐  |     |     |    
DEX         |  ☑  |     |     |     |     |      |      |      |      |     |     |     |    
DEY         |  ☑  |     |     |     |     |      |      |      |      |     |     |     |    
EOR         |     |     |  ☐  |  ☐  |  ☐  |  ☐   |  ☐   |  ☐   |  ☐   |  ☐  |     |     |    
INC         |     |     |  ☐  |  ☐  |     |  ☐   |      |      |      |  ☐  |     |     |    
INX         |  ☑  |     |     |     |     |      |      |      |      |     |     |     |    
INY         |  ☑  |     |     |     |     |      |      |      |      |     |     |     |    
JMP         |     |     |  ☑  |     |     |      |      |      |      |     |     |     |  ☐ 
JSR         |     |     |  ☑  |     |     |      |      |      |      |     |     |     |    
LDA         |     |     |  ☑  |  ☑  |  ☑  |  ☑   |  ☑   |  ☑   |  ☑   |  ☑  |     |     |    
LDX         |     |     |  ☑  |  ☑  |  ☑  |      |  ☑   |      |      |     |  ☑  |     |    
LDY         |     |     |  ☑  |  ☑  |  ☑  |  ☑   |      |      |      |  ☐  |     |     |    
LSR         |  ☑  |  ☑  |  ☐  |  ☑  |     |  ☐   |      |      |      |  ☐  |     |     |    
NOP         |  ☑  |     |     |     |     |      |      |      |      |     |     |     |    
ORA         |     |     |  ☑  |  ☑  |  ☑  |  ☐   |  ☐   |  ☐   |  ☐   |  ☑  |     |     |    
PHA         |  ☑  |     |     |     |     |      |      |      |      |     |     |     |    
PHP         |  ☑  |     |     |     |     |      |      |      |      |     |     |     |    
PLA         |  ☑  |     |     |     |     |      |      |      |      |     |     |     |    
PLP         |  ☑  |     |     |     |     |      |      |      |      |     |     |     |    
ROL         |  ☐  |  ☐  |  ☐  |  ☐  |     |  ☐   |      |      |      |  ☐  |     |     |    
ROR         |  ☐  |  ☐  |  ☐  |  ☐  |     |  ☐   |      |      |      |  ☐  |     |     |    
RTI         |  ☐  |     |     |     |     |      |      |      |      |     |     |     |    
RTS         |  ☑  |     |     |     |     |      |      |      |      |     |     |     |    
SBC         |     |     |  ☐  |  ☐  |  ☐  |  ☐   |  ☐   |  ☐   |  ☐   |  ☐  |     |     |    
SEC         |  ☑  |     |     |     |     |      |      |      |      |     |     |     |    
SED         |  ☑  |     |     |     |     |      |      |      |      |     |     |     |    
SEI         |  ☑  |     |     |     |     |      |      |      |      |     |     |     |    
STA         |     |     |  ☑  |  ☑  |     |  ☑   |  ☑   |  ☑   |  ☑   |  ☑  |     |     |    
STX         |     |     |  ☑  |  ☑  |     |      |      |      |      |     |  ☑  |     |    
STY         |     |     |  ☑  |  ☑  |     |      |      |      |      |  ☑  |     |     |    
TAX         |  ☑  |     |     |     |     |      |      |      |      |     |     |     |    
TAY         |  ☑  |     |     |     |     |      |      |      |      |     |     |     |    
TSX         |  ☑  |     |     |     |     |      |      |      |      |     |     |     |    
TXA         |  ☑  |     |     |     |     |      |      |      |      |     |     |     |    
TXS         |  ☑  |     |     |     |     |      |      |      |      |     |     |     |    
TYA         |  ☑  |     |     |     |     |      |      |      |      |     |     |     |    
