"""Read-only original resumable path Create/Delete/Get/Set owners. Allocation
and frees captured with deliberately dirty INT buffers; pointer initialization,
transfer identity and scalar cleanup execute original instructions. No native
heap failure, undefined INT read, stale pointer or negative-index parity claim.
"""
from pathlib import Path
import sys,struct,hashlib,json,itertools,re
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from unicorn import Uc,UC_ARCH_X86,UC_MODE_64,UC_HOOK_CODE
from unicorn.x86_const import *
data=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes();digest=hashlib.sha256(data).hexdigest();assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=data);base=pe.OPTIONAL_HEADER.ImageBase
u=Uc(UC_ARCH_X86,UC_MODE_64);u.mem_map(base,(pe.OPTIONAL_HEADER.SizeOfImage+4095)&~4095);u.mem_write(base,pe.get_memory_mapped_image())
heap,stack,stop=0x200000000,0x300000000,0x400000000
u.mem_map(heap,0x20000);u.mem_map(stack,0x10000);u.mem_map(stop,0x1000)
path,output,oldNodes,oldStarts,oldCounts,pool0,pool1,pool2=[heap+n*0x1000 for n in range(8)]
ranges=[]
for file in ['live-native-path-alternatives-full-asm.txt','live-native-path-alternatives-leaf-asm.txt']:
    for line in (root/'backups/animations'/file).read_text().splitlines():
        if line.startswith('FUNCTION REQUESTED'):ranges.extend((int(a,16),int(b,16)) for a,b in re.findall(r'([0-9a-f]+):([0-9a-f]+)',line))
def i(a):return int.from_bytes(u.mem_read(a,4),'little')
def si(a):return struct.unpack('<i',u.mem_read(a,4))[0]
def q(a):return int.from_bytes(u.mem_read(a,8),'little')
def wi(a,v):u.mem_write(a,struct.pack('<I',v&0xffffffff))
def wq(a,v):u.mem_write(a,struct.pack('<Q',v))
def finish(v=0):
    rsp=u.reg_read(UC_X86_REG_RSP);u.reg_write(UC_X86_REG_RIP,q(rsp));u.reg_write(UC_X86_REG_RSP,rsp+8);u.reg_write(UC_X86_REG_RAX,v&0xffffffffffffffff)
def hook(u,a,n,_):
    if a==stop:u.emu_stop();return
    x=u.reg_read(UC_X86_REG_RCX)
    if a==0x140c10368:
        ptr=[pool0,pool1,pool2][len(allocations)];allocations.append(x);u.mem_write(ptr,bytes([0xa5])*0x1000);finish(ptr)
    elif a==0x140c10370:freed.append(x);finish()
    elif not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Unmapped alternatives dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def invoke(entry,args,extras=[]):
    rsp=stack+0xff08;u.mem_write(rsp-0x100,bytes(0x180));wq(rsp,stop);u.reg_write(UC_X86_REG_RSP,rsp)
    for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(reg,value&0xffffffffffffffff)
    for n,value in enumerate(extras):wq(rsp+0x28+n*8,value)
    u.emu_start(entry,stop,count=20000);assert u.reg_read(UC_X86_REG_RIP)==stop
def run(case):
    global allocations,freed
    c=case;allocations=[];freed=[];u.mem_write(heap,bytes(0x20000));wi(path+0x104,c['oldCount']);wi(path+0x100,9);wi(path+0xf8,1)
    if c['present']:
        wq(path+0x118,oldNodes);wq(path+0x108,oldStarts);wq(path+0x110,oldCounts)
        for n in range(c['oldCount']):wq(oldNodes+n*8,heap+0x9000+n*0x100 if n%2 else 0)
    if c['mode']=='delete':invoke(0x140294090,[path]);observations=[];dirty=[];initialPointers=[]
    else:
        invoke(0x140293eb0,[path,c['newCount']]);initialPointers=[q(pool0+n*8) for n in range(c['newCount'])];dirty=[i(pool1+n*4) for n in range(c['newCount'])]+[i(pool2+n*4) for n in range(c['newCount'])];observations=[]
        for n in range(c['newCount']):
            pointer=heap+0xb000+n*0x100 if n%2 else 0
            invoke(0x140294b20,[path,n,n-2,c['savedCount']],[pointer]);invoke(0x1402941c0,[path,n,output,output+4],[output+8]);observations.append(dict(start=si(output),count=si(output+4),node=n if q(output+8) else None))
    return dict(case=c,allocations=allocations,freedCount=len(freed),count=si(path+0x104),flags=[i(path+0xf8),i(path+0x100)],pointers=[q(path+off)!=0 for off in [0x108,0x110,0x118]],observations=observations,initialPointers=initialPointers,dirty=dirty,oldNodeCells=[q(oldNodes+n*8) for n in range(c['oldCount'])])
default=dict(mode='create',present=False,oldCount=0,newCount=3,savedCount=3)
rows=[run(default|dict(mode=mode,present=present,oldCount=old,newCount=new,savedCount=count)) for mode,present,old,new,count in itertools.product(['create','delete'],[False,True],[0,1,2,3],[0,1,2,3,6],[-3,0,7])]
out=root/'backups/animations/native-path-alternative-observations.json';out.write_text(json.dumps(dict(binarySha256=digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
