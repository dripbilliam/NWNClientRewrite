"""Original invisibility constructor51a3b0, apply42e490/remove4372d0,
concealment constructor518a70 and apply4280b0.
The complete original clearing copy constructor executes; VM/base allocation,
registry casts, module unique-list mutations and
child application are captured. Native enum/defaults, icon choice, source-ID
comparison and removal scan execute. No renderer/observer acceptance claim.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
from native_effect_copy_fixture import NativeEffectCopyFixture
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);actor,effect,ints,vt,app,stats,pool,module=[m.heap+n*0x2000 for n in range(1,9)]
copy_fixture=NativeEffectCopyFixture(m)
def snapshot(ptr):
    flags=int.from_bytes(u.mem_read(ptr+0xa,2),'little');return dict(id=f'{m.q(ptr):016x}',type=int.from_bytes(u.mem_read(ptr+8,2),'little'),subtype=flags&~7,durationType=flags&7,
      spellId=m.si(ptr+0x1c),creatorId=m.si(ptr+0x18)&0xffffffff,casterLevel=m.si(ptr+0x28),showIcon=m.si(ptr+0x24),exposed=m.si(ptr+0x20),integers=[m.si(m.q(ptr+0x48)+i*4) for i in range(8)])
def hook(u,a,n,_):
    global allocation,output,intReads
    if a==m.stop:u.emu_stop();return
    if copy_fixture.handle(a):return
    x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
    if a==m.stop+0x10:m.finish(actor if c.get('objectType',5)==5 else 0)
    elif a==0x14055b6e0:m.finish(module)
    elif a==0x140174af0:calls.append(['addInvisible',y&0xffffffff]);m.finish()
    elif a==0x1400b5450:calls.append(['removeInvisible',y&0xffffffff]);m.finish()
    elif a==0x140286110:
        value=([c.get('amount',50),c.get('kind',0)][intReads] if c['mode']=='concealConstructor' else c.get('kind',1));intReads+=1;m.wi(y,value);m.finish(1)
    elif a==0x1404953b0:m.finish(c.get('dead',0))
    elif a==0x140c10324:allocation+=1;m.finish(m.heap+0x60000+allocation*0x1000)
    elif a==0x1404233d0:
        m.wq(x,100);m.wq(x+0x48,x+0x200);m.wi(x+0x18,0x7f000000);m.wi(x+0x1c,-1);m.wi(x+0x28,-1);m.wi(x+0x20,1);m.wi(x+0x24,1);m.finish(x)
    elif a==0x140425110:m.wi(x+0x18,y);m.finish()
    elif a==0x140286330:output=snapshot(z);m.finish(1)
    elif a in [0x140423770,0x140c10360]:m.finish()
    elif a==0x14048e350:calls.append(['apply',snapshot(y),z&0xffffffff]);m.finish(1)
    elif not any(lo<=a<hi for lo,hi in [(0x140518a70,0x140518bd0),(0x1404280b0,0x140428197),(0x14051a3b0,0x14051a4c3),(0x14042e490,0x14042e5bc),(0x1404372d0,0x1404373bb),(0x140423fc0,0x140423fcb),(0x140425210,0x14042521c)]):raise AssertionError(f'Uncaptured invisibility dependency {a:x} {c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
    global c,calls,allocation,output,intReads
    c=case;calls=[];allocation=intReads=0;output=None;u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,app);m.wq(0x1412df910,app);m.wq(app+8,app);m.wi(app+0xc,99);m.wq(actor,vt);m.wq(vt+0x60,m.stop+0x10);m.wi(actor+8,99);m.wq(actor+0xad0,stats);m.wq(actor+0x150,pool);m.wi(actor+0x158,len(c.get('effects',[])))
    for i,e in enumerate(c.get('effects',[])):
        ptr=effect if e.get('samePointer') else m.heap+0x30000+i*0x200;m.wq(pool+i*8,ptr)
        if ptr!=effect:m.wq(ptr,e.get('id',10+i));u.mem_write(ptr+8,struct.pack('<H',e['type']))
    first=next((i for i,e in enumerate(c.get('effects',[])) if e.get('type',47)>=47),len(c.get('effects',[])));u.mem_write(stats+0xda2,struct.pack('<H',first))
    m.wq(effect,77);m.wq(effect+0x48,ints);u.mem_write(effect+8,struct.pack('<HH',47,8|(c.get('durationType',2)&7)));m.wi(effect+0x20,1);m.wi(effect+0x24,c.get('showIcon',1));m.wi(effect+0x18,98);m.wi(effect+0x1c,11);m.wi(effect+0x28,7);m.wi(ints,c.get('kind',1));m.wi(ints+4,28);rsp=m.stack+0x1fe08;u.mem_write(rsp-0x300,bytes(0x400));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
    if c['mode']=='concealApply':u.mem_write(effect+8,struct.pack('<H',76));m.wi(ints,c.get('amount',50))
    regs=[app,457,1,0] if c['mode']=='constructor' else [app,458,c.get('argc',2),0] if c['mode']=='concealConstructor' else [app,actor,effect,c.get('loading',0)]
    for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],regs):u.reg_write(reg,value)
    copy_fixture.prepare(effect);u.emu_start(dict(concealConstructor=0x140518a70,concealApply=0x1404280b0,constructor=0x14051a3b0,apply=0x14042e490,remove=0x1404372d0)[c['mode']],m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
    return dict(case=c,calls=calls,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,output=output)
rows=[]
for kind in [-3,0,1,2,3,4,5,2147483647]:rows.append(run(dict(mode='constructor',kind=kind)))
for kind,objectType,showIcon,loading in itertools.product([-1,1,2,4],[5,9],[0,1],[0,1]):rows.append(run(dict(mode='apply',kind=kind,objectType=objectType,showIcon=showIcon,loading=loading)))
for kind,objectType in itertools.product([47,63,46,64],[5,9]):
    for effects in [[],[dict(type=kind,id=77)],[dict(type=kind,id=78)],[dict(type=47,samePointer=True),dict(type=63,id=78)]]:rows.append(run(dict(mode='remove',objectType=objectType,effects=sorted(effects,key=lambda e:e['type']))))
for amount,kind,argc in itertools.product([-1,0,1,50,100,101,2147483647],[-1,0,1,2,3],[1,2]):rows.append(run(dict(mode='concealConstructor',amount=amount,kind=kind,argc=argc)))
for amount,loading,dead,duration in itertools.product([0,1,50,100,101],[0,1],[0,1],[0,1,2,3,4]):rows.append(run(dict(mode='concealApply',amount=amount,loading=loading,dead=dead,durationType=duration)))
out=m.root/'backups/animations/native-invisibility-concealment-observations-v2.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,copyConstructorExecutions=copy_fixture.executions,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),copies=copy_fixture.executions,output=str(out))))
