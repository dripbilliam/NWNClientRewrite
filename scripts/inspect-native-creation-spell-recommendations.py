"""Execute complete original7eb630 spell-preference helper instructions.

Active C2DA loading/conversions, spell-level/known-capacity/gain/minimum getters,
known-book mutations and allocation/GUI-free services are captured boundaries.
This is not full9c9df0 chooser recommendation/controller/loader acceptance.
No live process, credentials, server or GPU.
"""
import importlib.util
import json
import random
from pathlib import Path

spec = importlib.util.spec_from_file_location('image', Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *

u = m.u
u.hook_del(m.hook_handle)
stats, rule, cls, spell_array, spells, twodas, school_table, string, result_level, vtable = [
    m.heap + n for n in [0x1000, 0x8000, 0xb000, 0x12000, 0x20000, 0x40000, 0x41000, 0x50000, 0x51000, 0x52000]]
ranges = [(0x1407eb630, 0x1407eba2a), (0x1407eba30, 0x1407ebd37)]
case = {}
known = []
calls = []
allocation = 0
preference_table = 0


def byte(address, value):
    u.mem_write(address, bytes([value & 255]))


def level_for(pointer):
    return case['spells'][(pointer - spells) // 0x1b8]['level']


def hook(_u, address, _n, _):
    global allocation, preference_table
    if address == m.stop:
        u.emu_stop()
        return
    x, y, z, w = [u.reg_read(r) for r in [UC_X86_REG_RCX, UC_X86_REG_RDX, UC_X86_REG_R8, UC_X86_REG_R9]]
    if address == 0x1407f10a0:
        m.finish(0)
    elif address == 0x1407ec3a0:
        m.finish(case['intModifier'])
    elif address in [0x140c10324, 0x140c10368]:
        pointer = m.heap + 0x70000 + allocation * 0x100
        assert x <= 0x100
        allocation += 1
        m.finish(pointer)
    elif address == 0x140c10370 or address == m.stop + 0x10:
        m.finish()
    elif address == 0x14018dea0:
        m.finish(x)
    elif address == 0x1401a62b0:
        preference_table = x
        m.wq(x, vtable)
        m.wi(x + 0x50, len(case['preferences']))
        m.finish(x)
    elif address == 0x1401a73a0:
        m.finish(int(case['loaded']))
    elif address == 0x1401a7010:
        value = case['preferences'][y] if x == preference_table else case['opposition']
        m.wi(w, value or 0)
        m.finish(int(value is not None))
    elif address == 0x1402af4a0:
        identity = y & 0xffffffff
        m.finish(spells + identity * 0x1b8 if identity < len(case['spells']) else 0)
    elif address == 0x1402af530:
        m.finish(level_for(x))
    elif address == 0x1407f6b20:
        m.finish(case['gain'][z & 255] if z & 255 < 10 else 0)
    elif address == 0x1407f7130:
        m.finish(int(case['minimum'][z & 255]) if z & 255 < 10 else 0)
    elif address == 0x1407f69a0:
        m.finish(case['school'])
    elif address == 0x1407f66e0:
        m.finish(len(known[z & 255]) if z & 255 < 10 else 0)
    elif address == 0x1407f5c50:
        m.finish(known[z & 255][w & 255])
    elif address == 0x140299e70:
        m.finish(case['capacity'][z & 255] if z & 255 < 10 else 0)
    elif address == 0x1407ebed0:
        identity = z & 0xffffffff
        level = case['spells'][identity]['level']
        calls.append(['learn', identity])
        if identity not in known[level]:
            known[level].append(identity)
        m.finish()
    elif not any(first <= address < last for first, last in ranges):
        raise AssertionError(f'Uncaptured original spell recommendation dependency {address:x}')


u.hook_add(UC_HOOK_CODE, hook)


def run(value):
    global case, known, calls, allocation, preference_table
    case = value
    known = [row.copy() for row in case['known']]
    calls = []
    allocation = preference_table = 0
    u.mem_write(m.heap, bytes(0x100000))
    u.mem_write(m.stack, bytes(0x20000))
    m.wq(0x1412df8f8, rule)
    m.wq(rule + 0x110, cls)
    m.wq(rule + 0xd0, spell_array)
    m.wq(rule + 0x130, twodas)
    m.wq(twodas + 0x290, school_table)
    m.wi(cls + 0x4ec, int(case['memorizes']))
    m.wi(cls + 0x4f0, int(case['restricted']))
    byte(cls + 0x4e8, 3)
    byte(stats + 0x6a, 0)
    byte(stats + 0x296, case['classLevel'])
    byte(stats + 0x79, 14)
    m.wq(vtable, m.stop + 0x10)
    m.wq(string, m.heap + 0x53000)
    m.wq(string + 8, 8)
    u.mem_write(m.heap + 0x53000, b'fixture\0')
    byte(result_level, 0xa5)
    for identity, spell in enumerate(case['spells']):
        byte(spells + identity * 0x1b8 + 0x29, spell['school'])
    rsp = m.stack + 0x1fe08
    m.wq(rsp, m.stop)
    u.reg_write(UC_X86_REG_RSP, rsp)
    u.reg_write(UC_X86_REG_RCX, stats)
    u.reg_write(UC_X86_REG_RDX, string)
    u.reg_write(UC_X86_REG_R8, result_level)
    try:
        u.emu_start(0x1407eb630, m.stop, count=500000)
    except Exception:
        print(json.dumps(dict(input=case, rip=hex(u.reg_read(UC_X86_REG_RIP)), calls=calls)))
        raise
    assert u.reg_read(UC_X86_REG_RIP) == m.stop
    return {'input': case, 'output': {'remaining': u.reg_read(UC_X86_REG_RAX) & 255,
                                    'highest': u.mem_read(result_level, 1)[0],
                                    'known': known, 'calls': calls}}


if __name__ == '__main__':
    output = m.root / 'godot-client/reports/native-creation-spell-recommendations-original-v1.json'
    assert not output.exists(), 'Preserve original evidence'
    randomizer = random.Random(7130630)
    rows = []
    for at in range(480):
        definitions = [dict(id=identity, level=randomizer.choice([0, 0, 1, 1, 2, 5, 9, 255]), school=identity % 4)
                       for identity in range(4 + at % 17)]
        books = [[] for _ in range(10)]
        for spell in definitions:
            if spell['level'] < 10 and randomizer.randrange(7) == 0:
                books[spell['level']].append(spell['id'])
        preferences = [randomizer.choice([None, -1, len(definitions) + 4] + list(range(len(definitions))))
                       for _ in range(at % 25)]
        source = dict(memorizes=bool(at % 2), restricted=bool((at // 2) % 2),
                      loaded=at % 13 != 0, classLevel=[1, 2, 40][at % 3],
                      intModifier=[-2, 0, 2, 127, 128, 255][at % 6],
                      school=at % 3, opposition=[None, 0, 1, 255][at % 4],
                      spells=definitions, known=books, preferences=preferences,
                      gain=[randomizer.choice([0, 1, 2, 255]) for _ in range(10)],
                      minimum=[bool(randomizer.randrange(2)) for _ in range(10)],
                      capacity=[randomizer.choice([0, 0, 1, 3, 5]) for _ in range(10)])
        rows.append(run(source))
    output.write_text(json.dumps(dict(target=m.digest, scope=__doc__,
                                     ranges=[[hex(a), hex(b)] for a, b in ranges], rows=rows), indent=2) + '\n')
    print(json.dumps(dict(output=str(output), cases=len(rows), gpu=False, serverConnections=0)))
