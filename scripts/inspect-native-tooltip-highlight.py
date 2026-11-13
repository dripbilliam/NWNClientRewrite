"""Read-only original highlight/instant-tooltip key dispatch research.

The pinned image is never launched. Static candidate references and decoded
instructions are research inputs; later execution observations are separate.
"""
import importlib.util,itertools,json,re,struct,sys
from pathlib import Path
spec=importlib.util.spec_from_file_location('image',Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
import capstone
cs=capstone.Cs(capstone.CS_ARCH_X86,capstone.CS_MODE_64)
start=0x1406ed720
instructions=[dict(address=hex(i.address),op=i.mnemonic,args=i.op_str)for i in cs.disasm(bytes(m.u.mem_read(start,0x1406ef64a-start)),start)if 0x1406ef300<=i.address<=0x1406ef46b]
references=[]
for section in m.pe.sections:
    if not section.Characteristics&0x20000000:continue
    code=section.get_data();origin=m.pe.OPTIONAL_HEADER.ImageBase+section.VirtualAddress
    for match in re.finditer(rb'[\x48\x4c]\x8d[\x05\x0d\x15\x1d\x25\x2d\x35\x3d](.{4})',code,re.S):
        address=origin+match.start();target=address+7+struct.unpack('<i',match.group(1))[0]
        if target==0x140e29f58:references.append(hex(address))
config_start=0x1406ae3b0
config=[dict(address=hex(i.address),op=i.mnemonic,args=i.op_str)for i in cs.disasm(bytes(m.u.mem_read(config_start,0x1406b6205-config_start)),config_start)if 0x1406b6120<=i.address]
frame_start=0x1406f14e0
frame=[dict(address=hex(i.address),op=i.mnemonic,args=i.op_str)for i in cs.disasm(bytes(m.u.mem_read(frame_start,0x1406f1bb3-frame_start)),frame_start)if 0x1406f16fc<=i.address<=0x1406f1750]
if '--inspect' in sys.argv:
    print(json.dumps(dict(binarySha256=m.digest,action97SwitchCase=m.u.mem_read(0x1406ef758+97,1)[0],candidateOptionReferences=references,instructions=instructions,registration=config,frame=frame)));sys.exit()

from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);ui=m.heap;exo=m.heap+0x1000;option=m.heap+0x2000
ranges=[(0x1406ed720,0x1406ef650),(0x1406f16f9,0x1406f1737),(0x1406b614f,0x1406b615a),(0x1406b618b,0x1406b61f9),(0x140134200,0x140134219),(0x140c10410,0x140c10431)]
def hook(u,address,size,data):
    if address in [m.stop,0x1406f1737,0x1406b615a,0x1406b61f9]:u.emu_stop();return
    x,y,z=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
    if address==0x1406d82f0:m.finish();return
    if address==0x1406ef7d0:
        events.append(int(y&0xffffffff));m.wi(ui+0x180,(m.si(ui+0x180)&~2)|(2 if y else 0));m.finish();return
    if address==0x14016dd40:m.finish(case['now']);return
    if address==0x14003dc20:
        name=bytes(u.mem_read(y,z));assert name==b'input.keyboard.tooltip-doubletap-threshold'
        raw=m.heap+0x4000;u.mem_write(raw,name+b'\0');m.wq(x,raw);m.wq(x+0x10,len(name));m.wq(x+0x18,len(name));m.finish(x);return
    if address==0x140119480:m.finish(case['threshold']);return
    if address==0x140c10360:m.finish();return
    if not any(lo<=address<hi for lo,hi in ranges):raise AssertionError(f'Unexpected original highlight dependency {address:x}')
u.hook_add(UC_HOOK_CODE,hook)
def reset(value):
    global case,events
    case=value;events=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
    m.wq(0x1412df8b8,exo);m.wq(exo,m.heap+0x3000);m.wq(exo+0x10,m.heap+0x5000)
    for offset,key in [(0x188,'held'),(0x190,'phase'),(0x194,'previous'),(0x18c,'refresh')]:m.wi(ui+offset,value.get(key,0))
    m.wi(ui+0x180,0x20|(2 if value.get('enabled',False)else 0))
def snapshot():return dict(held=m.si(ui+0x188),phase=m.si(ui+0x190),previous=m.si(ui+0x194)&0xffffffff,refresh=m.si(ui+0x18c)&0xffffffff,enabled=bool(m.si(ui+0x180)&2),events=events.copy())
def call(entry,args,limit=m.stop):
    sp=m.stack+0x1fd08;m.wq(sp,m.stop);m.wi(sp+0x28,0);u.reg_write(UC_X86_REG_RSP,sp)
    for register,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(register,value)
    u.emu_start(entry,m.stop,count=2000);assert u.reg_read(UC_X86_REG_RIP)==limit
reset({});u.reg_write(UC_X86_REG_RBP,m.heap+0x10000);call(0x1406b614f,[],0x1406b615a);default=m.q(m.heap+0x10000+0x278);assert default==200
reset({});u.reg_write(UC_X86_REG_RBP,m.heap+0x10000);u.reg_write(UC_X86_REG_RAX,option);call(0x1406b618b,[],0x1406b61f9);minimum,maximum=m.q(option+0x168),m.q(option+0x178);assert(minimum,maximum)==(0,1000)
rows=[]
for phase,held,pressed,threshold,elapsed in itertools.product([0,1,2,3,4,99],[0,1],[0,1],[0,200,1000],[0,199,200,201,999,1000,1001]):
    value=dict(phase=phase,held=held,pressed=pressed,threshold=threshold,previous=1000,now=1000+elapsed,refresh=333,enabled=bool(held));reset(value);call(0x1406ed720,[ui,97,pressed,0]);rows.append(dict(kind='key',input=value,output=snapshot()))
for phase,held,pressed,elapsed in itertools.product([0,1,2,3,4],[0,1],[0,1],[199,200,201]):
    value=dict(phase=phase,held=held,pressed=pressed,threshold=200,previous=0xffffffc0,now=(0xffffffc0+elapsed)&0xffffffff,refresh=333,enabled=bool(held));reset(value);call(0x1406ed720,[ui,97,pressed,0]);rows.append(dict(kind='key',input=value,output=snapshot()))
for held,elapsed,previous in itertools.product([0,1],[0,100,101,1000],[1000,0xffffffc0]):
    value=dict(phase=4,held=held,pressed=0,threshold=200,previous=444,now=(previous+elapsed)&0xffffffff,refresh=previous,enabled=False);reset(value);u.reg_write(UC_X86_REG_RBX,ui);call(0x1406f16f9,[],0x1406f1737);rows.append(dict(kind='refresh',input=value,output=snapshot()))
out=m.root/'backups/animations/native-tooltip-highlight-v1.json';assert not out.exists(),'Immutable original observations already exist'
out.write_text(json.dumps(dict(binarySha256=m.digest,scope='Complete original action97 key dispatcher with explicit modal/game/instant/string/config/timer providers; bounded original registration and held-refresh slices. Not original window input, rendering or packets.',defaultMs=default,minimumMs=minimum,maximumMs=maximum,action97SwitchCase=u.mem_read(0x1406ef758+97,1)[0],observations=rows),indent=2)+'\n')
print(json.dumps(dict(defaultMs=default,minimumMs=minimum,maximumMs=maximum,observations=len(rows),file=str(out))))
