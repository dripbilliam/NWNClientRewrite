"""Read-only complete GetItemInInventory1405283f0 wrapper.
Synthetic owner repositories, item IDs and cursors. Object casts, lookup,
linked-list GetNext/ItemListGetItem and base row lookup captured; native
branching, bag/outer cursor updates and store category traversal execute.
Does not validate repository import, allocator or stale-store infinite loops.
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
u.mem_map(heap,0x100000);u.mem_map(stack,0x10000);u.mem_map(stop,0x1000)
owner,app,vt,rules=[heap+n*0x1000 for n in range(4)]
def i(a):return int.from_bytes(u.mem_read(a,4),'little')
def h(a):return int.from_bytes(u.mem_read(a,2),'little')
def q(a):return int.from_bytes(u.mem_read(a,8),'little')
def wi(a,v):u.mem_write(a,struct.pack('<I',v&0xffffffff))
def wh(a,v):u.mem_write(a,struct.pack('<H',v&65535))
def wq(a,v):u.mem_write(a,struct.pack('<Q',v))
def finish(v=0):
    rsp=u.reg_read(UC_X86_REG_RSP);u.reg_write(UC_X86_REG_RIP,q(rsp));u.reg_write(UC_X86_REG_RSP,rsp+8);u.reg_write(UC_X86_REG_RAX,v)
def hook(u,a,n,_):
    global pushed
    if a==stop:u.emu_stop();return
    x,y,z=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
    if a==0x140286160:wi(y,77);finish(1)
    elif a==0x14055b4c0:finish(owner if c['kind'] else 0)
    elif a==0x14055b6c0:finish(items.get(y&0xffffffff,0))
    elif a==0x140286470:pushed=y&0xffffffff;finish(1)
    elif a in [stop+0x100,stop+0x108,stop+0x110,stop+0x118]:finish(owner if c['kind']=={stop+0x100:5,stop+0x108:9,stop+0x110:6,stop+0x118:14}[a] else 0)
    elif a==0x140169110:wq(y,next_nodes.get(q(y),0));finish()
    elif a==0x1404693e0:finish(items.get(node_ids.get(y,-1),0))
    elif a==0x14029ca00:finish(bases.get(y&0xffffffff,0))
    elif not(0x1405283f0<=a<0x14052895b):raise RuntimeError(f'Unmapped inventory enumeration dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def repo(values):
    global allocation
    allocation+=0x2000;p=allocation;internal=p+0x100;wq(p+0x10,internal);wi(internal+0x10,len(values));previous=0
    for k,id in enumerate(values):
        node=p+0x200+k*0x40;node_ids[node]=id
        if previous:next_nodes[previous]=node
        else:wq(internal,node)
        previous=node
    if previous:next_nodes[previous]=0
    return p
observations=[]
for kind,first,root_values,children,container,bag_owner in itertools.product([0,5,6,9,14,7],[False,True],[[],[100],[999,100,102],[100,101,102]], [[],[103,104],[101,103,104]], [0,1,2],[77,999]):
    c=dict(kind=kind,first=first,root=root_values,children=children,container=container,bagOwner=bag_owner);u.mem_write(heap,bytes(0x100000));items={};bases={};node_ids={};next_nodes={};allocation=heap+0x10000;wq(0x1412df970,app);wq(app+8,app);wq(0x1412df8f8,rules);wq(rules+0x20,rules);wq(owner,vt);wi(owner+8,77);wi(owner+0x50,77)
    for off,address in [(0x60,stop+0x100),(0x98,stop+0x108),(0x70,stop+0x110),(0xd0,stop+0x118)]:wq(vt+off,address)
    for n,id in enumerate(range(100,105)):
        p=heap+0x50000+n*0x1000;items[id]=p;wi(p+0x50,id);wi(p+0x40,id);wi(p+0x3c8,bag_owner if id==100 else 100 if id==101 else 77);bases[id]=p+0x800;wi(p+0x800+0x80,container if id in [100,101] else 0)
    root_repo=repo(root_values);child_repo=repo(children);nested=repo([104]);wq(items[100]+0x3d0,child_repo);wq(items[101]+0x3d0,nested)
    wq(owner+0x958,root_repo);wq(owner+0x540,root_repo);wq(owner+0x3d0,root_repo)
    for offset in [0x960,0x548]:wi(owner+offset,0);wi(owner+offset+4,0x7f000000)
    wh(owner+0x460,0);wh(owner+0x388,0);u.mem_write(owner+0x38a,bytes([0]))
    stock=[[],[101],[],[100,102],[]]
    for n,values in enumerate(stock):wq(owner+0x328+n*8,repo(values))
    outputs=[]
    for n in range(7):
        pushed=None;rsp=stack+0xff08;u.mem_write(rsp-0x100,bytes(0x180));wq(rsp,stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,owner);u.reg_write(UC_X86_REG_RDX,339 if first and n==0 else 340)
        u.emu_start(0x1405283f0,stop,count=15000);assert u.reg_read(UC_X86_REG_RIP)==stop
        offset=0x960 if kind==5 else 0x548
        outputs.append(dict(id=pushed,outer=h(owner+offset),inner=h(owner+offset+2),bag=i(owner+offset+4),item=h(owner+0x460),store=h(owner+0x388),category=u.mem_read(owner+0x38a,1)[0]))
    observations.append(dict(case=c,outputs=outputs))
out=root/'backups/animations/native-inventory-enumeration-observations.json';out.write_text(json.dumps(dict(binarySha256=digest,limits=__doc__,observations=observations),indent=2));print(json.dumps(dict(output=str(out),observations=len(observations))))
