# GD6502
A [6502](https://en.wikipedia.org/wiki/MOS_Technology_6502) emulator in the Godot game engine designed to be usable in emulators of 6502-based platforms.

To add GD6502 to your project (assuming you're using Git), add it as a submodule by running `git submodule add https://github.com/eggbertx/GD6502 addons/GD6502` from the root directory of your project.

To limit dependences, unit tests for this project are stored in the [GD6502-IDE](https://github.com/Eggbertx/GD6502-IDE) repository.

## Opcodes
Here is a table of the implemented opcodes. An empty checkbox means that it hasn't been implemented yet.
N/A means that the addressing mode does not exist for the respective instruction.

Instruction | IMP | ACC | ABS | ZP  | IMM | ABSX | ABSY | INDX | INDY | ZPX | ZPY | REL | IND
------------|-----|-----|-----|-----|-----|------|------|------|------|-----|-----|-----|------
ADC         | N/A | N/A | [ ] | [ ] | [ ] | [ ]  | [ ]  | [ ]  | [ ]  | [ ] | N/A | N/A | N/A
AND         | N/A | N/A | [ ] | [x] | [x] | [ ]  | [ ]  | [ ]  | [ ]  | [x] | N/A | N/A | N/A
ASL         | N/A | [ ] | [ ] | [ ] | N/A | [ ]  | N/A  | N/A  | N/A  | [ ] | N/A | N/A | N/A
BCC         | N/A | N/A | N/A | N/A | N/A | N/A  | N/A  | N/A  | N/A  | N/A | N/A | [ ] | N/A
BCS         | N/A | N/A | N/A | N/A | N/A | N/A  | N/A  | N/A  | N/A  | N/A | N/A | [ ] | N/A
BEQ         | N/A | N/A | N/A | N/A | N/A | N/A  | N/A  | N/A  | N/A  | N/A | N/A | [ ] | N/A
BIT         | N/A | N/A | [ ] | [ ] | N/A | N/A  | N/A  | N/A  | N/A  | N/A | N/A | N/A | N/A
BMI         | N/A | N/A | N/A | N/A | N/A | N/A  | N/A  | N/A  | N/A  | N/A | N/A | [ ] | N/A
BNE         | N/A | N/A | N/A | N/A | N/A | N/A  | N/A  | N/A  | N/A  | N/A | N/A | [ ] | N/A
BPL         | N/A | N/A | N/A | N/A | N/A | N/A  | N/A  | N/A  | N/A  | N/A | N/A | [ ] | N/A
BRK         | [x] | N/A | N/A | N/A | N/A | N/A  | N/A  | N/A  | N/A  | N/A | N/A | N/A | N/A
BVC         | N/A | N/A | N/A | N/A | N/A | N/A  | N/A  | N/A  | N/A  | N/A | N/A | [ ] | N/A
BVS         | N/A | N/A | N/A | N/A | N/A | N/A  | N/A  | N/A  | N/A  | N/A | N/A | [ ] | N/A
CLC         | [x] | N/A | N/A | N/A | N/A | N/A  | N/A  | N/A  | N/A  | N/A | N/A | N/A | N/A
CLD         | [x] | N/A | N/A | N/A | N/A | N/A  | N/A  | N/A  | N/A  | N/A | N/A | N/A | N/A
CLI         | [x] | N/A | N/A | N/A | N/A | N/A  | N/A  | N/A  | N/A  | N/A | N/A | N/A | N/A
CLV         | [x] | N/A | N/A | N/A | N/A | N/A  | N/A  | N/A  | N/A  | N/A | N/A | N/A | N/A
CMP         | N/A | N/A | [ ] | [ ] | [ ] | [ ]  | [ ]  | [ ]  | [ ]  | [ ] | N/A | N/A | N/A
CPX         | N/A | N/A | [ ] | [ ] | [ ] | N/A  | N/A  | N/A  | N/A  | N/A | N/A | N/A | N/A
CPY         | N/A | N/A | [ ] | [ ] | [ ] | N/A  | N/A  | N/A  | N/A  | N/A | N/A | N/A | N/A
DEC         | N/A | N/A | [ ] | [x] | N/A | [ ]  | N/A  | N/A  | N/A  | [ ] | N/A | N/A | N/A
DEX         | [x] | N/A | N/A | N/A | N/A | N/A  | N/A  | N/A  | N/A  | N/A | N/A | N/A | N/A
DEY         | [x] | N/A | N/A | N/A | N/A | N/A  | N/A  | N/A  | N/A  | N/A | N/A | N/A | N/A
EOR         | N/A | N/A | [ ] | [ ] | [ ] | [ ]  | [ ]  | [ ]  | [ ]  | [ ] | N/A | N/A | N/A
INC         | N/A | N/A | [ ] | [ ] | N/A | [ ]  | N/A  | N/A  | N/A  | [ ] | N/A | N/A | N/A
INX         | [x] | N/A | N/A | N/A | N/A | N/A  | N/A  | N/A  | N/A  | N/A | N/A | N/A | N/A
INY         | [x] | N/A | N/A | N/A | N/A | N/A  | N/A  | N/A  | N/A  | N/A | N/A | N/A | N/A
JMP         | N/A | N/A | [x] | N/A | N/A | N/A  | N/A  | N/A  | N/A  | N/A | N/A | N/A | [ ]
JSR         | N/A | N/A | [ ] | N/A | N/A | N/A  | N/A  | N/A  | N/A  | N/A | N/A | N/A | N/A
LDA         | N/A | N/A | [x] | [x] | [x] | [x]  | [x]  | [x]  | [x]  | [x] | N/A | N/A | N/A
LDX         | N/A | N/A | [x] | [x] | [x] | N/A  | [x]  | N/A  | N/A  | N/A | [x] | N/A | N/A
LDY         | N/A | N/A | [x] | [x] | [x] | [x]  | N/A  | N/A  | N/A  | [ ] | N/A | N/A | N/A
LSR         | [ ] | [ ] | [ ] | [ ] | N/A | [ ]  | N/A  | N/A  | N/A  | [ ] | N/A | N/A | N/A
NOP         | [ ] | N/A | N/A | N/A | N/A | N/A  | N/A  | N/A  | N/A  | N/A | N/A | N/A | N/A
ORA         | N/A | N/A | [x] | [x] | [x] | [ ]  | [ ]  | [ ]  | [ ]  | [x] | N/A | N/A | N/A
PHA         | [ ] | N/A | N/A | N/A | N/A | N/A  | N/A  | N/A  | N/A  | N/A | N/A | N/A | N/A
PHP         | [ ] | N/A | N/A | N/A | N/A | N/A  | N/A  | N/A  | N/A  | N/A | N/A | N/A | N/A
PLA         | [ ] | N/A | N/A | N/A | N/A | N/A  | N/A  | N/A  | N/A  | N/A | N/A | N/A | N/A
PLP         | [ ] | N/A | N/A | N/A | N/A | N/A  | N/A  | N/A  | N/A  | N/A | N/A | N/A | N/A
ROL         | [ ] | [ ] | [ ] | [ ] | N/A | [ ]  | N/A  | N/A  | N/A  | [ ] | N/A | N/A | N/A
ROR         | [ ] | [ ] | [ ] | [ ] | N/A | [ ]  | N/A  | N/A  | N/A  | [ ] | N/A | N/A | N/A
RTI         | [ ] | N/A | N/A | N/A | N/A | N/A  | N/A  | N/A  | N/A  | N/A | N/A | N/A | N/A
RTS         | [ ] | N/A | N/A | N/A | N/A | N/A  | N/A  | N/A  | N/A  | N/A | N/A | N/A | N/A
SBC         | N/A | N/A | [ ] | [ ] | [ ] | [ ]  | [ ]  | [ ]  | [ ]  | [ ] | N/A | N/A | N/A
SEC         | [x] | N/A | N/A | N/A | N/A | N/A  | N/A  | N/A  | N/A  | N/A | N/A | N/A | N/A
SED         | [ ] | N/A | N/A | N/A | N/A | N/A  | N/A  | N/A  | N/A  | N/A | N/A | N/A | N/A
SEI         | [x] | N/A | N/A | N/A | N/A | N/A  | N/A  | N/A  | N/A  | N/A | N/A | N/A | N/A
STA         | N/A | N/A | [x] | [x] | N/A | [x]  | [x]  | [x]  | [x]  | [x] | N/A | N/A | N/A
STX         | N/A | N/A | [x] | [x] | N/A | N/A  | N/A  | N/A  | N/A  | N/A | [x] | N/A | N/A
STY         | N/A | N/A | [x] | [x] | N/A | N/A  | N/A  | N/A  | N/A  | [x] | N/A | N/A | N/A
TAX         | [x] | N/A | N/A | N/A | N/A | N/A  | N/A  | N/A  | N/A  | N/A | N/A | N/A | N/A
TAY         | [x] | N/A | N/A | N/A | N/A | N/A  | N/A  | N/A  | N/A  | N/A | N/A | N/A | N/A
TSX         | [ ] | N/A | N/A | N/A | N/A | N/A  | N/A  | N/A  | N/A  | N/A | N/A | N/A | N/A
TXA         | [x] | N/A | N/A | N/A | N/A | N/A  | N/A  | N/A  | N/A  | N/A | N/A | N/A | N/A
TXS         | [ ] | N/A | N/A | N/A | N/A | N/A  | N/A  | N/A  | N/A  | N/A | N/A | N/A | N/A
TYA         | [x] | N/A | N/A | N/A | N/A | N/A  | N/A  | N/A  | N/A  | N/A | N/A | N/A | N/A