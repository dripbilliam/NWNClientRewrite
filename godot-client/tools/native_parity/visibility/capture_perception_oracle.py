"""Read-only original handler140810970 instruction oracle.

Complete entry..RET executes. Object lookup, empty map-head allocation and the
two visual dispatches are explicit captured boundaries. No visual loader,
renderer, network, original process, DLL build or server is exercised.
"""
import argparse, importlib, json, struct, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / 'scripts'))
m = importlib.import_module('inspect-native-intratile-coordinator')
u = m.u
u.hook_del(m.hook_handle)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import UC_X86_REG_RAX, UC_X86_REG_RCX, UC_X86_REG_RDX, UC_X86_REG_R8, UC_X86_REG_R9, UC_X86_REG_RSP, UC_X86_REG_RIP

EXPECTED_SHA = '3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
if m.digest != EXPECTED_SHA:
    raise RuntimeError('Original PE pin mismatch')
ACTOR, VTABLE, APP, CONTEXT, RECORD, HEAD = [m.heap + i * 0x1000 for i in range(1, 7)]
APPLY, REMOVE = m.stop + 0x100, m.stop + 0x200
current = None
calls = []

def hook(_u, address, _size, _data):
    x, y, z, w = [u.reg_read(reg) for reg in [UC_X86_REG_RCX, UC_X86_REG_RDX, UC_X86_REG_R8, UC_X86_REG_R9]]
    if address == m.stop:
        u.emu_stop()
    elif address == 0x1406ab9e0:
        if x != CONTEXT or (y & 0xffffffff) != current['id']:
            raise AssertionError('Object lookup ABI/order changed')
        calls.append({'kind': 'lookup', 'id': y & 0xffffffff})
        m.finish(ACTOR if current['present'] else 0)
    elif address == 0x140368530:
        calls.append({'kind': 'empty-map-head'})
        u.mem_write(HEAD, bytes(0x50))
        m.wq(HEAD, HEAD)
        m.wq(HEAD + 8, HEAD)
        m.wq(HEAD + 16, HEAD)
        u.mem_write(HEAD + 0x19, b'\x01')
        m.finish(HEAD)
    elif address == APPLY:
        sp = u.reg_read(UC_X86_REG_RSP)
        point = m.q(sp + 0x38)
        transform_map = m.q(sp + 0x40)
        if x != ACTOR:
            raise AssertionError('Wrong apply owner')
        event = {'kind': 'apply6', 'visual_id': y & 0xffff, 'mode': z & 0xffffffff,
                 'source_id': w & 0xffffffff, 'source_part': int.from_bytes(u.mem_read(sp + 0x28, 1), 'little'),
                 'target_part': int.from_bytes(u.mem_read(sp + 0x30, 1), 'little'),
                 'point_words': bytes(u.mem_read(point, 12)).hex(),
                 'map_empty': m.q(transform_map) == HEAD and m.q(transform_map + 8) == 0}
        if event != {'kind': 'apply6', 'visual_id': 6, 'mode': 0, 'source_id': 0x7f000000,
                     'source_part': 0, 'target_part': 0, 'point_words': '00' * 12, 'map_empty': True}:
            raise AssertionError(('Unexpected apply ABI', event))
        calls.append(event)
        # A callback may write the same field. Native handler must still make
        # its unconditional final latch write after the callback returns.
        m.wi(ACTOR + 0x26c, 19)
        m.finish(current['callback_result'])
    elif address == REMOVE:
        if x != ACTOR or y != 6:
            raise AssertionError('Wrong removal ABI')
        calls.append({'kind': 'remove6', 'visual_id': y})
        m.wi(ACTOR + 0x26c, 19)
        m.finish(current['callback_result'])
    elif not 0x140810970 <= address <= 0x140810a82:
        raise RuntimeError(f'Uncaptured perception dependency {address:x}')

u.hook_add(UC_HOOK_CODE, hook)

def run(case):
    global current, calls
    current = case
    calls = []
    u.mem_write(m.heap, bytes(0x8000))
    u.mem_write(m.stack, bytes([0xa5]) * 0x20000)
    m.wq(0x1412df970, APP)
    m.wq(APP, CONTEXT)
    m.wq(ACTOR, VTABLE)
    m.wq(VTABLE + 0x178, APPLY)
    m.wq(VTABLE + 0x180, REMOVE)
    m.wi(ACTOR + 0x26c, case['latched'])
    m.wi(RECORD, case['id'])
    u.mem_write(RECORD + 4, bytes([case['packed_flags']]))
    steps = []
    for _ in range(2):
        calls = []
        sp = m.stack + 0x1fe08
        m.wq(sp, m.stop)
        u.reg_write(UC_X86_REG_RSP, sp)
        u.reg_write(UC_X86_REG_RCX, APP)
        u.reg_write(UC_X86_REG_RDX, RECORD)
        u.emu_start(0x140810970, m.stop, count=10000)
        if u.reg_read(UC_X86_REG_RIP) != m.stop:
            raise AssertionError('Handler did not reach normal return')
        steps.append({'calls': list(calls), 'latched': m.si(ACTOR + 0x26c)})
    return {'case': case, 'steps': steps}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    output = Path(args.output).resolve()
    boundary = (ROOT / 'godot-client/.cache/native-presentation-parity').resolve()
    if not output.is_relative_to(boundary) or output.exists():
        raise RuntimeError('Fresh owned private output under native-presentation-parity required')
    rows = []
    for flags in range(256):
        for latched in [0, 1]:
            for present in [False, True]:
                for callback_result in [0, 1]:
                    rows.append(run({'packed_flags': flags, 'latched': latched, 'present': present,
                                     'callback_result': callback_result, 'id': 0xffffffff}))
    for object_id in [0, 1, 0x7f000000, 0x80000001]:
        rows.append(run({'packed_flags': 2, 'latched': 0, 'present': True, 'callback_result': 0, 'id': object_id}))
    result = {'binarySha256': m.digest, 'entry': '0x140810970', 'inclusiveEnd': '0x140810a82',
              'scope': __doc__, 'rows': rows, 'cases': len(rows), 'executions': len(rows) * 2,
              'capturedBoundaries': ['object lookup', 'empty map-head allocation', 'apply visual', 'remove visual'],
              'notCovered': ['lookup implementation', 'visual loader/phase/render effects', 'network', 'native constructor execution']}
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'output': str(output), 'cases': len(rows), 'executions': len(rows) * 2, 'binarySha256': m.digest}))

if __name__ == '__main__':
    main()
