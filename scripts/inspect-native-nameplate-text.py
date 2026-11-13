"""Execute complete original plain-text visible-width and word-wrap routines.

The font uses authored single-byte atlas metrics, rather than a real font file.
Texture-ready, allocation, free, strncpy and finite floorf are captured platform
boundaries. Original CalculateVisibleStringLengthAndWidth, GetSymbolCoords,
AlignGUIToPixel and WrapLines execute unchanged. No markup, actual TTF shaping,
GUI rendering, process inspection, network or GPU acceptance is claimed.
"""
import importlib.util, itertools, json, math, re, struct, sys
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    'image', Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *

u = m.u
u.hook_del(m.hook_handle)
gob, font, info, texture, texture_vtable, pointers, item, text, upper, lower = [
    m.heap + n * 0x1000 for n in range(10)]
loaded = m.stop + 0x100
ranges = [(0x14004c120, 0x14004c427), (0x1400ebb10, 0x1400ebb9e),
          (0x140074e20, 0x140074e54), (0x14004afe0, 0x14004b2cf),
          (0x1401fd690, 0x1401fd8e4)]
allocation = m.heap + 0x10000
popup, string_object, string_vtable, display = [m.heap + n * 0x1000 for n in range(10, 14)]
virtuals = {offset: m.stop + 0x200 + offset for offset in
            (8, 0x68, 0x70, 0xb0, 0xb8, 0xc0, 0xc8, 0xd0, 0xe8)}
policy_prepared = {}
policy_width = 0.0


def cstring(address):
    output = bytearray()
    while len(output) < 10000:
        value = u.mem_read(address + len(output), 1)[0]
        if value == 0:
            return bytes(output)
        output.append(value)
    raise AssertionError('Unexpected unterminated authored string')


def hook(engine, address, size, context):
    global allocation, policy_width
    if address == m.stop:
        engine.emu_stop()
        return
    x, y, z = [engine.reg_read(reg) for reg in
               (UC_X86_REG_RCX, UC_X86_REG_RDX, UC_X86_REG_R8)]
    if address == loaded:
        m.finish(1)
    elif address == virtuals[0xb8]:
        m.finish(display)
    elif address == virtuals[0xc0]:
        policy_width = m.xmm(UC_X86_REG_XMM1)
        m.finish()
    elif address == virtuals[0xd0]:
        m.finish(int(policy_prepared[round(policy_width, 5)]['overflow']))
    elif address == virtuals[0xe8]:
        m.finish(policy_prepared[round(policy_width, 5)]['line_count'])
    elif address in virtuals.values() or address in (0x1401fb230, 0x1401fb710, 0x140c10410):
        m.finish()
    elif address == 0x140c7ed44:
        value = math.floor(m.xmm(UC_X86_REG_XMM0))
        engine.reg_write(UC_X86_REG_XMM0,
                         int.from_bytes(struct.pack('<f', value), 'little'))
        m.finish()
    elif address in (0x140c10324, 0x140c10368):
        assert 0 < x < 100000
        result = allocation
        allocation += (x + 31) & ~15
        assert allocation < m.heap + 0xf0000
        u.mem_write(result, bytes(x))
        m.finish(result)
    elif address == 0x140c10370:
        m.finish()
    elif address == 0x140c4eec0:
        assert z < 10000
        value = cstring(y)[:z]
        u.mem_write(x, value + bytes(z - len(value)))
        m.finish(x)
    elif not any(lo <= address < hi for lo, hi in ranges):
        raise AssertionError(f'Uncaptured text-layout dependency {address:x}')


u.hook_add(UC_HOOK_CODE, hook)


def begin(case):
    global allocation
    allocation = m.heap + 0x10000
    u.mem_write(m.heap, bytes(0x100000))
    u.mem_write(m.stack, bytes(0x20000))
    m.wq(font + 0x28, info)
    m.wq(font + 0x30, texture)
    m.wq(texture, texture_vtable)
    m.wq(texture_vtable + 0x30, loaded)
    m.wf(info + 4, 0.14)
    m.wf(info + 8, 0.11)
    m.wf(info + 0xc, 1.0)
    m.wf(info + 0x10, case['spacing'])
    m.wf(info + 0x14, 0.0)
    m.wq(info + 0x20, upper)
    m.wq(info + 0x30, lower)
    m.wf(0x1413016ac, 0.01)
    for code in range(256):
        width = case['glyphs'].get(chr(code), case['default'])
        m.wf(lower + code * 12, width)
    m.wq(item + 8, text)
    u.mem_write(text, case['text'].encode('ascii') + b'\0')


def call(address, x, y=0, wrapping=False):
    rsp = m.stack + 0x1fe08
    m.wq(rsp, m.stop)
    u.reg_write(UC_X86_REG_RSP, rsp)
    for reg, value in [(UC_X86_REG_RCX, x), (UC_X86_REG_RDX, y),
                       (UC_X86_REG_R9, int(wrapping))]:
        u.reg_write(reg, value)
    u.reg_write(UC_X86_REG_XMM2,
                int.from_bytes(struct.pack('<f', case['width']), 'little'))
    u.emu_start(address, m.stop, count=2000000)
    assert u.reg_read(UC_X86_REG_RIP) == m.stop
    return u.reg_read(UC_X86_REG_RAX) & 0xffffffff


def run(source):
    global case
    case = source
    observations = []
    for wrapping in (False, True):
        begin(case)
        overflow = call(0x14004c120, font, item, wrapping)
        # The ABI returns bool in AL; higher RAX bits can retain a pointer.
        observations.append(dict(wrapping=wrapping, overflow=bool(overflow & 255),
                                 visible=m.si(item + 0x14), width=m.rf(item + 0x1c)))
    begin(case)
    m.wq(gob + 0x4d0, font)
    u.mem_write(gob + 0x4c8, b'\1')
    m.wq(gob + 0x500, pointers)
    m.wq(pointers, item)
    m.wi(gob + 0x508, 1)
    m.wi(gob + 0x50c, 256)
    m.wi(gob + 0x510, 0x100000)
    m.wf(gob + 0x534, case['width'])
    result = call(0x14004afe0, gob)
    lines = [cstring(m.q(m.q(pointers + index * 8) + 8)).decode('ascii')
             for index in range(m.si(gob + 0x508))]
    return dict(input=case, measures=observations, lines=lines,
                wrap_result=result if result < 0x80000000 else result - 0x100000000)


def run_policy(source):
    global case, policy_prepared, policy_width
    policy_prepared = {}
    for width in (100, 150, 300):
        case = source | dict(width=(width - source['indent']) * 0.01)
        observation = run(case)
        policy_prepared[round(case['width'], 5)] = dict(
            overflow=observation['measures'][0]['overflow'],
            line_count=len(observation['lines']))
    case = source | dict(width=0)
    begin(case)
    m.wq(popup + 0xf0, string_object)
    m.wq(string_object, string_vtable)
    for offset, target in virtuals.items():
        m.wq(string_vtable + offset, target)
    m.wf(display + 0x28, source['line_height'])
    m.wf(popup + 0x108, source['indent'])
    m.wi(popup + 0x10c, source['minimum_lines'])
    m.wi(popup + 0x110, -1)
    m.wi(popup + 0x114, 1)
    call(0x1401fd690, popup, text)
    return dict(input=source, providers=policy_prepared,
                bubble_index=m.si(popup + 0x110),
                dimensions=[m.rf(popup + 0xf8), m.rf(popup + 0xfc)])


if __name__ == '__main__':
    samples = ['', 'A', 'ABCDE', 'ABCDEFGHIJKLMN', 'ABCDEFGHIJKLMNOP' * 3,
               'one two three', 'one  two   three', ' one two', '   abcdefgh',
               'abc ', 'abc\n', '\n', '\n\n', 'abc\n\ndef',
               'a abcdefghijklmnop q', 'one\ttwo three', 'Wim Wim Wim']
    cases = [dict(text=value, width=width, spacing=spacing, default=0.06,
                  glyphs={' ': 0.03, '\n': 0.0, '\t': 0.0, 'W': 0.095, 'i': 0.025})
             for value, width, spacing in itertools.product(
                 samples, [0.0, 0.02, 0.06, 0.06001, 0.18, 0.3, 0.76, 1.0, 2.76],
                 [0.0, 0.005, 0.01])]
    name = next((arg.split('=', 1)[1] for arg in sys.argv[1:]
                 if arg.startswith('--report=')), 'native-nameplate-text-v1.json')
    assert re.fullmatch(r'native-nameplate-text-[a-z0-9-]+\.json', name)
    output = m.root / 'backups/animations' / name
    assert not output.exists(), 'Preserve prior evidence'
    rows = [run(source) for source in cases]
    policies = [run_policy(dict(text=value, spacing=spacing, default=0.06,
                               glyphs={' ': 0.03, '\n': 0.0, '\t': 0.0,
                                       'W': 0.095, 'i': 0.025}, indent=indent,
                               minimum_lines=minimum, line_height=height))
                for value, spacing, indent, minimum, height in itertools.product(
                    samples, [0.0, 0.005], [0, 24], [1, 2], [14, 17])]
    output.write_text(json.dumps(dict(target=m.digest, scope=__doc__, rows=rows,
                                     policies=policies,
                                     policy_scope='Complete original CGuiTextBubble::SetText policy. '
                                     'Its text/line providers use separately executed plain-text '
                                     'width/wrap observations; model attachment is captured.'),
                                 indent=2) + '\n')
    print(json.dumps(dict(output=str(output), cases=len(rows),
                          policies=len(policies),
                          publicConnections=0, gpu=False)))
