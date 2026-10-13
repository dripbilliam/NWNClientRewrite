"""Evaluate the recorded target's finite asinf instructions independently.

This is a bounded instruction interpreter, not execution of original game code.
It reads hash-verified textual disassembly/constants saved by inspect-combat.py.
No expected results are taken from the JavaScript port or installed CRT.
FP status writes are ignored; exceptional input branches are deliberately rejected.
"""
import json
import math
import re
import struct
import sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
text = (root / 'backups/animations/live-native-orbit-math-asm.txt').read_text()
text += (root / 'backups/animations/live-native-asin-extra-data.txt').read_text()
constants = {int(a, 16): struct.unpack('<I', bytes.fromhex(raw)[:4])[0]
             for a, raw in re.findall(r'DATA (\w+): (\w+)', text)}
body = text.split('FUNCTION REQUESTED 140c7a9a8')[1].split('FUNCTION REQUESTED')[0]
instructions = [(int(a, 16), op, args.strip()) for a, op, args in re.findall(r'^(\w+): (\w+)(.*)$', body, re.M)]
code = {address: (op, args, instructions[i + 1][0] if i + 1 < len(instructions) else None)
        for i, (address, op, args) in enumerate(instructions)}

def value(raw):
    return struct.unpack('<f', struct.pack('<I', raw))[0]

def raw(number):
    return struct.unpack('<I', struct.pack('<f', number))[0]

def run(input_bits):
    registers = {'xmm0': input_bits}
    stack = {}
    pc = 0x140c7a9a8
    equal = less = negative = False

    def memory(operand, next_pc):
        match = re.search(r'\[(rsp|rip) \+ (0x\w+)\]', operand)
        if not match:
            raise ValueError(f'Unsupported operand {operand}')
        base, offset = match.groups()
        return constants if base == 'rip' else stack, (next_pc if base == 'rip' else 0) + int(offset, 16)

    def read(operand, next_pc):
        if 'ptr [' in operand:
            store, key = memory(operand, next_pc)
            return store[key]
        if operand == 'al':
            return registers['eax'] & 255
        if operand.startswith('0x') or operand.isnumeric():
            return int(operand, 0)
        return registers[operand]

    def write(operand, number, next_pc):
        if 'ptr [' in operand:
            store, key = memory(operand, next_pc)
            if store is constants:
                raise ValueError('Instruction attempted constant write')
            store[key] = number & 0xffffffff
        else:
            registers[operand] = number & 0xffffffff

    for _ in range(200):
        op, args, next_pc = code[pc]
        operands = [v.strip() for v in args.split(',')]
        jump = None
        if op == 'ret':
            return registers['xmm0']
        if 'xmmword ptr [rsp' in args or operands[0] == 'rsp':
            pass  # Stack allocation and save/restore of callee-saved xmm6.
        elif op in ['mov', 'movzx', 'movss', 'movaps']:
            write(operands[0], read(operands[1], next_pc), next_pc)
        elif op in ['and', 'shr', 'btr', 'xorps']:
            a = 0 if op == 'and' and operands[1] == '0' else read(operands[0], next_pc) if operands[0] in registers or 'ptr' in operands[0] else 0
            b = read(operands[1], next_pc) if operands[1] != operands[0] else a
            answer = a & b if op == 'and' else a >> b if op == 'shr' else a & ~(1 << b) if op == 'btr' else a ^ b
            write(operands[0], answer, next_pc)
        elif op in ['mulss', 'addss', 'subss', 'divss']:
            a, b = value(read(operands[0], next_pc)), value(read(operands[1], next_pc))
            answer = a * b if op == 'mulss' else a + b if op == 'addss' else a - b if op == 'subss' else a / b
            write(operands[0], raw(answer), next_pc)
        elif op == 'sqrtss':
            write(operands[0], raw(math.sqrt(value(read(operands[1], next_pc)))), next_pc)
        elif op in ['cmp', 'ucomiss']:
            a, b = read(operands[0], next_pc), read(operands[1], next_pc)
            if op == 'ucomiss':
                a, b = value(a), value(b)
            equal, less, negative = a == b, a < b, a < b
        elif op == 'test':
            answer = read(operands[0], next_pc) & read(operands[1], next_pc)
            equal, negative = answer == 0, bool(answer & 0x80000000)
        elif op.startswith('j'):
            taken = {'jmp': True, 'jb': less, 'jbe': less or equal, 'je': equal, 'jne': not equal, 'jns': not negative, 'jp': False}[op]
            if taken:
                jump = int(operands[0], 16)
        elif op == 'call':
            if operands[0] != '0x140cae8e0':
                raise ValueError('Exceptional asinf branch is outside the reference domain')
        else:
            raise ValueError(f'Unsupported instruction {pc:x}: {op} {args}')
        pc = jump or next_pc
    raise ValueError('Instruction reference exceeded step limit')

capture = json.loads(Path(sys.argv[1]).read_text())
observations = [[input_bits, run(input_bits)] for input_bits, _ in capture['asin']]
Path(sys.argv[2]).write_text(json.dumps({'reference': 'independent finite SSE instruction interpreter of recorded target asinf140c7a9a8; FP flags excluded', 'asin': observations}))
print(json.dumps({'instructionInputs': len(observations)}))
