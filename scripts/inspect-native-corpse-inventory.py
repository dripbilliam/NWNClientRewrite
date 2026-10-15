"""Read-only original corpse GetItemCount and script Get/SetLootable.
Native arithmetic, physical slot traversal and query gates execute unchanged.
Repository/inventory/VM and dead/dying/possessed helpers are captured.
"""
import importlib.util,itertools,json,re
from pathlib import Path
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);q,si,wi,wq,finish=[getattr(m,n) for n in ['q','si','wi','wq','finish']]
actor,inventory,repo,listOwner,nodes,items=[m.heap+n*0x1000 for n in range(6)];ranges=[]
for line in (m.root/'backups/animations/live-native-corpse-itemcount-lootable-asm.txt').read_text().splitlines():
    if line.startswith('FUNCTION REQUESTED'):ranges.extend((int(a,16),int(b,16)) for a,b in re.findall(r'([0-9a-f]+):([0-9a-f]+)',line))
def hook(u,a,n,_):
    if a==m.stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
    if a in [0x14040ff6d,0x1404100da,0x140410504]:u.emu_stop();return
    if a in [0x1401a0f60,0x1401a1510,0x1401a0ee0]:
        rsp=u.reg_read(UC_X86_REG_RSP);name=bytes(u.mem_read(z,40)).split(b'\0')[0].decode();default=si(rsp+0x28);value=c['data'].get(name,default);wi(w,int(name in c['data']))
        if a==0x1401a1510:value&=0xffffffff
        elif a==0x1401a0ee0:value&=255
        else:value=int((value&255)!=0)
        finish(value)
    elif a==0x140462bd0:
        calls.append(['slot',y]);index=c['slots'].get(str(y),-1);finish(items+index*0x500 if index>=0 else 0)
    elif a==0x1404693e0:
        index=(y-nodes)//16;calls.append(['repositoryItem',index]);item=c['repository'][index];finish(items+item*0x500 if item>=0 else 0)
    elif a==0x140169110:
        index=(q(y)-nodes)//16+1;wq(y,nodes+index*16 if index<len(c['repository']) else 0);finish()
    elif a==0x140286160:wi(y,77);finish(1)
    elif a==0x140286110:wi(y,c['value']);finish(1)
    elif a==0x140286410:calls.append(['result',y if y<0x80000000 else y-0x100000000]);finish(1)
    elif a==0x14055b3d0:calls.append(['creature',y]);finish(actor if c.get('exists',1) else 0)
    elif a in [0x1404953b0,0x140495620,0x1403d54d0]:
        name={0x1404953b0:'dead',0x140495620:'dying',0x1403d54d0:'possessed'}[a];calls.append([name]);finish(c[name])
    elif not any(lo<=a<hi for lo,hi in ranges) and not 0x14040ff47<=a<0x1404100da and not 0x1404104d8<=a<0x140410504:raise RuntimeError(f'Unmapped corpse inventory dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
    global c,calls
    c=case;calls=[];u.mem_write(m.heap,bytes(0x100000));wq(0x1412df970,m.heap+0x9000)
    wi(actor+0x898,c.get('gold',0));wi(actor+0x4e8,c.get('old',0));wi(actor+0x89c,c.get('pc',0));wq(actor+0x950,inventory if c.get('equipment',0) else 0);wq(actor+0x958,repo if c.get('carried',0) else 0);wq(repo+0x10,listOwner);wq(listOwner,nodes if c.get('repository',[]) else 0)
    for n,v in enumerate(c.get('droppable',[])):wi(items+n*0x500+0x448,v)
    rsp=m.stack+0x1fe08;u.mem_write(rsp-0x100,bytes(0x200));wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,actor);u.reg_write(UC_X86_REG_RDX,c.get('filter',0))
    entry={'count':0x1403916b0,'get':0x14052b590,'set':0x1405436e0}[c['mode']]
    try:u.emu_start(entry,m.stop,count=10000)
    except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
    return dict(case=c,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,calls=calls,lootable=si(actor+0x4e8))
default=dict(mode='count',equipment=1,carried=1,slots={'1':0,'16':1,'8192':2,'16384':3},repository=[0,1,-1,2],droppable=[1,0,-1,1],gold=0,filter=0)
def run_import(case):
    global c,calls
    c=case;calls=[];u.mem_write(m.heap,bytes(0x100000));wq(inventory+0x30,actor);wi(inventory+0xb0,c['pc']);u.mem_write(actor+0x8a8,bytes([c['body']]))
    rsp=m.stack+0x1f000;u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_R14,inventory);u.reg_write(UC_X86_REG_R15,0);u.reg_write(UC_X86_REG_RBX,1)
    for lo,hi in [(0x14040ff47,0x14040ff6d),(0x14040ffd5,0x1404100da),(0x1404104d8,0x140410504)]:
        if lo==0x14040ffd5:u.reg_write(UC_X86_REG_RBX,1) # mov ebx,1 at14040ff89, before this bounded range.
        u.emu_start(lo,hi,count=2000);assert u.reg_read(UC_X86_REG_RIP)==hi
    return dict(case=c,lootable=si(actor+0x4e8),decay=int.from_bytes(u.mem_read(actor+0x4ec,4),'little'),destroyable=si(actor+0xf0),raiseable=si(actor+0xf4),selectable=si(actor+0xf8),noPermDeath=si(actor+0x8bc),body=u.mem_read(actor+0x8a8,1)[0])
rows=[run(default|dict(equipment=e,carried=r,gold=g,filter=flag)) for e,r,g,flag in itertools.product([0,1],[0,1],[0,1,-1],[0,1,2,-1])]
rows += [run(dict(mode='set',exists=exists,old=7,value=value,dead=dead,dying=dying,pc=pc,possessed=possessed)) for exists,value,dead,dying,pc,possessed in itertools.product([0,1],[-2,0,1,2],[0,1],[0,1],[0,1],[0,1])]
rows += [run(dict(mode='get',exists=exists,old=old)) for exists,old in itertools.product([0,1],[-1,0,1,2])]
imports=[run_import(dict(mode='import',pc=pc,body=body,data=data)) for pc,body,data in itertools.product([0,1,2],[0,3],[{},dict(Lootable=1),dict(Lootable=2,DecayTime=3000,IsDestroyable=0,IsRaiseable=0,DeadSelectable=0,NoPermDeath=1,BodyBag=257),dict(Lootable=0,DecayTime=-1,IsDestroyable=1,IsRaiseable=1,DeadSelectable=1,NoPermDeath=0,BodyBag=255),dict(Lootable=256,DecayTime=9000,IsDestroyable=256,IsRaiseable=2,DeadSelectable=2,NoPermDeath=256,BodyBag=-1)])]
out=m.root/'backups/animations/native-corpse-inventory-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows,imports=imports),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows),imports=len(imports))))
