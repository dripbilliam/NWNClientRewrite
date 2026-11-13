"""Unchanged original6f7870 gate execution, with explicit UI/set/transport fixtures.

No target process, server, renderer or native build. The original gate traverses
real-layout ordered-set nodes and decides its owner-state branches unchanged.
Only current-object/message getters and GUI packet writing are captured helpers.
"""
from pathlib import Path
import argparse, hashlib, json, struct, sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'backups/research-python'))
import pefile
from unicorn import Uc, UC_ARCH_X86, UC_MODE_64, UC_HOOK_CODE
from unicorn.x86_const import *
import capstone
import unicorn

parser = argparse.ArgumentParser()
parser.add_argument('--report', required=True)
args = parser.parse_args()
output = Path(args.report).resolve()
if output.exists():
    raise SystemExit('Refusing to overwrite existing original evidence')
image = (ROOT.parent / 'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes()
digest = hashlib.sha256(image).hexdigest()
assert digest == '3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe = pefile.PE(data=image)
base = pe.OPTIONAL_HEADER.ImageBase
u = Uc(UC_ARCH_X86, UC_MODE_64)
u.mem_map(base, (pe.OPTIONAL_HEADER.SizeOfImage + 4095) & ~4095)
u.mem_write(base, pe.get_memory_mapped_image())
heap, stack, stop = 0x200000000, 0x300000000, 0x400000000
u.mem_map(heap, 0x100000)
u.mem_map(stack, 0x10000)
u.mem_map(stop, 0x1000)
client = heap + 0x1000
START, END, INVALID = 0x1406f7870, 0x1406f7a9f, 0x7f000000
q = lambda address: int.from_bytes(u.mem_read(address, 8), 'little')
def wq(address, value): u.mem_write(address, struct.pack('<Q', value))
def wi(address, value): u.mem_write(address, struct.pack('<I', value & 0xffffffff))
app = heap + 0x400
wq(0x1412df970, app)
wq(app, heap + 0x800)
events, trace, available, returned = [], [], (True, True), False
def finish(value=0):
    sp = u.reg_read(UC_X86_REG_RSP)
    u.reg_write(UC_X86_REG_RAX, value)
    u.reg_write(UC_X86_REG_RIP, q(sp))
    u.reg_write(UC_X86_REG_RSP, sp + 8)
def hook(_u, address, size, _data):
    global returned
    if address == stop:
        returned = True
        u.emu_stop()
        return
    if address == 0x1406ac1a0:
        finish(heap + 0x900 if available[0] else 0)
    elif address == 0x1406abf90:
        finish(heap + 0xa00 if available[1] else 0)
    elif address == 0x1407bdf30:
        vector = q(u.reg_read(UC_X86_REG_RSP) + 0x28)
        events.append({'event': u.reg_read(UC_X86_REG_RDX) & 65535,
                       'selection': u.reg_read(UC_X86_REG_R8) & 65535,
                       'target': u.reg_read(UC_X86_REG_R9) & 0xffffffff,
                       'position': list(struct.unpack('<fff', u.mem_read(vector, 12)))})
        finish()
    elif not START <= address < END:
        raise RuntimeError('Uncaptured original helper: ' + hex(address))
    if len(trace) == 64: trace.pop(0)
    trace.append(hex(address))
u.hook_add(UC_HOOK_CODE, hook)
def ordered_set(panel, members):
    header = heap + 0x10000 + panel * 0x100
    nodes = [heap + 0x20000 + panel * 0x200 + n * 0x40 for n in range(len(members))]
    u.mem_write(header, bytes(0x30))
    u.mem_write(header + 0x19, b'\x01')
    for node, value in zip(nodes, members):
        u.mem_write(node, bytes(0x30))
        wi(node + 0x1c, value)
    def tree(lo, hi, parent):
        if lo >= hi: return header
        mid = (lo + hi) // 2
        node = nodes[mid]
        wq(node, tree(lo, mid, node))
        wq(node + 8, parent)
        wq(node + 16, tree(mid + 1, hi, node))
        return node
    root = tree(0, len(nodes), header)
    wq(header, nodes[0] if nodes else header)
    wq(header + 8, root)
    wq(header + 16, nodes[-1] if nodes else header)
    wq(client + (panel + 0x3d) * 16, header)
    wq(client + (panel + 0x3d) * 16 + 8, len(nodes))
def prepare(panel, members, mode, bypass):
    u.mem_write(client, bytes(0x600))
    for p in range(23): ordered_set(p, sorted(set(members)) if p == panel else [])
    if mode != 'absent':
        for index, offset in enumerate([0xb8, 0x48, 0x88, 0x80, 0x98, 0x78]):
            window = heap + 0x40000 + index * 0x4000
            u.mem_write(window, bytes(0x3000))
            wq(client + offset, window)
            wi(window + 0xb0, int(mode == 'visible'))
            if offset == 0x48: wi(window + 0x2f64, int(mode == 'inventory-alternate'))
    wi(client + 0x540, bypass)
def expected(panel, target, members, mode, bypass):
    if panel < 0 or panel > 22 or bypass: return False
    if target not in members and INVALID not in members: return False
    if panel == 2: return mode not in ('absent', 'visible')
    if panel == 4: return mode not in ('absent', 'visible', 'inventory-alternate')
    if panel in (5, 6, 7, 8): return mode == 'absent'
    return 9 <= panel <= 22
def execute(panel, target, members, mode, bypass=0, controller=True, message=True):
    global available, returned
    prepare(panel, members, mode, bypass)
    events.clear(); trace.clear(); available = (controller, message); returned = False
    for register in (UC_X86_REG_RAX, UC_X86_REG_RBX, UC_X86_REG_RBP, UC_X86_REG_RSI,
                     UC_X86_REG_RDI, UC_X86_REG_R9, UC_X86_REG_R10, UC_X86_REG_R11,
                     UC_X86_REG_R12, UC_X86_REG_R13, UC_X86_REG_R14, UC_X86_REG_R15):
        u.reg_write(register, 0)
    sp = stack + 0xff08
    wq(sp, stop)
    u.reg_write(UC_X86_REG_RSP, sp)
    u.reg_write(UC_X86_REG_RCX, client)
    u.reg_write(UC_X86_REG_RDX, panel & 0xffffffff)
    u.reg_write(UC_X86_REG_R8, target)
    u.emu_start(START, stop + 1, count=20000)
    assert returned, 'Original gate did not return within finite instruction bound'
    result = bool(u.reg_read(UC_X86_REG_RAX) & 255)
    wanted = expected(panel, target, members, mode, bypass)
    assert result == wanted, ('gate mismatch', panel, target, members, mode, bypass, result, wanted)
    wanted_events = ([{'event': 14, 'selection': panel, 'target': target, 'position': [0., 0., 0.]}]
                     if wanted and controller and message else [])
    assert events == wanted_events, ('event mismatch', panel, mode, events, wanted_events)
    return {'panel': panel, 'target': target, 'members': sorted(set(members)), 'owner': mode,
            'rawBypass540': bypass, 'currentObjectAvailable': controller,
            'messageOwnerAvailable': message, 'blocked': result, 'events': list(events)}
rows, failure = [], None
try:
    for panel in list(range(23)) + [-1, 23, 0x7fffffff]:
        for target in [0, 42, 0x80000002, INVALID]:
            different = 0x12345678
            sets = [[], [target], [INVALID], [different], [different, INVALID],
                    [target, different], [target, different, INVALID]]
            for mode in ['absent', 'hidden', 'visible', 'inventory-alternate']:
                for members in sets:
                    rows.append(execute(panel, target, members, mode))
            rows.append(execute(panel, target, [target, INVALID], 'absent', bypass=1))
    for panel, mode in [(2, 'hidden'), (4, 'hidden'), (5, 'absent'), (6, 'absent'),
                        (7, 'absent'), (8, 'absent'), (9, 'absent'), (14, 'absent'), (22, 'absent')]:
        for controller, message in [(False, True), (True, False), (False, False)]:
            rows.append(execute(panel, 0x80000002, [INVALID], mode,
                                controller=controller, message=message))
except Exception as error:
    failure = {'type': type(error).__name__, 'message': str(error), 'trace': list(trace)}
cs = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_64)
functions = []
for name, start, end in [('gate', START, END), ('receiver', 0x14079d160, 0x14079d34d),
                          ('disable', 0x1406f7160, 0x1406f73d3),
                          ('enable', 0x1406f75d0, 0x1406f76e9)]:
    body = pe.get_data(start - base, end - start)
    functions.append({'name': name, 'start': hex(start), 'endExclusive': hex(end),
                      'sha256': hashlib.sha256(body).hexdigest(),
                      'assembly': [f'{i.address:#x}: {i.mnemonic} {i.op_str}' for i in cs.disasm(body, start)]})
result = {'success': failure is None, 'checks': len(rows), 'target': digest,
          'source': str(Path(__file__).relative_to(ROOT)),
          'sourceSha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
          'runtime': {'unicorn': unicorn.__version__, 'capstone': capstone.__version__}, 'failure': failure,
          'functions': functions, 'rows': rows,
          'boundaries': {'executedUnchanged': 'Original6f7870 machine-code body and set traversal',
                         'fixtures': ['Original-layout ordered-set nodes and UI owner state',
                                      'Current-object/message getters; final GUI14 writer captured'],
                         'notExecuted': ['Panel closure6f7160', 'Set allocation/erase6f75d0',
                                         'Network53/2 decoding and actual original-server script outcome'],
                         'scope': 'Finite CPU proof only; no live process, server, GPU or native build'}}
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf8')
print(json.dumps({'success': result['success'], 'checks': len(rows), 'report': str(output), 'failure': failure}))
raise SystemExit(0 if failure is None else 1)
