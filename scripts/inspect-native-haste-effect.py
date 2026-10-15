"""Original visible Haste/Slow balance, hidden controller apply/remove.
Allocations/base and copy constructors, object casts, immunity/feedback,
nested effect apply/removal, and ruleset lookup are captured lower owners.
Native count/clamp/selection, fixed/rules fields, copy flags, ordering and
QWORD/DWORD760/764 writes execute. Full speed/AC/attack children are separate.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
from native_rule_fixture import ruleset_value
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);actor,source,effect,ints,pool,storage,vtable,app=m.heap,m.heap+0x1000,m.heap+0x2000,m.heap+0x3000,m.heap+0x4000,m.heap+0x5000,m.heap+0x8000,m.heap+0x9000
def snapshot(ptr):
    flags=int.from_bytes(u.mem_read(ptr+0xa,2),'little')
    return dict(id=f'{m.q(ptr):016x}',type=int.from_bytes(u.mem_read(ptr+8,2),'little'),subtype=flags&~7,durationType=flags&7,
      spellId=m.si(ptr+0x1c),creatorId=m.si(ptr+0x18)&0xffffffff,casterLevel=m.si(ptr+0x28),showIcon=m.si(ptr+0x24),exposed=m.si(ptr+0x20),integers=[m.si(m.q(ptr+0x48)+i*4) for i in range(8)])
def hook(u,a,n,_):
    global allocation,ids
    if a==m.stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
    if a==m.stop+0x10:m.finish(actor if c.get('objectType',5)==5 else 0)
    elif a==0x1404953b0:m.finish(c.get('dead',0))
    elif a==0x14055b3d0:m.finish(source if c.get('sourceExists',True) else 0)
    elif a==0x140400ab0:calls.append(['immunity',y&255]);m.finish(c.get('immune',0))
    elif a==0x140c10324:allocation+=1;m.finish(m.heap+0x10000+allocation*0x1000)
    elif a==0x1404233d0:
        ids+=1;m.wq(x,100+ids);m.wq(x+0x48,x+0x200);m.wi(x+0x20,1);m.wi(x+0x24,1);m.wi(x+0x1c,-1);m.wi(x+0x28,-1);m.wi(x+0x18,0x7f000000);m.finish(x)
    elif a==0x140423570:
        u.mem_write(x,bytes(u.mem_read(y,0x110)));m.wq(x+0x48,x+0x200);u.mem_write(x+0x200,bytes(u.mem_read(m.q(y+0x48),32)));m.wi(x+0x20,0);m.wi(x+0x24,m.si(y+0x24) if z else 0);m.finish(x)
    elif a==0x14048e350:calls.append(['apply',snapshot(y),z&0xffffffff,m.si(actor+0x760),m.si(actor+0x764)]);m.finish(1)
    elif a==0x140498280:calls.append(['remove',f'{y:016x}']);m.finish()
    elif a==0x1402da770:messages[x]=dict(objectIds=[z&0xffffffff]);m.finish()
    elif a==0x1402d5210:messages[y]=dict(messages[x]);m.finish()
    elif a==0x1403a2480:calls.append(['feedback',99 if x==actor else 98,y&65535,messages[z]]);m.finish()
    elif a==0x1402a4130:m.finish(ruleset_value(c.get('rulesOverrides',{}),y,z))
    elif not any(lo<=a<hi for lo,hi in [(0x14042d950,0x14042df04),(0x140436cb0,0x140436e90),(0x1404333c0,0x14043369a),(0x140436c80,0x140436ca6),(0x140438850,0x140438876),(0x1402ae870,0x1402ae899),(0x140425210,0x14042521c)]):raise AssertionError(f'Uncaptured haste dependency {a:x} case={c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
    global c,calls,allocation,ids,messages
    c=case;calls=[];allocation=ids=0;messages={};u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,app);m.wq(app+8,app);m.wq(actor,vtable);m.wq(vtable+0x60,m.stop+0x10);m.wi(actor+8,99);m.wi(source+8,98);m.wi(actor+0x760,c.get('hasted',0));m.wi(actor+0x764,c.get('slowed',0));m.wq(actor+0x150,pool);m.wi(actor+0x158,len(c.get('effects',[])))
    for i,type in enumerate(c.get('effects',[])):
        ptr=storage+i*0x100;m.wq(ptr,10+i);u.mem_write(ptr+8,struct.pack('<H',type));m.wq(pool+i*8,ptr)
    m.wq(effect,77);m.wq(effect+0x48,ints);u.mem_write(effect+8,struct.pack('<HH',c['type'],8|(c.get('durationType',2)&7)));m.wi(effect+0x20,1);m.wi(effect+0x24,c.get('showIcon',1));m.wi(effect+0x18,98);m.wi(effect+0x1c,11);m.wi(effect+0x28,7);m.wi(effect+0x108,c.get('bypass',0))
    rsp=m.stack+0x1fe08;u.mem_write(rsp-0x300,bytes(0x400));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
    entry={'apply':0x14042dba0,'remove':0x140436cb0,'controller':0x14042d950 if c['type']==41 else 0x1404333c0,'controllerRemove':0x140436c80 if c['type']==41 else 0x140438850}[c['mode']]
    for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[app,actor,effect,c.get('loading',0)]):u.reg_write(reg,value)
    u.emu_start(entry,m.stop,count=15000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
    return dict(case=c,calls=calls,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,hasted=m.si(actor+0x760),slowed=m.si(actor+0x764))
rows=[]
for mode,type,hastes,slows,controller in itertools.product(['apply','remove'],[1,3],range(4),range(4),[0,41,42]):rows.append(run(dict(mode=mode,type=type,effects=[1]*hastes+[3]*slows+([controller] if controller else []))))
for key,values in [('objectType',[4,6]),('dead',[1]),('immune',[1,2]),('bypass',[1]),('sourceExists',[False])]:
    for value in values:rows.append(run(dict(mode='apply',type=3,loading=1,**{key:value})))
for type,showIcon,speed,ac in itertools.product([41,42],[0,1],[0,100,101,150,300],[-1,0,4,20]):rows.append(run(dict(mode='controller',type=type,showIcon=showIcon,rulesOverrides={'HASTE_MOVEMENT_SPEED_INCREASE_BONUS':speed,'HASTE_DODGE_AC_INCREASE_AMOUNT':ac})))
for type,objectType,hasted,slowed in itertools.product([41,42],[4,5,6],[0,1],[0,1]):rows.append(run(dict(mode='controllerRemove',type=type,objectType=objectType,hasted=hasted,slowed=slowed)))
out=m.root/'backups/animations/native-haste-effect-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
