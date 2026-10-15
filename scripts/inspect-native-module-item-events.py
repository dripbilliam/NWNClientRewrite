"""Read-only native module acquired/lost handler and getter oracle, build89.

Full EventHandler/RunEventScript/getter bodies execute with Tracy disabled.
Script-event accessors, VM script/stack, destruction and module lookup are
substituted/captured. Validates histories/context/dispatch, not event scripts,
VM cache/profiling semantics or full module lifecycle.
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
module,payload,vm=heap,heap+0x1000,heap+0x2000
def q(a):return struct.unpack('<Q',u.mem_read(a,8))[0]
def i(a):return struct.unpack('<I',u.mem_read(a,4))[0]
def wi(a,v):u.mem_write(a,struct.pack('<I',v&0xffffffff))
def wq(a,v):u.mem_write(a,struct.pack('<Q',v))
def finish(v=0):
    rsp=u.reg_read(UC_X86_REG_RSP);u.reg_write(UC_X86_REG_RIP,q(rsp));u.reg_write(UC_X86_REG_RSP,rsp+8);u.reg_write(UC_X86_REG_RAX,v&0xffffffffffffffff)
case={};scripts=[];event_calls=[];pushed=None;present=True
def hook(u,a,n,_):
    global pushed
    if a==stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
    if a==0x1404c6b10:finish(case['objects'][y] if y<len(case['objects']) else 0x7f000000)
    elif a==0x1404c6af0:finish(case['quantity'])
    elif a==0x140283990:
        name={module+0x228:'acq',module+0x238:'lost',module+0x2a8:'equip',module+0x2b8:'unequip'}[y];scripts.append({'name':name,'objectId':z,'context':i(u.reg_read(UC_X86_REG_RSP)+0x28),'valid':w});finish(1)
    elif a in [0x1404c64d0,0x140c10360,0x140c10370]:finish()
    elif a==0x14055b6e0:finish(module if present else 0)
    elif a in [0x140286410,0x140286470]:
        pushed=(y&0x7fffffff)-(y&0x80000000) if a==0x140286410 else y&0xffffffff;finish(1)
    elif a==0x140484d70:event_calls.append(y)
    elif not(0x14047c0b0<=a<0x14047d1d5 or 0x140484d70<=a<0x140484ddb or 0x14052bb70<=a<0x14052bc69):
        raise RuntimeError(f'Unmapped module item dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(address,args):
    rsp=stack+0xff08;u.mem_write(rsp-0x500,bytes(0x580));wq(rsp,stop)
    for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[module,*args]):u.reg_write(reg,value)
    u.reg_write(UC_X86_REG_RSP,rsp);u.emu_start(address,stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==stop
observations=[]
cells={'nativeAcquiredItem34c':0x34c,'nativeAcquiredFrom350':0x350,'nativeAcquiredBy354':0x354,'nativeLostItem358':0x358,'nativeLostBy35c':0x35c,'nativeAcquiredQuantity360':0x360,'nativeLostQuantity364':0x364}
for event_type,caller,objects,quantity,names,script_type in itertools.product([19,20],[0,21,0x80000001],[[],[0x80000002,31,22]],[-5,0,5],[0,1,2,3],[3,259]):
    case={'type':event_type,'caller':caller,'objects':objects,'quantity':quantity,'names':names,'scriptType':script_type};scripts=[];event_calls=[]
    u.mem_write(heap,bytes(0x10000));u.mem_write(0x14141e310,b'\0');wq(0x1412df910,vm);wq(0x1412df970,vm)
    wi(module+0x30,11);u.mem_write(module+0x34,bytes([script_type&255]));u.mem_write(payload,struct.pack('<H',event_type))
    for index,offset in enumerate(cells.values()):wi(module+offset,100+index)
    wi(module+0x230,3 if names&1 else 0);wi(module+0x240,4 if names&2 else 0)
    run(0x14047c0b0,[10,caller,payload])
    history={name:(i(module+offset)&0x7fffffff)-(i(module+offset)&0x80000000) if offset in [0x360,0x364] else i(module+offset) for name,offset in cells.items()}
    getters={}
    for present in [False,True]:
        for ordinal in [282,283,292,293,579,707,0]:
            pushed=None;run(0x14052bb70,[ordinal,0]);getters[f'{int(present)}:{ordinal}']=pushed
    observations.append({'case':case,'result':{'history':history,'scripts':scripts,'eventCalls':event_calls,'getters':getters}})
output=root/'backups/animations/native-module-item-event-observations.json'
output.write_text(json.dumps({'binarySha256':digest,'limits':__doc__,'observations':observations},indent=2))
print(json.dumps({'output':str(output),'observations':len(observations)}))
observations=[]
cells={'nativeEquippedItem368':0x368,'nativeEquippedBy36c':0x36c,'nativeUnequippedItem370':0x370,'nativeUnequippedBy374':0x374,'nativeEquippedSlot378':0x378}
for event_type,objects,quantity,names in itertools.product([39,40],[[],[0x80000002,31]],[-1,0,17],[0,1,2,3]):
    case={'type':event_type,'objects':objects,'quantity':quantity,'names':names};scripts=[];event_calls=[]
    u.mem_write(heap,bytes(0x10000));u.mem_write(0x14141e310,b'\0');wq(0x1412df910,vm)
    wi(module+0x30,11);u.mem_write(module+0x34,b'\3');u.mem_write(payload,struct.pack('<H',event_type))
    for index,offset in enumerate(cells.values()):wi(module+offset,100+index)
    wi(module+0x2b0,5 if names&1 else 0);wi(module+0x2c0,7 if names&2 else 0)
    run(0x14047c0b0,[10,21,payload])
    history={name:((i(module+offset)&0x7fffffff)-(i(module+offset)&0x80000000) if offset==0x378 else i(module+offset)) for name,offset in cells.items()}
    observations.append({'case':case,'result':{'history':history,'scripts':scripts,'eventCalls':event_calls}})
output=root/'backups/animations/native-module-equipment-event-observations.json'
output.write_text(json.dumps({'binarySha256':digest,'limits':__doc__,'observations':observations},indent=2));print(json.dumps({'output':str(output),'observations':len(observations)}))
