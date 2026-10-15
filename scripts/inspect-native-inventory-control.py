"""Read-only build89 RemoveItem/RemoveItemFromRepository/RepositoryRemove,
ClearActivities and creature inventory disturbance event/getter observations.
Full owner bodies execute with synthetic objects. Lookup, repository primitives,
equipment/unequip, weight, possession, quickbar, event accessor, hostile and VM
helpers are captured substitutions; not their native lifecycle or packet proof.
Creature event inputs are already spawned (548=1), skipping common perception
spawn processing before the event-specific dispatch.
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
u.mem_map(heap,0x20000);u.mem_map(stack,0x10000);u.mem_map(stop,0x1000)
actor,item,owner,repo,bagrepo,vt,info,pool,payload,vm,script=[heap+n*0x2000 for n in range(11)]
def i(a):return int.from_bytes(u.mem_read(a,4),'little')
def q(a):return int.from_bytes(u.mem_read(a,8),'little')
def wi(a,v):u.mem_write(a,struct.pack('<I',v&0xffffffff))
def wq(a,v):u.mem_write(a,struct.pack('<Q',v))
def signed(v):return struct.unpack('<i',struct.pack('<I',v&0xffffffff))[0]
def finish(v=0):
    rsp=u.reg_read(UC_X86_REG_RSP);u.reg_write(UC_X86_REG_RIP,q(rsp));u.reg_write(UC_X86_REG_RSP,rsp+8);u.reg_write(UC_X86_REG_RAX,v&0xffffffffffffffff)
def hook(u,a,n,_):
    global pushed
    if a==stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
    if a in [0x140c10360,0x140c10370,0x1404c64d0]:finish()
    elif a==0x140462b40:finish(c['equipped'])
    elif a==0x14039fff0:calls.append(['unequip',y&0xffffffff,z&0xffffffff,w&255,i(rsp+0x28)&255,signed(i(rsp+0x30)),i(rsp+0x38)]);finish()
    elif a==0x140468bd0:finish(c['contains'])
    elif a==0x14046b250 and c['mode']!='repository':calls.append(['remove',11 if x==repo else 22]);finish(c['removed'])
    elif a==0x1403db1e0:calls.append(['weight',11 if x==actor else 22,y&0xffffffff]);finish()
    elif a==0x14046c520:calls.append(['possessor',y&0xffffffff,z&0xffffffff,w&0xffffffff,signed(i(rsp+0x28))]);wi(item+0x3c8,y);finish()
    elif a==0x14039bf80:calls.append(['quickbar',y&0xffffffff]);finish()
    elif a==0x14055b4c0:finish(owner if c.get('mode')!='event' and c.get('mode')!='get' else actor if c.get('present',True) else 0)
    elif a==0x14055b3d0:finish(actor if c['parentCreature'] else 0)
    elif a==stop+0x100:finish(x if c.get('ownerType',6)==6 else 0)
    elif a==stop+0x108:finish(x if c.get('objectCast',True) else 0)
    elif a==stop+0x110:finish(x)
    elif a==stop+0x118:finish(script)
    elif a==0x1401690b0:finish(y+0x20)
    elif a==0x140169110:wq(y,q(q(y)));finish()
    elif a==0x1401691f0:
        wi(repo+0x100+0x40,i(repo+0x100+0x40)-1)
        previous=0;current=q(repo+0x100)
        while current!=y:previous=current;current=q(current)
        wq(previous if previous else repo+0x100,q(y));calls.append(['unlink',i(y+0x20)]);finish(y+0x20)
    elif a==0x14029ca00:finish(info)
    elif a==0x1403a2650:calls.append(['activity',y&0xffffffff,z&0xffffffff]);finish()
    elif a==0x14049b070:calls.append(['hostile',y&0xffffffff,z&0xffffffff]);finish()
    elif a==0x1404c6af0:finish(c['disturbType'])
    elif a==0x1404c6b10:finish(c['disturbItem'])
    elif a==0x140283990:calls.append(['script',z&0xffffffff,i(rsp+0x28)]);finish(1)
    elif a in [0x140286410,0x140286470]:pushed=signed(y) if a==0x140286410 else y&0xffffffff;finish(1)
    elif not any(start<=a<end for start,end in [(0x1403d7490,0x1403d7577),(0x14039eac0,0x14039eb81),(0x14046b250,0x14046b3d3),(0x1403877e0,0x140387b36),(0x14038d7d0,0x14038fe4b),(0x1404998a0,0x14049990c),(0x140526870,0x140526913),(0x140526920,0x1405269cd),(0x14052a120,0x14052a1e2)]):raise RuntimeError(f'Unmapped inventory control dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def reset(case):
    global c,calls,pushed
    c=case;calls=[];pushed=None;u.mem_write(heap,bytes(0x20000));u.mem_write(0x14141e310,b'\0')
    wq(0x1412df970,vm);wq(vm+8,vm);wq(0x1412df8f8,vm);wq(vm+0x20,info);wq(0x1412df910,vm)
    for p,id in [(actor,11),(item,33),(owner,22)]:wq(p,vt);wi(p+8,id);wi(p+0x50,id)
    for off,a in [(0x70,stop+0x100),(0x20,stop+0x108),(0x60,stop+0x110),(0x98,stop+0x110),(0x1e0,stop+0x118)]:wq(vt+off,a)
    u.mem_write(owner+0xc,bytes([c.get('ownerType',6)]));u.mem_write(actor+0xc,bytes([c.get('objectType',5)]))
    wi(item+0x3c8,c.get('possessor',11));wi(owner+0x3c8,c.get('parent',11));wq(actor+0x958,repo);wq(owner+0x3d0,bagrepo);wq(actor+0x4e0,pool if c.get('quickbar') else 0);wi(actor+0x548,1)
    wi(repo+8,22);wq(repo+0x10,repo+0x100)
    ids=c.get('ids',[]);wq(repo+0x100,repo+0x200 if ids else 0);wi(repo+0x140,len(ids))
    for k,id in enumerate(ids):link=repo+0x200+k*0x100;wq(link,link+0x100 if k+1<len(ids) else 0);wi(link+0x20,id)
    wi(info+0x80,c.get('container',0));wi(owner+0x370,len(c.get('properties',[])));wq(owner+0x368,pool)
    for k,t in enumerate(c.get('properties',[])):u.mem_write(pool+k*0x30,struct.pack('<H',t))
def run(address,args,extra=[]):
    rsp=stack+0xff08;u.mem_write(rsp-0x1000,bytes(0x1080));wq(rsp,stop)
    for k,v in enumerate(extra):wq(rsp+0x28+k*8,v&0xffffffffffffffff)
    for r,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[*args]):u.reg_write(r,v)
    u.reg_write(UC_X86_REG_RSP,rsp)
    try:u.emu_start(address,stop,count=10000)
    except Exception:print(json.dumps({'case':c,'rip':hex(u.reg_read(UC_X86_REG_RIP)),'calls':calls}));raise
    assert u.reg_read(UC_X86_REG_RIP)==stop;return u.reg_read(UC_X86_REG_RAX)&0xffffffff
removed=[]
for present,equipped,contains,possessor,parent,ownerType,skip,clear,quickbar in itertools.product([False,True],[0,1],[0,1],[11,22],[11,99],[5,6,9],[0,1],[0,1],[False,True]):
    reset(dict(mode='remove',present=present,equipped=equipped,contains=contains,possessor=possessor,parent=parent,ownerType=ownerType,removed=0,quickbar=quickbar,skip=skip,clear=clear))
    result=run(0x1403d7490,[actor,item if present else 0,2,3],[skip,clear]);removed.append({'case':c,'result':result,'possessor':i(item+0x3c8),'calls':calls})
repositories=[]
for ids,ownerType,container,parent,parentCreature,properties in itertools.product([[],[99,33,33],[99,44],[33,99,33],[33]],[5,6,9],[0,1,2],[11,0x7f000000],[False,True],[[],[1],[32],[1,32]]):
    reset(dict(mode='repository',ids=ids,ownerType=ownerType,container=container,parent=parent,parentCreature=parentCreature,properties=properties))
    result=run(0x14046b250,[repo,item]);remaining=[];link=q(repo+0x100)
    while link:remaining.append(i(link+0x20));link=q(link)
    repositories.append({'case':c,'result':result,'ids':remaining,'calls':calls})
activities=[]
for mask,active,locked in itertools.product([0,31,0xffffffff,0x1ffc00,0x40000],[0,31,0xffffffff,0x140000],[0,31,0xffffffff,0x40000]):
    reset(dict(mode='activities'));wi(actor+0x8e0,active);wi(actor+0x8e4,locked);run(0x1403877e0,[actor,mask]);activities.append({'mask':mask,'active':active,'locked':locked,'calls':calls})
events=[]
for caller,disturbType,disturbItem,hasScript in itertools.product([0,0x80000001],[-1,0,1],[0x7f000000,0x80000002],[False,True]):
    reset(dict(mode='event',disturbType=disturbType,disturbItem=disturbItem,hasScript=hasScript));u.mem_write(payload,struct.pack('<H',27));wi(script+8,3 if hasScript else 0)
    run(0x14038d7d0,[actor,10,caller,payload]);events.append({'case':c,'history':[i(actor+0x19c),i(actor+0x1b0),signed(i(actor+0x1b4))],'calls':calls})
getters=[]
for objectType,present,objectCast in itertools.product([3,5,6,9,10],[False,True],[False,True]):
    reset(dict(mode='get',objectType=objectType,present=present,objectCast=objectCast));wi(actor+0x19c,0x80000001);wi(actor+0x1b0,0x80000002);wi(actor+0x1b4,-1);wi(vm+0xc,11)
    values=[]
    for a in [0x14052a120,0x140526870,0x140526920]:run(a,[vm,0,0]);values.append(pushed)
    getters.append({'case':c,'values':values})
output=root/'backups/animations/native-inventory-control-observations.json';output.write_text(json.dumps({'binarySha256':digest,'limits':__doc__,'removed':removed,'repositories':repositories,'activities':activities,'events':events,'getters':getters},indent=2));print(json.dumps({'output':str(output),'removed':len(removed),'repositories':len(repositories),'activities':len(activities),'events':len(events),'getters':len(getters)}))
