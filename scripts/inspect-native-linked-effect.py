"""Untouched SetLinked/UpdateLinked and OnApplyLink owners. Effect creator
attribution, custom string copy and child application are captured boundaries.
Recursion, subtype masks, ID/context propagation and child order/detachment
execute original instructions. No claim of full nested child effect handlers.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);root=m.heap+0x1000;actor=m.heap+0xa000
def snapshot(ptr):
    if not ptr:return None
    return dict(id=f'{m.q(ptr):016x}',subtype=int.from_bytes(u.mem_read(ptr+0xa,2),'little')&~7,durationType=int.from_bytes(u.mem_read(ptr+0xa,2),'little')&7,
      creatorId=m.si(ptr+0x18)&0xffffffff,spellId=m.si(ptr+0x1c),casterLevel=m.si(ptr+0x28),duration=m.rf(ptr+0xc),expiryDay=m.si(ptr+0x10)&0xffffffff,expiryTime=m.si(ptr+0x14)&0xffffffff,
      propertyId=f'{m.q(ptr+0xf0):016x}',customTag='tag' if m.q(ptr+0xf8) else '',bypassImmunity=m.si(ptr+0x108),showIcon=m.si(ptr+0x24),linkLeft=snapshot(m.q(ptr+0x30)),linkRight=snapshot(m.q(ptr+0x38)))
def hook(u,a,n,_):
    if a==m.stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
    if a==0x140425110:
        m.wi(x+0x18,y)
        if m.si(x+0x1c)==-1:m.wi(x+0x1c,70)
        if m.si(x+0x28)==-1:m.wi(x+0x28,8)
        m.finish()
    elif a==0x14003d8c0:m.wq(x,y if z else 0);m.wi(x+8,z);m.finish(x)
    elif a==0x14048e350:calls.append(dict(effect=snapshot(y),loading=z&0xffffffff,flag=w&0xffffffff));m.finish(1)
    elif a==0x140286030:m.wq(z,root);m.finish(1)
    elif a==0x140286330:m.finish(1)
    elif a in [0x140423770,0x140c10360]:m.finish()
    elif not any(lo<=a<hi for lo,hi in [(0x140544eb0,0x140544fad),(0x140425220,0x14042522f),(0x140425370,0x1404255ee),(0x14042ef20,0x14042ef92)]):raise AssertionError(f'Uncaptured linked effect dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
    global calls
    calls=[];u.mem_write(m.heap,bytes(0x100000));counter=0
    def store(node):
        nonlocal counter
        ptr=root+counter*0x200;counter+=1
        for off,value in [(0x18,node['creatorId']),(0x1c,node['spellId']),(0x28,node['casterLevel']),(0x10,node['expiryDay']),(0x14,node['expiryTime']),(0x108,node['bypassImmunity']),(0x24,node['showIcon'])]:m.wi(ptr+off,value)
        m.wq(ptr,int(node['id'],16));m.wq(ptr+0xf0,int(node['propertyId'],16));m.wf(ptr+0xc,node['duration']);u.mem_write(ptr+8,struct.pack('<HH',node.get('type',40),(node['subtype']|node['durationType'])&65535))
        if node['customTag']:m.wq(ptr+0xf8,m.heap+0xb000);m.wi(ptr+0x100,3)
        for off,key in [(0x30,'linkLeft'),(0x38,'linkRight')]:m.wq(ptr+off,store(node[key]) if node.get(key) else 0)
        return ptr
    store(case['effect']);rsp=m.stack+0x1fe08;u.mem_write(rsp-0x300,bytes(0x400));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
    if case['mode']=='update':entry=0x140425370;x,y,z,w=root,case['icons'],0,0
    elif case['mode']=='subtype':entry=0x140544eb0;x,y,z,w=actor,case['ordinal'],1,0
    else:entry=0x14042ef20;x,y,z,w=actor,actor,root,case['loading']
    for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[x,y,z,w]):u.reg_write(reg,value)
    u.emu_start(entry,m.stop,count=30000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
    return dict(case=case,effect=snapshot(root),calls=calls)
def node(id,subtype=0,**kwargs):return dict(id=f'{id:016x}',subtype=subtype,durationType=2,creatorId=35,spellId=-1,casterLevel=-1,duration=2,expiryDay=5,expiryTime=6,propertyId=f'{id+100:016x}',customTag='tag',bypassImmunity=1,showIcon=1,linkLeft=None,linkRight=None)|kwargs
rows=[]
for subtype,childSubtype,icons,depth in itertools.product([0,8,16,24,32,40],[0,8,16,24,32],[0,1],[1,2,3]):
    left=node(2,childSubtype,duration=7,showIcon=0)
    for n in range(depth-1):left=node(3+n,childSubtype,linkLeft=left,duration=9,showIcon=0)
    rows.append(run(dict(mode='update',icons=icons,effect=node(1,subtype,spellId=11,casterLevel=12,linkLeft=left,linkRight=node(10,childSubtype)))))
for loading,left,right in itertools.product([0,1],[None,node(2,16)],[None,node(3,24)]):rows.append(run(dict(mode='apply',loading=loading,effect=node(1,8,spellId=11,casterLevel=12,linkLeft=left,linkRight=right))))
for ordinal,type,subtype,duration in itertools.product([112,113,114,1036,0],[8,40],[0,8,16,24,32,40,64,248],range(8)):
    rows.append(run(dict(mode='subtype',ordinal=ordinal,effect=node(1,subtype,type=type,durationType=duration,linkLeft=node(2,24),linkRight=node(3,16)))))
out=m.root/'backups/animations/native-linked-effect-observations-v2.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
