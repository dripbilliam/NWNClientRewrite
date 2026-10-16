"""Original enchantment8 and internal state9 apply/removal handlers.
The complete original clearing copy constructor executes.
Captured lower owners: allocation/base constructors, object casts,
immunity/feedback, action clearing, ambient recomputation, nested effects,
association/reputation queries. Native branches, field writes, ordering and
child payloads execute; this is not a full association or animation oracle.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
from native_effect_copy_fixture import NativeEffectCopyFixture
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);actor,source,effect,ints,pool,storage,vtable,app,stats,sourceStats=m.heap,m.heap+0x1000,m.heap+0x2000,m.heap+0x3000,m.heap+0x4000,m.heap+0x5000,m.heap+0x8000,m.heap+0x9000,m.heap+0xa000,m.heap+0xb000
copy_fixture=NativeEffectCopyFixture(m)

def snapshot(ptr):
    flags=int.from_bytes(u.mem_read(ptr+0xa,2),'little')
    return dict(id=f'{m.q(ptr):016x}',type=int.from_bytes(u.mem_read(ptr+8,2),'little'),subtype=flags&~7,durationType=flags&7,
      spellId=m.si(ptr+0x1c),creatorId=m.si(ptr+0x18)&0xffffffff,casterLevel=m.si(ptr+0x28),showIcon=m.si(ptr+0x24),exposed=m.si(ptr+0x20),integers=[m.si(m.q(ptr+0x48)+i*4) for i in range(8)])
def erase(id):
    rows=[m.q(pool+i*8) for i in range(m.si(actor+0x158))];rows=[ptr for ptr in rows if m.q(ptr)!=id]
    m.wi(actor+0x158,len(rows))
    for i,ptr in enumerate(rows):m.wq(pool+i*8,ptr)
def hook(u,a,n,_):
    global allocation,ids
    if a==m.stop:u.emu_stop();return
    if copy_fixture.handle(a):return
    x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
    if a==m.stop+0x10:m.finish(actor if c.get('objectType',5)==5 else 0)
    elif a==0x1404953b0:m.finish(c.get('dead',0))
    elif a==0x14055b3d0:m.finish(source if c.get('sourceExists',True) else 0)
    elif a==0x140400ab0:calls.append(['immunity',y&255]);m.finish(c.get('immunities',{}).get(str(y&255),0))
    elif a==0x140c10324:allocation+=1;m.finish(m.heap+0x10000+allocation*0x1000)
    elif a==0x1404233d0:
        ids+=1;m.wq(x,100+ids);m.wq(x+0x48,x+0x200);m.wi(x+0x20,1);m.wi(x+0x24,1);m.wi(x+0x1c,-1);m.wi(x+0x28,-1);m.wi(x+0x18,0x7f000000);m.finish(x)
    elif a==0x140425110:m.wi(x+0x18,y);m.finish()
    elif a==0x14048e350:calls.append(['apply',snapshot(y),z&0xffffffff]);m.finish(1)
    elif a==0x140498280:calls.append(['remove',f'{y:016x}']);erase(y);m.finish()
    elif a==0x1402da770:messages[x]=dict(objectIds=[z&0xffffffff]);m.finish()
    elif a==0x1402d5210:messages[y]=dict(messages[x]);m.finish()
    elif a==0x1403ab1a0:messages[x]={};m.finish(x)
    elif a==0x1403a2480:calls.append(['feedback',99 if x==actor else 98,y&65535,messages[z]]);m.finish()
    elif a==0x140439ae0:calls.append(['floaty',y&0xffffffff,z&0xffffffff]);m.finish()
    elif a==0x140490b80:calls.append(['clearActions',m.si(actor+0xec)]);m.finish()
    elif a==0x14039db40:calls.append(['ambient']);m.finish()
    elif a==0x14049b070:calls.append(['setLock',y&0xffffffff,z&0xffffffff]);m.finish()
    elif a in [0x1403d3680,0x1403d0c50,0x1403d0410,0x1403d51d0,0x1403d9190,0x1403d70f0,0x1403d7390,0x14038b0c0,0x1403d54d0,0x1403d3760,0x1403dba50]:
        calls.append([f'owner{a:x}',99 if x==actor else 98,y&0xffffffff,z&0xffffffff]);m.finish(0)
    elif a==0x140494e80:m.finish(0)
    elif not any(lo<=a<hi for lo,hi in [(0x140431730,0x1404324fe),(0x140432500,0x140432eaf),(0x140438470,0x140438623),(0x140438630,0x1404387e9),(0x1402ae870,0x1402ae899),(0x140423fc0,0x140423fcb),(0x140425210,0x14042521c)]):raise AssertionError(f'Uncaptured enchantment dependency {a:x} case={c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
    global c,calls,allocation,ids,messages
    c=case;calls=[];allocation=ids=0;messages={};u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,app);m.wq(app+8,app);m.wq(actor,vtable);m.wq(vtable+0x60,m.stop+0x10);m.wi(actor+8,99);m.wi(source+8,98);m.wq(actor+0xad0,stats);m.wq(source+0xad0,sourceStats);m.wi(sourceStats+0xb0,c.get('sourcePC',0));m.wi(actor+0xfc,c.get('plot',0));m.wi(actor+0xec,c.get('commandable',1));u.mem_write(actor+0x771,bytes([c.get('state',0)&255]));m.wi(actor+0x8b8,c.get('immuneAll',0));u.mem_write(actor+0x908,struct.pack('<H',c.get('associate',0)));m.wi(actor+0x8fc,98);m.wq(actor+0x150,pool);m.wi(actor+0x158,len(c.get('effects',[])))
    for i,e in enumerate(c.get('effects',[])):
        ptr=effect if e.get('samePointer') else storage+i*0x200
        if ptr!=effect:m.wq(ptr,e.get('id',10+i));u.mem_write(ptr+8,struct.pack('<H',e['type']));m.wq(ptr+0x48,ptr+0x100);m.wi(ptr+0x100,e.get('kind',0));m.wi(ptr+0x18,98)
        m.wq(pool+i*8,ptr)
    m.wq(effect,77);m.wq(effect+0x48,ints);u.mem_write(effect+8,struct.pack('<HH',c.get('type',8),c.get('subtype',8)|(c.get('durationType',2)&7)));m.wi(effect+0x20,1);m.wi(effect+0x24,c.get('showIcon',1));m.wi(effect+0x18,98);m.wi(effect+0x1c,c.get('spellId',11));m.wi(effect+0x28,7);m.wi(effect+0x108,c.get('bypass',0));m.wi(ints,c.get('kind',9));m.wi(ints+4,c.get('integer1',0))
    rsp=m.stack+0x1fe08;u.mem_write(rsp-0x300,bytes(0x400));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
    entry={'apply':0x140431730,'remove':0x140438470,'controller':0x140432500,'controllerRemove':0x140438630}[c['mode']]
    for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[app,actor,effect,c.get('loading',0)]):u.reg_write(reg,value)
    copy_fixture.prepare(effect);u.emu_start(entry,m.stop,count=15000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
    return dict(case=c,calls=calls,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,state=u.mem_read(actor+0x771,1)[0],commandable=m.si(actor+0xec),field54c=m.si(actor+0x54c),field550=m.si(actor+0x550))
rows=[]
for mode,kind in itertools.product(['apply','controller','controllerRemove'],range(0,23)):rows.append(run(dict(mode=mode,type=9 if mode!='apply' else 8,kind=kind)))
for kind,loading,dead,duration in itertools.product([1,3,5,6,7,8,9,20,21],[0,1],[0,1],[2,3,4]):rows.append(run(dict(mode='apply',kind=kind,loading=loading,dead=dead,durationType=duration)))
for kind,immune,bypass in itertools.product(range(1,10),[1,2],[0,1]):rows.append(run(dict(mode='apply',kind=kind,immunities={str(i):immune for i in range(32)},bypass=bypass)))
for kind,state,associate in itertools.product([1,5,7,9,20,21],[0,5,9,21],[0,1,5,6]):rows.append(run(dict(mode='apply',kind=kind,state=state,associate=associate,sourcePC=1)))
for effects in [[],[dict(type=8,kind=9,id=77)],[dict(type=8,kind=9,samePointer=True)],[dict(type=8,kind=5),dict(type=8,kind=9),dict(type=9)],[dict(type=8,kind=-1),dict(type=9)]]:rows.append(run(dict(mode='remove',effects=effects)))
for key,values in [('objectType',[4,6]),('plot',[1]),('immuneAll',[1]),('sourceExists',[False]),('subtype',[16]),('integer1',[1])]:
    for kind,value in itertools.product([1,5,7,9,20,21],values):rows.append(run(dict(mode='apply',kind=kind,**{key:value})))
out=m.root/'backups/animations/native-enchantment-effect-observations-v2.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,copyConstructorExecutions=copy_fixture.executions,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),copies=copy_fixture.executions,output=str(out))))
