"""Read-only original placeable acquisition and complete corpse collection.
Canonical lookup, item copy/construction, array storage, repository mutation,
gold template loading and acquisition are captured. Native ownership gates,
four copy slots, five-bucket order, UINT gold and successful count execute.
Does not prove CopyItem/property or actual destination acquisition owners.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);q,si,wi,wq,finish=[getattr(m,n) for n in ['q','si','wi','wq','finish']]
actor,source,app,objects,repo,inventory,repoList,nodes,ref,rules,vtable=[m.heap+n*0x1000 for n in range(11)]
items={id:m.heap+0x10000+id*0x1000 for id in range(1,21)};freshBase=m.heap+0x40000;baseInfos=m.heap+0x60000
definitions=[dict(id=n,width=w,height=h,droppable=n%2) for n,(w,h) in enumerate([(3,1),(2,4),(2,2),(1,4),(1,1),(0,0),(255,255),(2,3),(1,2),(4,4),(2,0),(0,5),(1,3),(3,2)],1)]
def idof(ptr):return si(ptr+0x50)&0xffffffff
def hook(u,a,n,_):
    global allocation
    if a==m.stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
    if a==0x14055b850:finish(objects)
    elif a==0x140296470:wq(z,source if c['ownerType'] else 0);finish(0 if c['ownerType'] else 1)
    elif a==0x14055b3d0:calls.append(['creature',y&0xffffffff]);finish(source if c['ownerType']==5 else 0)
    elif a==0x14055b890:calls.append(['placeable',y&0xffffffff]);finish(source if c['ownerType']==9 else 0)
    elif a in [m.stop+0x100,m.stop+0x108,m.stop+0x110]:finish(x)
    elif a==0x1403d7490:calls.append(['removeCreature',idof(y),z&0xffffffff,w&0xffffffff,si(rsp+0x28),si(rsp+0x30)]);finish(0)
    elif a==0x1404b69d0:calls.append(['removePlaceable',idof(y),z&0xffffffff]);finish(0)
    elif a==0x14046b250:calls.append(['removeRepository',idof(y)]);finish(0)
    elif a==0x14046b1d0:calls.append(['removeArea',idof(x)]);finish()
    elif a==0x14029ca00:
        if c['mode']=='acquire':calls.append(['baseOwner']);finish(baseInfos)
        else:calls.append(['base',y&0xffffffff]);finish(baseInfos+(y&0xffffffff)*0x100)
    elif a==0x140464200:
        calls.append(['add',idof(q(y)),z&255,w&255,si(rsp+0x28),si(rsp+0x30)]);wq(y,0 if c['nullAfter'] else items[2]);finish(c['result'])
    elif a==0x14046c520:calls.append(['possessor',idof(x),y&0xffffffff,z&0xffffffff,w&0xffffffff,si(rsp+0x28)]);finish()
    elif a==0x140462bd0:calls.append(['equipment',y&0xffffffff]);finish(items.get(c['equipment'].get(str(y&0xffffffff),0),0))
    elif a==0x140c11414:
        for index in range(5):wq(x+index*16,m.heap+0x70000+index*0x1000);wi(x+index*16+8,0);wi(x+index*16+12,128)
        finish()
    elif a==0x140c10434:finish()
    elif a==0x1403d0230:count=si(x+8);wq(q(x)+count*8,y);wi(x+8,count+1);finish()
    elif a==0x1404693e0:finish(items.get(c['repository'][(y-nodes)//32],0))
    elif a==0x140169110:index=(q(y)-nodes)//32+1;wq(y,nodes+index*32 if index<len(c['repository']) else 0);finish()
    elif a==0x140c10324:ptr=freshBase+allocation*0x1000;allocation+=1;finish(ptr)
    elif a==0x140462e90:
        id=80+allocation-1;wi(x+0x50,id);wi(x+0x3c8,0x7f000000);calls.append(['construct',id]);finish(x)
    elif a==0x140466910:calls.append(['copy',idof(x),idof(y),z&0xffffffff]);finish()
    elif a==0x1404b11d0 and c['mode']=='collect':calls.append(['acquire',idof(q(y)),z&0xffffffff,w&255,si(rsp+0x28)&255,si(rsp+0x30)]);finish(c['result'])
    elif a==0x14018ded0:u.mem_write(x,bytes(u.mem_read(y,17)));finish(x)
    elif a==0x14046a7c0:calls.append(['template',idof(x),bytes(u.mem_read(y,17)).split(b'\0')[0].decode(),z&0xffffffff]);finish(0)
    elif a==0x1403a3180:calls.append(['gold',y&0xffffffff]);wi(source+0x898,y);finish()
    elif a==0x140c10410:finish(u.reg_read(UC_X86_REG_RAX))
    elif not (0x1404b11d0<=a<0x1404b134e or 0x1404b1350<=a<0x1404b1879):raise RuntimeError(f'Unmapped corpse transfer dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
    global c,calls,allocation
    c=case;calls=[];allocation=0;u.mem_write(m.heap,bytes(0x100000));wq(0x1412df970,app);wq(app+8,app);wq(0x1412df8f8,rules);wq(rules+0x20,baseInfos);wi(actor+8,90);wi(source+8,77);u.mem_write(source+12,bytes([c['ownerType']]));wq(source,vtable);wq(vtable+0x60,m.stop+0x100);wq(vtable+0x98,m.stop+0x108);wq(vtable+0x70,m.stop+0x110)
    wq(actor+0x540,repo if c.get('destinationRepo',True) else 0);wq(source+0x950,inventory if c.get('hasEquipment',True) else 0);wq(source+0x958,repo if c.get('sourceRepo',True) else 0);wq(source+0x540,repo if c.get('sourceRepo',True) else 0);wq(source+0x3d0,repo);wq(repo+16,repoList)
    for row in definitions:
        id=row['id'];ptr=items[id];wi(ptr+0x50,id);wi(ptr+0x40,id);wi(ptr+0x448,row['droppable']);u.mem_write(baseInfos+id*0x100+0x14,bytes([row['width'],row['height']]))
    if c['mode']=='acquire':
        wi(items[1]+0x3c8,77 if c['matches'] else 78);wq(ref,items[1]);wi(baseInfos+0x80,c['container']);entry=0x1404b11d0;args=[actor,ref,77,255];extra=[254,2]
    else:
        wi(source+0x898,c['gold']);wq(repoList,nodes if c['repository'] else 0);entry=0x1404b1350;args=[actor,77,c['filter'],0];extra=[]
    rsp=m.stack+0x1fe08;u.mem_write(rsp-0x400,bytes(0x500));wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
    for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(reg,v&0xffffffffffffffff)
    for n,v in enumerate(extra):wi(rsp+0x28+n*8,v)
    try:u.emu_start(entry,m.stop,count=20000)
    except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
    assert u.reg_read(UC_X86_REG_RIP)==m.stop
    return dict(case=c,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,calls=calls,gold=si(source+0x898))
acquisitions=[run(dict(mode='acquire',ownerType=ownerType,matches=matches,container=container,destinationRepo=dest,result=result,nullAfter=nullAfter)) for ownerType,matches,container,dest,result,nullAfter in itertools.product([0,5,6,7,9],[False,True],[0,1,2],[False,True],[0,1,2],[False,True])]
equipment={str(1<<n):n+1 for n in range(14)}
collections=[run(dict(mode='collect',ownerType=ownerType,filter=filter,equipment=eq,repository=repository,gold=gold,sourceRepo=sourceRepo,hasEquipment=hasEquipment,result=result)) for ownerType,filter,eq,repository,gold,sourceRepo,hasEquipment,result in itertools.product([0,5,9],[0,1,2],[{},equipment],[[],[5,1,8,0,9,4]],[0,17,-1],[False,True],[False,True],[0,1,2])]
out=m.root/'backups/animations/native-corpse-transfer-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,definitions=definitions,acquisitions=acquisitions,collections=collections),indent=2));print(json.dumps(dict(output=str(out),acquisitions=len(acquisitions),collections=len(collections))))
