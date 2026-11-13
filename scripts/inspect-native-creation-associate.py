"""Execute original associate-list5ca0 and selectiona900 complete instructions.

C2DA load/getters, allocation/string formatting and GUI/character-sheet services
are captured boundaries. No full panel preparation/name generator/commit/server
or pixels acceptance. No live process, key, server or GPU.
"""
import importlib.util
import json
from pathlib import Path

spec = importlib.util.spec_from_file_location('image', Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *

u = m.u
u.hook_del(m.hook_handle)
panel, table, wrapper, vtable, ids = [m.heap + n for n in [0x1000, 0x4000, 0x5000, 0x6000, 0x7000]]
ranges = [(0x1409c5ca0, 0x1409c6105), (0x1409ca900, 0x1409caab5)]
case, choices, calls, allocation, current = {}, [], [], 0, None


def allocate(size):
    global allocation
    pointer = m.heap + 0x10000 + allocation * 0x400
    assert size <= 0x400 and allocation < 900
    allocation += 1
    return pointer


def text(pointer):
    result = bytearray()
    while pointer and u.mem_read(pointer, 1)[0]:
        result.extend(u.mem_read(pointer, 1)); pointer += 1
    return result.decode('latin1')


def string(pointer, value):
    encoded = value.encode('latin1')
    data = allocate(len(encoded) + 1)
    u.mem_write(data, encoded + b'\0')
    m.wq(pointer, data); m.wi(pointer + 8, len(encoded)); m.wi(pointer + 12, len(encoded) + 1)


def hook(_u, address, _n, _):
    global current
    if address == m.stop:
        u.emu_stop(); return
    x, y, z, w = [u.reg_read(r) for r in [UC_X86_REG_RCX, UC_X86_REG_RDX, UC_X86_REG_R8, UC_X86_REG_R9]]
    if address in [0x140c10324, 0x140c10368]: m.finish(allocate(x))
    elif address == 0x140c10370: m.finish()
    elif address == 0x14018ded0:
        u.mem_write(x, text(y).lower().encode('latin1')[:16].ljust(17, b'\0')); m.finish(x)
    elif address == 0x14018dea0:
        u.mem_write(x, text(m.q(y)).lower().encode('latin1')[:16].ljust(17, b'\0')); m.finish(x)
    elif address == 0x1401a62b0:
        calls.append(['table', text(y)]); m.wi(x + 0x50, len(case['rows'])); m.finish(x)
    elif address == 0x1401a73a0: m.finish(1)
    elif address == 0x1401a7010:
        value = case['rows'][y]['title']; m.wi(w, value or 0); m.finish(int(value is not None))
    elif address == 0x1401a68f0:
        value = case['rows'][y]['base']
        if value is not None: string(w, value)
        m.finish(int(value is not None and len(value) > 0))
    elif address == 0x1408dcbc0:
        m.wq(x + 0xc0, wrapper); current = {'button': x}; m.finish(x)
    elif address == 0x1401e4950: m.finish(x)
    elif address in [0x1401fb710, 0x1409d1760, 0x1401e5c60, 0x1401eb5c0, m.stop + 0x10]: m.finish()
    elif address == 0x1401ed630:
        current['id'] = z & 0xffffffff; choices.append(current); m.finish()
    elif address == 0x1401fb890:
        current['title'] = y & 0xffffffff; m.finish()
    elif address == 0x1401eb800: calls.append(['enabled', y & 0xffffffff]); m.finish()
    elif address == 0x14016afb0:
        string(x, text(z) + f'{w & 0xffffffff:02d}'); m.finish()
    elif address == 0x14088ad50:
        calls.append(['preview', bytes(u.mem_read(y, 16)).split(b'\0')[0].decode('latin1'), z & 0xffffffff]); m.finish()
    elif not any(first <= address < last for first, last in ranges):
        raise AssertionError(f'Uncaptured original familiar dependency {address:x}')


u.hook_add(UC_HOOK_CODE, hook)


def invoke(address, *args):
    rsp = m.stack + 0x1fe08
    m.wq(rsp, m.stop); u.reg_write(UC_X86_REG_RSP, rsp)
    for reg, value in zip([UC_X86_REG_RCX, UC_X86_REG_RDX, UC_X86_REG_R8, UC_X86_REG_R9], args): u.reg_write(reg, value & 0xffffffffffffffff)
    u.emu_start(address, m.stop, count=500000)
    assert u.reg_read(UC_X86_REG_RIP) == m.stop


def run(value):
    global case, choices, calls, allocation, current
    case, choices, calls, allocation, current = value, [], [], 0, None
    u.mem_write(m.heap, bytes(0x100000)); u.mem_write(m.stack, bytes(0x20000))
    for offset in [0x68, 0x78]: m.wq(vtable + offset, m.stop + 0x10)
    m.wq(wrapper, vtable); m.wi(panel + 0x100, case['arcane'])
    invoke(0x1409c5ca0, panel)
    loaded = [{'id': row['id'], 'title': row['title']} for row in choices]
    # The list callbacks consume a visible list index and the original physical
    # row-ID vector. No guessed dense/sorted mapping is used here.
    m.wq(panel + 0x528, ids); m.wq(panel + 0xf8, m.heap + 0x9000)
    m.wi(panel + 0xa98, case['level'])
    for index, row in enumerate(loaded): m.wi(ids + index * 4, row['id'])
    selected = case['selected']
    if selected >= len(loaded): selected = -1
    before = len(calls)
    invoke(0x1409ca900, panel, selected)
    return {'input': case, 'entries': loaded, 'loadCalls': calls[:before],
            'selectedIndex': selected, 'selectionCalls': calls[before:]}


if __name__ == '__main__':
    output = m.root / 'godot-client/reports/native-creation-associate-original-v1.json'
    assert not output.exists(), 'Preserve original evidence'
    rows = []
    for at in range(180):
        physical = [{'title': None if (index + at) % 5 == 0 else (-1 if index % 7 == 0 else 100 + index),
                     'base': None if (index + at) % 7 == 0 else '' if index % 6 == 0 else ['Familiar', 'a_very_long_resource_base', 'Companion'][index % 3]}
                    for index in range(at % 17)]
        rows.append(run({'arcane': [0, 1, 2][at % 3], 'level': [1, 2, 20, 100, 255][at % 5],
                         'selected': [-1, 0, 1, 3][at % 4], 'rows': physical}))
    output.write_text(json.dumps({'target': m.digest, 'scope': __doc__,
                       'ranges': [[hex(a), hex(b)] for a, b in ranges], 'rows': rows}, indent=2) + '\n')
    print(json.dumps({'output': str(output), 'cases': len(rows), 'gpu': False, 'serverConnections': 0}))
