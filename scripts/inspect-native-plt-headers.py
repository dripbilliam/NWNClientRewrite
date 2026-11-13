"""Execute original CResPLT uncompressed admission and attribute getters.

Synthetic bounded headers/payloads, no game/network/GPU. This proves original
header admission/metadata/pointer ownership, not palette sampling or pixels.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('image',Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);resource=m.heap;payload=m.heap+0x1000;outputs=m.heap+0x80000
allowed=[(0x1400fab60,0x1400fabee),(0x1400faa90,0x1400faac4)]
def hook(u,address,size,data):
    if address==m.stop:u.emu_stop();return
    if not any(start<=address<=end for start,end in allowed):raise AssertionError(f'Unexpected original dependency {address:x}')
u.hook_add(UC_HOOK_CODE,hook)
def call(entry,args):
    sp=m.stack+0x1fe08;u.mem_write(m.stack,bytes(0x20000));m.wq(sp,m.stop);u.reg_write(UC_X86_REG_RSP,sp)
    for register,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(register,value)
    u.emu_start(entry,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
    return u.reg_read(UC_X86_REG_RAX)&0xffffffff
rows=[]
for attribute,(width,height) in itertools.product([0,1,10,11,65535,4294967295],[(1,1),(64,64),(64,128)]):
    u.mem_write(m.heap,bytes(0x100000));raw=b'PLT V1  '+struct.pack('<4I',attribute,0,width,height)+bytes(width*height*2)
    u.mem_write(payload,raw);m.wq(resource+0x20,payload);m.wi(resource+0x30,len(raw))
    accepted=call(0x1400fab60,[resource]);assert accepted==1
    got=call(0x1400faa90,[resource,outputs,outputs+4,outputs+8]);values=struct.unpack('<3I',bytes(u.mem_read(outputs,12)))
    assert got==1 and values==(width,height,attribute) and m.q(resource+0x78)==payload+24 and m.si(resource+0x6c)==len(raw)-24
    rows.append(dict(attribute=attribute,width=width,height=height,accepted=accepted,metadata=list(values),pixelOffset=24,pixelBytes=m.si(resource+0x6c)))
for missing in [False,True]:
    u.mem_write(m.heap,bytes(0x100000))
    if not missing:u.mem_write(payload,b'BAD V1  '+struct.pack('<4I',11,0,64,64));m.wq(resource+0x20,payload);m.wi(resource+0x30,24)
    assert call(0x1400fab60,[resource])==0
out=m.root/'backups/animations/native-plt-header-v1.json'
assert not out.exists(),'Immutable original evidence already exists'
out.write_text(json.dumps(dict(binarySha256=m.digest,scope=__doc__,observations=rows,rejected=2),indent=2)+'\n')
print(json.dumps(dict(observations=len(rows),rejected=2,file=str(out))))
