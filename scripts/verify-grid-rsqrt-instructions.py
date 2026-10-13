"""Bounded independent SSE interpreter of hash-verified fast_rsqrt text.

Does not execute or copy original machine code. Finite positive observations
cover the [1,2] input domain used by native grid stop-tolerance projection.
"""
import json
import random
import re
import struct
import sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
source = (root / 'backups/animations/live-native-grid-owners-asm.txt').read_text()
data = source + (root / 'backups/animations/live-native-path-chooser-constants.txt').read_text()
constants = {}
for address, raw in re.findall(r'DATA (\w+): (\w+)', data):
    words = struct.unpack('<II', bytes.fromhex(raw))
    for offset, word in enumerate(words):
        constants[int(address, 16) + offset * 4] = word
body = source.split('FUNCTION REQUESTED 14022fd20')[1].split('FUNCTION REQUESTED')[0]
instructions = [(int(a, 16), op, args.strip()) for a, op, args in re.findall(r'^(\w+): (\w+)(.*)$', body, re.M)]

def number(raw):
    return struct.unpack('<f', struct.pack('<I', raw))[0]

def bits(value):
    return struct.unpack('<I', struct.pack('<f', value))[0]

def run(input_bits):
    registers, stack = {'xmm0': input_bits}, {}
    for index, (address, op, args) in enumerate(instructions):
        if op == 'ret':
            return registers['xmm0']
        following = instructions[index + 1][0]
        operands = [operand.strip() for operand in args.split(',')]

        def location(operand):
            match = re.search(r'\[(rsp|rip) \+ (0x\w+|\d+)\]', operand)
            base, offset = match.groups()
            return (stack, int(offset, 0)) if base == 'rsp' else (constants, following + int(offset, 0))

        def read(operand):
            if 'ptr [' in operand:
                memory, offset = location(operand)
                return memory[offset]
            return int(operand, 0) if operand.startswith('0x') or operand.isnumeric() else registers[operand]

        def write(operand, raw):
            if 'ptr [' in operand:
                memory, offset = location(operand)
                if memory is constants:
                    raise ValueError('Attempted constant write')
                memory[offset] = raw & 0xffffffff
            else:
                registers[operand] = raw & 0xffffffff

        if op in ['mov', 'movss', 'movaps']:
            write(operands[0], read(operands[1]))
        elif op == 'sar':
            signed = struct.unpack('<i', struct.pack('<I', read(operands[0])))[0]
            write(operands[0], signed >> read(operands[1]))
        elif op == 'sub':
            write(operands[0], read(operands[0]) - read(operands[1]))
        elif op in ['mulss', 'subss']:
            a, b = number(read(operands[0])), number(read(operands[1]))
            write(operands[0], bits(a * b if op == 'mulss' else a - b))
        else:
            raise ValueError(f'Unsupported instruction {address:x}: {op} {args}')
    raise ValueError('No return instruction')

rng = random.Random(20261013)
inputs = [0x3f800000, 0x40000000, 0x3fc00000]
inputs += [rng.randrange(0x3f800000, 0x40000001) for _ in range(50000)]
observations = [[raw, run(raw)] for raw in inputs]
Path(sys.argv[1]).write_text(json.dumps({'reference': 'independent SSE interpreter of recorded fast_rsqrt14022fd20; finite [1,2] inputs; FP flags excluded', 'observations': observations}))
print(json.dumps({'instructionInputs': len(observations)}))
