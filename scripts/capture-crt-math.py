"""Independent installed Windows CRT math reference; never loads game code.

This checks the portable native-traced math against ucrtbase.dll, not the
exact CRT linked into the recorded game build. Keep that limitation in reports.
"""
import ctypes
import json
import random
import struct
import sys

crt = ctypes.CDLL('ucrtbase.dll')
functions = [crt.sinf, crt.cosf]
for function in functions:
    function.argtypes = [ctypes.c_float]
    function.restype = ctypes.c_float

def bits(value):
    return struct.unpack('<I', struct.pack('<f', value))[0]

randomizer = random.Random(20261013)
inputs = [0.0, -0.0, 2**-149, -2**-149, .0001220703125, .0078125,
          .7853981633974483, 1.5707963267948966, 3.141592653589793,
          6.283185307179586, -6.283185307179586, 32.0, -32.0]
inputs += [randomizer.uniform(-32, 32) for _ in range(25000)]
inputs += [randomizer.uniform(-.008, .008) for _ in range(5000)]
observations = [[bits(value), *[bits(function(value)) for function in functions]] for value in inputs]
with open(sys.argv[1], 'w', encoding='utf-8') as output:
    json.dump({'reference': 'installed Windows ucrtbase.dll, independent of game process and exact game CRT build',
               'observations': observations}, output)
