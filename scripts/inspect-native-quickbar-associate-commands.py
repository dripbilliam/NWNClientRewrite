"""Execute original associate Commands builders and party lookup/cursor bodies.

CRadialMenu allocation/construction/SetEntry/SetSubMenu, current creature/party
lookup, full-name string lookup/free and the final quickslot setter are captured
boundaries. Party count/first/next/remaining/raw-index lookup, all three menu
builders and995f10's callback packing execute original machine code unchanged.
No live process, network, game state, renderer or original game file is changed.
"""
from pathlib import Path
import sys, json, hashlib, importlib
sys.dont_write_bytecode = True
root = Path(__file__).resolve().parents[1]
label = sys.argv[1] if len(sys.argv) == 2 else ''
if not label or any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789-' for c in label):
    raise RuntimeError('Supply a unique evidence label')
directory = root / 'godot-client/.cache/quickbar-associate-cpu' / label
if directory.exists():
    raise RuntimeError('Existing evidence preserved')
directory.mkdir(parents=True)
sys.path.insert(0, str(Path(__file__).resolve().parent))
m = importlib.import_module('inspect-native-intratile-coordinator')
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import UC_X86_REG_RCX, UC_X86_REG_RDX, UC_X86_REG_R8, UC_X86_REG_R9, UC_X86_REG_RSP, UC_X86_REG_RAX, UC_X86_REG_RIP
u = m.u
u.hook_del(m.hook_handle)
evidence = json.loads((root / 'godot-client/reports/native-quickbar-associate-commands-original-v1.json').read_text())
extra = json.loads((root / 'godot-client/reports/native-quickbar-associate-index-original-v1.json').read_text())
assert evidence['binarySha256'] == extra['binarySha256'] == m.digest
addresses = {0x1409945d0, 0x14098f7d0, 0x140992240, 0x1408520c0, 0x140851dd0,
             0x140851ff0, 0x140852180, 0x140851d80, 0x140851d00, 0x140995f10}
ranges = []
for record in evidence['records'] + [extra]:
    if int(record['procedure']['address'], 16) in addresses:
        ranges += [(int(row['start'], 16), int(row['end'], 16) + 1)
                   for row in record['procedure']['body']['ranges']]
assert len(ranges) == len(addresses)
app, controlled, bar, array, cards, actors, stats, names, string_result, parent, widget = [
    m.heap + offset for offset in [0x1000, 0x2000, 0x4000, 0x10000, 0x18000,
                                  0x40000, 0x70000, 0x80000, 0x90000, 0x92000, 0x94000]]
INVALID = 0x7f000000

def signed(value):
    return value - 0x100000000 if value & 0x80000000 else value

def cstring(pointer):
    return bytes(u.mem_read(pointer, 256)).split(b'\0', 1)[0].decode('ascii')

def hook(_u, address, _size, _data):
    global allocation
    x, y, z, w = [u.reg_read(reg) for reg in [UC_X86_REG_RCX, UC_X86_REG_RDX, UC_X86_REG_R8, UC_X86_REG_R9]]
    sp = u.reg_read(UC_X86_REG_RSP)
    if address == m.stop:
        u.emu_stop(); return
    if address == 0x1406ac1a0:
        m.finish(controlled); return
    if address == 0x1406ac020:
        m.finish(bar); return
    if address == 0x1406ab9e0:
        m.finish(object_pointers.get(y & 0xffffffff, 0)); return
    if address == 0x14003d790:
        m.finish(0); return
    if address == 0x1407f3f00:
        pointer = name_pointers[x]
        m.wq(string_result, pointer); m.wi(string_result + 8, len(cstring(pointer)))
        m.finish(string_result); return
    if address == 0x140c10370:
        m.finish(); return
    if address == 0x140c10324:
        pointer = m.heap + 0xa0000 + allocation * 0x1000
        allocation += 1
        assert allocation < 64
        u.mem_write(pointer, bytes(0x1000)); m.finish(pointer); return
    if address == 0x1401f7950:
        m.finish(x); return
    if address == 0x1401fa3a0 or address in [0x1401fa9e0, 0x1401faa40]:
        callback, parameter = m.q(sp + 0x30), m.q(sp + 0x38)
        entry = dict(slot=int(y), icon=cstring(z), callback=hex(callback), parameter=parameter & 0xffffffff)
        if address == 0x1401fa3a0:
            entry.update(kind='action', titleRef=w & 0xffffffff)
        elif callback == 0x140992240:
            entry.update(kind='more', titleRef=w & 0xffffffff)
        else:
            assert callback == 0x14098f7d0
            index = signed(parameter & 0xffffffff)
            entry.update(kind='associate', partyIndex=index, objectId=current['members'][index], label=cstring(w))
        entries.append(entry); m.finish(); return
    if address == 0x140860760:
        setters.append(dict(packed=y & 0xffffffff, objectId=m.si(x + 0xe8) & 0xffffffff))
        m.finish(); return
    if any(low <= address < high for low, high in ranges):
        return
    raise RuntimeError('Uncaptured original dependency at ' + hex(address))

u.hook_add(UC_HOOK_CODE, hook)

def call(address, arguments=()):
    sp = m.stack + 0x1fe08
    u.mem_write(sp - 0x100, bytes(0x200)); m.wq(sp, m.stop)
    u.reg_write(UC_X86_REG_RSP, sp)
    for register, value in zip([UC_X86_REG_RCX, UC_X86_REG_RDX, UC_X86_REG_R8, UC_X86_REG_R9], list(arguments) + [0] * 4):
        u.reg_write(register, value & 0xffffffffffffffff)
    u.emu_start(address, m.stop, count=500000)
    if u.reg_read(UC_X86_REG_RIP) != m.stop:
        raise RuntimeError('Original function exceeded its bounded instruction count')
    return u.reg_read(UC_X86_REG_RAX)

def normalize(raw):
    normalized = []
    for entry in raw:
        if entry['kind'] == 'action' and entry['callback'] == '0x140998100':
            continue  # The five already covered all-associate commands.
        value = {key: entry[key] for key in ['kind', 'slot', 'icon']}
        if entry['kind'] == 'action':
            index = signed(entry['parameter']) >> 16
            command = entry['parameter'] & 65535
            if command & 32768: command -= 65536
            target = current['members'][index] if index >= 0 else current['controlledId']
            value.update(titleRef=entry['titleRef'], command=command, partyIndex=index, objectId=target)
        elif entry['kind'] == 'more':
            value.update(titleRef=entry['titleRef'], offset=m.si(bar + 0x15cc))
        else:
            value.update(partyIndex=entry['partyIndex'], objectId=entry['objectId'], label=entry['label'])
        normalized.append(value)
    return normalized

def prepare(case):
    global current, allocation, object_pointers, name_pointers, entries, setters
    current = case; allocation = 0; object_pointers = {}; name_pointers = {}; entries = []; setters = []
    u.mem_write(m.heap, bytes(0x100000)); u.mem_write(m.stack, bytes([0xa5]) * 0x20000)
    m.wq(0x1412df970, app); m.wi(controlled + 8, case['controlledId'])
    m.wq(bar + 0x1190, array); m.wi(bar + 0x1198, len(case['members'])); m.wi(bar + 0x15cc, 0)
    m.wq(parent + 0x828, widget); m.wi(parent + 0x7f8, case['controlledId'])
    for index, oid in enumerate(case['members']):
        pointer = cards + index * 0x400; m.wq(array + index * 8, pointer); m.wi(pointer + 0x328, oid)
    for index, source in enumerate(case['objects']):
        if source.get('removed') or source.get('objectType', 5) != 5:
            continue
        pointer, stat, name = actors + index * 0x800, stats + index * 0x100, names + index * 0x100
        object_pointers[source['id']] = pointer
        m.wi(pointer + 8, source['id']); m.wi(pointer + 0x270, source['master']); m.wi(pointer + 0x274, source['type']); m.wq(pointer + 0x3b0, stat)
        u.mem_write(name, ('Member' + str(source['id'])).encode() + b'\0'); name_pointers[stat] = name

cases = []
for count in [0, 1, 2, 3, 4, 8, 9, 10, 11, 12, 17, 18, 20]:
    objects = [dict(id=0xfffffff0 - index, master=0xfffffffe, type=1) for index in range(count)]
    cases.append(dict(name='plain-' + str(count), controlledId=0xfffffffe, members=[row['id'] for row in objects], objects=objects))
    mixed = ([dict(id=101, master=0xfffffffe, type=0), dict(id=102, master=7, type=1),
              dict(id=103, master=0xfffffffe, type=2), dict(id=104, master=0xfffffffe, type=1, removed=True)] + objects)
    cases.append(dict(name='mixed-' + str(count), controlledId=0xfffffffe, members=[101, 102, 0x80000001, 103, 104] + [row['id'] for row in objects], objects=mixed))
cases.append(dict(name='invalid-sentinel', controlledId=0xfffffffe, members=[INVALID], objects=[]))
cases.append(dict(name='duplicate-source-index', controlledId=0xfffffffe, members=[301, 301, 302], objects=[dict(id=301, master=0xfffffffe, type=1), dict(id=302, master=0xfffffffe, type=1)]))
rows = []
for case in cases:
    try:
        prepare(case); call(0x1409945d0, [parent, 0, 1]); root_entries = normalize(entries)
        assert len([entry for entry in entries if entry['callback'] == '0x140998100']) == 5
        pages = []; parent_entries = root_entries
        while any(row['kind'] == 'more' for row in parent_entries):
            assert len(pages) < 10
            offset = m.si(bar + 0x15cc); entries = []; call(0x140992240, [parent]); parent_entries = normalize(entries)
            pages.append(dict(offset=offset, entries=parent_entries))
        children = []
        for entry in root_entries + [entry for page in pages for entry in page['entries']]:
            if entry['kind'] != 'associate':continue
            entries = []; call(0x14098f7d0, [parent, entry['partyIndex']]); actions = normalize(entries)
            assignments = []
            for raw in entries:
                setters = []; call(0x140995f10, [parent, raw['parameter']]); assert len(setters) == 1
                assignments.append(setters[0])
            children.append(dict(partyIndex=entry['partyIndex'], objectId=entry['objectId'], entries=actions, assignments=assignments))
        rows.append(dict(case=case, root=root_entries, pages=pages, children=children))
    except Exception:
        (directory / 'failure.json').write_text(json.dumps(dict(case=case, rip=hex(u.reg_read(UC_X86_REG_RIP))), indent=2) + '\n')
        raise
sources = [Path(__file__), root / 'scripts/inspect-native-intratile-coordinator.py',
           root / 'godot-client/reports/native-quickbar-associate-commands-original-v1.json',
           root / 'godot-client/reports/native-quickbar-associate-index-original-v1.json']
report = dict(success=True, target=m.digest, limits=__doc__, cases=rows,
              sources=[dict(path=str(path.relative_to(root)).replace('\\', '/'), sha256=hashlib.sha256(path.read_bytes()).hexdigest()) for path in sources])
(directory / 'result.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(dict(success=True, cases=len(rows), output=str(directory / 'result.json'))))
