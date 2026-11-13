"""Execute original STB glyph-index, H/V metrics and pixel-height scale getters.

Real installed font bytes are supplied by the separate native resource probe.
SFNT directory/cmap selection is a decoded font-info fixture, not original
stbtt_InitFont acceptance. All reached getter instructions execute unchanged;
there are no substituted calls. Atlas packing/enhancement/pixels are excluded.
"""
import importlib.util, json, re, struct, sys, hashlib
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    'image', Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *

u = m.u
u.hook_del(m.hook_handle)
info = m.heap + 0x1000
outputs = m.heap + 0x2000
font_address = 0x500000000
u.mem_map(font_address, 0x400000)
ranges = [(0x1401036c0, 0x140103a61), (0x140104d10, 0x140104e3b),
          (0x1401044a0, 0x140104549), (0x140107a10, 0x140107a61)]


def hook(engine, address, size, context):
    if address == m.stop:
        engine.emu_stop()
        return
    if not any(lo <= address < hi for lo, hi in ranges):
        raise AssertionError(f'Uncaptured original TTF metric dependency {address:x}')


u.hook_add(UC_HOOK_CODE, hook)


def u16(data, at):
    return struct.unpack_from('>H', data, at)[0]


def directory(data):
    return {data[12 + n * 16:16 + n * 16].decode('ascii'):
            struct.unpack_from('>II', data, 20 + n * 16)
            for n in range(u16(data, 4))}


def prepare(data):
    assert len(data) < 0x400000
    u.mem_write(m.heap, bytes(0x10000))
    u.mem_write(font_address, data)
    tables = directory(data)
    cmap = tables['cmap'][0]
    chosen = 0
    for index in range(u16(data, cmap + 2)):
        at = cmap + 4 + index * 8
        platform, encoding, offset = struct.unpack_from('>HHI', data, at)
        if platform == 0 or platform == 3 and encoding in (1, 10):
            chosen = cmap + offset
    assert chosen and u16(data, chosen) in (0, 4, 6, 12, 13)
    m.wq(info + 8, font_address)
    m.wi(info + 0x24, tables['hhea'][0])
    m.wi(info + 0x28, tables['hmtx'][0])
    m.wi(info + 0x38, chosen)
    return dict(tables={name: {'offset': row[0], 'length': row[1]}
                        for name, row in tables.items()},
                cmap_offset=chosen, cmap_format=u16(data, chosen))


def call(address, second=0, third=0, fourth=0, height=None):
    u.mem_write(m.stack, bytes(0x20000))
    rsp = m.stack + 0x1fe08
    m.wq(rsp, m.stop)
    u.reg_write(UC_X86_REG_RSP, rsp)
    for register, value in [(UC_X86_REG_RCX, info), (UC_X86_REG_RDX, second),
                            (UC_X86_REG_R8, third), (UC_X86_REG_R9, fourth)]:
        u.reg_write(register, value)
    if height is not None:
        u.reg_write(UC_X86_REG_XMM1,
                    int.from_bytes(struct.pack('<f', height), 'little'))
    u.emu_start(address, m.stop, count=100000)
    assert u.reg_read(UC_X86_REG_RIP) == m.stop
    return u.reg_read(UC_X86_REG_RAX) & 0xffffffff


if __name__ == '__main__':
    path = next((arg.split('=', 1)[1] for arg in sys.argv[1:]
                 if arg.startswith('--probe=')),
                str(m.root / 'godot-client/reports/native-ttf-metrics-current-v2.json'))
    probe = json.loads(Path(path).read_text(encoding='utf-8-sig'))
    observations = []
    for resource in probe['resources']:
        data = Path(resource['path']).read_bytes()
        assert hashlib.sha256(data).hexdigest() == resource['sha256']
        decoded = prepare(data)
        call(0x1401044a0, outputs, outputs + 4, outputs + 8)
        vertical = dict(ascent=m.si(outputs), descent=m.si(outputs + 4),
                        line_gap=m.si(outputs + 8))
        rows = []
        for size in resource['sizes']:
            height = size['requested_height']
            call(0x140107a10, height=height)
            scale = m.xmm(UC_X86_REG_XMM0)
            glyphs = []
            for current in size['glyphs']:
                code = current['codepoint']
                # Original LoadFromTTF uses the pipe glyph for the NUL slot.
                glyph = call(0x1401036c0, 124 if code == 0 else code)
                call(0x140104d10, glyph, outputs, outputs + 4)
                advance, bearing = m.si(outputs), m.si(outputs + 4)
                pixels = struct.unpack('<f', struct.pack('<f', advance * scale))[0]
                glyphs.append(dict(byte=current['byte'], codepoint=code,
                                   glyph=glyph, advance_units=advance,
                                   left_bearing_units=bearing,
                                   native_advance_pixels=pixels,
                                   godot_glyph=current['glyph'],
                                   godot_advance=current['advance'],
                                   godot_single_string_width=current['single_string_width']))
            rows.append(dict(requested_height=height, native_scale=scale,
                             native_line_height=height,
                             godot_line_height=size['godot_height'], glyphs=glyphs))
        observations.append(dict(name=resource['name'], font_sha256=resource['sha256'],
                                 font_bytes=len(data), decoded=decoded,
                                 vertical=vertical, sizes=rows))
    name = next((arg.split('=', 1)[1] for arg in sys.argv[1:]
                 if arg.startswith('--report=')), 'native-ttf-metrics-v1.json')
    assert re.fullmatch(r'native-ttf-metrics-[a-z0-9-]+\.json', name)
    output = m.root / 'backups/animations' / name
    assert not output.exists(), 'Preserve previous evidence'
    output.write_text(json.dumps(dict(target=m.digest, scope=__doc__,
                                     font_probe_sha256=hashlib.sha256(Path(path).read_bytes()).hexdigest(),
                                     procedures=[hex(lo) for lo, hi in ranges],
                                     fonts=observations), indent=2) + '\n')
    print(json.dumps(dict(output=str(output), fonts=len(observations),
                          glyph_rows=sum(len(size['glyphs']) for font in observations
                                         for size in font['sizes']),
                          gameServerConnections=0, gpu=False)))
