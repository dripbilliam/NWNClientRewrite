"""Execute unchanged native normal-self and world-emote radial decision code.

PE source is pinned. UI allocation, entry publication, controlled/target lookup,
DM permission and class lookup are captured service boundaries. Party owner is
absent: these observations do not prove party/possession/DM role selection.
No target process, network, renderer, installed-file mutation or native build.
"""
from pathlib import Path
import argparse, hashlib, itertools, json, struct, sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'backups/research-python'))
import pefile
from unicorn import Uc, UC_ARCH_X86, UC_MODE_64, UC_HOOK_CODE
from unicorn.x86_const import *

parser = argparse.ArgumentParser()
parser.add_argument('--report', required=True)
args = parser.parse_args()
output = Path(args.report).resolve()
if output.exists(): raise SystemExit('Refusing to overwrite original observations')
image = (ROOT.parent / 'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes()
digest = hashlib.sha256(image).hexdigest()
assert digest == '3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe = pefile.PE(data=image)
u = Uc(UC_ARCH_X86, UC_MODE_64)
base = pe.OPTIONAL_HEADER.ImageBase
u.mem_map(base, (pe.OPTIONAL_HEADER.SizeOfImage + 4095) & ~4095)
u.mem_write(base, pe.get_memory_mapped_image())
heap, stack, stop = 0x200000000, 0x300000000, 0x400000000
u.mem_map(heap, 0x100000); u.mem_map(stack, 0x10000); u.mem_map(stop, 0x1000)
menu, actor, app, vt = heap+0x1000, heap+0x3000, heap+0x5000, heap+0x6000
INVALID, ID = 0x7f000000, 99
q = lambda a: int.from_bytes(u.mem_read(a, 8), 'little')
def wq(a, v): u.mem_write(a, struct.pack('<Q', v & 0xffffffffffffffff))
def wi(a, v): u.mem_write(a, struct.pack('<I', v & 0xffffffff))
def text(a):
    result = bytearray()
    for _ in range(256):
        c = bytes(u.mem_read(a, 1)); a += 1
        if c == b'\0': return result.decode('ascii')
        result.extend(c)
    raise RuntimeError('Unterminated original radial resource')
entries, disabled, calls, trace = [], [], [], []
first_class, start, end = 0, 0, 0
def finish(value=0):
    sp = u.reg_read(UC_X86_REG_RSP)
    u.reg_write(UC_X86_REG_RAX, value)
    u.reg_write(UC_X86_REG_RIP, q(sp)); u.reg_write(UC_X86_REG_RSP, sp+8)
def hook(_u, address, size, _data):
    if address == stop: u.emu_stop(); return
    if len(trace) == 80: trace.pop(0)
    trace.append(hex(address))
    x,y,z,w = [u.reg_read(r) for r in (UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9)]
    sp = u.reg_read(UC_X86_REG_RSP)
    if address == 0x1406ac1a0: finish(actor)
    elif address == 0x1406ab9e0: finish(actor if y & 0xffffffff == ID else 0)
    elif address == stop+0x100: finish(heap+0x7000)
    elif address == 0x1402377b0: finish(0)
    elif address == 0x1407f0f60: finish(first_class)
    elif address in (0x1401fa3a0,0x1401faa40):
        entries.append(dict(slot=y,icon=text(z),tooltip=w,kind='branch' if address==0x1401faa40 else 'entry',callback=hex(q(sp+0x30)),argument=q(sp+0x38)))
        finish()
    elif address == 0x1401f8b30: disabled.append(y); finish()
    elif address in (0x1401f7e80,0x140c10410): finish()
    elif address == 0x1406abf90: finish(heap+0x8000)
    elif address == 0x1407bf180: calls.append(dict(writer=hex(address),target=y&0xffffffff)); finish(1)
    elif not start <= address <= end: raise RuntimeError('Uncaptured original boundary '+hex(address))
u.hook_add(UC_HOOK_CODE, hook)
def execute(address, last, flags=0, mode=0, related=INVALID, polymorph=0, locked=0, extra=0, cls=0):
    global first_class, start, end
    first_class, start, end = cls, address, last
    u.mem_write(heap, bytes(0x100000)); entries.clear(); disabled.clear(); calls.clear(); trace.clear()
    wq(0x1412df970, app); wq(app,vt); wq(vt,heap+0xa000); wq(heap+0xa038,stop+0x100)
    wi(menu+0x7f8,ID); wi(menu+0x804,INVALID); wi(menu+0x808,0)
    u.mem_write(menu+0x80c,bytes([mode])); wi(menu+0x810,related)
    wi(actor+8,ID); wi(actor+0x37c,flags); wi(actor+0x380,extra)
    wi(actor+0x408,polymorph); wi(actor+0x40c,locked); wq(actor+0x3b0,heap+0x9000)
    for r in (UC_X86_REG_RAX,UC_X86_REG_RBX,UC_X86_REG_RBP,UC_X86_REG_RSI,UC_X86_REG_RDI,UC_X86_REG_R8,UC_X86_REG_R9,UC_X86_REG_R10,UC_X86_REG_R11,UC_X86_REG_R12,UC_X86_REG_R13,UC_X86_REG_R14,UC_X86_REG_R15): u.reg_write(r,0)
    sp=stack+0xfe08; u.mem_write(sp-0x200,bytes(0x300)); wq(sp,stop)
    u.reg_write(UC_X86_REG_RSP,sp); u.reg_write(UC_X86_REG_RCX,menu); u.reg_write(UC_X86_REG_RDX,0)
    try: u.emu_start(address,stop,count=10000)
    except Exception as error: raise RuntimeError(str(error)+'; trace='+str(trace)) from error
    assert u.reg_read(UC_X86_REG_RIP)==stop, 'Original function did not return'
    return dict(entries=list(entries),disabled=list(disabled),calls=list(calls))
rows=[]
for flags,mode,related,poly,locked in itertools.product([0,128,65535],[0,1,2,255],[INVALID,ID,100],[0,1],[0,1]):
    value=execute(0x14098ec00,0x14098f0a2,flags,mode,related,poly,locked)
    byslot={r['slot']:r for r in value['entries']}
    assert set(byslot)=={0,1,3,5,6,7}|({2} if mode==2 and related==ID or flags&128 else set())|({4} if poly and not locked else set())
    if 2 in byslot: assert byslot[2]['icon']==('IR_DISENGAGE' if mode==2 and related==ID else 'IR_ATTACK')
    if 4 in byslot: assert byslot[4]['icon']=='IR_SKILLSELF'
    rows.append(dict(input=dict(flags=flags,mode=mode,related=related,polymorph=poly,locked=locked),**value))
emotes=[]
for cls,flags in itertools.product(range(256),[0,16,65535]):
    value=execute(0x140994130,0x1409943a8,extra=flags,cls=cls)
    assert [r['slot'] for r in value['entries']]==[5,4,3,6,2,0,1,7]
    assert value['entries'][0]['argument']==(0 if cls==8 else 1 if cls in [2,3,6,9,10] else 2)
    assert value['disabled']==([5,4,3,6,2,0,1] if flags&16 else [])
    emotes.append(dict(firstClass=cls,field8E0=flags,**value))
disengage=execute(0x140996250,0x14099627e)
assert disengage['calls']==[dict(writer='0x1407bf180',target=INVALID)]
report=dict(success=True,binarySha256=digest,scriptSha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),scope=__doc__,selfCases=len(rows),emoteCases=len(emotes),rows=rows,emotes=emotes,disengage=disengage,limits=['Role4 party, possession and DM are intentionally not represented by absent party-owner fixtures. Polymorph predicate is proved, but raw replicated alias publication requires its separate owner mapping.','SetEntryx/SetSubMenuCreatorx capture original slot/icon/TLK/callback/argument; no glyph draw, network acknowledgement or live-client acceptance.'])
output.parent.mkdir(parents=True,exist_ok=True); output.write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(dict(success=True,selfCases=len(rows),emoteCases=len(emotes),report=str(output))))
