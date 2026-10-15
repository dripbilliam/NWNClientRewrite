"""Read-only build89 client base-state transition observations.

Executes full140764300..140765470 and category/record constructors. Synthetic
actor has object type5 and a valid animation context; AsCreature returns null
to isolate generic body-state transitions from weapon/ambient side effects.
PlayAnimation and animation-engine virtuals are captured, not executed.
Creature emote clearing14080b200 is a captured no-op for synthetic states70/71.
Empty queue, zero timer: observations do not validate creature hooks, packet
timing or blending.
"""
from pathlib import Path
import sys,struct,hashlib,json,itertools
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from unicorn import Uc,UC_ARCH_X86,UC_MODE_64,UC_HOOK_CODE
from unicorn.x86_const import *
data=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes()
digest=hashlib.sha256(data).hexdigest()
assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=data);base=pe.OPTIONAL_HEADER.ImageBase
u=Uc(UC_ARCH_X86,UC_MODE_64);u.mem_map(base,(pe.OPTIONAL_HEADER.SizeOfImage+4095)&~4095);u.mem_write(base,pe.get_memory_mapped_image())
heap,stack,stop=0x200000000,0x300000000,0x400000000
u.mem_map(heap,0x10000);u.mem_map(stack,0x10000);u.mem_map(stop,0x1000)
actor,context,vt,cvt,record=[heap+n*0x1000 for n in range(5)]
def q(a):return struct.unpack('<Q',u.mem_read(a,8))[0]
def h(a):return struct.unpack('<H',u.mem_read(a,2))[0]
def wq(a,v):u.mem_write(a,struct.pack('<Q',v))
def wh(a,v):u.mem_write(a,struct.pack('<H',v))
def finish(v=0):
    rsp=u.reg_read(UC_X86_REG_RSP);u.reg_write(UC_X86_REG_RIP,q(rsp));u.reg_write(UC_X86_REG_RSP,rsp+8);u.reg_write(UC_X86_REG_RAX,v)
calls=[]
def hook(u,a,n,_):
    if a==stop:u.emu_stop();return
    x,y,z=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
    if a in [stop+0x10,stop+0x20,stop+0x30]:finish()
    elif a==stop+0x40:
        calls.append({'animation':y&65535,'reaction':h(z+0x16) if z else 0,'reactionDuration':h(z+0x14) if z else 0});finish()
    elif a==stop+0x50:finish(1)
    elif a==0x140c10324:finish(record)
    elif a==0x14080b200:finish()
    elif not(0x140764300<=a<0x140765470 or 0x140762530<=a<0x1407625c9 or 0x1407fb0e0<=a<0x1407fb13a):
        raise RuntimeError(f'Unmapped transition dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
observations=[]
cases=list(itertools.product([0,1,4,5,6,7,8,9],range(9)))
states=list(range(171))+[250,251,252,253,261,267,273]
cases+=list(itertools.product(states,states))
for previous,requested in dict.fromkeys(cases):
    u.mem_write(heap,bytes(0x10000));calls=[]
    wq(actor,vt);wq(actor+0x78,context);u.mem_write(actor+0xc,b'\x05');wh(actor+0x64,previous);wh(actor+0x5c,previous)
    u.mem_write(actor+0x60,struct.pack('<f',1))
    wq(vt+0x58,stop+0x10);wq(vt+0x150,stop+0x40)
    wq(context,cvt);wq(cvt+0x70,stop+0x20);wq(cvt+0x60,stop+0x30);wq(cvt+0x80,stop+0x50)
    rsp=stack+0xff08;u.mem_write(rsp-0x200,bytes(0x280));wq(rsp,stop)
    for reg,val in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_RSP],[actor,requested,rsp]):u.reg_write(reg,val)
    u.emu_start(0x140764300,stop,count=20000);assert u.reg_read(UC_X86_REG_RIP)==stop
    observations.append({'previous':previous,'requested':requested,'calls':calls,'base':h(actor+0x64)})
output=root/'backups/animations/native-body-transition-observations.json'
categories=[]
for kind,animation in itertools.product([5,9,10,4],list(range(426))+[65535,65536]):
    u.mem_write(actor+0xc,bytes([kind]));rsp=stack+0xff08;wq(rsp,stop)
    for reg,val in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_RSP],[actor,animation,rsp]):u.reg_write(reg,val)
    u.emu_start(0x140762530,stop,count=1000);assert u.reg_read(UC_X86_REG_RIP)==stop
    categories.append({'kind':kind,'animation':animation,'category':u.reg_read(UC_X86_REG_RAX)})
output.write_text(json.dumps({'binarySha256':digest,'limits':__doc__,'observations':observations,'categories':categories},indent=2))
print(json.dumps({'output':str(output),'observations':len(observations)}))
