"""Read-only complete script Math cos wrapper + original double CRT SSE
cosine/sine. VM float pop/push captured; degree conversion, libm instructions and
float32 return execute unchanged. FMA CPU dispatch and exceptional/large
range reduction/errno are not validated by this bounded capture.
"""
from pathlib import Path
import sys,struct,hashlib,json
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from unicorn import Uc,UC_ARCH_X86,UC_MODE_64,UC_HOOK_CODE
from unicorn.x86_const import *
data=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes();digest=hashlib.sha256(data).hexdigest()
assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=data);base=pe.OPTIONAL_HEADER.ImageBase
u=Uc(UC_ARCH_X86,UC_MODE_64);u.mem_map(base,(pe.OPTIONAL_HEADER.SizeOfImage+4095)&~4095);u.mem_write(base,pe.get_memory_mapped_image())
heap,stack,stop=0x200000000,0x300000000,0x400000000
u.mem_map(heap,0x1000);u.mem_map(stack,0x10000);u.mem_map(stop,0x1000)
def q(a):return int.from_bytes(u.mem_read(a,8),'little')
def finish(v=0):
    rsp=u.reg_read(UC_X86_REG_RSP);u.reg_write(UC_X86_REG_RIP,q(rsp));u.reg_write(UC_X86_REG_RSP,rsp+8);u.reg_write(UC_X86_REG_RAX,v)
def hook(u,a,n,_):
    global pushed
    if a==stop:u.emu_stop();return
    if a==0x1402860c0:u.mem_write(u.reg_read(UC_X86_REG_RDX),struct.pack('<f',value));finish(1)
    elif a==0x1402863b0:pushed=u.reg_read(UC_X86_REG_XMM1)&0xffffffff;finish(1)
    elif a==0x140c10324:finish(heap+0x800)
    elif a==0x140286160:u.mem_write(u.reg_read(UC_X86_REG_RDX),struct.pack('<I',areaId));finish(1)
    elif a==0x140286250:u.mem_write(u.reg_read(UC_X86_REG_RDX),struct.pack('<fff',.25,-3,7));finish(1)
    elif a==0x140286330:pushed=bytes(u.mem_read(u.reg_read(UC_X86_REG_R8),28));finish(1)
    elif a==0x140c10360:finish()
    elif not(0x140314240<=a<0x140314490 or 0x140c79d30<=a<0x140c7a2aa or 0x140c92d20<=a<0x140c93360 or 0x1405354a0<=a<0x1405355fe or 0x140230920<=a<0x1402309f5):raise RuntimeError(f'Unmapped script trigonometric dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook);u.mem_write(heap+0x10,struct.pack('<Q',heap+0x100));u.mem_write(heap+0x18,struct.pack('<I',1));u.mem_write(0x1415d8224,bytes(4))
values=[n/8 for n in range(-8192,8193)]+[0,90,180,270,360,-90,-180,359.99999,90.00001,-0.0]
observations=[]
for value,ordinal in [(value,ordinal) for value in values for ordinal in [68,69]]:
    value=struct.unpack('<f',struct.pack('<f',value))[0];pushed=None;rsp=stack+0xff08;u.mem_write(rsp-0x200,bytes(0x280));u.mem_write(rsp,struct.pack('<Q',stop));u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,heap);u.reg_write(UC_X86_REG_RDX,ordinal)
    u.emu_start(0x140314240,stop,count=3000);assert u.reg_read(UC_X86_REG_RIP)==stop;observations.append(dict(degrees=value,ordinal=ordinal,bits=pushed))
out=root/'backups/animations/native-script-cos-observations.json';out.write_text(json.dumps(dict(binarySha256=digest,limits=__doc__,degreesToRadians=struct.unpack('<d',u.mem_read(0x140dd3410,8))[0],observations=observations),indent=2));print(json.dumps(dict(output=str(out),observations=len(observations))))
locations=[]
for value,areaId in [(degree,id) for degree in [0,45,90,180,270,360,-180,33.3] for id in [0,77,0x7f000000,0x80000001,0xffffffff]]:
    pushed=None;rsp=stack+0xff08;u.mem_write(rsp-0x200,bytes(0x280));u.mem_write(rsp,struct.pack('<Q',stop));u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,heap)
    u.emu_start(0x1405354a0,stop,count=3000);assert u.reg_read(UC_X86_REG_RIP)==stop
    locations.append(dict(degrees=value,area=areaId,position=list(struct.unpack_from('<fff',pushed)),orientation=list(struct.unpack_from('<fff',pushed,12)),storedArea=struct.unpack_from('<I',pushed,24)[0]))
out=root/'backups/animations/native-script-location-observations.json';out.write_text(json.dumps(dict(binarySha256=digest,limits=__doc__+' Location construction additionally executes original vector normalization; allocation/pop/push/free are captured.',observations=locations),indent=2));print(json.dumps(dict(output=str(out),locations=len(locations))))
