"""Execute complete original CResLTR236810 and name generator2359b0.

Resource bytes and deterministic15-bit RNG samples are authored inputs; heap,
memcpy/string/CRT case services and active NameFilter2DA are captured boundaries.
Not full name-table resolution, actual installed LTR, creator controls, server or
pixels acceptance. No live process/key/server/GPU.
"""
import importlib.util
import json
import hashlib
import struct
from pathlib import Path

spec = importlib.util.spec_from_file_location('image', Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u = m.u; u.hook_del(m.hook_handle)
owner, resource, header, result, vtable = [m.heap + n for n in [0x1000, 0x2000, 0x3000, 0x4000, 0x5000]]
source = m.heap + 0x90000
ranges = [(0x140236810, 0x140236f0d), (0x1402359b0, 0x140236089)]
allocation, seed, draws, case = 0, 0, 0, {}


def allocate(size):
    global allocation
    pointer = m.heap + 0x10000 + allocation
    allocation += (max(size, 1) + 15) & ~15
    assert pointer + size < source, (hex(pointer), size)
    return pointer


def text(pointer):
    result = bytearray()
    while pointer and u.mem_read(pointer, 1)[0]:
        result.extend(u.mem_read(pointer, 1)); pointer += 1
    return result.decode('latin1')


def string(pointer, value):
    data = value.encode('latin1'); p = allocate(len(data) + 1)
    u.mem_write(p, data + b'\0'); m.wq(pointer, p); m.wi(pointer + 8, len(data)); m.wi(pointer + 12, len(data) + 1)


def hook(_u, address, _n, _):
    global seed, draws
    if address == m.stop: u.emu_stop(); return
    x, y, z, w = [u.reg_read(r) for r in [UC_X86_REG_RCX, UC_X86_REG_RDX, UC_X86_REG_R8, UC_X86_REG_R9]]
    if address in [0x140c10324, 0x140c10368]: m.finish(allocate(x))
    elif address in [0x140c10370, 0x140c10410, 0x1401a9b10, m.stop + 0x10]: m.finish()
    elif address == 0x140c417f0:
        assert z < 0x80000; u.mem_write(x, bytes(u.mem_read(y, z))); m.finish(x)
    elif address == 0x140c7ed00:
        seed = (seed * 214013 + 2531011) & 0xffffffff; draws += 1
        assert draws <= 100000, 'Original authored RNG budget exceeded'
        m.finish((seed >> 16) & 32767)
    elif address == 0x140c7fec4: m.finish(ord(chr(x & 255).upper()))
    elif address == 0x14018ded0:
        u.mem_write(x, text(y).lower().encode('latin1')[:16].ljust(17, b'\0')); m.finish(x)
    elif address == 0x1401a62b0:
        m.wq(x, vtable); m.wi(x + 0x50, len(case.get('filters', []))); m.finish(x)
    elif address == 0x1401a73a0: m.finish(int(case.get('filterLoaded', False)))
    elif address == 0x1401a68f0:
        string(w, case['filters'][y]); m.finish(1)
    elif address == 0x14016ae00: m.finish(int(text(m.q(x)).lower() == text(m.q(y)).lower()))
    elif not any(first <= address < last for first, last in ranges):
        raise AssertionError(f'Uncaptured original name dependency {address:x}')


u.hook_add(UC_HOOK_CODE, hook)


def reset(value):
    global allocation, seed, draws, case
    allocation, seed, draws, case = 0, value.get('seed', 0), 0, value
    u.mem_write(m.heap, bytes(0x100000)); u.mem_write(m.stack, bytes(0x20000))
    m.wq(vtable, m.stop + 0x10); m.wq(vtable + 0x18, m.stop + 0x10)


def invoke(address, *args):
    rsp = m.stack + 0x1fe08; m.wq(rsp, m.stop); u.reg_write(UC_X86_REG_RSP, rsp)
    for register, value in zip([UC_X86_REG_RCX, UC_X86_REG_RDX, UC_X86_REG_R8, UC_X86_REG_R9], args): u.reg_write(register, value)
    u.emu_start(address, m.stop, count=3000000)
    assert u.reg_read(UC_X86_REG_RIP) == m.stop
    return u.reg_read(UC_X86_REG_RAX) & 0xffffffff


def probability(n, order, mode, index, left=0, right=0, sparse=False):
    if sparse and order == 3 and mode != 0 and (left * 3 + right) % 11 == 0: return 0.0
    scale = .75 if sparse and mode == 1 else .5 if sparse and mode == 2 else 1.0
    return struct.unpack('<f', struct.pack('<f', scale * (index + 1) / n))[0]


def content(n, sparse=False):
    values = []
    for mode in range(3): values += [probability(n, 1, mode, i, sparse=sparse) for i in range(n)]
    for left in range(n):
        for mode in range(3): values += [probability(n, 2, mode, i, left, sparse=sparse) for i in range(n)]
    for left in range(n):
        for right in range(n):
            for mode in range(3): values += [probability(n, 3, mode, i, left, right, sparse) for i in range(n)]
    return b'LTR V1.0' + bytes([n]) + struct.pack('<' + 'f' * len(values), *values)


def parsed_bytes(n):
    out = bytearray()
    for offset in [0x90, 0x98, 0xa0]: out += u.mem_read(m.q(resource + offset), n * 4)
    for left in range(n):
        for offset in [0x78, 0x80, 0x88]: out += u.mem_read(m.q(m.q(resource + offset) + left * 8), n * 4)
    for left in range(n):
        for right in range(n):
            for offset in [0x60, 0x68, 0x70]: out += u.mem_read(m.q(m.q(m.q(resource + offset) + left * 8) + right * 8), n * 4)
    return bytes(out)


def parser_case(n, kind):
    reset({}); data = content(n)
    if kind == 'trailing': data += b'extra bytes'
    elif kind == 'truncated': data = data[:-1]
    elif kind == 'wrong-header': data = b'BAD ' + data[4:]
    u.mem_write(source, data); m.wq(resource, vtable); m.wq(resource + 0x20, source); m.wi(resource + 0x30, len(data))
    result = invoke(0x140236810, resource)
    return {'input': {'count': n, 'kind': kind}, 'ready': bool(result),
            'probabilitySha256': hashlib.sha256(parsed_bytes(n)).hexdigest() if result else None}


def name_case(value):
    reset(value); n = value['count']; data = content(n, value['sparse'])
    u.mem_write(source, data); m.wq(resource, vtable); m.wq(resource + 0x20, source); m.wi(resource + 0x30, len(data))
    assert invoke(0x140236810, resource) == 1
    m.wq(owner + 8, resource)
    invoke(0x1402359b0, owner, result)
    return {'input': value, 'name': text(m.q(result)), 'draws': draws}


if __name__ == '__main__':
    output = m.root / 'godot-client/reports/native-name-generation-original-v1.json'
    assert not output.exists(), 'Preserve original evidence'
    parsers = [parser_case(n, kind) for n in [0, 1, 3, 4, 26, 28] for kind in ['exact', 'trailing', 'truncated', 'wrong-header'] if not (n == 0 and kind == 'truncated')]
    names = []
    for at in range(72):
        value = {'count': [3, 4, 28][at % 3], 'seed': 1 + at * 19937, 'sparse': bool(at % 2), 'filterLoaded': False, 'filters': []}
        first = name_case(value)
        if at % 4 == 0:
            value = value | {'filterLoaded': True, 'filters': [first['name'].lower(), 'NeverMatch']}
            first = name_case(value)
        names.append(first)
    output.write_text(json.dumps({'target': m.digest, 'scope': __doc__, 'ranges': [[hex(a), hex(b)] for a, b in ranges], 'parsers': parsers, 'names': names}, indent=2) + '\n')
    print(json.dumps({'output': str(output), 'parserCases': len(parsers), 'nameCases': len(names), 'gpu': False, 'serverConnections': 0}))
