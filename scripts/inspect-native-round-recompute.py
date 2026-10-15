"""Read-only original RecomputeRound140378960. Class/weapon/feat queries,
InitializeNumberOfAttacks, linked-list cursor/removal and feedback are captured.
All owner instructions and future-group mutations execute unchanged; no full
equipment/effects/attack-count provider or allocation-failure parity claim.
"""
from pathlib import Path
import sys,struct,hashlib,json,itertools,re
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from unicorn import Uc,UC_ARCH_X86,UC_MODE_64,UC_HOOK_CODE
from unicorn.x86_const import *
data=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes();digest=hashlib.sha256(data).hexdigest()
assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=data);base=pe.OPTIONAL_HEADER.ImageBase
u=Uc(UC_ARCH_X86,UC_MODE_64);u.mem_map(base,(pe.OPTIONAL_HEADER.SizeOfImage+4095)&~4095);u.mem_write(base,pe.get_memory_mapped_image())
heap,stack,stop=0x200000000,0x300000000,0x400000000
u.mem_map(heap,0x20000);u.mem_map(stack,0x10000);u.mem_map(stop,0x1000)
r,o,stats,item,baseinfo,inventory,wrapper,linked=[heap+n*0x4000 for n in range(8)]
def i(a):return int.from_bytes(u.mem_read(a,4),'little')
def si(a):return struct.unpack('<i',u.mem_read(a,4))[0]
def q(a):return int.from_bytes(u.mem_read(a,8),'little')
def wi(a,v):u.mem_write(a,struct.pack('<I',v&0xffffffff))
def wq(a,v):u.mem_write(a,struct.pack('<Q',v))
def finish(v=0):
    rsp=u.reg_read(UC_X86_REG_RSP);u.reg_write(UC_X86_REG_RIP,q(rsp));u.reg_write(UC_X86_REG_RSP,rsp+8);u.reg_write(UC_X86_REG_RAX,v&0xffffffffffffffff)
def sync():
    wq(linked,nodes[0] if nodes else 0)
    for n,ptr in enumerate(nodes):wq(ptr+8,nodes[n+1] if n+1<len(nodes) else 0)
def hook(u,a,n,_):
    if a==stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
    if a==0x1403fa4a0:finish(c['classes'][y&255])
    elif a==0x140462bd0:finish(item if c['right'] else 0)
    elif a==0x14029ca00:finish(baseinfo)
    elif a==0x14040b900:calls.append(['feat',y&65535]);finish(c['feat899'] if y==899 else c['feat866'])
    elif a==0x140392fd0:calls.append(['size']);finish(c['size'])
    elif a==0x1403a2480:calls.append(['feedback',y&0xffffffff]);finish()
    elif a==0x1403d8c50:calls.append(['mode',y&255,z&0xffffffff]);u.mem_write(o+0x6ef,bytes([y&255]));finish()
    elif a==0x1403773a0:calls.append(['initialize']);wi(r+0x2f50,c['new']);finish(c['new'])
    elif a==0x140169110:
        next=q(q(y)+8);wq(y,next);finish(q(next+0x10) if next else 0)
    elif a==0x1401691f0:
        value=q(y+0x10);nodes.remove(y);sync();finish(value)
    elif a==0x140c10360:finish()
    elif not 0x140378960<=a<0x140378d47:raise RuntimeError(f'Unmapped recomputation dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
    global c,calls,nodes
    c=case;calls=[];nodes=[];u.mem_write(heap,bytes(0x20000));wq(0x1412df8f8,o+0x1000);wq(o+0x1020,baseinfo);wq(r+0x2f78,o);wq(o+0xad0,stats);wq(o+0x950,inventory);wq(r+0x2f70,wrapper);wq(wrapper,linked)
    u.mem_write(o+0x6ef,bytes([c['mode']]));u.mem_write(stats+0xd8,bytes([len(c['classes'])]));u.mem_write(r+0x2f2c,bytes([c['current']]));wi(r+0x2f50,c['old'])
    wi(item+0x40,c['baseItem']);u.mem_write(baseinfo+0x18,bytes([c['ranged']]));wi(baseinfo+0xc0,c['monk'])
    for n,action in enumerate(c['actions']):
        ptr=heap+0x1f000+n*0x100;value=ptr+0x40;nodes.append(ptr);wq(ptr+0x10,value);wi(value+0xc,action['count']);u.mem_write(value+0x10,bytes([action['nativeActionType']]))
    sync();rsp=stack+0xff08;wq(rsp,stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,r)
    try:u.emu_start(0x140378960,stop,count=10000)
    except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
    assert u.reg_read(UC_X86_REG_RIP)==stop
    return dict(case=c,calls=calls,mode=int.from_bytes(u.mem_read(o+0x6ef,1),'little'),actions=[dict(count=si(q(ptr+0x10)+0xc),nativeActionType=int.from_bytes(u.mem_read(q(ptr+0x10)+0x10,1),'little')) for ptr in nodes])
a=lambda count,type=1:dict(count=count,nativeActionType=type)
default=dict(mode=0,classes=[],right=False,baseItem=8,ranged=0,monk=0,feat899=0,feat866=0,size=0,old=3,new=2,current=0,actions=[a(1),a(1),a(1)])
rows=[run(default|dict(old=old,new=new,current=current,actions=actions)) for old,new,current,actions in itertools.product([0,1,2,3,5,258],[0,1,2,3,4],[0,1,2,4],[[],[a(1)],[a(2),a(2),a(1)],[a(0,6),a(1),a(1)],[a(1),a(0,7)],[a(0,6),a(0,4)],[a(2),a(1),a(3)]])]
rows += [run(default|dict(mode=mode,classes=classes,right=right,baseItem=baseItem,ranged=ranged,monk=monk,feat899=feat899,feat866=feat866,size=size)) for mode,classes,right,baseItem,ranged,monk,feat899,feat866,size in itertools.product([0,1,5,6,11,12],[[],[5],[40],[0,5,40]],[False,True],[6,8],[0,1],[0,1],[0,1],[0,1],[-1,0])]
out=root/'backups/animations/native-round-recompute-observations.json';out.write_text(json.dumps(dict(binarySha256=digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
