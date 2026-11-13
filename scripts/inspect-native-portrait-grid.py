"""Pinned original portrait grid/reveal instructions, CPU-only isolated emulator.
Resource-size selection and GUI/string calls are captured boundaries; no game,
window, network, directory enumeration or raster rendering is executed.
"""
from pathlib import Path
import sys,struct,hashlib,json
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from unicorn import Uc,UC_ARCH_X86,UC_MODE_64,UC_HOOK_CODE
from unicorn.x86_const import *
data=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes()
digest=hashlib.sha256(data).hexdigest()
assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=data); base=pe.OPTIONAL_HEADER.ImageBase
u=Uc(UC_ARCH_X86,UC_MODE_64);u.mem_map(base,(pe.OPTIONAL_HEADER.SizeOfImage+4095)&~4095);u.mem_write(base,pe.get_memory_mapped_image())
heap,stack,stop=0x200000000,0x300000000,0x400000000
u.mem_map(heap,0x20000);u.mem_map(stack,0x20000);u.mem_map(stop,0x1000)
panel,refs,widgets,objects,source=heap,heap+0x2000,heap+0x5000,heap+0x6000,heap+0x8000
def q(a):return int.from_bytes(u.mem_read(a,8),'little')
def wi(a,v):u.mem_write(a,struct.pack('<I',v&0xffffffff))
def wq(a,v):u.mem_write(a,struct.pack('<Q',v))
def string(a):return bytes(u.mem_read(a,64)).split(b'\0',1)[0]
def write(a,v):u.mem_write(a,v[:16].ljust(17,b'\0'))
def finish(v=0):
    rsp=u.reg_read(UC_X86_REG_RSP);u.reg_write(UC_X86_REG_RIP,q(rsp));u.reg_write(UC_X86_REG_RSP,rsp+8);u.reg_write(UC_X86_REG_RAX,v&0xffffffffffffffff)
def hook(u,a,n,_):
    if a==stop:u.emu_stop();return
    x,y,z=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
    if a in [0x14018de80,0x14018ded0]:write(x,string(y));finish(x)
    elif a==0x14018df10:finish(int(string(x).lower()==string(y).lower()))
    elif a==0x14084c170:write(x,b'');finish(x)
    elif a in [0x14084c1a0,0x140c10410]:finish()
    elif a==0x14084c2f0:write(y,string(x)+b'm');finish(y)
    elif a==0x14084c550:images.append([x-0x500000000,string(y).decode('ascii')]);finish()
    elif a==0x1401eff30:tabs.append(struct.unpack('<i',struct.pack('<I',y&0xffffffff))[0]);finish()
    elif a==0x1401e7720:scrolls.append(y&0xffffffff);finish()
    elif not (0x1409d1350<=a<=0x1409d14eb or 0x1409d28d0<=a<=0x1409d298a):raise RuntimeError(hex(a))
u.hook_add(UC_HOOK_CODE,hook)
def setup(count,selected=''):
    u.mem_write(panel,bytes(0x800));wq(panel+0x408,refs);wi(panel+0x410,count);wi(panel+0x4c0,min(24,count));wq(panel+0x108,widgets);write(panel+0x4c8,selected.encode())
    for i in range(count):write(refs+i*17,f'p{i:03}_'.encode())
    for i in range(24):wq(widgets+i*8,objects+i*32);wq(objects+i*32+16,0x500000000+i)
def invoke(entry,argument):
    rsp=stack+0x1fe08;u.mem_write(rsp-0x300,bytes(0x400));wq(rsp,stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,panel);u.reg_write(UC_X86_REG_RDX,argument)
    u.emu_start(entry,stop,count=30000);assert u.reg_read(UC_X86_REG_RIP)==stop
rows=[];reveals=[]
for count in [0,1,5,6,17,18,19,23,24,25,35,36,37,71,128]:
    maximum=(count//18)*321
    for position in sorted({0,min(1,maximum),min(106,maximum),min(107,maximum),min(320,maximum),min(321,maximum),maximum}):
        for selected in ['',f'p{max(0,count-1):03}_','p000_']:
            setup(count,selected);images=[];tabs=[];scrolls=[];invoke(0x1409d1350,position)
            rows.append(dict(count=count,position=position,selected=selected,images=images,tabs=tabs,firstRow=int.from_bytes(u.mem_read(panel+0x4c4,4),'little')))
    for selected in ['', 'absent_',f'p{max(0,count-1):03}_','p000_',f'p{min(18,max(0,count-1)):03}_']:
        setup(count);write(source,selected.encode());images=[];tabs=[];scrolls=[];invoke(0x1409d28d0,source)
        reveals.append(dict(count=count,selected=selected,result=u.reg_read(UC_X86_REG_RAX),scrolls=scrolls,tabs=tabs))
out=dict(target=digest,scope=__doc__,scrollEntry='0x1409d1350',revealEntry='0x1409d28d0',scroll=rows,reveal=reveals)
path=root/'backups/animations/native-portrait-grid-v1.json'
if path.exists():raise RuntimeError('Evidence already exists')
path.write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps(dict(scrollCases=len(rows),revealCases=len(reveals),target=digest)))
