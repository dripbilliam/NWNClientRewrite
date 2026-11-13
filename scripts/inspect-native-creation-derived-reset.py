"""Execute the complete original CG_MAIN draft-reset routine and its feat-list,
known-spell and memorized-slot clearing helpers. Skill-budget/modifier queries,
rule feat queries, array allocation operations and frees are explicit providers.
This is read-only CPU evidence, not character saving, renderer or server proof.
"""
from pathlib import Path
import importlib.util, itertools, json, struct

root = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('pinned_nwn_image', root / 'scripts/inspect-native-intratile-coordinator.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
u = m.u
u.hook_del(m.hook_handle)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import UC_X86_REG_RCX, UC_X86_REG_RDX, UC_X86_REG_R8, UC_X86_REG_RSP, UC_X86_REG_RIP

stats, rules, ranks, additions, feats, granted, pending = [m.heap + n * 0x4000 for n in range(7)]
race_table, class_table, feat_table, resources = [m.heap + n * 0x4000 for n in range(7, 11)]
ranges = [(0x1407edcc0, 0x1407edfdb), (0x1407ed6d0, 0x1407ed7db),
          (0x1407edbf0, 0x1407edcb6), (0x1407ed920, 0x1407ed9ba)]

def word(address, value): u.mem_write(address, struct.pack('<H', value & 0xffff))
def byte(address, value): u.mem_write(address, bytes([value & 255]))
def words(address, count): return list(struct.unpack('<' + 'H' * count, bytes(u.mem_read(address, count * 2))))

def hook(_u, address, _size, _data):
    if address == m.stop: u.emu_stop(); return
    x, y, z = [u.reg_read(r) for r in [UC_X86_REG_RCX, UC_X86_REG_RDX, UC_X86_REG_R8]]
    if address == 0x1407ec0c0:
        calls.append(['skill-budget']); word(stats + 0x10e, case['budget']); m.finish()
    elif address == 0x1407fadc0:
        calls.append(['recompute-skill-modifiers']); m.finish()
    elif address == 0x140c42060:
        calls.append(['memset', 'ranks' if x == ranks else 'additions', y, z])
        u.mem_write(x, bytes([y & 255]) * z); m.finish(x)
    elif address == 0x140c417f0:
        if z: u.mem_write(x, bytes(u.mem_read(y, z)))
        m.finish(x)
    elif address == 0x140c10360:
        calls.append(['free', y]); m.finish()
    elif address == 0x1402a3bd0:
        calls.append(['feat', y & 0xffff]); m.finish(feat_table + y * 0x100 if y != 0 else 0)
    elif address == 0x1407f5d70: m.finish(case['firstLevel'])
    elif address == 0x1402a19a0: m.finish(int((y & 0xffff) in [1, 2]))
    elif address == 0x14029a130:
        if (y & 0xffff) in [2, 3, 4]: byte(z, 2 if y == 3 else 1); m.finish(1)
        else: m.finish(0)
    elif address == 0x140296910: m.finish(int((y & 0xffff) in words(m.q(x), m.si(x + 8))))
    elif address == 0x1400a1bb0:
        count = m.si(x + 8); word(m.q(x) + count * 2, y); m.wi(x + 8, count + 1); m.finish()
    elif address == 0x14018de80: u.mem_write(x, bytes(u.mem_read(y, 17))); m.finish(x)
    elif address == 0x140115890: calls.append(['warning']); m.finish()
    elif not any(lo <= address <= hi for lo, hi in ranges):
        raise RuntimeError(f'Unmapped original dependency {address:x}')

u.hook_add(UC_HOOK_CODE, hook)

def run(value):
    global case, calls
    case, calls = value, []
    u.mem_write(m.heap, bytes(0x100000))
    m.wq(0x1412df8f8, rules); m.wq(rules + 0x110, class_table); m.wq(rules + 0x118, race_table)
    word(rules + 0x100, value['featCount'])
    byte(stats + 0x69, value['classes']); byte(stats + 0x6a, 0); word(stats + 0x50, 0)
    m.wi(stats + 0x94, value['racialAdjustment']); m.wi(stats + 0xe0, 177); word(stats + 0x10e, 65530)
    m.wq(stats + 0xd0, ranks); m.wq(stats + 0xd8, additions)
    u.mem_write(ranks, bytes([17]) * 256); u.mem_write(additions, bytes([18]) * 256)
    for pointer, array, count in [(0x118, feats, 3), (0x128, granted, 2), (0x138, pending, 2)]:
        m.wq(stats + pointer, array); m.wi(stats + pointer + 8, count)
    for n, feat in enumerate([9, 10, 11]): word(feats + 2 * n, feat)
    m.wq(pending, m.heap + 0xd0000); m.wq(pending + 8, m.heap + 0xd0100)
    m.wq(stats + 0xc18, resources); m.wi(stats + 0xc20, 3)
    slots = []
    for index in range(9):
        cls = stats + 0x148 + index * 0x150
        byte(cls + 0x14a, 7); byte(cls + 0x14b, index + 10); byte(cls + 0x14c, index + 30)
        byte(cls + 0x14d, 0); byte(cls + 0x14e, value['level'])
        if index >= value['classes']: continue
        for level in range(10):
            # Distinct actual backing arrays for known lists and prepared slots.
            backing = m.heap + 0x40000 + (index * 10 + level) * 0x100
            m.wq(cls + level * 16, backing); m.wi(cls + level * 16 + 8, 2)
            m.wq(cls + 0xa0 + level * 16, backing + 0x40); m.wi(cls + 0xa8 + level * 16, 2)
            m.wi(backing, level + 100); m.wi(backing + 4, level + 200)
            m.wq(backing + 0x40, backing + 0x80); m.wq(backing + 0x48, backing + 0xa0)
            slots.append((cls, level, backing))
    rsp = m.stack + 0x1fe08
    u.mem_write(rsp - 0x100, bytes(0x200)); m.wq(rsp, m.stop)
    u.reg_write(UC_X86_REG_RSP, rsp); u.reg_write(UC_X86_REG_RCX, stats)
    u.emu_start(0x1407edcc0, m.stop, count=100000)
    assert u.reg_read(UC_X86_REG_RIP) == m.stop
    output = dict(points=m.si(stats + 0xe0), budget=words(stats + 0x10e, 1)[0],
        ranks=list(u.mem_read(ranks, 256)), additions=list(u.mem_read(additions, 256)),
        feats=words(feats, m.si(stats + 0x120)), pending=m.si(stats + 0x140),
        granted=m.si(stats + 0x130), resources=m.si(stats + 0xc20),
        domains=[list(u.mem_read(stats + 0x293 + n * 0x150, 2)) for n in range(9)],
        adjacent=[list(u.mem_read(stats + 0x292 + n * 0x150, 5)) for n in range(9)],
        known=[m.si(cls + level * 16 + 8) for cls, level, _ in slots],
        memorized=[list(u.mem_read(backing + 0x40, 16)) for _, _, backing in slots])
    assert output['points'] == 0 and output['budget'] == value['budget']
    assert output['ranks'] == [0] * 255 + [17] and output['additions'] == [0] * 255 + [18]
    assert output['pending'] == output['granted'] == output['resources'] == 0
    assert all(count == 0 for count in output['known']) and all(v == [0] * 16 for v in output['memorized'])
    assert all(v == ([255, 255] if n < min(8, value['classes']) else [n + 10, n + 30]) for n, v in enumerate(output['domains']))
    assert all(v[0] == 7 and v[3:] == [0, value['level']] for v in output['adjacent'])
    return dict(input=value, output=output, calls=calls)

if __name__ == '__main__':
    path = root / 'backups/animations/native-creation-derived-reset-v1.json'
    if path.exists(): raise RuntimeError('Original evidence already exists')
    rows = [run(dict(classes=count, featCount=feats, firstLevel=first, racialAdjustment=adjust,
                     budget=budget, level=level))
            for count, feats, first, adjust, budget, level in itertools.product([0, 1, 2, 8, 9], [0, 5], [0, 1], [0, 1], [4, 32], [1, 2])]
    report = dict(binarySha256=m.digest, scope=__doc__, entry='0x1407edcc0',
                  originalHelpers=[hex(a) for a, _ in ranges[1:]], rows=rows)
    path.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(dict(output=str(path), rows=len(rows), binarySha256=m.digest)))
