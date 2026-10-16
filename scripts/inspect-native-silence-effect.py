"""Original silence apply432f10/remove4387f0. Registry/casts, immunity,
feedback, allocation and child application are captured lower boundaries.
The complete original clearing copy constructor executes.
Native admission, child payloads, copy flags/order and75c writes execute.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
from native_effect_copy_fixture import NativeEffectCopyFixture
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);actor,source,effect,ints,vt,app,stats=[m.heap+n*0x1000 for n in range(1,8)]
copy_fixture=NativeEffectCopyFixture(m)
def snapshot(ptr):
    flags=int.from_bytes(u.mem_read(ptr+0xa,2),'little');return dict(id=f'{m.q(ptr):016x}',type=int.from_bytes(u.mem_read(ptr+8,2),'little'),subtype=flags&~7,durationType=flags&7,
      spellId=m.si(ptr+0x1c),creatorId=m.si(ptr+0x18)&0xffffffff,casterLevel=m.si(ptr+0x28),showIcon=m.si(ptr+0x24),exposed=m.si(ptr+0x20),integers=[m.si(m.q(ptr+0x48)+i*4) for i in range(8)])
def hook(u,a,n,_):
    global allocation
    if a==m.stop:u.emu_stop();return
    if copy_fixture.handle(a):return
    x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
    if a==m.stop+0x10:m.finish(actor if c.get('objectType',5)==5 else 0)
    elif a==0x1404953b0:m.finish(c.get('dead',0))
    elif a==0x14055b3d0:m.finish(source if c.get('sourceExists',True) else 0)
    elif a==0x140400ab0:calls.append(['immunity',y&255]);m.finish(c.get('immune',0))
    elif a==0x140c10324:allocation+=1;m.finish(m.heap+0x10000+allocation*0x1000)
    elif a==0x14048e350:calls.append(['apply',snapshot(y),z&0xffffffff]);m.finish(1)
    elif a==0x1402da770:messages[x]=dict(objectIds=[z&0xffffffff]);m.finish()
    elif a==0x1402d5210:messages[y]=dict(messages[x]);m.finish()
    elif a==0x1403a2480:calls.append(['feedback',99 if x==actor else 98,y&65535,messages[z]]);m.finish()
    elif not any(lo<=a<hi for lo,hi in [(0x140432f10,0x140433182),(0x1404387f0,0x140438825),(0x140425210,0x14042521c)]):raise AssertionError(f'Uncaptured silence dependency {a:x} {c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
    global c,calls,allocation,messages
    c=case;calls=[];allocation=0;messages={};u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,app);m.wq(app+8,app);m.wq(actor,vt);m.wq(vt+0x60,m.stop+0x10);m.wi(actor+8,99);m.wi(source+8,98);m.wq(actor+0xad0,stats);m.wi(actor+0xfc,c.get('plot',0));m.wi(actor+0x75c,c.get('silenced',0))
    m.wq(effect,77);m.wq(effect+0x48,ints);u.mem_write(effect+8,struct.pack('<HH',46,8|(c.get('durationType',2)&7)));m.wi(effect+0x20,1);m.wi(effect+0x24,c.get('showIcon',1));m.wi(effect+0x18,98);m.wi(effect+0x1c,11);m.wi(effect+0x28,7);m.wi(effect+0x108,c.get('bypass',0));rsp=m.stack+0x1fe08;u.mem_write(rsp-0x300,bytes(0x400));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
    for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[app,actor,effect,c.get('loading',0)]):u.reg_write(reg,value)
    copy_fixture.prepare(effect);u.emu_start(0x1404387f0 if c.get('remove',False) else 0x140432f10,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
    return dict(case=c,calls=calls,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,silenced=m.si(actor+0x75c))
rows=[]
for loading,dead,duration,kind,plot in itertools.product([0,1],[0,1],[0,1,2,3,4],[5,9],[0,1]):rows.append(run(dict(loading=loading,dead=dead,durationType=duration,objectType=kind,plot=plot)))
for immune,bypass,sourceExists,showIcon in itertools.product([0,1,2],[0,1],[False,True],[0,1]):rows.append(run(dict(immune=immune,bypass=bypass,sourceExists=sourceExists,showIcon=showIcon)))
for kind,silenced in itertools.product([5,9],[0,1,2]):rows.append(run(dict(remove=True,objectType=kind,silenced=silenced)))
out=m.root/'backups/animations/native-silence-effect-observations-v2.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,copyConstructorExecutions=copy_fixture.executions,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),copies=copy_fixture.executions,output=str(out))))
