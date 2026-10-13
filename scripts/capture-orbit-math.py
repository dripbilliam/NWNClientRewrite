"""Independent installed CRT reference, not the exact embedded game CRT."""
import ctypes
import json
import random
import struct
import sys

crt = ctypes.CDLL('ucrtbase.dll')
crt.asinf.argtypes = [ctypes.c_float]
crt.asinf.restype = ctypes.c_float
crt.atan2f.argtypes = [ctypes.c_float, ctypes.c_float]
crt.atan2f.restype = ctypes.c_float

def bits(value):
    return struct.unpack('<I', struct.pack('<f', value))[0]

def number(raw):
    return struct.unpack('<f', struct.pack('<I', raw))[0]

rng = random.Random(20261013)
asin = [0., -0., 1., -1., .5, -.5, 2**-149, -2**-149]
asin += [number(raw + offset) for raw in [0x387fffff, 0x38800000, 0x3effffff, 0x3f000000, 0x3f7ffffe] for offset in range(-2, 3)]
asin += [rng.uniform(-1, 1) for _ in range(50000)]
axes = [0., -0., 1., -1., 2**-149, -2**-149, 2**-126, -2**-126, number(0x7f7fffff), number(0xff7fffff)]
atan = [(y, x) for y in axes for x in axes]
atan += [(rng.uniform(-1, 1), rng.uniform(-1, 1)) for _ in range(50000)]
atan += [(number(rng.randrange(0x7f800000) | rng.randrange(2) << 31), number(rng.randrange(0x7f800000) | rng.randrange(2) << 31)) for _ in range(10000)]
with open(sys.argv[1], 'w', encoding='utf-8') as output:
    json.dump({'reference': 'installed Windows ucrtbase.dll; not exact embedded game CRT or process floating state',
               'asin': [[bits(x), bits(crt.asinf(x))] for x in asin],
               'atan2': [[bits(y), bits(x), bits(crt.atan2f(y, x))] for y, x in atan]}, output)
