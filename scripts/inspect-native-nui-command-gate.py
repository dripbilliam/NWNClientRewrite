"""Unchanged numeric command early-return prefix after NUI gate construction."""
from pathlib import Path
import argparse
import hashlib
import json
import struct
import sys
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'backups/research-python'))
import capstone
import pefile
import unicorn
from unicorn import Uc, UC_ARCH_X86, UC_MODE_64, UC_HOOK_CODE, UC_HOOK_MEM_READ
from unicorn.x86_const import *

p = argparse.ArgumentParser()
p.add_argument('--report', required=True)
output = Path(p.parse_args().report).resolve()
if output.exists():
    raise SystemExit('Refusing to overwrite original observations')
raw = (ROOT.parent / 'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes()
digest = hashlib.sha256(raw).hexdigest()
assert digest == '3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe = pefile.PE(data=raw)
base = pe.OPTIONAL_HEADER.ImageBase
START, CONTINUE, EXIT = 0x1406ed78f, 0x1406ed7ef, 0x1406ef621
CONTEXT = 0x1414299a0
body = pe.get_data(START - base, CONTINUE - START)
u = Uc(UC_ARCH_X86, UC_MODE_64)
for page in sorted({START & ~4095, EXIT & ~4095, CONTEXT & ~4095}):
    u.mem_map(page, 4096)
u.mem_write(START, body)
u.mem_write(CONTINUE, b'\xc3')
u.mem_write(EXIT, b'\xc3')
heap, stack = 0x200000000, 0x300000000
u.mem_map(heap, 0x30000)
u.mem_map(stack, 0x10000)
world, context, window = heap, heap + 0x10000, heap + 0x20000
rbp = stack + 0x4000


def wq(at, value):
    u.mem_write(at, struct.pack('<Q', value))


def wi(at, value):
    u.mem_write(at, struct.pack('<I', value & 0xffffffff))


boundary = None
trace = []
window_reads = 0


def code_hook(_u, address, size, _data):
    global boundary
    if address in [CONTINUE, EXIT]:
        boundary = 'continue' if address == CONTINUE else 'early_exit'
        u.emu_stop()
    elif not START <= address < CONTINUE:
        raise RuntimeError('Unexpected boundary ' + hex(address))
    trace.append(hex(address))


def read_hook(_u, _access, address, size, _value, _data):
    global window_reads
    if address == window + 0x18c:
        window_reads += 1


u.hook_add(UC_HOOK_CODE, code_hook)
u.hook_add(UC_HOOK_MEM_READ, read_hook)
wq(CONTEXT, context)
wq(context + 0x6730, window)
rows = []
failure = None
case = {}
try:
    for command in [-1, *range(128), 0x7fffffff]:
        for parameter5 in [0, 1, -1]:
            for world12c in [0, 1]:
                for argument3 in [0, 1]:
                    for window18c in [0, 1]:
                        case = {'numericCommand': command, 'parameter5': parameter5, 'world12c': world12c,
                                'argument3': argument3, 'window18c': window18c}
                        boundary = None; trace.clear(); window_reads = 0
                        wi(rbp + 0x190, parameter5); wi(world + 0x12c, world12c); wi(window + 0x18c, window18c)
                        u.reg_write(UC_X86_REG_RBP, rbp); u.reg_write(UC_X86_REG_RSI, world)
                        u.reg_write(UC_X86_REG_RBX, command & 0xffffffffffffffff)
                        u.reg_write(UC_X86_REG_RDI, argument3); u.reg_write(UC_X86_REG_R12, 0)
                        u.reg_write(UC_X86_REG_RSP, stack + 0xff08)
                        u.emu_start(START, EXIT + 1, count=128)
                        assert boundary is not None, 'Finite128-instruction bound exceeded'
                        initial_exit = parameter5 != 0 and (command == 1 or world12c == 0 and command == 0 or command == 113)
                        read_window = parameter5 != 0 and not initial_exit and argument3 != 0
                        expected_exit = initial_exit or read_window and window18c != 0 and command not in [2, 3, 111, 112, 114]
                        assert boundary == ('early_exit' if expected_exit else 'continue'), (case, boundary)
                        assert window_reads == int(read_window), (case, window_reads)
                        rows.append({'case': dict(case), 'boundary': boundary, 'windowFieldReads': window_reads})
except Exception as error:
    failure = {'type': type(error).__name__, 'message': str(error), 'case': dict(case), 'trace': list(trace)}
cs = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_64)
result = {'success': failure is None, 'checks': len(rows), 'binarySha256': digest,
          'sourceSha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
          'prefix': {'start': hex(START), 'continue': hex(CONTINUE), 'earlyExit': hex(EXIT),
                     'sha256': hashlib.sha256(body).hexdigest(),
                     'assembly': [f'{i.address:#x}: {i.mnemonic} {i.op_str}' for i in cs.disasm(body, START)]},
          'rows': rows, 'failure': failure,
          'boundary': 'Only unchanged6ed78f..6ed7ef prefix executes; continuation and early-exit labels captured. Original-offset complete authored memory, nonnull context window, numeric command IDs/R12D=0. No command names, helper meanings, full command behavior, NUI membership/render order, GUI/native/server acceptance inferred.',
          'runtime': {'unicorn': unicorn.__version__, 'capstone': capstone.__version__}, 'servers': 0, 'gpu': False, 'nativeBuilds': 0}
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'success': result['success'], 'checks': len(rows), 'failure': failure, 'report': str(output)}))
raise SystemExit(0 if result['success'] else 1)
