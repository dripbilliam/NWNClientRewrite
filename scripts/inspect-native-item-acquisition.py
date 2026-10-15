"""Read-only build89 CreateItemOnObject and fresh creature AcquireItem oracle.
Full owner bodies execute. VM stack, typed lookup, ctor/template/destructor,
repository/encumbrance/possession/area helpers are captured substitutes.
Fresh acquire uses INVALID source/destination, no old owner; no claim of
transfer, property loading, full inventory drop or packet parity.
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
actor,item,existing,info,vm,command,repo,reference,vt,strings=[heap+n*0x1000 for n in range(10)]
def i(a):return int.from_bytes(u.mem_read(a,4),'little')
def q(a):return int.from_bytes(u.mem_read(a,8),'little')
def wi(a,v):u.mem_write(a,struct.pack('<I',v&0xffffffff))
def wq(a,v):u.mem_write(a,struct.pack('<Q',v))
def signed(v):return struct.unpack('<i',struct.pack('<I',v&0xffffffff))[0]
def finish(v=0):
    rsp=u.reg_read(UC_X86_REG_RSP);u.reg_write(UC_X86_REG_RIP,q(rsp));u.reg_write(UC_X86_REG_RSP,rsp+8);u.reg_write(UC_X86_REG_RAX,v&0xffffffffffffffff)
case={};calls=[];pushed=None;string_index=0
def mutate(ref):wq(ref,0 if case['mutation']=='null' else existing if case['mutation']=='existing' else q(ref))
def hook(u,a,n,_):
    global pushed,string_index
    if a==stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
    if a in [0x140c10370,0x140c10410]:finish()
    elif a==0x1402861b0:
        wq(y,strings if string_index==0 else 0);wi(y+8,4 if string_index==0 else 0);string_index+=1;finish(1)
    elif a==0x140286160:wi(y,11);finish(1)
    elif a==0x140286110:wi(y,case['stack']);finish(1)
    elif a==0x140286470:pushed=y&0xffffffff;finish(1)
    elif a==0x14055b850:finish(vm)
    elif a==0x140296470:wq(z,actor);finish(0 if case['present'] else 1)
    elif a==0x14018ded0:finish(x)
    elif a==0x140c10324:finish(item)
    elif a==0x140462e90:calls.append(['construct',y&0xffffffff]);finish(item)
    elif a==0x14046a7c0:calls.append(['load']);finish(case['loaded'])
    elif a==0x14029ca00:finish(info if case['validBase'] else 0)
    elif a in [stop+0x108,stop+0x110,stop+0x118,stop+0x120]:finish(actor if case['type']=={stop+0x108:5,stop+0x110:9,stop+0x118:14,stop+0x120:6}[a] else 0)
    elif a==stop+0x100:calls.append(['destroy',i(x+0x50)]);finish()
    elif a in [0x1403cff30,0x1404b11d0,0x1404f9ea0,0x140463e80] and case['mode']=='create':
        calls.append(['acquire',{0x1403cff30:5,0x1404b11d0:9,0x1404f9ea0:14,0x140463e80:6}[a],signed(i(item+0x454))])
        if a!=0x1404f9ea0:mutate(y)
        finish(0) # Deliberately fail BOOL: wrapper must still return pointer ID.
    elif a==0x1404681d0:calls.append(['find',i(rsp+0x28)]);u.mem_write(z,b'\1');u.mem_write(w,b'\2');finish(case['find'])
    elif a==0x140465c10:calls.append(['fit',z&255,w&255]);finish(case['fit'])
    elif a==0x14055b4c0:finish(0)
    elif a==0x140464200:calls.append(['add',z&255,w&255,i(rsp+0x28),i(rsp+0x30)]);mutate(y);finish(case['add'])
    elif a==0x1403db1e0:calls.append(['encumbrance',y&0xffffffff]);finish()
    elif a==0x14046b1d0:calls.append(['removeArea',i(x+0x50)]);finish()
    elif a==0x14046c520:calls.append(['possessor',i(x+0x50),y&0xffffffff,z&0xffffffff,w&0xffffffff,signed(i(rsp+0x28))]);wi(x+0x3c8,y);finish()
    elif not(0x1405138a0<=a<0x140513bd7 or 0x1403cff30<=a<0x1403d0222 or 0x14046c420<=a<0x14046c432):raise RuntimeError(f'Unmapped acquisition dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def reset():
    global calls,pushed,string_index
    calls=[];pushed=None;string_index=0;u.mem_write(heap,bytes(0x10000))
    wq(0x1412df8f8,vm);wq(0x1412df910,vm);wq(0x1412df970,vm);wq(vm+8,vm);wq(vm+0x20,vm);wi(command+8,1)
    u.mem_write(strings,b'item\0');wq(actor,vt);wi(actor+8,11);wq(actor+0x958,repo if case.get('repository',True) else 0)
    for offset,address in [(0,stop+0x100),(0x60,stop+0x108),(0x98,stop+0x110),(0xd0,stop+0x118),(0x70,stop+0x120)]:wq(vt+offset,address)
    for p,id in [(item,42),(existing,43)]:wq(p,vt);wi(p+0x50,id);wi(p+0x40,49);wi(p+0x3c8,0x7f000000);wi(p+0x454,1)
    wq(reference,item);u.mem_write(info+0x24,struct.pack('<H',case.get('maximum',99)))
def run(address,args,extra=[]):
    rsp=stack+0xff08;u.mem_write(rsp-0x600,bytes(0x680));wq(rsp,stop)
    for n,v in enumerate(extra):wq(rsp+0x28+n*8,v&0xffffffffffffffff)
    for reg,val in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[*args]):u.reg_write(reg,val)
    u.reg_write(UC_X86_REG_RSP,rsp);u.emu_start(address,stop,count=5000);assert u.reg_read(UC_X86_REG_RIP)==stop
    return u.reg_read(UC_X86_REG_RAX)&0xffffffff
created=[]
for kind,present,loaded,valid,maximum,quantity,mutation in itertools.product([5,9,14,6,10],[False,True],[0,1],[False,True],[0,1,99],[-1,0,1,100,65536],['keep','existing','null']):
    case=dict(mode='create',type=kind,present=present,loaded=loaded,validBase=valid,maximum=maximum,stack=quantity,mutation=mutation);reset();run(0x1405138a0,[command,0,4,0])
    created.append({'case':case,'result':pushed,'calls':calls,'stack':i(item+0x454),'droppable':i(item+0x448)})
acquired=[]
for repository,find,fit,add,x,y,mutation,feedback in itertools.product([False,True],[0,1],[0,1],[0,1],[0,255],[0,255],['keep','existing','null'],[0,1]):
    case=dict(mode='acquire',repository=repository,find=find,fit=fit,add=add,x=x,y=y,mutation=mutation,feedback=feedback,stack=17,type=5);reset();wi(item+0x454,17)
    result=run(0x1403cff30,[actor,reference,0x7f000000,0x7f000000],[x,y,1,feedback]);pointer=q(reference)
    acquired.append({'case':case,'result':result,'itemId':i(pointer+0x50) if pointer else None,'possessor':i(pointer+0x3c8) if pointer else None,'calls':calls})
identified=[]
for dirty,value in itertools.product([-1,0,1,2],[-2147483648,-1,0,1,2,2147483647]):
    case={};reset();wi(item+0x398,dirty);run(0x14046c420,[item,value&0xffffffff]);identified.append({'dirty':dirty,'value':value,'identified':signed(i(item+0x360)),'resultDirty':signed(i(item+0x398))})
output=root/'backups/animations/native-item-acquisition-observations.json'
output.write_text(json.dumps({'binarySha256':digest,'limits':__doc__,'created':created,'acquired':acquired,'identified':identified},indent=2));print(json.dumps({'output':str(output),'created':len(created),'acquired':len(acquired),'identified':len(identified)}))
