"""Read-only native repository insertion oracle, build89.

Complete AddItem, CheckFit, FindPosition and AddPanel bodies execute for the
no-merge import path. Synthetic unowned repository; canonical/list/base queries,
module lookup, allocation/head insertion and warning sink are substituted.
Does not validate gold, merges, possession/equipment or event handlers.
"""
from pathlib import Path
import sys,hashlib,struct,json,itertools
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
repo,item,info,app,linked,vt,other,ref=[heap+n*0x1000 for n in range(8)]
def q(a):return struct.unpack('<Q',u.mem_read(a,8))[0]
def i(a):return struct.unpack('<I',u.mem_read(a,4))[0]
def wi(a,v):u.mem_write(a,struct.pack('<I',v&0xffffffff))
def wb(a,v):u.mem_write(a,bytes([v&255]))
def wq(a,v):u.mem_write(a,struct.pack('<Q',v))
def finish(v=0):
    rsp=u.reg_read(UC_X86_REG_RSP);u.reg_write(UC_X86_REG_RIP,q(rsp));u.reg_write(UC_X86_REG_RSP,rsp+8);u.reg_write(UC_X86_REG_RAX,v)
case={};warnings=0
def hook(u,a,n,_):
    global warnings
    if a==stop:u.emu_stop();return
    x,y,z=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
    if a==0x14055b6e0:finish(app+0x400)
    elif a in [0x14055b4c0,0x14055b3d0]:finish()
    elif a==0x14029ca00:finish(info if y==1 else info+0x100)
    elif a==0x14055b850:finish(app+0x100)
    elif a==0x1401690b0:finish(y+8)
    elif a==0x140169110:wq(y,q(q(y)));finish()
    elif a==0x140296470:wq(z,other);finish()
    elif a==stop+0x100:finish(x)
    elif a==0x140c10324:finish(heap+0x8000)
    elif a==0x140168fb0:
        node=heap+0xc000;wq(node,q(linked));wi(node+8,i(y));wq(linked,node);finish()
    elif a==0x140115890:warnings+=1;finish()
    elif not(0x140464200<=a<0x140464b01 or 0x140465c10<=a<0x140465e59 or 0x1404681d0<=a<0x1404686ce or 0x140464b10<=a<0x140464b4c):
        raise RuntimeError(f'Unmapped repository AddItem dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
observations=[]
for x,y,(width,height),pool,expand in itertools.product([0,9,255,256],[0,5,255,256],[(1,1),(2,2),(10,6),(11,7)],[0,1,2],[0,1]):
    case={'x':x,'y':y,'width':width,'height':height,'pool':pool,'expand':expand};warnings=0;u.mem_write(heap,bytes(0x10000))
    wq(0x1412df8f8,app);wq(0x1412df970,app);wq(app+0x20,app+0x200);wq(app+8,app+0x300)
    wb(repo,10);wb(repo+1,36);wi(repo+4,60);wi(repo+8,0x7f000000);wi(repo+0xc,expand);wq(repo+0x10,linked)
    wi(item+0x40,1);wi(item+0x50,1);wi(item+0x3c8,0x7f000000);wi(item+0x454,1);wb(item+0x3d8,255);wb(item+0x3d9,255);wq(ref,item)
    wb(info+0x14,width);wb(info+0x15,height);wq(vt+0x70,stop+0x100)
    if pool:
        node=heap+0xb000;wq(linked,node);wi(node+8,1 if pool==2 else 2)
        wq(other,vt);wi(other+0x40,2);wi(other+0x50,1 if pool==2 else 2)
        wb(info+0x114,10);wb(info+0x115,36)
    rsp=stack+0xff08;u.mem_write(rsp-0x200,bytes(0x280));wq(rsp,stop);wi(rsp+0x28,123);wi(rsp+0x30,0)
    for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9,UC_X86_REG_RSP],[repo,ref,x,y,rsp]):u.reg_write(reg,value)
    u.emu_start(0x140464200,stop,count=300000);assert u.reg_read(UC_X86_REG_RIP)==stop
    ids=[];node=q(linked)
    while node:ids.append(i(node+8));node=q(node)
    observations.append({'case':case,'result':{'value':u.reg_read(UC_X86_REG_RAX)&0xffffffff,'x':u.mem_read(item+0x3d8,1)[0],'y':u.mem_read(item+0x3d9,1)[0],
      'height':u.mem_read(repo+1,1)[0],'ids':ids,'warnings':warnings}})
output=root/'backups/animations/native-repository-add-observations.json'
output.write_text(json.dumps({'binarySha256':digest,'limits':__doc__,'observations':observations},indent=2))
print(json.dumps({'output':str(output),'observations':len(observations)}))
