"""Original Type5 load/attach/update/stop CPU instruction oracle.

Complete original bodies execute; the Type5 dispatch selector, object/view
lookup, C2DA queries, string allocation/free and presentation calls are captured
explicit boundaries. No table parser, renderer, original process or network.
"""
import argparse, importlib, itertools, json, struct, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / 'scripts'))
m = importlib.import_module('inspect-native-intratile-coordinator')
u = m.u
u.hook_del(m.hook_handle)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *

EXPECTED_SHA = '3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
if m.digest != EXPECTED_SHA: raise RuntimeError('Original PE pin mismatch')
EFFECT, OBJECT, VIEW, VTABLE, VIEW_TABLE, APP, CONTEXT, RULES, ARRAYS, TABLE, STRING = [m.heap + n * 0x1000 for n in range(1, 12)]
GET_VIEW, VECTOR_SET, VECTOR_CLEAR, VISIBILITY_REFRESH = [m.stop + n * 0x100 for n in range(1, 5)]
RANGES = {'load': (0x14096c8e0, 0x14096ccaf), 'attach': (0x1409689f0, 0x140968ca9),
          'update': (0x140971e10, 0x140972088), 'stop': (0x14096fa90, 0x14096fdbc)}
case = None
calls = []

def words(address, count=1): return [int.from_bytes(u.mem_read(address + n * 4, 4), 'little') for n in range(count)]
def fw(value): return int.from_bytes(struct.pack('<f', value), 'little')
def output_state():
    return dict(alpha_word=words(EFFECT + 0x100)[0], minimum_word=words(EFFECT + 0x104)[0],
                counter_ms=words(EFFECT + 0xcc)[0], phase=int.from_bytes(u.mem_read(EFFECT + 0xfb, 1), 'little'))

def hook(_u, address, _size, _data):
    x, y, z, w = [u.reg_read(reg) for reg in [UC_X86_REG_RCX, UC_X86_REG_RDX, UC_X86_REG_R8, UC_X86_REG_R9]]
    if address == m.stop: u.emu_stop()
    elif address == 0x14096c340: m.finish(5)
    elif address == 0x1406abb60:
        if x != CONTEXT or y != case['target_id']: raise AssertionError('Target lookup ABI')
        calls.append(dict(kind='lookup', target_id=y))
        m.finish(OBJECT if case['object_present'] else 0)
    elif address == GET_VIEW:
        if x != OBJECT: raise AssertionError('View owner ABI')
        calls.append(dict(kind='view'))
        m.finish(VIEW if case['view_present'] else 0)
    elif address == 0x140c10368:
        if x != 7: raise AssertionError('Unexpected string allocation')
        u.mem_write(STRING, bytes(32)); m.finish(STRING)
    elif address == 0x140c10370:
        if x not in [0, STRING]: raise AssertionError('Unexpected free')
        m.finish()
    elif address in [0x1401a7010, 0x1401a6c70]:
        text = bytes(u.mem_read(m.q(z), 7)).split(b'\x00')[0].decode('ascii')
        kind = 'integer' if address == 0x1401a7010 else 'float'
        if x != TABLE or y != case['program_id']: raise AssertionError('Program query ABI')
        cell = case['program'][kind].get(text, dict(found=False))
        calls.append(dict(kind='query', scalar_kind=kind, column=text, found=cell['found']))
        if cell['found']:
            m.wi(w, cell['value'] if kind == 'integer' else cell['word'])
        m.finish(1 if cell['found'] else 0)
    elif address == 0x1407642e0:
        if x != VIEW or z & 255 != 255: raise AssertionError('Alpha publication ABI')
        calls.append(dict(kind='set_alpha', scope=255, alpha_word=u.reg_read(UC_X86_REG_XMM1) & 0xffffffff,
                          state_before=output_state()))
        if case.get('callback_counter') is not None: m.wi(EFFECT + 0xcc, case['callback_counter'])
        m.finish(0) # Failed callback still must preserve native post-call writes.
    elif address in [0x140765760, 0x140765c80]:
        if x != VIEW: raise AssertionError('Visibility owner ABI')
        calls.append(dict(kind='set_blocked' if address == 0x140765760 else 'set_visible', value=bool(y & 0xffffffff)))
        m.finish()
    elif address == VECTOR_SET:
        sp = u.reg_read(UC_X86_REG_RSP)
        if x != VIEW or z & 255 != 3: raise AssertionError('Vector publication ABI')
        calls.append(dict(kind='set_vector_channel', channel=3, vector_words=words(y, 3), flags=[u.reg_read(UC_X86_REG_XMM3) & 0xffffffff, words(sp + 0x28)[0]]))
        m.finish()
    elif address == VECTOR_CLEAR:
        if x != VIEW or y & 255 != 3: raise AssertionError('Vector clearing ABI')
        calls.append(dict(kind='clear_vector_channel', channel=3)); m.finish()
    elif address == VISIBILITY_REFRESH:
        if x != VIEW: raise AssertionError('Visibility refresh owner ABI')
        calls.append(dict(kind='refresh_visibility')); m.finish()
    elif not any(lo <= address <= hi for lo, hi in RANGES.values()):
        raise RuntimeError(f'Uncaptured alpha dependency {address:x}')

u.hook_add(UC_HOOK_CODE, hook)

def run(value):
    global case, calls
    case, calls = value, []
    u.mem_write(m.heap, bytes(0xc000)); u.mem_write(m.stack, bytes([0xa5]) * 0x20000)
    m.wq(0x1412df970, APP); m.wq(APP, CONTEXT)
    m.wq(0x1412df8f8, RULES); m.wq(RULES + 0x130, ARRAYS); m.wq(ARRAYS + 0x270, TABLE)
    m.wq(OBJECT, VTABLE); m.wq(VTABLE + 0x18, GET_VIEW)
    m.wq(VIEW, VIEW_TABLE); m.wq(VIEW_TABLE + 0x158, VECTOR_SET); m.wq(VIEW_TABLE + 0x160, VECTOR_CLEAR); m.wq(VIEW_TABLE + 0x210, VISIBILITY_REFRESH)
    for name, offset in [('alpha_word', 0x100), ('minimum_word', 0x104), ('counter_ms', 0xcc)]: m.wi(EFFECT + offset, case['state'][name])
    u.mem_write(EFFECT + 0xfb, bytes([case['state']['phase']]))
    u.mem_write(EFFECT + 0xd2, struct.pack('<H', case['program_id']))
    m.wi(EFFECT + 0x54, case['target_id']); m.wi(EFFECT + 0xd8, case['update_enabled'])
    sp = m.stack + 0x1fe08; m.wq(sp, m.stop)
    u.reg_write(UC_X86_REG_RSP, sp); u.reg_write(UC_X86_REG_RCX, EFFECT)
    u.reg_write(UC_X86_REG_RDX, case['elapsed_ms'] if case['operation'] == 'update' else case['program_id'])
    u.reg_write(UC_X86_REG_MXCSR, 0x1f80)
    u.emu_start(RANGES[case['operation']][0], m.stop, count=20000)
    if u.reg_read(UC_X86_REG_RIP) != m.stop: raise AssertionError('No normal alpha return')
    return dict(case=case, calls=list(calls), state=output_state())

def main():
    parser = argparse.ArgumentParser(); parser.add_argument('--output', required=True); args = parser.parse_args()
    output = Path(args.output).resolve(); boundary = (ROOT / 'godot-client/.cache/native-presentation-parity/render-agent').resolve()
    if not output.is_relative_to(boundary) or output.exists(): raise RuntimeError('Fresh owned output required')
    default = dict(operation='update', state=dict(alpha_word=fw(.75), minimum_word=fw(.5), counter_ms=0, phase=0),
                   program={'integer': {}, 'float': {}}, target_id=0xffffffff, program_id=400,
                   elapsed_ms=17, object_present=True, view_present=True, update_enabled=1)
    cases = []
    # Unsigned quotient/remainder, low-byte phase addition, signed denominator,
    # clamping, word wrap, signed zero, quiet NaNs, and callback ordering.
    for period, counter, phase, lower, upper in itertools.product([0, 1, 10, 1000, -1, -2147483648],
                [0, 1, 9, 10, 999, 1000, 0x7fffffff, 0xffffffff], [0, 1, 2, 3, 255], [fw(.5), fw(0), fw(1)], [fw(1), fw(.25)]):
        cases.append(default | dict(state=default['state'] | dict(counter_ms=counter, phase=phase, minimum_word=lower),
              program={'integer': {'param5': dict(found=True, value=period)}, 'float': {'param6': dict(found=True, word=upper)}}))
    for phase, lower, upper in itertools.product(range(4), [0, 0x80000000, 0x7f800000, 0xff800000, 0x7fc12345], [0, 0x80000000, fw(.5), 0x7fc54321]):
        cases.append(default | dict(state=default['state'] | dict(counter_ms=7, phase=phase, minimum_word=lower),
              program={'integer': {'param5': dict(found=True, value=10)}, 'float': {'param6': dict(found=True, word=upper)}}))
    for operation in ['load', 'attach', 'stop']:
        for first, second, period, available in itertools.product([None, fw(.5), 0, 0x80000000, 0x7fc12345], [None, fw(-1), 0, fw(1)], [0, 7], [True, False]):
            cells = {}
            if first is not None: cells['param1'] = dict(found=True, word=first)
            if second is not None: cells['param2'] = dict(found=True, word=second)
            cells['param3'], cells['param4'] = dict(found=True, word=fw(2)), dict(found=True, word=fw(-3))
            cases.append(default | dict(operation=operation, view_present=available,
                 program={'integer': {'param5': dict(found=True, value=period)}, 'float': cells},
                 state=default['state'] | dict(minimum_word=first if first is not None else fw(.75))))
    for object_present, view_present, enabled in itertools.product([False, True], repeat=3):
        for operation in RANGES:
            cases.append(default | dict(operation=operation, object_present=object_present, view_present=view_present, update_enabled=int(enabled)))
    for callback_counter in [0, 19, 0xffffffff]:
        for elapsed_ms in [0, 1, 0xffffffff]:
            cases.append(default | dict(callback_counter=callback_counter, elapsed_ms=elapsed_ms,
                program={'integer': {'param5': dict(found=True, value=10)}, 'float': {}}))
    rows = [run(value) for value in cases]
    result = dict(binarySha256=m.digest, scope=__doc__, entries={k: [hex(a), hex(b)] for k, (a, b) in RANGES.items()},
                  cases=len(rows), rows=rows, notCovered=['C2DA parsing', 'renderer alpha and blending', 'outer start/selection dispatch', 'network', 'effect list selector'])
    output.parent.mkdir(parents=True, exist_ok=True); output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(dict(output=str(output), cases=len(rows), binarySha256=m.digest)))

if __name__ == '__main__': main()
