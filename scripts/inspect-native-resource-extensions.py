"""Execute original extension-table builder15d630 and lookup1602b0.

Allocation/vector-string construction, copying and boolean case-insensitive
string equality are captured boundaries. No filesystem enumeration or installed
game process is run. The entire physical table and complete lookups execute.
"""
import importlib.util
import json
from pathlib import Path
spec = importlib.util.spec_from_file_location('image', Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u = m.u; u.hook_del(m.hook_handle)
owner, query = m.heap + 0x1000, m.heap + 0x3000
allocation = 0
ranges = [(0x14015d630, 0x14015f3cd), (0x1401602b0, 0x14016031a)]


def allocate(size):
    global allocation
    pointer = m.heap + 0x10000 + allocation
    allocation += (max(size, 1) + 15) & ~15
    assert allocation < 0x80000
    return pointer


def string(pointer):
    return bytes(u.mem_read(m.q(pointer), m.si(pointer + 8))).decode('latin1') if m.q(pointer) else ''


def hook(_u, address, _n, _):
    if address == m.stop: u.emu_stop(); return
    x, y, z, w = [u.reg_read(r) for r in [UC_X86_REG_RCX, UC_X86_REG_RDX, UC_X86_REG_R8, UC_X86_REG_R9]]
    if address == 0x140c10368: m.finish(allocate(x))
    elif address == 0x140c10370: m.finish()
    elif address == 0x140c11414: u.mem_write(x, bytes(y * z)); m.finish()
    elif address == 0x14003d8c0:
        if z & 0xffffffff == 0xffffffff:
            z = 0
            while u.mem_read(y + z, 1)[0]:
                z += 1
                assert z < 1024
        p = allocate(z + 1); u.mem_write(p, bytes(u.mem_read(y, z)) + b'\0'); m.wq(x, p); m.wi(x + 8, z); m.wi(x + 12, z + 1); m.finish()
    elif address == 0x14016ae00: m.finish(int(string(x).lower() == string(y).lower()))
    elif not any(first <= address < last for first, last in ranges): raise AssertionError(f'Uncaptured extension dependency {address:x}')


u.hook_add(UC_HOOK_CODE, hook)


def invoke(address, *args):
    rsp = m.stack + 0x1fe08; m.wq(rsp, m.stop); u.reg_write(UC_X86_REG_RSP, rsp)
    for reg, value in zip([UC_X86_REG_RCX, UC_X86_REG_RDX, UC_X86_REG_R8, UC_X86_REG_R9], args): u.reg_write(reg, value)
    u.emu_start(address, m.stop, count=1000000)
    assert u.reg_read(UC_X86_REG_RIP) == m.stop
    return u.reg_read(UC_X86_REG_RAX) & 65535


if __name__ == '__main__':
    output = m.root / 'godot-client/reports/native-resource-extensions-original-v1.json'
    assert not output.exists(), 'Preserve original evidence'
    u.mem_write(m.heap, bytes(0x100000)); invoke(0x14015d630, owner)
    rows = [{'extension': string(m.q(owner + 0x10) + i * 16),
             'type': int.from_bytes(u.mem_read(m.q(owner + 8) + i * 2, 2), 'little')}
            for i in range(m.si(owner))]
    lookups = []
    for value in [entry['extension'] for entry in rows] + [entry['extension'].upper() for entry in rows] + ['unknown', 'no_extension', '', '.ltr', 'ltr\t']:
        raw = value.encode('latin1'); u.mem_write(query + 0x100, raw + b'\0'); m.wq(query, query + 0x100); m.wi(query + 8, len(raw))
        lookups.append({'extension': value, 'type': invoke(0x1401602b0, owner, query)})
    output.write_text(json.dumps({'target': m.digest, 'scope': __doc__, 'ranges': [[hex(a), hex(b)] for a, b in ranges], 'rows': rows, 'lookups': lookups}, indent=2) + '\n')
    print(json.dumps({'output': str(output), 'entries': len(rows), 'lookups': len(lookups), 'missingBefore': [r for r in rows if r['extension'] in ['ltr', 'utc', 'bic', 'utm', 'uts', 'ute', 'utt']]}))
