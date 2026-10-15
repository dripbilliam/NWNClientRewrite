"""Read-only full RemoveFromActiveCreatureCount14043e480 body.
Synthetic prepared encounter storage; points, event allocation/constructor,
SetScriptObject, AddEvent and world clock captured. Does not validate caller
corpse scheduling, event delivery, transitive CR cost or allocation failure.
"""
from pathlib import Path
import sys,struct,hashlib,json,itertools
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from unicorn import Uc,UC_ARCH_X86,UC_MODE_64,UC_HOOK_CODE
from unicorn.x86_const import *
data=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes();digest=hashlib.sha256(data).hexdigest()
assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=data);base=pe.OPTIONAL_HEADER.ImageBase
u=Uc(UC_ARCH_X86,UC_MODE_64);u.mem_map(base,(pe.OPTIONAL_HEADER.SizeOfImage+4095)&~4095);u.mem_write(base,pe.get_memory_mapped_image())
heap,stack,stop=0x200000000,0x300000000,0x400000000
u.mem_map(heap,0x10000);u.mem_map(stack,0x10000);u.mem_map(stop,0x1000)
enc,app,entries,event,timer=[heap+n*0x1000 for n in range(5)]
def i(a):return int.from_bytes(u.mem_read(a,4),'little')
def si(a):return struct.unpack('<i',u.mem_read(a,4))[0]
def q(a):return int.from_bytes(u.mem_read(a,8),'little')
def wi(a,v):u.mem_write(a,struct.pack('<I',v&0xffffffff))
def wq(a,v):u.mem_write(a,struct.pack('<Q',v))
def rf(a):return struct.unpack('<f',u.mem_read(a,4))[0]
def wf(a,v):u.mem_write(a,struct.pack('<f',v))
def xm(r):return struct.unpack('<f',u.reg_read(r).to_bytes(16,'little')[:4])[0]
def finish(v=0):
    rsp=u.reg_read(UC_X86_REG_RSP);u.reg_write(UC_X86_REG_RIP,q(rsp));u.reg_write(UC_X86_REG_RSP,rsp+8);u.reg_write(UC_X86_REG_RAX,v)
def hook(u,a,n,_):
    if a==stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
    if a==0x14043b220:calls.append(['points',xm(UC_X86_REG_XMM1)]);u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',.75),'little'));finish()
    elif a==0x140c10324:finish(event)
    elif a==0x1404c6490:finish(x)
    elif a==0x1404c7320:calls.append(['object',y&0xffffffff,z&0xffffffff]);finish()
    elif a==0x14055b960:finish(app)
    elif a==0x1405570b0:calls.append(['event',y&0xffffffff,z&0xffffffff,w&0xffffffff,i(rsp+0x28),i(rsp+0x30),i(q(rsp+0x38))&65535]);finish()
    elif a==0x14055ba10:finish(timer)
    elif a==0x140597180:calls.append(['time']);wi(y,42);wi(z,5000);finish()
    elif not(0x14043e480<=a<0x14043e60b):raise RuntimeError(f'Unmapped encounter death dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
observations=[]
for count,active,flag,reset in itertools.product([-1,0,1,2],[0,.5,10],[0,1,2,-1],[0,1,2]):
    case=dict(count=count,active=active,flag=flag,reset=reset);calls=[];u.mem_write(heap,bytes(0x10000));wq(0x1412df970,app);wq(app+8,app)
    wi(enc+8,77);wi(enc+0x320,1);wi(enc+0x324,reset);wi(enc+0x340,count);wi(enc+0x354,1);wi(enc+0x34c,12);wi(enc+0x350,34);wf(enc+0x3c4,5);wf(enc+0x3c8,active);wq(enc+0x390,entries);wi(enc+0x398,3)
    for n in range(3):wi(entries+n*0x28+0x1c,n+1);wi(entries+n*0x28+0x20,n+2)
    rsp=stack+0xff08;u.mem_write(rsp-0x200,bytes(0x280));wq(rsp,stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,enc);u.reg_write(UC_X86_REG_R8,flag&0xffffffff);u.reg_write(UC_X86_REG_XMM1,int.from_bytes(struct.pack('<f',.5),'little'))
    u.emu_start(0x14043e480,stop,count=3000);assert u.reg_read(UC_X86_REG_RIP)==stop
    observations.append(dict(case=case,calls=calls,count=si(enc+0x340),active=rf(enc+0x3c8),pool=rf(enc+0x3c4),enabled=si(enc+0x320),started=si(enc+0x354),lastSpawn=dict(day=i(enc+0x34c),time=i(enc+0x350)),entries=[[si(entries+n*0x28+0x1c),si(entries+n*0x28+0x20)] for n in range(3)]))
out=root/'backups/animations/native-encounter-death-observations.json';out.write_text(json.dumps(dict(binarySha256=digest,limits=__doc__,observations=observations),indent=2));print(json.dumps(dict(output=str(out),observations=len(observations))))
